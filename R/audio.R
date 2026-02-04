#' Audio Feature Extraction Functions
#'
#' Functions for extracting audio features aligned to image frames or shots.
#'
#' @name audio
#' @keywords internal
NULL

#' Extract audio features per frame/shot
#'
#' Extract audio features for each row in a tl_images tibble. Uses timing
#' information to align audio segments with visual frames.
#'
#' ## How it works (ELI5)
#' Each image frame represents a moment in time. This function finds the
#' matching audio at that moment and measures things like how loud it is
#' and what frequencies are present.
#'
#' @param tl_images A tl_images tibble with video timing information.
#'   Should have either:
#'   - `start_time` and `end_time` columns (from video_extract_shots), or
#'   - Extracted from a video at known fps (uses frame index).
#' @param video_path Path to video file to extract audio from. If NULL,
#'   attempts to use `video_source` column.
#' @param fps Frames per second used for extraction. Required if tl_images
#'
#' @return The input tibble with added columns:
#'   - `audio_rms`: Root mean square amplitude (loudness).
#'   - `audio_peak`: Peak amplitude in the segment.
#'   - `audio_zcr`: Zero crossing rate (correlates with noisiness).
#'   - `audio_silence_ratio`: Proportion of near-silent samples.
#'   - `audio_low_freq_energy`: Energy in low frequencies (< 500 Hz).
#'   - `audio_high_freq_energy`: Energy in high frequencies (> 4000 Hz).
#'   - `audio_spectral_centroid`: Center of mass of spectrum (brightness).
#'
#' @details
#' Audio features are computed for each frame's time window:
#' - For shots: uses start_time to end_time.
#' - For frames: uses frame_index/fps as center, ±0.5/fps as window.
#'
#' @family audio
#' @export
#' @examples
#' \dontrun{
#' # Extract audio features per shot
#' shots <- video_extract_shots("film.mp4")
#' shots_with_audio <- extract_audio_features(shots, "film.mp4")
#'
#' # Extract audio features per frame
#' frames <- video_extract_frames("film.mp4", fps = 1)
#' frames_with_audio <- extract_audio_features(frames, "film.mp4", fps = 1)
#' }
extract_audio_features <- function(tl_images, video_path = NULL, fps = NULL) {
  
  # Check for required packages
  if (!requireNamespace("tuneR", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg tuneR} is required for audio analysis. Install with: install.packages('tuneR')")
  }
  if (!requireNamespace("av", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg av} is required for audio extraction. Install with: install.packages('av')")
  }
  
  # Validate input
  if (!inherits(tl_images, "data.frame")) {
    cli::cli_abort("{.arg tl_images} must be a data frame or tibble.")
  }
  
  n <- nrow(tl_images)
  if (n == 0) {
    cli::cli_warn("Empty tibble provided.")
    return(tl_images)
  }
  
  # Determine video path
  if (is.null(video_path)) {
    if ("video_source" %in% names(tl_images)) {
      video_sources <- unique(tl_images$video_source)
      if (length(video_sources) > 1) {
        cli::cli_abort("Multiple video sources found. Process one video at a time or specify {.arg video_path}.")
      }
      video_path <- video_sources[1]
    } else {
      cli::cli_abort("No {.arg video_path} provided and no {.code video_source} column found.")
    }
  }
  
  if (!file.exists(video_path)) {
    cli::cli_abort("Video file not found: {.file {video_path}}")
  }
  
  # Extract audio from video to temp wav file
  audio_path <- tempfile(fileext = ".wav")
  cli::cli_alert_info("Extracting audio from video...")
  
  av::av_audio_convert(video_path, output = audio_path)
  
  # Load the audio file
  audio <- tuneR::readWave(audio_path)
  
  # Convert to mono if stereo
  if (audio@stereo) {
    audio <- tuneR::mono(audio, which = "both")
  }
  
  sample_rate <- audio@samp.rate
  audio_data <- audio@left  # Mono data
  audio_duration <- length(audio_data) / sample_rate
  
  cli::cli_alert_info("Audio: {round(audio_duration, 1)}s, {sample_rate} Hz sample rate")
  
  # Determine timing for each row
  has_timing <- all(c("start_time", "end_time") %in% names(tl_images))
  
  if (!has_timing && is.null(fps)) {
    cli::cli_abort("Either {.arg fps} must be provided, or tl_images must have {.code start_time}/{.code end_time} columns.")
  }
  
  # Calculate time windows
  if (has_timing) {
    # Use shot timing
    start_times <- tl_images$start_time
    end_times <- tl_images$end_time
  } else {
    # Use frame index with fps
    # Assume frames are numbered 1, 2, 3, ...
    frame_indices <- seq_len(n)
    frame_duration <- 1 / fps
    start_times <- (frame_indices - 1) * frame_duration
    end_times <- frame_indices * frame_duration
  }
  
  cli::cli_alert_info("Computing audio features for {n} segments...")
  
  # Initialize result columns
  audio_rms <- numeric(n)
  audio_peak <- numeric(n)
  audio_zcr <- numeric(n)
  audio_silence_ratio <- numeric(n)
  audio_low_freq_energy <- numeric(n)
  audio_high_freq_energy <- numeric(n)
  audio_spectral_centroid <- numeric(n)
  
  # Progress bar
  cli::cli_progress_bar("Processing audio", total = n)
  
  for (i in seq_len(n)) {
    # Get sample indices for this time window
    start_sample <- max(1, floor(start_times[i] * sample_rate) + 1)
    end_sample <- min(length(audio_data), ceiling(end_times[i] * sample_rate))
    
    if (end_sample <= start_sample) {
      # Empty or invalid segment
      audio_rms[i] <- NA_real_
      audio_peak[i] <- NA_real_
      audio_zcr[i] <- NA_real_
      audio_silence_ratio[i] <- NA_real_
      audio_low_freq_energy[i] <- NA_real_
      audio_high_freq_energy[i] <- NA_real_
      audio_spectral_centroid[i] <- NA_real_
      cli::cli_progress_update()
      next
    }
    
    segment <- audio_data[start_sample:end_sample]
    segment_float <- segment / 32768  # Normalize 16-bit audio to [-1, 1]
    
    # RMS (Root Mean Square) - measure of loudness
    audio_rms[i] <- sqrt(mean(segment_float^2))
    
    # Peak amplitude
    audio_peak[i] <- max(abs(segment_float))
    
    # Zero Crossing Rate
    signs <- sign(segment_float)
    crossings <- sum(abs(diff(signs)) == 2)
    audio_zcr[i] <- crossings / (length(segment_float) - 1)
    
    # Silence ratio (samples below -60 dB threshold)
    silence_threshold <- 10^(-60/20)  # -60 dB
    audio_silence_ratio[i] <- mean(abs(segment_float) < silence_threshold)
    
    # Spectral features using FFT
    if (length(segment) >= 512) {
      # Use power-of-2 window for FFT efficiency
      fft_size <- 2^floor(log2(length(segment)))
      fft_segment <- segment_float[1:fft_size]
      
      # Apply Hanning window
      window <- 0.5 * (1 - cos(2 * pi * seq(0, fft_size - 1) / (fft_size - 1)))
      windowed <- fft_segment * window
      
      # Compute FFT
      spectrum <- Mod(fft(windowed)[1:(fft_size/2)])^2  # Power spectrum
      
      # Frequency bins
      freq_bins <- seq(0, sample_rate/2, length.out = length(spectrum))
      
      # Low frequency energy (< 500 Hz)
      low_mask <- freq_bins < 500
      audio_low_freq_energy[i] <- sum(spectrum[low_mask]) / sum(spectrum)
      
      # High frequency energy (> 4000 Hz)
      high_mask <- freq_bins > 4000
      audio_high_freq_energy[i] <- sum(spectrum[high_mask]) / sum(spectrum)
      
      # Spectral centroid (weighted mean frequency)
      audio_spectral_centroid[i] <- sum(freq_bins * spectrum) / sum(spectrum)
      
    } else {
      # Segment too short for reliable spectral analysis
      audio_low_freq_energy[i] <- NA_real_
      audio_high_freq_energy[i] <- NA_real_
      audio_spectral_centroid[i] <- NA_real_
    }
    
    cli::cli_progress_update()
  }
  
  cli::cli_progress_done()
  
  # Clean up temp file
  unlink(audio_path)
  
  # Add columns to tibble
  result <- tl_images
  result$audio_rms <- audio_rms
  result$audio_peak <- audio_peak
  result$audio_zcr <- audio_zcr
  result$audio_silence_ratio <- audio_silence_ratio
  result$audio_low_freq_energy <- round(audio_low_freq_energy, 4)
  result$audio_high_freq_energy <- round(audio_high_freq_energy, 4)
  result$audio_spectral_centroid <- round(audio_spectral_centroid, 1)
  
  cli::cli_alert_success("Added 7 audio feature columns")
  
  result
}


#' Extract simple audio loudness per frame
#'
#' A lightweight version of [extract_audio_features()] that only computes
#' RMS loudness. Useful when you only need basic volume information.
#'
#' @param tl_images A tl_images tibble.
#' @param video_path Path to video file.
#' @param fps Frames per second (required if no timing columns).
#'
#' @return The input tibble with added `audio_rms` column.
#'
#' @family audio
#' @export
extract_audio_rms <- function(tl_images, video_path = NULL, fps = NULL) {
  
  if (!requireNamespace("tuneR", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg tuneR} is required. Install with: install.packages('tuneR')")
  }
  if (!requireNamespace("av", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg av} is required. Install with: install.packages('av')")
  }
  
  n <- nrow(tl_images)
  if (n == 0) return(tl_images)
  
  # Get video path
  if (is.null(video_path)) {
    if ("video_source" %in% names(tl_images)) {
      video_path <- unique(tl_images$video_source)[1]
    } else {
      cli::cli_abort("No video path provided.")
    }
  }
  
  # Extract and load audio
  audio_path <- tempfile(fileext = ".wav")
  av::av_audio_convert(video_path, output = audio_path)
  audio <- tuneR::readWave(audio_path)
  
  if (audio@stereo) {
    audio <- tuneR::mono(audio, which = "both")
  }
  
  sample_rate <- audio@samp.rate
  audio_data <- audio@left / 32768  # Normalize
  
  # Get timing
  has_timing <- all(c("start_time", "end_time") %in% names(tl_images))
  
  if (has_timing) {
    start_times <- tl_images$start_time
    end_times <- tl_images$end_time
  } else {
    if (is.null(fps)) cli::cli_abort("fps required without timing columns")
    frame_indices <- seq_len(n)
    start_times <- (frame_indices - 1) / fps
    end_times <- frame_indices / fps
  }
  
  # Compute RMS for each segment
  audio_rms <- vapply(seq_len(n), function(i) {
    start_sample <- max(1, floor(start_times[i] * sample_rate) + 1)
    end_sample <- min(length(audio_data), ceiling(end_times[i] * sample_rate))
    
    if (end_sample <= start_sample) return(NA_real_)
    
    segment <- audio_data[start_sample:end_sample]
    sqrt(mean(segment^2))
  }, numeric(1))
  
  unlink(audio_path)
  
  result <- tl_images
  result$audio_rms <- audio_rms
  
  result
}
