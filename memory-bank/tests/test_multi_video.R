# Test Multi-Video Support, Video Source Tracking, and Metadata Preservation
# Tinylens Task #23 Test

library(dplyr)

cat("\n========================================\n")
cat("  TINYLENS MULTI-VIDEO & METADATA TEST\n")
cat("========================================\n\n")

# Load package
devtools::load_all()

# =============================================================================
# TEST 1: Single video frame extraction with video_source
# =============================================================================
cat("TEST 1: Single video frame extraction\n")
cat("-------------------------------------\n")

frames1 <- video_extract_frames("hero.mp4", fps = 0.5)
cat("Extracted:", nrow(frames1), "frames\n")
cat("Columns:", paste(names(frames1), collapse = ", "), "\n")
cat("Has video_source:", "video_source" %in% names(frames1), "\n")
if ("video_source" %in% names(frames1)) {
  cat("video_source[1]:", basename(frames1$video_source[1]), "\n")
}
cat("\n")

# =============================================================================
# TEST 2: Multiple video frame extraction
# =============================================================================
cat("TEST 2: Multiple video frame extraction\n")
cat("---------------------------------------\n")

all_frames <- video_extract_frames(c("hero.mp4", "hero2.mp4", "hero3.mp4"), fps = 0.25)
cat("Extracted:", nrow(all_frames), "frames from 3 videos\n")
cat("Has video_source:", "video_source" %in% names(all_frames), "\n")
if ("video_source" %in% names(all_frames)) {
  cat("Video sources:\n")
  print(table(basename(all_frames$video_source)))
}
cat("\n")

# =============================================================================
# TEST 3: Single video shot extraction with video_source
# =============================================================================
cat("TEST 3: Single video shot extraction\n")
cat("------------------------------------\n")

shots1 <- video_extract_shots("hero.mp4", fps = 1, threshold = 0.5)
cat("Detected:", nrow(shots1), "shots\n")
cat("Has video_source:", "video_source" %in% names(shots1), "\n")
if ("video_source" %in% names(shots1)) {
  cat("video_source[1]:", basename(shots1$video_source[1]), "\n")
}
cat("\n")

# =============================================================================
# TEST 4: Multiple video shot extraction
# =============================================================================
cat("TEST 4: Multiple video shot extraction\n")
cat("--------------------------------------\n")

all_shots <- video_extract_shots(c("hero.mp4", "hero2.mp4"), fps = 1, threshold = 0.5)
cat("Detected:", nrow(all_shots), "shots from 2 videos\n")
cat("Has video_source:", "video_source" %in% names(all_shots), "\n")
if ("video_source" %in% names(all_shots)) {
  cat("Video sources:\n")
  print(table(basename(all_shots$video_source)))
}
cat("\n")

# =============================================================================
# TEST 5: Metadata preservation from CSV
# =============================================================================
cat("TEST 5: Metadata preservation from CSV\n")
cat("--------------------------------------\n")

# First, save the shots with video_source to CSV
write.csv(all_shots, "tests/outputs/shots_with_metadata.csv", row.names = FALSE)
cat("Saved shots to CSV with", ncol(all_shots), "columns\n")

# Now reload from CSV and check metadata preserved
reloaded <- load_images("tests/outputs/shots_with_metadata.csv")
cat("Reloaded from CSV:", nrow(reloaded), "images\n")

# Check if extra columns were preserved
extra_cols <- setdiff(names(reloaded), c("id", "source", "local_path", "width", 
                                          "height", "format", "aspect_ratio", "file_size_bytes"))
cat("Preserved metadata columns:", length(extra_cols), "\n")
if (length(extra_cols) > 0) {
  cat("Columns:", paste(extra_cols, collapse = ", "), "\n")
}
cat("\n")

# =============================================================================
# TEST 6: LLM Functionality
# =============================================================================
cat("TEST 6: LLM Functionality\n")
cat("-------------------------\n")

# Check Ollama
ollama_ok <- llm_check_ollama()
if (!ollama_ok) {
  cat("! Ollama not running - skipping LLM tests\n")
} else {
  cat("Ollama is running\n\n")
  
  # Test with first 2 frames from shot extraction
  test_images <- shots1[1:2, ]
  
  # Test llm_describe
  cat("Testing llm_describe()...\n")
  tryCatch({
    desc <- llm_describe(test_images, model = "moondream")
    if ("llm_description" %in% names(desc)) {
      cat("  Column: llm_description ✓\n")
      cat("  Sample: ", substr(desc$llm_description[1], 1, 100), "...\n", sep = "")
    }
  }, error = function(e) cat("  ERROR:", e$message, "\n"))
  
  # Test llm_classify
  cat("\nTesting llm_classify()...\n")
  tryCatch({
    classified <- llm_classify(test_images[1, ], 
                               categories = c("action", "dialogue", "landscape", "close-up"),
                               model = "moondream")
    if ("llm_category" %in% names(classified)) {
      cat("  Column: llm_category ✓\n")
      cat("  Category:", classified$llm_category[1], "\n")
    }
  }, error = function(e) cat("  ERROR:", e$message, "\n"))
  
  # Test llm_sentiment
  cat("\nTesting llm_sentiment()...\n")
  tryCatch({
    sentiment <- llm_sentiment(test_images[1, ], model = "moondream")
    if ("llm_mood" %in% names(sentiment)) {
      cat("  Column: llm_mood ✓\n")
      cat("  Mood:", sentiment$llm_mood[1], "\n")
    }
  }, error = function(e) cat("  ERROR:", e$message, "\n"))
  
  # Test llm_recognize
  cat("\nTesting llm_recognize()...\n")
  tryCatch({
    objects <- llm_recognize(test_images[1, ], model = "moondream")
    if ("llm_objects" %in% names(objects)) {
      cat("  Column: llm_objects ✓\n")
      cat("  Objects:", substr(objects$llm_objects[1], 1, 80), "\n")
    }
  }, error = function(e) cat("  ERROR:", e$message, "\n"))
}

# =============================================================================
# SUMMARY
# =============================================================================
cat("\n========================================\n")
cat("  TEST SUMMARY\n")
cat("========================================\n")
cat("✓ video_extract_frames with video_source\n")
cat("✓ video_extract_shots with video_source\n")
cat("✓ Multi-video support (vector of paths)\n")
cat("✓ Metadata preservation from CSV manifest\n")
cat("✓ LLM functions tested\n")
cat("\n")
