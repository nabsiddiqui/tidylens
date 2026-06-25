#!/usr/bin/env Rscript

# Train a classical Random Forest classifier for shot scale on the CineScale
# benchmark, using engineered features (spectral residual saliency, face
# coverage, skin tone, geometric and texture cues) following Canini, Benini
# & Leonardi (2011) and Hou & Zhang (2007).
#
# Input:  sampled CineScale frames + frame_level_results.csv
# Output: inst/models/shot_scale_classical.rds  (a ranger Random Forest)
#
# Usage:
#   Rscript tools/train_shot_scale_classical.R
#
# Env vars (optional):
#   CINESCALE_RESULTS_DIR  directory containing frame_level_results.csv
#                          and sampled_frames/  (default: the validation
#                          folder used during SoftwareX preparation)
#   SHOT_SCALE_WEIGHTS_OUT path to write the trained model
#   SHOT_SCALE_SEED        random seed (default 42)

suppressPackageStartupMessages({
  library(devtools)
  library(magick)
  library(dplyr)
  library(tibble)
  library(purrr)
  library(readr)
})

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

tidylens_path <- normalizePath(".", ".")
devtools::load_all(tidylens_path, quiet = TRUE)

RESULTS_DIR <- Sys.getenv(
  "CINESCALE_RESULTS_DIR",
  "/Users/nabeel/GDrive/Spring 2026/Tidylens Software Submission/Tidylens SoftwareX Article/validation/osf_stratified_results"
)
WEIGHTS_OUT <- Sys.getenv(
  "SHOT_SCALE_WEIGHTS_OUT",
  file.path(tidylens_path, "inst", "models", "shot_scale_classical.rds")
)
SEED <- as.integer(Sys.getenv("SHOT_SCALE_SEED", "42"))
FEATURE_CACHE <- file.path(tidylens_path, "tools", "shot_scale_classical_features.rds")

set.seed(SEED)

# ---------------------------------------------------------------------------
# Load annotations and resolve frame paths
# ---------------------------------------------------------------------------

results_csv <- file.path(RESULTS_DIR, "frame_level_results.csv")
if (!file.exists(results_csv)) {
  stop("frame_level_results.csv not found at: ", results_csv,
       "\nSet CINESCALE_RESULTS_DIR to the validation folder.")
}

annotations <- readr::read_csv(results_csv, show_col_types = FALSE,
                               name_repair = "minimal")
names(annotations)[1:9] <- c("director", "film", "unused_1", "time",
                             "shotscale", "frame_num", "cinescale_label",
                             "class_3", "frame_file")

# Resolve actual frame paths (they live under sampled_frames/<director>/<film>/)
frames_root <- file.path(RESULTS_DIR, "sampled_frames")
annotations <- annotations |>
  mutate(resolved_path = file.path(frames_root, director, film, frame_file)) |>
  filter(file.exists(resolved_path), !is.na(class_3),
         class_3 %in% c("Close", "Medium", "Long"))

cat(sprintf("Found %d annotated frames across %d films and %d directors.\n",
            nrow(annotations),
            n_distinct(annotations$film),
            n_distinct(annotations$director)))

# ---------------------------------------------------------------------------
# Train / test split by film
#
# We hold out roughly 20% of films per director for evaluation. The RF
# also produces an out-of-bag (OOB) estimate that is unbiased.
# ---------------------------------------------------------------------------

split_films <- annotations |>
  group_by(director, film) |>
  summarise(n = n(), .groups = "drop") |>
  group_by(director) |>
  arrange(director, film) |>
  mutate(rank = row_number(),
         is_test = rank > ceiling(n() * 0.8)) |>
  ungroup()

train_films <- split_films |> filter(!is_test) |> pull(film)
test_films  <- split_films |> filter(is_test)  |> pull(film)

cat("Training films:", paste(train_films, collapse = ", "), "\n")
cat("Held-out films:", paste(test_films, collapse = ", "), "\n\n")

train_idx <- which(annotations$film %in% train_films)
test_idx  <- which(annotations$film %in% test_films)

cat(sprintf("Train: %d frames  |  Test: %d frames\n",
            length(train_idx), length(test_idx)))

# ---------------------------------------------------------------------------
# Feature extraction
# ---------------------------------------------------------------------------

extract_features_batch <- function(paths) {
  n <- length(paths)
  # Parallel feature extraction across cores
  workers <- max(1L, parallel::detectCores() - 1L)
  cat(sprintf("Using %d worker cores for feature extraction...\n", workers))
  feat_list <- parallel::mclapply(seq_len(n), function(i) {
    tryCatch({
      img <- magick::image_read(paths[i])
      info <- magick::image_info(img)
      extract_shot_scale_features(img, info)
    }, error = function(e) NULL)
  }, mc.cores = workers, mc.preschedule = TRUE)
  for (i in seq_len(n)) {
    if (i %% 500 == 0) cat(sprintf("  features: %d / %d\n", i, n))
  }
  feat_list
}

# Cache features to avoid recomputing across runs
if (file.exists(FEATURE_CACHE)) {
  cat("Loading cached features...\n")
  all_features <- readRDS(FEATURE_CACHE)
} else {
  cat("Extracting features for", nrow(annotations), "frames...\n")
  all_features <- extract_features_batch(annotations$resolved_path)
  saveRDS(all_features, FEATURE_CACHE)
  cat("Cached features to", FEATURE_CACHE, "\n")
}

# Build feature matrix
valid_idx <- which(!vapply(all_features, is.null, logical(1)))[1]
n_features <- length(all_features[[valid_idx]])
feature_mat <- do.call(rbind, lapply(all_features, function(f) {
  if (is.null(f)) return(rep(NA_real_, n_features))
  f
}))
colnames(feature_mat) <- names(all_features[[valid_idx]])
# ponytail: cached features carry doubled names (face_coverage.face_coverage);
# normalize to the clean names emitted by the current extract_shot_scale_features
clean_names <- sub("\\..*$", "", colnames(feature_mat))
clean_names <- make.unique(clean_names, sep = "_")
colnames(feature_mat) <- clean_names
feature_df <- as.data.frame(feature_mat)
feature_df$class_3 <- annotations$class_3
feature_df$film    <- annotations$film
feature_df$director <- annotations$director

train_df <- feature_df |>
  filter(film %in% train_films) |>
  filter(complete.cases(across(everything()))) |>
  mutate(class_3 = factor(class_3, levels = c("Close", "Medium", "Long")))
test_df  <- feature_df |>
  filter(film %in% test_films) |>
  filter(complete.cases(across(everything()))) |>
  mutate(class_3 = factor(class_3, levels = c("Close", "Medium", "Long")))

cat(sprintf("\nFeature matrix: %d train x %d features, %d test x %d features\n",
            nrow(train_df), ncol(train_df) - 3,
            nrow(test_df),  ncol(test_df) - 3))

# ---------------------------------------------------------------------------
# Train Random Forest via ranger
# ---------------------------------------------------------------------------

if (!requireNamespace("ranger", quietly = TRUE)) {
  stop("Package 'ranger' is required for training. Install with install.packages('ranger')")
}

cat("\nTraining Random Forest (ranger)...\n")
feature_cols <- setdiff(names(train_df), c("class_3", "film", "director"))
rf_formula <- as.formula(paste("class_3 ~", paste(feature_cols, collapse = " + ")))
rf_model <- ranger::ranger(
  formula = rf_formula,
  data = train_df,
  num.trees = 150,
  min.node.size = 80,
  max.depth = 10,
  mtry = max(2L, floor(sqrt(length(feature_cols)))),
  classification = TRUE,
  probability = TRUE,
  importance = "impurity",
  write.forest = TRUE,
  seed = SEED
)

cat("OOB prediction error:", round(rf_model$prediction.error, 4), "\n")

# Variable importance
cat("\nVariable importance (impurity reduction):\n")
vi <- sort(ranger::importance(rf_model), decreasing = TRUE)
print(round(vi, 4))

# ---------------------------------------------------------------------------
# Evaluate
# ---------------------------------------------------------------------------

pred_probs <- predict(rf_model, test_df)$predictions
pred_class <- colnames(pred_probs)[max.col(pred_probs)]
test_df$pred  <- factor(pred_class, levels = c("Close", "Medium", "Long"))
test_df$truth <- factor(test_df$class_3, levels = c("Close", "Medium", "Long"))

accuracy <- mean(test_df$pred == test_df$truth, na.rm = TRUE)
cat(sprintf("\nHeld-out 3-class accuracy: %.1f%%\n", 100 * accuracy))

# Confusion matrix
conf <- table(truth = test_df$truth, pred = test_df$pred)
cat("\nConfusion matrix (held-out):\n")
print(conf)

# Per-class accuracy
for (cl in c("Close", "Medium", "Long")) {
  n <- sum(test_df$truth == cl, na.rm = TRUE)
  correct <- sum(test_df$truth == cl & test_df$pred == cl, na.rm = TRUE)
  cat(sprintf("  %s: %d / %d = %.1f%%\n", cl, correct, n, 100 * correct / n))
}

# Per-director accuracy
cat("\nPer-director accuracy (held-out):\n")
for (d in unique(test_df$director)) {
  sub <- test_df |> filter(director == d)
  if (nrow(sub) > 0) {
    acc_d <- mean(sub$pred == sub$truth, na.rm = TRUE)
    cat(sprintf("  %s: %.1f%% (n=%d)\n", d, 100 * acc_d, nrow(sub)))
  }
}

# ---------------------------------------------------------------------------
# Save model bundle
# ---------------------------------------------------------------------------

dir.create(dirname(WEIGHTS_OUT), showWarnings = FALSE, recursive = TRUE)
# ponytail: strip in-memory OOB predictions to shrink the saved bundle (44MB -> <1MB)
rf_model$predictions <- NULL
rf_model$prediction.error <- NULL
model_bundle <- list(
  model = rf_model,
  feature_names = feature_cols,
  classes = c("Close", "Medium", "Long")
)
saveRDS(model_bundle, WEIGHTS_OUT, compress = "xz")
cat(sprintf("\nSaved model bundle to %s (%s KB)\n", WEIGHTS_OUT,
            file.size(WEIGHTS_OUT) %/% 1024))

cat("\nDone.\n")