# Comprehensive Tinylens Test Suite
# Tests all functions and saves organized CSVs to csvs/ folder

setwd("/Users/nabeel/Nextcloud/Spring 2026/tinylens")

# Load dependencies
library(magick)
library(tibble)
library(dplyr)
library(purrr)
library(cli)
library(fs)

# Source all R files
r_files <- list.files("R", pattern = "\\.R$", full.names = TRUE)
for (f in r_files) {
  tryCatch({
    source(f)
    cat(sprintf("  ✓ Sourced %s\n", basename(f)))
  }, error = function(e) {
    cat(sprintf("  ✗ Error in %s: %s\n", basename(f), conditionMessage(e)))
  })
}

# Create CSV output directory
csv_dir <- "csvs"
if (!dir.exists(csv_dir)) dir.create(csv_dir)

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("           TINYLENS COMPREHENSIVE TEST SUITE\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# ============================================================
# PART 1: IMAGE ANALYSIS (using frames 50-300 for variety)
# ============================================================
cat("PART 1: IMAGE ANALYSIS\n")
cat("────────────────────────────────────────────────────────────────\n")

cat("Loading images (frames 50-300)...\n")
images <- load_images("images/", pattern = "image_0000[5-9][0-9]\\.jpg|image_00010[0-9]\\.jpg|image_00011[0-9]\\.jpg|image_00012[0-9]\\.jpg|image_00013[0-9]\\.jpg|image_00014[0-9]\\.jpg|image_00015[0-9]\\.jpg|image_00016[0-9]\\.jpg|image_00017[0-9]\\.jpg|image_00018[0-9]\\.jpg|image_00019[0-9]\\.jpg|image_00020[0-9]\\.jpg|image_00021[0-9]\\.jpg|image_00022[0-9]\\.jpg|image_00023[0-9]\\.jpg|image_00024[0-9]\\.jpg|image_00025[0-9]\\.jpg|image_00026[0-9]\\.jpg|image_00027[0-9]\\.jpg|image_00028[0-9]\\.jpg|image_00029[0-9]\\.jpg|image_00030[0-9]\\.jpg")
cat(sprintf("Loaded %d images\n\n", nrow(images)))

# ── COLOR FUNCTIONS ──
cat("Testing COLOR functions...\n")

images <- images |>
  extract_brightness()
cat("  ✓ extract_brightness\n")

images <- images |>
  extract_color_mean()
cat("  ✓ extract_color_mean\n")

images <- images |>
  extract_color_median()
cat("  ✓ extract_color_median\n")

images <- images |>
  extract_color_mode()
cat("  ✓ extract_color_mode\n")

images <- images |>
  extract_saturation()
cat("  ✓ extract_saturation\n")

images <- images |>
  extract_colourfulness()
cat("  ✓ extract_colourfulness\n")

images <- images |>
  extract_warmth()
cat("  ✓ extract_warmth\n")

images <- images |>
  extract_dominant_color()
cat("  ✓ extract_dominant_color\n")

images <- images |>
  extract_color_variance()
cat("  ✓ extract_color_variance\n")

images <- images |>
  extract_color_moments()
cat("  ✓ extract_color_moments\n")

images <- images |>
  extract_hue_histogram()
cat("  ✓ extract_hue_histogram\n")

cat("  All 11 color functions passed ✓\n\n")

# ── TEXTURE FUNCTIONS ──
cat("Testing TEXTURE functions...\n")

images <- images |>
  extract_edge_density()
cat("  ✓ extract_edge_density\n")

images <- images |>
  extract_contrast()
cat("  ✓ extract_contrast\n")

images <- images |>
  extract_entropy()
cat("  ✓ extract_entropy\n")

images <- images |>
  extract_sharpness()
cat("  ✓ extract_sharpness\n")

images <- images |>
  extract_tamura_texture()
cat("  ✓ extract_tamura_texture\n")

cat("  Core texture functions passed ✓\n\n")

# ── FLUENCY FUNCTIONS ──
cat("Testing FLUENCY functions...\n")

images <- images |>
  extract_fluency_metrics()
cat("  ✓ extract_fluency_metrics\n")

images <- images |>
  extract_rule_of_thirds()
cat("  ✓ extract_rule_of_thirds\n")

images <- images |>
  extract_visual_complexity()
cat("  ✓ extract_visual_complexity\n")

images <- images |>
  extract_center_bias()
cat("  ✓ extract_center_bias\n")

cat("  All 4 fluency functions passed ✓\n\n")

# ── DETECTION FUNCTIONS ──
cat("Testing DETECTION functions...\n")

images <- images |>
  detect_skin_tones()
cat("  ✓ detect_skin_tones\n")

images <- images |>
  detect_dominant_regions()
cat("  ✓ detect_dominant_regions\n")

cat("  Core detection functions passed ✓\n\n")

# ── SAVE IMAGE RESULTS ──
cat("Saving image analysis results...\n")

# Select only scalar columns
result_df <- images |>
  select(-local_path) |>
  select(where(~ !is.list(.x)))

write.csv(result_df, file.path(csv_dir, "images_all_features.csv"), row.names = FALSE)
cat(sprintf("  ✓ Saved csvs/images_all_features.csv (%d rows, %d columns)\n\n", 
            nrow(result_df), ncol(result_df)))

# ============================================================
# PART 2: VIDEO/SHOT ANALYSIS
# ============================================================
cat("PART 2: VIDEO/SHOT ANALYSIS\n")
cat("────────────────────────────────────────────────────────────────\n")

# Check if av is available
if (!requireNamespace("av", quietly = TRUE)) {
  cat("⚠ av package not installed - skipping video tests\n")
} else {
  library(av)
  
  # Video info
  cat("Testing video_get_info()...\n")
  video_info <- video_get_info("hero.mp4")
  print(video_info)
  write.csv(video_info, file.path(csv_dir, "video_info.csv"), row.names = FALSE)
  cat("  ✓ video_get_info\n\n")
  
  # Shot extraction
  cat("Testing video_extract_shots()...\n")
  shots <- video_extract_shots("hero.mp4", threshold = 0.4)
  cat(sprintf("  Detected %d shots\n", nrow(shots)))
  
  # Save shots (without frame_path which is temp)
  shots_export <- shots |>
    select(-any_of(c("frame_path")))
  write.csv(shots_export, file.path(csv_dir, "shots_detected.csv"), row.names = FALSE)
  cat("  ✓ Saved csvs/shots_detected.csv\n\n")
  
  # Film metrics
  cat("Testing film metrics (using tidy summarise)...\n")
  
  # Pacing metrics using dplyr::summarise (tidy style)
  pacing <- shots |>
    summarise(
      asl = mean(duration),
      asl_median = median(duration),
      asl_std = sd(duration),
      shot_count = n(),
      total_duration = sum(duration),
      shortest_shot = min(duration),
      longest_shot = max(duration),
      shots_per_minute = n() / (sum(duration) / 60)
    )
  write.csv(pacing, file.path(csv_dir, "film_pacing.csv"), row.names = FALSE)
  cat(sprintf("  ASL: %.2f seconds\n", pacing$asl))
  cat(sprintf("  Shots per minute: %.1f\n", pacing$shots_per_minute))
  
  # Rhythm metrics using dplyr::summarise
  rhythm <- shots |>
    summarise(
      rhythm_regularity = 1 / (1 + sd(duration) / mean(duration)),
      rhythm_range_ratio = max(duration) / min(duration),
      rhythm_quartile_25 = quantile(duration, 0.25),
      rhythm_quartile_75 = quantile(duration, 0.75)
    )
  write.csv(rhythm, file.path(csv_dir, "film_rhythm.csv"), row.names = FALSE)
  cat(sprintf("  Rhythm regularity: %.3f\n", rhythm$rhythm_regularity))
  
  # Combined pacing metrics
  combined_metrics <- cbind(pacing, rhythm)
  write.csv(combined_metrics, file.path(csv_dir, "film_metrics_combined.csv"), row.names = FALSE)
  cat("  ✓ Saved csvs/film_pacing.csv, csvs/film_rhythm.csv, csvs/film_metrics_combined.csv\n\n")
  
  # Shot scale summary (using count + mutate, tidy style)
  cat("Testing shot scale distribution (tidy style)...\n")
  scales <- shots |>
    count(shot_scale) |>
    mutate(pct = n / sum(n))
  print(scales)
  write.csv(scales, file.path(csv_dir, "shot_scale_summary.csv"), row.names = FALSE)
  cat("  ✓ Saved csvs/shot_scale_summary.csv\n\n")
  
  # Get keyframes for each shot using video_sample_frames approach
  cat("Extracting keyframes from middle of each shot...\n")
  
  # Calculate middle timestamps for each shot
  shot_keyframe_times <- (shots$start_time + shots$end_time) / 2
  
  # Create a keyframe analysis table
  keyframe_analysis <- tibble(
    shot_id = shots$shot_id,
    keyframe_time = shot_keyframe_times,
    start_time = shots$start_time,
    end_time = shots$end_time,
    duration = shots$duration,
    shot_scale = shots$shot_scale,
    shot_scale_name = shots$shot_scale_name,
    subject_coverage = shots$subject_coverage
  )
  
  write.csv(keyframe_analysis, file.path(csv_dir, "shot_keyframes.csv"), row.names = FALSE)
  cat(sprintf("  ✓ Saved csvs/shot_keyframes.csv (%d shots)\n\n", nrow(keyframe_analysis)))
}

# ============================================================
# PART 3: SHOT DETECTION FROM IMAGES (using detect_shot_changes)
# ============================================================
cat("PART 3: SHOT DETECTION FROM IMAGE SEQUENCE\n")
cat("────────────────────────────────────────────────────────────────\n")

# Use images already loaded to detect shot changes
cat("Detecting shots from loaded image sequence...\n")
image_shots <- detect_shot_changes(images, threshold = 0.3)
cat(sprintf("  Detected %d shots from %d images\n", nrow(image_shots), nrow(images)))

# Add duration assuming 24fps (original video)
image_shots$duration <- (image_shots$end_frame - image_shots$start_frame) / 24

write.csv(image_shots, file.path(csv_dir, "shots_from_images.csv"), row.names = FALSE)
cat("  ✓ Saved csvs/shots_from_images.csv\n\n")

# Get shot frame analysis
cat("Analyzing representative frame from each shot...\n")
shot_frames <- video_extract_shot_frames(images, image_shots, position = "middle")
cat(sprintf("  Selected %d keyframes\n", nrow(shot_frames)))

# Analyze these keyframes
shot_frames_analyzed <- shot_frames |>
  select(-any_of(names(shot_frames)[grepl("^(brightness|mean_|median_|mode_|saturation|colourfulness|warmth|tint|dominant|color|cm_|edge|contrast|texture|sharpness|tamura|simplicity|symmetry|balance|rule|visual|center|skin|peripheral)", names(shot_frames))])) |>  # Remove already-computed features if any
  extract_brightness() |>
  extract_colourfulness() |>
  extract_warmth() |>
  extract_dominant_color() |>
  extract_edge_density() |>
  extract_contrast() |>
  detect_skin_tones()

# Save shot frame analysis
shot_frames_export <- shot_frames_analyzed |>
  select(-local_path) |>
  select(where(~ !is.list(.x)))

write.csv(shot_frames_export, file.path(csv_dir, "shot_frames_analyzed.csv"), row.names = FALSE)
cat(sprintf("  ✓ Saved csvs/shot_frames_analyzed.csv (%d rows, %d columns)\n\n", 
            nrow(shot_frames_export), ncol(shot_frames_export)))

# ============================================================
# SUMMARY
# ============================================================
cat("═══════════════════════════════════════════════════════════════\n")
cat("                    TEST SUMMARY\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# List all CSVs created
csv_files <- list.files(csv_dir, pattern = "\\.csv$", full.names = TRUE)
cat("CSV files created:\n")
for (f in csv_files) {
  info <- file.info(f)
  cat(sprintf("  • %s (%.1f KB)\n", basename(f), info$size / 1024))
}

cat("\n")
cat(sprintf("Total image columns: %d\n", ncol(result_df)))
cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("                 ALL TESTS COMPLETE ✓\n")
cat("═══════════════════════════════════════════════════════════════\n")
