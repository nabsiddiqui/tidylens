# Tinylens Test Script
# Run from project root: Rscript memory-bank/tests/test_run.R

library(magick)
library(tibble)
library(dplyr)
library(purrr)
library(cli)

# Set working directory
setwd("/Users/nabeel/Dropbox/Spring 2026/Sabbatical Preparation/projects/tinylens")

# Source all R files
r_files <- list.files("R", pattern = "[.]R$", full.names = TRUE)
for (f in r_files) source(f)

# Paths
video_path <- "memory-bank/tests/hero.mp4"
output_dir <- "memory-bank/tests/outputs"
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

cat("================================================\n")
cat("TINYLENS COMPREHENSIVE TEST\n")
cat("================================================\n\n")

# Extract shots
cat("[1] Extracting shots...\n")
shots <- video_extract_shots(video_path)
cat("    Shots detected:", nrow(shots), "\n\n")

# Color features
cat("[2] Color features...\n")
shots <- shots |>
  extract_brightness() |>
  extract_colourfulness() |>
  extract_color_mean() |>
  extract_color_median() |>
  extract_color_mode() |>
  extract_warmth() |>
  extract_dominant_color() |>
  extract_color_variance() |>
  extract_saturation()
cat("    Color features added\n\n")

# Fluency features
cat("[3] Fluency/composition features...\n")
shots <- shots |>
  extract_fluency_metrics() |>
  extract_rule_of_thirds() |>
  extract_visual_complexity() |>
  extract_center_bias()
cat("    Fluency features added\n\n")

# Film metrics
cat("[4] Film metrics...\n")
shots <- shots |>
  film_classify_angle()
cat("    Camera angle added\n\n")

# Save shots
cat("[5] Saving outputs...\n")
write.csv(shots, file.path(output_dir, "shots.csv"), row.names = FALSE)
cat("    Saved shots.csv with", ncol(shots), "columns\n\n")

# ASL metrics
asl <- film_compute_asl(shots)
write.csv(asl, file.path(output_dir, "asl_metrics.csv"), row.names = FALSE)
cat("    Saved asl_metrics.csv\n")

# Rhythm
rhythm <- film_compute_rhythm(shots)
write.csv(rhythm, file.path(output_dir, "rhythm_metrics.csv"), row.names = FALSE)
cat("    Saved rhythm_metrics.csv\n")

# Scale distribution
scale_dist <- film_summarize_scales(shots)
write.csv(scale_dist, file.path(output_dir, "scale_distribution.csv"), row.names = FALSE)
cat("    Saved scale_distribution.csv\n\n")

cat("================================================\n")
cat("TEST COMPLETE\n")
cat("Columns in final output:", ncol(shots), "\n")
cat("================================================\n")
