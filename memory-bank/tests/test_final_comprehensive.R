# Final Comprehensive Test for Tinylens v1.7
# Tests all major function categories including audio

library(tibble)
library(dplyr)
library(purrr)
library(cli)
library(magick)

setwd("/Users/nabeel/Nextcloud/Spring 2026/tinylens")

# Source all R files
cat("Loading tinylens functions...\n")
for (f in list.files("R", pattern = "[.]R$", full.names = TRUE)) {
  tryCatch(source(f), error = function(e) cat("Skip:", f, "\n"))
}

# Test video path
video_path <- "hero.mp4"

if (!file.exists(video_path)) {
  stop("Test video 'hero.mp4' not found. Place it in the tinylens directory.")
}

results <- list()

# ============================================
# 1. VIDEO PROCESSING
# ============================================
cat("\n", strrep("=", 50), "\n")
cat("1. VIDEO PROCESSING\n")
cat(strrep("=", 50), "\n")

# Video info
info <- video_get_info(video_path)
cat("Video:", info$duration, "seconds,", info$fps, "fps\n")
results$video_info <- "PASS"

# Extract frames (sample a few frames for testing)
frames <- video_sample_frames(video_path, n = 10)
cat("Extracted", nrow(frames), "frames\n")
results$extract_frames <- "PASS"

# Extract shots
shots <- video_extract_shots(video_path, fps = 2)
cat("Detected", nrow(shots), "shots\n")
results$extract_shots <- "PASS"

# ============================================
# 2. AUDIO EXTRACTION
# ============================================
cat("\n", strrep("=", 50), "\n")
cat("2. AUDIO EXTRACTION\n")
cat(strrep("=", 50), "\n")

# Audio features on shots
shots_audio <- extract_audio_features(shots, video_path)
cat("Audio columns:", paste(grep("^audio_", names(shots_audio), value = TRUE), collapse = ", "), "\n")
cat("Mean loudness (RMS):", round(mean(shots_audio$audio_rms, na.rm = TRUE), 4), "\n")
results$audio_features <- "PASS"

# Audio RMS only
shots_rms <- extract_audio_rms(shots, video_path)
cat("RMS only column added:", "audio_rms" %in% names(shots_rms), "\n")
results$audio_rms <- "PASS"

# ============================================
# 3. COLOR FEATURES
# ============================================
cat("\n", strrep("=", 50), "\n")
cat("3. COLOR FEATURES\n")
cat(strrep("=", 50), "\n")

frames <- frames |>
  extract_brightness() |>
  extract_colourfulness() |>
  extract_warmth()

cat("Brightness range:", range(frames$brightness), "\n")
cat("Colourfulness range:", range(frames$colourfulness), "\n")
cat("Warmth range:", range(frames$warmth), "\n")
results$color_features <- "PASS"

# ============================================
# 4. TEXTURE FEATURES
# ============================================
cat("\n", strrep("=", 50), "\n")
cat("4. TEXTURE FEATURES\n")
cat(strrep("=", 50), "\n")

frames <- frames |>
  extract_edge_density() |>
  extract_contrast() |>
  extract_entropy()

cat("Edge density range:", range(frames$edge_density), "\n")
cat("Contrast RMS range:", range(frames$contrast_rms), "\n")
cat("Entropy range:", range(frames$texture_entropy), "\n")
results$texture_features <- "PASS"

# ============================================
# 5. FLUENCY/COMPOSITION
# ============================================
cat("\n", strrep("=", 50), "\n")
cat("5. FLUENCY/COMPOSITION\n")
cat(strrep("=", 50), "\n")

frames <- frames |>
  extract_fluency_metrics() |>
  extract_center_bias()

cat("Symmetry H range:", range(frames$symmetry_h), "\n")
cat("Center bias range:", range(frames$center_bias), "\n")
results$fluency_features <- "PASS"

# ============================================
# 6. DETECTION
# ============================================
cat("\n", strrep("=", 50), "\n")
cat("6. DETECTION\n")
cat(strrep("=", 50), "\n")

frames <- frames |>
  detect_skin_tones()

cat("Skin tone proportion range:", range(frames$skin_tone_prop), "\n")
results$detection <- "PASS"

# ============================================
# 7. FILM METRICS
# ============================================
cat("\n", strrep("=", 50), "\n")
cat("7. FILM METRICS\n")
cat(strrep("=", 50), "\n")

# Classify shot scale
shots_scaled <- film_classify_scale(shots_audio)
cat("Shot scales:", unique(shots_scaled$shot_scale), "\n")
results$film_classify <- "PASS"

# Compute ASL
asl <- film_compute_asl(shots_audio)
cat("ASL:", round(asl$asl, 2), "seconds\n")
cat("Shots per minute:", round(asl$shots_per_minute, 2), "\n")
results$film_asl <- "PASS"

# ============================================
# 8. SUMMARY
# ============================================
cat("\n", strrep("=", 50), "\n")
cat("FINAL SUMMARY\n")
cat(strrep("=", 50), "\n")

cat("\nFrames tibble:", nrow(frames), "rows x", ncol(frames), "columns\n")
cat("Shots tibble:", nrow(shots_audio), "rows x", ncol(shots_audio), "columns\n")

# List all results
cat("\nTest Results:\n")
for (name in names(results)) {
  cat("  ", name, ":", results[[name]], "\n")
}

# Count total columns
cat("\nTotal frame columns:", ncol(frames), "\n")
cat("Total shot columns:", ncol(shots_audio), "\n")

cat("\n✓ All tests completed successfully!\n")
