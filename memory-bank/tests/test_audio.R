# Test audio feature extraction
library(tibble)
library(dplyr)
library(purrr)
library(cli)
library(magick)

setwd("/Users/nabeel/Nextcloud/Spring 2026/tinylens")

# Source all R files
for (f in list.files("R", pattern = "[.]R$", full.names = TRUE)) {
  tryCatch(source(f), error = function(e) cat("Skip:", f, "\n"))
}

# Test with shots
cat("Testing audio extraction on SHOTS...\n")

shots <- video_extract_shots("hero.mp4", fps = 2)
cat("Detected", nrow(shots), "shots\n")

# Extract audio features for shots
shots_with_audio <- extract_audio_features(shots, "hero.mp4")

cat("\nShot audio features (first 5):\n")
print(shots_with_audio[1:min(5, nrow(shots_with_audio)), 
      c("shot_id", "duration", "audio_rms", "audio_peak", "audio_spectral_centroid")])

cat("\nLoudest shot:\n")
loudest <- which.max(shots_with_audio$audio_rms)
print(shots_with_audio[loudest, c("shot_id", "start_time", "duration", "audio_rms")])

cat("\nQuietest shot:\n")
quietest <- which.min(shots_with_audio$audio_rms)
print(shots_with_audio[quietest, c("shot_id", "start_time", "duration", "audio_rms")])
