# Tinylens Comprehensive Test Script
# Tests all core functions with ~40 images and LLM functions
# Run with: source("tests/run_comprehensive_test.R")

library(tinylens)
library(dplyr)

cat("\n========================================\n")
cat("  TINYLENS COMPREHENSIVE TEST\n")
cat("========================================\n\n")

# =============================================================================
# Setup: Extract frames from video (targeting ~40 images)
# =============================================================================
video_path <- "hero.mp4"

if (!file.exists(video_path)) {
  stop("Video file 'hero.mp4' not found in working directory!")
}

cat("1. VIDEO ANALYSIS\n")
cat("-----------------\n")

# Get video info
video_info <- video_get_info(video_path)
cat("Video: ", round(video_info$duration, 1), "s at ", 
    round(video_info$fps, 1), " fps\n", sep = "")

# Extract ~40 frames (1 frame every ~6 seconds for 237s video)
frames_dir <- file.path(tempdir(), "tinylens_test_frames")
if (dir.exists(frames_dir)) unlink(frames_dir, recursive = TRUE)
dir.create(frames_dir)

# Extract at 0.17 fps to get ~40 frames
images <- video_extract_frames(video_path, 
                                output_dir = frames_dir, 
                                fps = 0.17)

cat("Extracted:", nrow(images), "frames\n\n")

# =============================================================================
# 2. Shot Detection and Film Metrics
# =============================================================================
cat("2. SHOT DETECTION & FILM METRICS\n")
cat("---------------------------------\n")

# Detect shots from video directly
shots <- video_extract_shots(video_path, fps = 2, threshold = 0.5)
cat("Detected:", nrow(shots), "shots\n")

# Add audio features to shots
cat("Extracting audio features for shots...\n")
shots <- extract_audio_features(shots, video_path)
cat("Audio columns added:", paste(grep("^audio_", names(shots), value = TRUE), collapse = ", "), "\n")
cat("Shot columns:", paste(names(shots), collapse = ", "), "\n\n")

# Film metrics (aggregate functions)
asl <- film_compute_asl(shots)
cat("ASL Metrics:\n")
cat("  - Average Shot Length:", round(asl$asl, 2), "seconds\n")
cat("  - Shots per minute:", round(asl$shots_per_minute, 1), "\n")
cat("  - Shortest shot:", round(asl$shortest_shot, 2), "s\n")
cat("  - Longest shot:", round(asl$longest_shot, 2), "s\n\n")

rhythm <- film_compute_rhythm(shots)
cat("Rhythm Metrics:\n")
cat("  - Entropy:", round(rhythm$rhythm_entropy, 3), "\n")
cat("  - Regularity:", round(rhythm$rhythm_regularity, 3), "\n")
cat("  - Acceleration:", round(rhythm$rhythm_acceleration, 3), "\n\n")

scale_dist <- film_summarize_scales(shots)
cat("Shot Scale Distribution:\n")
print(scale_dist)
cat("\n")

# =============================================================================
# 3. Color Analysis (11 functions)
# =============================================================================
cat("3. COLOR ANALYSIS\n")
cat("-----------------\n")

color_results <- images |>
  extract_brightness() |>
  extract_color_mean() |>
  extract_color_median() |>
  extract_color_mode() |>
  extract_hue_histogram() |>
  extract_saturation() |>
  extract_colourfulness() |>
  extract_warmth() |>
  extract_dominant_color() |>
  extract_color_variance() |>
  extract_color_moments()

color_cols <- setdiff(names(color_results), names(images))
cat("Color columns added:", length(color_cols), "\n")
cat("Columns:", paste(head(color_cols, 10), collapse = ", "), "...\n\n")

# =============================================================================
# 4. Fluency/Composition (4 functions)
# =============================================================================
cat("4. FLUENCY/COMPOSITION\n")
cat("----------------------\n")

fluency_results <- color_results |>
  extract_fluency_metrics() |>
  extract_rule_of_thirds() |>
  extract_visual_complexity() |>
  extract_center_bias()

fluency_cols <- setdiff(names(fluency_results), names(color_results))
cat("Fluency columns added:", length(fluency_cols), "\n")
cat("Columns:", paste(fluency_cols, collapse = ", "), "\n\n")

# =============================================================================
# 5. Detection (2 functions)
# =============================================================================
cat("5. DETECTION\n")
cat("------------\n")

detection_results <- fluency_results |>
  detect_skin_tones()

tryCatch({
  detection_results <- detection_results |> detect_faces()
  cat("  - Face detection: OK\n")
}, error = function(e) cat("  - Face detection: skipped (missing package)\n"))

detection_cols <- setdiff(names(detection_results), names(fluency_results))
cat("Detection columns added:", length(detection_cols), "\n\n")

# =============================================================================
# 6. Film Classification (per-image)
# =============================================================================
cat("6. FILM CLASSIFICATION\n")
cat("----------------------\n")

film_results <- detection_results |>
  film_classify_scale() |>
  film_classify_angle()

film_cols <- setdiff(names(film_results), names(detection_results))
cat("Film classification columns added:", length(film_cols), "\n")
cat("Columns:", paste(film_cols, collapse = ", "), "\n\n")

# =============================================================================
# 7. All Results Summary
# =============================================================================
cat("7. FINAL SUMMARY\n")
cat("----------------\n")

final_results <- film_results
cat("Total images:", nrow(final_results), "\n")
cat("Total columns:", ncol(final_results), "\n")
cat("\nColumn names:\n")
print(names(final_results))
cat("\n")

# =============================================================================
# 8. LLM Functions (Ollama)
# =============================================================================
cat("8. LLM FUNCTIONS (Ollama)\n")
cat("-------------------------\n")

# Check Ollama
ollama_ok <- llm_check_ollama()
if (!ollama_ok) {
  cat("! Ollama not running - skipping LLM tests\n")
  cat("  Start with: ollama serve\n\n")
} else {
  cat("Ollama is running\n")
  
  # Test with first 3 images only (LLM is slow)
  test_images <- images[1:3, ]
  
  cat("\nTesting llm_describe()...\n")
  tryCatch({
    desc <- llm_describe(test_images, model = "moondream")
    cat("  - Description for image 1: ", 
        substr(desc$llm_description[1], 1, 80), "...\n", sep = "")
    cat("  - llm_describe: OK\n")
  }, error = function(e) cat("  - llm_describe: FAILED -", e$message, "\n"))
  
  cat("\nTesting llm_classify()...\n")
  tryCatch({
    classified <- llm_classify(test_images[1, ], 
                               categories = c("action", "dialogue", "landscape", "close-up"),
                               model = "moondream")
    cat("  - Category:", classified$llm_category[1], "\n")
    cat("  - llm_classify: OK\n")
  }, error = function(e) cat("  - llm_classify: FAILED -", e$message, "\n"))
  
  cat("\nTesting llm_sentiment()...\n")
  tryCatch({
    sentiment <- llm_sentiment(test_images[1, ], model = "moondream")
    cat("  - Mood:", sentiment$llm_mood[1], "\n")
    cat("  - llm_sentiment: OK\n")
  }, error = function(e) cat("  - llm_sentiment: FAILED -", e$message, "\n"))
  
  cat("\nTesting llm_recognize()...\n")
  tryCatch({
    objects <- llm_recognize(test_images[1, ], model = "moondream")
    cat("  - Objects:", substr(objects$llm_objects[1], 1, 60), "\n")
    cat("  - llm_recognize: OK\n")
  }, error = function(e) cat("  - llm_recognize: FAILED -", e$message, "\n"))
}

# =============================================================================
# 9. Save Results
# =============================================================================
cat("\n9. SAVING RESULTS\n")
cat("-----------------\n")

output_dir <- "tests/outputs"
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

# Save all feature data
write.csv(final_results, file.path(output_dir, "all_features.csv"), row.names = FALSE)
cat("Saved: all_features.csv\n")

# Save shot data
write.csv(shots, file.path(output_dir, "shots.csv"), row.names = FALSE)
cat("Saved: shots.csv\n")

# Save film metrics
write.csv(asl, file.path(output_dir, "asl_metrics.csv"), row.names = FALSE)
write.csv(rhythm, file.path(output_dir, "rhythm_metrics.csv"), row.names = FALSE)
write.csv(scale_dist, file.path(output_dir, "scale_distribution.csv"), row.names = FALSE)
cat("Saved: asl_metrics.csv, rhythm_metrics.csv, scale_distribution.csv\n")

cat("\n========================================\n")
cat("  TEST COMPLETE\n")
cat("========================================\n")
cat("Images analyzed:", nrow(final_results), "\n")
cat("Columns extracted:", ncol(final_results), "\n")
cat("Shots detected:", nrow(shots), "\n")
cat("Output directory:", output_dir, "\n\n")
