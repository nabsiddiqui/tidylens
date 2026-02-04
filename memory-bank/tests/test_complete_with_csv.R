# Test Multi-Video Support, Video Source Tracking, Metadata Preservation, and LLM
# Tinylens Task #24 - Save all results to CSV

library(dplyr)

cat("\n========================================\n")
cat("  TINYLENS COMPLETE TEST WITH CSV OUTPUT\n")
cat("========================================\n\n")

# Load package
devtools::load_all()

# Create output directory
output_dir <- "tests/outputs"
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

# =============================================================================
# TEST 1: Create multiple test videos
# =============================================================================
cat("TEST 1: Creating test videos\n")
cat("----------------------------\n")

# Copy hero.mp4 to create test videos
if (!file.exists("hero2.mp4")) file.copy("hero.mp4", "hero2.mp4")
if (!file.exists("hero3.mp4")) file.copy("hero.mp4", "hero3.mp4")
cat("Created: hero2.mp4, hero3.mp4\n\n")

# =============================================================================
# TEST 2: Multi-video frame extraction
# =============================================================================
cat("TEST 2: Multi-video frame extraction\n")
cat("------------------------------------\n")

# Extract fewer frames for speed (0.1 fps = ~24 frames per video)
all_frames <- video_extract_frames(c("hero.mp4", "hero2.mp4", "hero3.mp4"), fps = 0.1)
cat("Extracted:", nrow(all_frames), "frames from 3 videos\n")
cat("Columns:", paste(names(all_frames), collapse = ", "), "\n")

# Save to CSV
write.csv(all_frames, file.path(output_dir, "multi_video_frames.csv"), row.names = FALSE)
cat("Saved: multi_video_frames.csv\n\n")

# =============================================================================
# TEST 3: Multi-video shot extraction
# =============================================================================
cat("TEST 3: Multi-video shot extraction\n")
cat("-----------------------------------\n")

# Extract shots from 2 videos
all_shots <- video_extract_shots(c("hero.mp4", "hero2.mp4"), fps = 1, threshold = 0.5)
cat("Detected:", nrow(all_shots), "shots from 2 videos\n")
cat("Columns:", paste(names(all_shots), collapse = ", "), "\n")

# Save to CSV
write.csv(all_shots, file.path(output_dir, "multi_video_shots.csv"), row.names = FALSE)
cat("Saved: multi_video_shots.csv\n\n")

# =============================================================================
# TEST 4: LLM Functionality with CSV output
# =============================================================================
cat("TEST 4: LLM Functionality\n")
cat("-------------------------\n")

# Check Ollama
ollama_ok <- llm_check_ollama()
if (!ollama_ok) {
  cat("! Ollama not running - skipping LLM tests\n")
  cat("  Start with: ollama serve\n")
} else {
  cat("Ollama is running\n\n")
  
  # Use 5 frames for LLM testing
  idx <- as.integer(seq(1, nrow(all_frames), length.out = 5))
  test_images <- all_frames[idx, ]
  cat("Testing with", nrow(test_images), "images\n\n")
  
  # Run all LLM functions
  llm_results <- test_images
  
  # 1. llm_describe
  cat("Running llm_describe()...\n")
  tryCatch({
    llm_results <- llm_describe(llm_results, model = "moondream")
    cat("  ✓ Added llm_description column\n")
  }, error = function(e) cat("  ✗ ERROR:", e$message, "\n"))
  
  # 2. llm_classify  
  cat("Running llm_classify()...\n")
  tryCatch({
    llm_results <- llm_classify(llm_results, 
                                 categories = c("action", "dialogue", "landscape", "close-up", "wide-shot"),
                                 model = "moondream")
    cat("  ✓ Added llm_category column\n")
  }, error = function(e) cat("  ✗ ERROR:", e$message, "\n"))
  
  # 3. llm_sentiment
  cat("Running llm_sentiment()...\n")
  tryCatch({
    llm_results <- llm_sentiment(llm_results, model = "moondream")
    cat("  ✓ Added llm_mood, llm_mood_valence, llm_mood_intensity columns\n")
  }, error = function(e) cat("  ✗ ERROR:", e$message, "\n"))
  
  # 4. llm_recognize
  cat("Running llm_recognize()...\n")
  tryCatch({
    llm_results <- llm_recognize(llm_results, model = "moondream")
    cat("  ✓ Added llm_objects, llm_people_count, llm_text_detected columns\n")
  }, error = function(e) cat("  ✗ ERROR:", e$message, "\n"))
  
  # Save LLM results to CSV
  write.csv(llm_results, file.path(output_dir, "llm_results.csv"), row.names = FALSE)
  cat("\nSaved: llm_results.csv\n")
  cat("LLM columns:", paste(grep("^llm_", names(llm_results), value = TRUE), collapse = ", "), "\n\n")
  
  # Print sample results
  cat("\n--- Sample LLM Results ---\n")
  for (i in 1:min(3, nrow(llm_results))) {
    cat("\nImage", i, ":", llm_results$id[i], "\n")
    cat("  video_source:", basename(llm_results$video_source[i]), "\n")
    if ("llm_description" %in% names(llm_results)) {
      cat("  description:", substr(llm_results$llm_description[i], 1, 80), "...\n")
    }
    if ("llm_category" %in% names(llm_results)) {
      cat("  category:", llm_results$llm_category[i], "\n")
    }
    if ("llm_mood" %in% names(llm_results)) {
      cat("  mood:", llm_results$llm_mood[i], "\n")
    }
  }
}

# =============================================================================
# TEST 5: Metadata preservation from CSV
# =============================================================================
cat("\n\nTEST 5: Metadata Preservation\n")
cat("-----------------------------\n")

# Reload the multi_video_shots.csv and check metadata preserved
reloaded <- load_images(file.path(output_dir, "multi_video_shots.csv"))
cat("Reloaded from CSV:", nrow(reloaded), "images\n")
cat("Total columns:", ncol(reloaded), "\n")

preserved_cols <- setdiff(names(reloaded), 
                          c("id", "source", "local_path", "width", "height", 
                            "format", "aspect_ratio", "file_size_bytes"))
cat("Preserved metadata columns:", length(preserved_cols), "\n")
cat("Columns:", paste(preserved_cols, collapse = ", "), "\n")

# Save reloaded to verify
write.csv(reloaded, file.path(output_dir, "reloaded_with_metadata.csv"), row.names = FALSE)
cat("Saved: reloaded_with_metadata.csv\n")

# =============================================================================
# Cleanup
# =============================================================================
cat("\n\nCleaning up test videos...\n")
if (file.exists("hero2.mp4")) file.remove("hero2.mp4")
if (file.exists("hero3.mp4")) file.remove("hero3.mp4")

# =============================================================================
# Summary
# =============================================================================
cat("\n========================================\n")
cat("  OUTPUT FILES CREATED\n")
cat("========================================\n")

csv_files <- list.files(output_dir, pattern = "\\.csv$", full.names = TRUE)
for (f in csv_files) {
  info <- file.info(f)
  cat(sprintf("%-35s  %6.1f KB\n", basename(f), info$size / 1024))
}

cat("\nAll files saved to:", output_dir, "\n")
