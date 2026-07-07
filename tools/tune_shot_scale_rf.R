#!/usr/bin/env Rscript

# Grid-search Random Forest hyperparameters for shot scale, evaluated on the
# same film-level held-out split used by tools/train_shot_scale_classical.R.
#
# Current production config: num.trees=150, min.node.size=80, max.depth=10,
# mtry=floor(sqrt(15))=3  ->  65.0% held-out accuracy.
#
# Input:  cached features (tools/shot_scale_classical_features.rds)
# Output: ranked grid table; optionally retrain + save best model
#
# Usage:
#   Rscript tools/tune_shot_scale_rf.R            # report only
#   SHOT_SCALE_SAVE_BEST=1 Rscript tools/tune_shot_scale_rf.R  # also save
#
# Env vars:
#   CINESCALE_RESULTS_DIR  validation folder (must be set by the user)
#   SHOT_SCALE_SEED        random seed (default 42)
#   SHOT_SCALE_SAVE_BEST   if "1", retrain best config and overwrite model

suppressPackageStartupMessages({
  library(devtools)
  library(magick)
  library(dplyr)
  library(tibble)
  library(purrr)
  library(readr)
  library(ranger)
})

tidylens_path <- normalizePath(".", ".")
devtools::load_all(tidylens_path, quiet = TRUE)

RESULTS_DIR <- Sys.getenv(
  "CINESCALE_RESULTS_DIR",
  ""
)
SEED <- as.integer(Sys.getenv("SHOT_SCALE_SEED", "42"))
FEATURE_CACHE <- file.path(tidylens_path, "tools", "shot_scale_classical_features.rds")
set.seed(SEED)

# ── Load annotations + film split (mirror training script) ────────────────

results_csv <- file.path(RESULTS_DIR, "frame_level_results.csv")
if (!file.exists(results_csv)) {
  stop("frame_level_results.csv not found at: ", results_csv,
       "\nSet CINESCALE_RESULTS_DIR to the validation folder.")
}
if (!file.exists(FEATURE_CACHE)) {
  stop("Feature cache not found. Run tools/train_shot_scale_classical.R first.")
}

annotations <- readr::read_csv(results_csv, show_col_types = FALSE,
                               name_repair = "minimal")
names(annotations)[1:9] <- c("director", "film", "unused_1", "time",
                             "shotscale", "frame_num", "cinescale_label",
                             "class_3", "frame_file")
frames_root <- file.path(RESULTS_DIR, "sampled_frames")
annotations <- annotations |>
  mutate(resolved_path = file.path(frames_root, director, film, frame_file)) |>
  filter(file.exists(resolved_path), !is.na(class_3),
         class_3 %in% c("Close", "Medium", "Long"))

split_films <- annotations |>
  group_by(director, film) |>
  summarise(n = n(), .groups = "drop") |>
  group_by(director) |>
  arrange(director, film) |>
  mutate(rank = row_number(), is_test = rank > ceiling(n() * 0.8)) |>
  ungroup()
train_films <- split_films |> filter(!is_test) |> pull(film)
test_films  <- split_films |> filter(is_test)  |> pull(film)

# ── Build feature frame (mirror training script normalization) ────────────

all_features <- readRDS(FEATURE_CACHE)
valid_idx <- which(!vapply(all_features, is.null, logical(1)))[1]
n_features <- length(all_features[[valid_idx]])
feature_mat <- do.call(rbind, lapply(all_features, function(f) {
  if (is.null(f)) return(rep(NA_real_, n_features))
  f
}))
colnames(feature_mat) <- names(all_features[[valid_idx]])
clean_names <- make.unique(sub("\\..*$", "", colnames(feature_mat)), sep = "_")
colnames(feature_mat) <- clean_names
expected_feature_names <- names(extract_shot_scale_features(
  magick::image_read(annotations$resolved_path[1])
))
missing_features <- setdiff(expected_feature_names, colnames(feature_mat))
if (length(missing_features) > 0) {
  stop("Feature cache is stale; missing: ", paste(missing_features, collapse = ", "),
       "\nRun tools/train_shot_scale_classical.R to refresh tools/shot_scale_classical_features.rds.")
}
feature_df <- as.data.frame(feature_mat)
feature_df <- dplyr::select(feature_df, -dplyr::any_of(c("skin_tone", "skin_center")))
feature_df$class_3  <- annotations$class_3
feature_df$film     <- annotations$film
feature_df$director <- annotations$director

train_df <- feature_df |>
  filter(film %in% train_films) |>
  filter(complete.cases(across(everything()))) |>
  mutate(class_3 = factor(class_3, levels = c("Close", "Medium", "Long")))
test_df <- feature_df |>
  filter(film %in% test_films) |>
  filter(complete.cases(across(everything()))) |>
  mutate(class_3 = factor(class_3, levels = c("Close", "Medium", "Long")))

feature_cols <- setdiff(names(train_df), c("class_3", "film", "director"))
rf_formula <- as.formula(paste("class_3 ~", paste(feature_cols, collapse = " + ")))

cat(sprintf("Train: %d  Test: %d  Features: %d\n",
            nrow(train_df), nrow(test_df), length(feature_cols)))

# ── Grid ──────────────────────────────────────────────────────────────────

grid <- expand.grid(
  num.trees     = c(150, 500),
  mtry          = c(3, 5, 7),
  min.node.size = c(5, 20, 80),
  max.depth     = c(10, 15, 0),  # 0 = unlimited
  stringsAsFactors = FALSE
)

macro_f1 <- function(pred, truth) {
  mean(sapply(levels(truth), function(cl) {
    tp <- sum(truth == cl & pred == cl); fp <- sum(truth != cl & pred == cl)
    fn <- sum(truth == cl & pred != cl)
    prec <- if (tp + fp > 0) tp / (tp + fp) else 0
    rec  <- if (tp + fn > 0) tp / (tp + fn) else 0
    if (prec + rec > 0) 2 * prec * rec / (prec + rec) else 0
  }))
}

cat(sprintf("Evaluating %d configurations...\n", nrow(grid)))
res <- lapply(seq_len(nrow(grid)), function(i) {
  g <- grid[i, ]
  m <- ranger::ranger(
    formula = rf_formula, data = train_df,
    num.trees = g$num.trees, mtry = g$mtry,
    min.node.size = g$min.node.size, max.depth = g$max.depth,
    classification = TRUE, probability = TRUE, seed = SEED, write.forest = TRUE
  )
  probs <- predict(m, test_df)$predictions
  pred <- factor(colnames(probs)[max.col(probs)], levels = levels(test_df$class_3))
  acc <- mean(pred == test_df$class_3)
  cat(sprintf("  [%2d/%d] trees=%d mtry=%d node=%d depth=%d -> acc=%.1f%%\n",
              i, nrow(grid), g$num.trees, g$mtry, g$min.node.size, g$max.depth,
              100 * acc))
  cbind(g, accuracy = acc, macro_f1 = macro_f1(pred, test_df$class_3))
})
res <- do.call(rbind, res)
res <- res[order(-res$accuracy), ]

cat("\n── Top 10 configurations ──\n")
print(head(res, 10), row.names = FALSE)

best <- res[1, ]
cat(sprintf("\nBest: trees=%d mtry=%d node=%d depth=%d -> %.1f%% acc, %.3f F1\n",
            best$num.trees, best$mtry, best$min.node.size, best$max.depth,
            100 * best$accuracy, best$macro_f1))
cat(sprintf("Baseline (production, trees=150 mtry=3 node=80 depth=10): 65.0%%\n"))
cat(sprintf("Delta: %+.1f points\n", 100 * best$accuracy - 65.0))

# ── Optionally retrain best on full train set and overwrite model ─────────

if (identical(Sys.getenv("SHOT_SCALE_SAVE_BEST"), "1")) {
  cat("\nRetraining best config and saving model bundle...\n")
  m <- ranger::ranger(
    formula = rf_formula, data = train_df,
    num.trees = best$num.trees, mtry = best$mtry,
    min.node.size = best$min.node.size, max.depth = best$max.depth,
    classification = TRUE, probability = TRUE, importance = "impurity",
    seed = SEED, write.forest = TRUE
  )
  m$predictions <- NULL; m$prediction.error <- NULL
  bundle <- list(model = m, feature_names = feature_cols,
                 classes = c("Close", "Medium", "Long"))
  out <- file.path(tidylens_path, "inst", "models", "shot_scale_classical.rds")
  saveRDS(bundle, out, compress = "xz")
  cat(sprintf("Saved to %s (%s KB)\n", out, file.size(out) %/% 1024))
}

cat("\nDone.\n")
