#!/usr/bin/env Rscript

# Benchmark shot scale classifier against simple baselines.
#
# Compares:
#   1. Random Forest (current production model)
#   2. Majority-class baseline
#   3. Saliency-coverage heuristic (coverage > median -> Close, else Long)
#
# Input:  CineScale frame_level_results.csv + sampled_frames/
# Output: printed benchmark table
#
# Usage:
#   Rscript tools/benchmark_shot_scale.R
#
# Env vars (optional):
#   CINESCALE_RESULTS_DIR  directory containing frame_level_results.csv
#                          and sampled_frames/

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
  "/Users/nabeel/GDrive/Spring 2026/Tidylens Software Submission/Tidylens SoftwareX Article/validation/osf_stratified_results"
)

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

frames_root <- file.path(RESULTS_DIR, "sampled_frames")
annotations <- annotations |>
  mutate(resolved_path = file.path(frames_root, director, film, frame_file)) |>
  filter(file.exists(resolved_path), !is.na(class_3),
         class_3 %in% c("Close", "Medium", "Long"))

cat(sprintf("Loaded %d annotated frames\n", nrow(annotations)))

# ── Train / test split by film (same as training script) ─────────────────

split_films <- annotations |>
  group_by(director, film) |>
  summarise(n = n(), .groups = "drop") |>
  group_by(director) |>
  arrange(director, film) |>
  mutate(rank = row_number(),
         is_test = rank > ceiling(n() * 0.8)) |>
  ungroup()

test_films <- split_films |> filter(is_test) |> pull(film)
test_idx <- which(annotations$film %in% test_films)
cat(sprintf("Held-out: %d frames across %d films\n",
            length(test_idx), length(unique(test_films))))

# ── Extract features for test set ─────────────────────────────────────────

FEATURE_CACHE <- file.path(tidylens_path, "tools", "shot_scale_classical_features.rds")
if (!file.exists(FEATURE_CACHE)) {
  stop("Feature cache not found. Run tools/train_shot_scale_classical.R first.")
}
all_features <- readRDS(FEATURE_CACHE)

valid_idx <- which(!vapply(all_features, is.null, logical(1)))[1]
n_features <- length(all_features[[valid_idx]])
feature_mat <- do.call(rbind, lapply(all_features, function(f) {
  if (is.null(f)) return(rep(NA_real_, n_features))
  f
}))
colnames(feature_mat) <- names(all_features[[valid_idx]])
clean_names <- sub("\\..*$", "", colnames(feature_mat))
clean_names <- make.unique(clean_names, sep = "_")
colnames(feature_mat) <- clean_names
model_path <- file.path(tidylens_path, "inst", "models", "shot_scale_classical.rds")
bundle <- readRDS(model_path)
missing_features <- setdiff(bundle$feature_names, colnames(feature_mat))
if (length(missing_features) > 0) {
  stop("Feature cache is missing model features: ",
       paste(missing_features, collapse = ", "),
       "\nRun tools/train_shot_scale_classical.R to refresh the cache/model.")
}
feature_df <- as.data.frame(feature_mat)
feature_df <- dplyr::select(feature_df, -dplyr::any_of(c("skin_tone", "skin_center")))
feature_df$class_3 <- annotations$class_3
feature_df$film    <- annotations$film
feature_df$director <- annotations$director

test_df <- feature_df |>
  filter(film %in% test_films) |>
  filter(complete.cases(across(everything()))) |>
  mutate(class_3 = factor(class_3, levels = c("Close", "Medium", "Long")))

cat(sprintf("Test set after filtering: %d frames\n", nrow(test_df)))

# ── 1. Random Forest ─────────────────────────────────────────────────────

rf_probs <- predict(bundle$model, test_df[, bundle$feature_names, drop = FALSE])$predictions
rf_pred <- factor(colnames(rf_probs)[max.col(rf_probs)],
                  levels = c("Close", "Medium", "Long"))

# ── 2. Majority baseline ──────────────────────────────────────────────────

majority_class <- names(which.max(table(test_df$class_3)))
majority_pred <- factor(rep(majority_class, nrow(test_df)),
                        levels = c("Close", "Medium", "Long"))

# ── 3. Saliency-coverage heuristic ───────────────────────────────────────

# ponytail: simple median-split on salience_coverage.
# Close shots have more salient foreground (face/detail fills frame).
# Long shots have less salient coverage (landscape, full body).
sal_cov <- test_df$salience_coverage
med_cov <- median(sal_cov, na.rm = TRUE)
saliency_pred <- factor(
  ifelse(sal_cov > med_cov, "Close", "Long"),
  levels = c("Close", "Medium", "Long")
)

# ── Evaluation ────────────────────────────────────────────────────────────

evaluate <- function(pred, truth, label) {
  acc <- mean(pred == truth, na.rm = TRUE)
  cm <- table(truth = truth, pred = pred)
  # per-class recall
  recalls <- sapply(levels(truth), function(cl) {
    n <- sum(truth == cl, na.rm = TRUE)
    if (n == 0) return(NA_real_)
    sum(truth == cl & pred == cl, na.rm = TRUE) / n
  })
  # macro F1
  f1s <- sapply(levels(truth), function(cl) {
    tp <- sum(truth == cl & pred == cl, na.rm = TRUE)
    fp <- sum(truth != cl & pred == cl, na.rm = TRUE)
    fn <- sum(truth == cl & pred != cl, na.rm = TRUE)
    prec <- if (tp + fp > 0) tp / (tp + fp) else 0
    rec  <- if (tp + fn > 0) tp / (tp + fn) else 0
    if (prec + rec > 0) 2 * prec * rec / (prec + rec) else 0
  })
  macro_f1 <- mean(f1s, na.rm = TRUE)

  cat(sprintf("\n── %s ──\n", label))
  cat(sprintf("Accuracy:  %.1f%%\n", 100 * acc))
  cat(sprintf("Macro F1:  %.3f\n", macro_f1))
  cat("Per-class recall:\n")
  for (cl in levels(truth)) {
    cat(sprintf("  %s: %.1f%%\n", cl, 100 * recalls[cl]))
  }
  cat("Confusion matrix:\n")
  print(cm)

  invisible(list(accuracy = acc, macro_f1 = macro_f1, recalls = recalls, cm = cm))
}

evaluate(rf_pred,       test_df$class_3, "Random Forest")
evaluate(majority_pred, test_df$class_3, "Majority Baseline")
evaluate(saliency_pred, test_df$class_3, "Saliency Heuristic (Close vs Long)")

cat("\nDone.\n")
