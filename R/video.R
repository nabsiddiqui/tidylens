#' Video Frame Extraction Functions
#'
#' Functions for extracting frames from video files.
#'
#' @name video
#' @keywords internal
NULL

#' Extract frames from a video
#'
#' Extract frames from a video file at a regular interval. Returns a tl_frames
#' tibble with a `video_source` column tracking the original video.
#'
#' @param video_path Path to video file (single file or vector of paths).
#' @param every Extract one frame every `every` seconds. Default 1 (one frame
#'   per second). Internally converted to `fps = 1 / every`. Mutually exclusive
#'   with `fps`.
#' @param output_dir Directory to save extracted frames. Default is `tempdir()`.
#' @param fps Frames per second to extract. Mutually exclusive with `every`.
#'   Provided for advanced use; prefer `every` for readability.
#' @param format Output image format. Default `"jpg"`.
#' @param prefix Filename prefix for extracted frames. Default `"frame"`.
#'
#' @return A tl_frames tibble of extracted frames with additional column:
#'   - `video_source`: Path to the original video file.
#'
#' @family video
#' @export
#' @examples
#' \dontrun{
#' # Extract one frame every 5 seconds
#' frames <- frame_extract_by_seconds("video.mp4", every = 5)
#'
#' # Extract one frame per second
#' frames <- frame_extract_by_seconds("video.mp4", every = 1)
#'
#' # Extract from multiple videos
#' frames <- frame_extract_by_seconds(c("video1.mp4", "video2.mp4"), every = 2)
#' }
frame_extract_by_seconds <- function(video_path,
                                 every = 1,
                                 output_dir = tempdir(),
                                 fps = NULL,
                                 format = "jpg",
                                 prefix = "frame") {

  if (!requireNamespace("av", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg av} is required for video processing. Install with: install.packages('av')"
    )
  }

  # Only one of every/fps may be specified. Use missing() so an internal
  # caller passing fps= doesn't trip the guard against every's default value.
  if (!missing(every) && !is.null(fps)) {
    cli::cli_abort("Specify {.arg every} or {.arg fps}, not both.")
  }
  if (is.null(fps)) {
    if (!is.numeric(every) || length(every) != 1 || every <= 0) {
      cli::cli_abort("{.arg every} must be a positive number of seconds.")
    }
    fps <- 1 / every
  }

  # Handle multiple videos
  if (length(video_path) > 1) {
    all_frames <- lapply(seq_along(video_path), function(i) {
      vp <- video_path[i]
      pfx <- paste0(prefix, "_v", i)
      frame_extract_by_seconds(
        vp,
        output_dir = output_dir,
        fps = fps,
        format = format,
        prefix = pfx
      )
    })
    result <- dplyr::bind_rows(all_frames)
    class(result) <- c("tl_frames", class(result)[class(result) != "tl_frames"])
    return(result)
  }

  if (!file.exists(video_path)) {
    cli::cli_abort("Video file not found: {.file {video_path}}")
  }

  # Create output directory
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  # Get video info
  info <- av::av_media_info(video_path)
  video_info <- info$video
  
  if (nrow(video_info) == 0) {
    cli::cli_abort("No video stream found in {.file {video_path}}")
  }
  
  total_frames <- video_info$frames[1]
  video_fps <- video_info$framerate[1]
  duration <- info$duration
  
  cli::cli_alert_info("Video: {total_frames} frames, {round(video_fps, 1)} fps, {round(duration, 1)}s")
  
  extract_fps <- fps %||% 1
  
  cli::cli_alert_info("Extracting frames at {extract_fps} fps...")
  
  # Extract frames using av (suppress ffmpeg warnings)
  extracted_files <- suppressMessages(suppressWarnings(
    av::av_video_images(
      video = video_path,
      destdir = output_dir,
      format = format,
      fps = extract_fps
    )
  ))
  
  cli::cli_alert_success("Extracted {length(extracted_files)} frames")
  
  # Rename files to match our pattern
  new_paths <- character(length(extracted_files))
  for (i in seq_along(extracted_files)) {
    new_name <- file.path(output_dir, sprintf("%s_%06d.%s", prefix, i, format))
    file.rename(extracted_files[i], new_name)
    new_paths[i] <- new_name
  }
  
  # Create tl_frames tibble and add video_source
  result <- load_frame_files(new_paths)
  result$video_source <- normalizePath(video_path, mustWork = FALSE)
  
  result
}

#' Download video from URL
#'
#' Download a video file from a URL to a local file. Supports common video
#' hosting sites and direct video URLs.
#'
#' @param url URL of the video to download.
#' @param destfile Path to save the video. If `NULL`, uses temp directory.
#' @param overwrite Overwrite existing file? Default `FALSE`.
#'
#' @return Path to the downloaded video file invisibly.
#'
#' @details
#' For YouTube and other sites that require yt-dlp, install it first:
#' - macOS: `brew install yt-dlp`
#' - Linux: `pip install yt-dlp`
#' - Windows: `winget install yt-dlp`
#'
#' For direct video URLs (e.g., .mp4 files), uses base R `download.file()`.
#'
#' @family video
#' @export
#' @examples
#' \dontrun{
#' # Download from direct URL
#' video_download("https://example.com/video.mp4", "local_video.mp4")
#'
#' # Download multiple videos
#' urls <- c("https://example.com/video1.mp4", "https://example.com/video2.mp4")
#' videos <- sapply(urls, video_download)
#' }
video_download <- function(url, destfile = NULL, overwrite = FALSE) {
  # Generate destfile if not provided
  if (is.null(destfile)) {
    # Extract filename from URL or generate one
    url_basename <- basename(sub("\\?.*$", "", url))
    if (!grepl("\\.(mp4|mkv|webm|avi|mov)$", url_basename, ignore.case = TRUE)) {
      url_basename <- paste0("video_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".mp4")
    }
    destfile <- file.path(tempdir(), url_basename)
  }
  
  # Check if file exists
  if (file.exists(destfile) && !overwrite) {
    cli::cli_alert_info("File already exists: {.file {destfile}}")
    return(invisible(destfile))
  }
  
  # Check if it's a direct video URL or needs yt-dlp
  is_direct_url <- grepl("\\.(mp4|mkv|webm|avi|mov)$", url, ignore.case = TRUE)
  
  if (is_direct_url) {
    # Direct download
    cli::cli_alert_info("Downloading video from: {.url {url}}")
    tryCatch({
      utils::download.file(url, destfile, mode = "wb", quiet = FALSE)
      cli::cli_alert_success("Downloaded to: {.file {destfile}}")
    }, error = function(e) {
      cli::cli_abort("Failed to download: {e$message}")
    })
  } else {
    # Try yt-dlp for YouTube and other sites
    yt_dlp <- Sys.which("yt-dlp")
    
    if (yt_dlp == "") {
      cli::cli_abort(c(
        "yt-dlp is required for this URL type.",
        "i" = "Install with: {.code brew install yt-dlp} (macOS)",
        "i" = "Or: {.code pip install yt-dlp} (Python)",
        "i" = "Or provide a direct video URL ending in .mp4, .webm, etc."
      ))
    }
    
    cli::cli_alert_info("Downloading video with yt-dlp...")
    
    # Use yt-dlp to download
    result <- system2(
      yt_dlp,
      args = c("-o", shQuote(destfile), "--format", "best[ext=mp4]/best", shQuote(url)),
      stdout = TRUE,
      stderr = TRUE
    )
    
    if (!file.exists(destfile)) {
      # yt-dlp may add extension
      possible_files <- list.files(dirname(destfile), 
                                   pattern = paste0("^", tools::file_path_sans_ext(basename(destfile))),
                                   full.names = TRUE)
      if (length(possible_files) > 0) {
        destfile <- possible_files[1]
      } else {
        cli::cli_abort("Download failed. yt-dlp output: {paste(result, collapse = '\n')}")
      }
    }
    
    cli::cli_alert_success("Downloaded to: {.file {destfile}}")
  }
  
  invisible(destfile)
}

#' Get video information
#'
#' Retrieve metadata about a video file as a tibble.
#'
#' @param video_path Path to video file.
#'
#' @return A tibble with one row containing video metadata:
#'   - `source`: Path to the video file.
#'
#'   - `duration`: Video duration in seconds.
#'
#'   - `fps`: Frames per second.
#'
#'   - `width`: Video width in pixels.
#'
#'   - `height`: Video height in pixels.
#'
#'   - `total_frames`: Total number of frames.
#'
#'   - `codec`: Video codec.
#'
#' @family video
#' @export
video_get_info <- function(video_path) {
  if (!requireNamespace("av", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg av} is required for video processing.")
  }

  if (!file.exists(video_path)) {
    cli::cli_abort("Video file not found: {.file {video_path}}")
  }

  info <- av::av_media_info(video_path)
  video <- info$video

  if (nrow(video) == 0) {
    cli::cli_abort("No video stream found in {.file {video_path}}")
  }

  tibble::tibble(
    source = video_path,
    duration = info$duration,
    fps = video$framerate[1],
    width = video$width[1],
    height = video$height[1],
    total_frames = video$frames[1],
    codec = video$codec[1]
  )
}

#' Sample frames from video
#'
#' Extract frames at regular intervals to create a summary of the video.
#'
#' @param video_path Path to video file.
#' @param n Number of frames to extract (evenly spaced).
#' @param output_dir Directory to save extracted frames.
#' @param format Output image format. Default `"jpg"`.
#'
#' @return A tl_frames tibble of sampled frames.
#'
#' @family video
#' @export
frame_extract_evenly <- function(video_path,
                                n = 10,
                                output_dir = tempdir(),
                                format = "jpg") {
  info <- video_get_info(video_path)

  # Calculate fps to match approximately n frames
  fps_needed <- n / info$duration

  frames <- frame_extract_by_seconds(
    video_path,
    output_dir = output_dir,
    fps = fps_needed,
    format = format
  )

  # Select exact n frames if we got more
  if (nrow(frames) > n) {
    indices <- round(seq(1, nrow(frames), length.out = n))
    frames <- frames[indices, ]
  }

  frames
}

#' Detect shot changes in a sequence of frames
#'
#' Detects shot boundaries (cuts) by measuring color histogram differences
#' between consecutive frames. Uses a simple but effective algorithm:
#' computes normalized color histograms for each frame and measures the
#' chi-squared distance between consecutive frames.
#'
#' @param frames A tl_frames tibble.
#' @param method Shot-detection method: `"adaptive"` (default), `"content"`,
#'   or `"histogram"` (original pre-1.x behaviour).
#' @param threshold Threshold for the histogram and content methods. Higher =
#'   fewer cuts. Default 0.5.
#' @param adaptive_threshold Adaptive ratio cutoff (adaptive method). Default 3.0.
#' @param window Rolling-mean half-width in frames (adaptive method). Default 2.
#' @param min_content_val Minimum absolute HSV score to register a cut
#'   (adaptive method). Default 15.
#' @param min_scene_len Minimum gap between cuts, in frames. Suppresses
#'   flash/strobe; set to 0 to disable. Default 0.
#' @param bins Histogram bins per channel (histogram method). Default 16.
#' @param downsample Max dimension for resizing before analysis. Default 100.
#'
#' @return A tibble with detected shot boundaries:
#'   - `shot_id`: Sequential shot number.
#'
#'   - `start_frame`: First frame index of the shot.
#'
#'   - `end_frame`: Last frame index of the shot.
#'
#'   - `start_id`: ID of first frame.
#'
#'   - `end_id`: ID of last frame.
#'
#'   - `n_frames`: Number of frames in the shot.
#'
#' @details
#' Three methods are supported, selected via `method`:
#'
#' - `"histogram"` (original): normalised RGB color histograms compared with
#'   a chi-squared distance; a cut is reported wherever the distance exceeds
#'   `threshold`. Reproduces the pre-1.x default bit-for-bit.
#' - `"content"`: HSV mean absolute pixel distance (the PySceneDetect
#'   ContentDetector score); cut where `score >= threshold`. Scores are on
#'   the 0-255 scale, so `threshold` here is independent of the histogram scale.
#' - `"adaptive"` (default): same HSV score, but the threshold is not fixed.
#'   For each frame `t`, `ratio = score_t / mean(score over +/- window frames,
#'   excluding t)`. A cut is reported when `ratio >= adaptive_threshold`
#'   *and* `score_t >= min_content_val`. Self-calibrates to local pacing, so
#'   it suppresses false cuts from fast camera motion / lighting flicker that
#'   a single global threshold cannot.
#'
#' `min_scene_len` (frames) suppresses cuts closer than this to the previous
#' accepted cut — a flash/strobe guard. Set to 0 to disable.
#'
#' The per-frame scores are attached as attribute `"frame_differences"` for
#' inspection; the method is attached as attribute `"method"`.
#'
#' @references
#' Castellano, B. PySceneDetect ContentDetector / AdaptiveDetector.
#' <https://www.scenedetect.com/docs/latest/api/detectors.html>
#'
#' Lienhart, R. (2001). Reliable Transition Detection in Videos.
#' <https://doi.org/10.1145/500141.500149>
#'
#' @family video
#' @export
detect_shot_changes <- function(frames,
                                 method = c("adaptive", "content", "histogram"),
                                threshold = 0.5,
                                adaptive_threshold = 3.0,
                                window = 2,
                                min_content_val = 15,
                                min_scene_len = 0,
                                bins = 16,
                                downsample = 100) {
  n <- nrow(frames)

  if (n < 2) {
    cli::cli_abort("Need at least 2 frames to detect shot changes.")
  }

  method <- match.arg(method)

  # Per-frame descriptors depend on method
  if (method == "histogram") {
    descriptors <- compute_histograms(frames, bins, downsample)
    score <- function(prev, curr) {
      denom <- prev + curr
      denom[denom == 0] <- 1
      sum((prev - curr)^2 / denom) / 2
    }
  } else {
    descriptors <- compute_hsv_planes(frames, downsample)
    score <- hsv_content_score
  }

  cli::cli_alert_info("Detecting shot boundaries ({method})...")

  # Consecutive-frame score vector (length n-1; score[i] is between i and i+1)
  diffs <- numeric(n - 1)
  for (i in seq_len(n - 1)) {
    diffs[i] <- score(descriptors[[i]], descriptors[[i + 1]])
  }

  # Decide cut positions depending on method
  if (method == "adaptive") {
    cuts <- adaptive_cuts(diffs, adaptive_threshold, window, min_content_val)
  } else {
    cuts <- which(diffs > threshold)
  }

  # Enforce minimum shot length (flash/strobe guard)
  if (is.numeric(min_scene_len) && length(min_scene_len) == 1 &&
      !is.na(min_scene_len) && min_scene_len > 0 && length(cuts) > 0) {
    keep <- logical(length(cuts))
    keep[1] <- TRUE
    last <- cuts[1]
    for (k in seq_along(cuts)[-1]) {
      if (cuts[k] - last >= min_scene_len) {
        keep[k] <- TRUE
        last <- cuts[k]
      }
    }
    cuts <- cuts[keep]
  }

  shots <- build_shots(cuts, n, frames)
  attr(shots, "frame_differences") <- diffs
  attr(shots, "method") <- method

  cli::cli_alert_success("Detected {nrow(shots)} shots from {n} frames")

  shots
}

# ---- internals -------------------------------------------------------------

# Per-frame normalised RGB color histograms (vector of length bins*3).
compute_histograms <- function(frames, bins, downsample) {
  cli::cli_progress_bar("Computing histograms", total = nrow(frames))
  out <- vector("list", nrow(frames))
  bin_width <- 256 / bins
  for (i in seq_len(nrow(frames))) {
    img <- magick::image_read(frames$local_path[i])
    if (!is.null(downsample)) {
      img <- magick::image_resize(img, paste0(downsample, "x"))
    }
    data <- as.integer(magick::image_data(img, channels = "rgb"))
    h_r <- tabulate(as.integer(as.vector(data[, , 1]) / bin_width) + 1L, nbins = bins)
    h_g <- tabulate(as.integer(as.vector(data[, , 2]) / bin_width) + 1L, nbins = bins)
    h_b <- tabulate(as.integer(as.vector(data[, , 3]) / bin_width) + 1L, nbins = bins)
    total <- sum(h_r) + sum(h_g) + sum(h_b)
    out[[i]] <- c(h_r, h_g, h_b) / total
    cli::cli_progress_update()
  }
  cli::cli_progress_done()
  out
}

# Per-frame HSV planes (H, S, V as integer matrices, 0-255).
compute_hsv_planes <- function(frames, downsample) {
  cli::cli_progress_bar("Computing HSV frames", total = nrow(frames))
  out <- vector("list", nrow(frames))
  for (i in seq_len(nrow(frames))) {
    img <- magick::image_read(frames$local_path[i])
    if (!is.null(downsample)) {
      img <- magick::image_resize(img, paste0(downsample, "x"))
    }
    img <- magick::image_convert(img, colorspace = "HSV")
    data <- as.integer(magick::image_data(img, channels = "rgb"))  # H,S,V in the 3 planes
    out[[i]] <- list(h = data[, , 1], s = data[, , 2], v = data[, , 3])
    cli::cli_progress_update()
  }
  cli::cli_progress_done()
  out
}

# PySceneDetect ContentDetector score: mean of per-channel mean(|delta|).
# ponytail: equal channel weights, no edge component (heavier; skip until measured need).
# Hue wraps 0<->255 via pmin(d, 256-d) so red-near-0 and red-near-255 aren't far apart.
hsv_content_score <- function(prev, curr) {
  dh <- abs(as.vector(prev$h) - as.vector(curr$h))
  dh <- pmin(dh, 256 - dh)
  ds <- abs(as.vector(prev$s) - as.vector(curr$s))
  dv <- abs(as.vector(prev$v) - as.vector(curr$v))
  (mean(dh) + mean(ds) + mean(dv)) / 3
}

# Adaptive cut selection from a score vector: a cut at position t when
# ratio = score_t / mean(neighbours +/- window, excluding t) >= threshold
# AND score_t >= min_content_val. Position t indexes `diffs` (between t and t+1).
adaptive_cuts <- function(diffs, adaptive_threshold, window, min_content_val) {
  m <- length(diffs)
  if (m == 0) return(integer(0))

  cuts <- integer(0)
  for (t in seq_len(m)) {
    st <- diffs[t]
    if (st < min_content_val) next
    lo <- max(1, t - window)
    hi <- min(m, t + window)
    neighbours <- diffs[setdiff(seq(lo, hi), t)]
    if (length(neighbours) == 0) next
    mu <- mean(neighbours)
    ratio <- if (abs(mu) < 1e-9) 255.0 else min(st / mu, 255.0)
    if (ratio >= adaptive_threshold) cuts <- c(cuts, t)
  }
  cuts
}

# Assemble the shot tibble from cut positions (indices into diffs / frames).
build_shots <- function(cuts, n, frames) {
  if (length(cuts) == 0) {
    shots <- tibble::tibble(
      shot_id = 1L,
      start_frame = 1L,
      end_frame = n,
      start_id = frames$id[1],
      end_id = frames$id[n],
      n_frames = n
    )
  } else {
    shot_starts <- c(1, cuts + 1)
    shot_ends <- c(cuts, n)
    shots <- tibble::tibble(
      shot_id = seq_along(shot_starts),
      start_frame = as.integer(shot_starts),
      end_frame = as.integer(shot_ends),
      start_id = frames$id[shot_starts],
      end_id = frames$id[shot_ends],
      n_frames = as.integer(shot_ends - shot_starts + 1)
    )
  }
  shots
}

#' Extract shots from video with timing
#'
#' Analyze a video file directly to detect shots and return timing information.
#' This is a convenience function that combines frame extraction, shot detection,
#' and timing calculation in one step.
#'
#' ## How it works (ELI5)
#' This function watches the video and notices when the scene changes (like when
#' a movie cuts from one camera angle to another). It tells you when each shot
#' starts and ends in seconds, plus how long it lasts.
#'
#' @param video_path Path to video file.
#' @param fps Frames per second to analyze. Higher = more accurate but slower. Default 2.
#' @param method Shot-detection method: `"adaptive"` (default), `"content"`, or
#'   `"histogram"` (pre-1.x behaviour). See [detect_shot_changes()].
#' @param threshold Shot detection threshold (histogram & content methods). Higher = fewer cuts.
#' @param adaptive_threshold Adaptive ratio cutoff (adaptive method). Default 3.0.
#' @param window Rolling-mean half-width (adaptive method). Default 2.
#' @param min_content_val Minimum absolute HSV score to cut (adaptive method). Default 15.
#' @param min_scene_len Minimum gap between cuts, in analysis frames. By default the gap
#'   is derived from `fps` (about 0.25 s) to suppress flash/strobe; set to 0 to disable.
#' @param output_dir Directory for temporary frames. Default `tempdir()`.
#' @param position Which frame to keep for each shot: `"first"`, `"middle"`,
#'   or `"last"`. Default `"middle"`.
#' @param include_style Whether to classify shot scale (ECU, CU, etc.). Default `TRUE`.
#'
#' @return A tibble with one row per shot containing:
#'   - `shot_id`: Sequential shot number.
#'
#'   - `start_time`: Start time in seconds.
#'
#'   - `end_time`: End time in seconds.
#'
#'   - `duration`: Shot duration in seconds.
#'
#'   - `start_frame`: Frame index of start.
#'
#'   - `end_frame`: Frame index of end.
#'
#'   - `n_frames`: Number of frames in shot.
#'
#'   - `shot_scale`: Broad shot scale group: Close, Medium, or Long
#'     (if include_style = TRUE).
#'
#'   - `shot_scale_confidence`: Random Forest class probability for the predicted shot scale.
#'
#'   - `frame_path`: Path to representative frame image.
#'
#' @details
#' The shot detection algorithm is forwarded to [detect_shot_changes()]; see
#' that function for the full method catalogue. The default `"adaptive"` method
#' self-calibrates to local pacing and is more robust to fast motion and
#' lighting changes than the original fixed-threshold histogram detector.
#'
#' @references
#' Chi-squared histogram comparison is a standard technique in video analysis.
#' See: Lienhart, R. (2001). Reliable Transition Detection in Videos.
#' <https://doi.org/10.1145/500141.500149>
#'
#' @family video
#' @export
frame_extract_shots <- function(video_path,
                                fps = 2,
                                method = c("adaptive", "content", "histogram"),
                                threshold = 0.5,
                                adaptive_threshold = 3.0,
                                window = 2,
                                min_content_val = 15,
                                min_scene_len = NULL,
                                output_dir = tempdir(),
                                position = "middle",
                                include_style = TRUE) {

  # Handle multiple videos
  if (length(video_path) > 1) {
    all_shots <- lapply(video_path, function(vp) {
      frame_extract_shots(
        vp,
        fps = fps,
        method = method,
        threshold = threshold,
        adaptive_threshold = adaptive_threshold,
        window = window,
        min_content_val = min_content_val,
        min_scene_len = min_scene_len,
        output_dir = output_dir,
        position = position,
        include_style = include_style
      )
    })
    result <- dplyr::bind_rows(all_shots)
    # Renumber shot_id across all videos
    result$shot_id <- seq_len(nrow(result))
    class(result) <- c("tl_frames", class(result)[class(result) != "tl_frames"])
    return(result)
  }

  # Get video info for timing calculations
  video_info <- video_get_info(video_path)
  video_fps <- video_info$fps[1]
  duration <- video_info$duration[1]
  video_source_path <- normalizePath(video_path, mustWork = FALSE)

  cli::cli_alert_info("Video: {round(duration, 1)}s at {round(video_fps, 1)} fps")

  # Extract frames at specified analysis fps
  frames <- frame_extract_by_seconds(video_path, output_dir = output_dir, fps = fps)

  # Detect shot changes
  method <- match.arg(method)
  # ponytail: derive a ~0.25 s flash/strobe guard from the analysis fps unless overridden.
  min_scene_len <- if (is.null(min_scene_len)) max(1L, round(fps * 0.25)) else min_scene_len
  shots <- detect_shot_changes(
    frames,
    method = method,
    threshold = threshold,
    adaptive_threshold = adaptive_threshold,
    window = window,
    min_content_val = min_content_val,
    min_scene_len = min_scene_len
  )

  # Calculate timing based on analysis fps
  # Each frame represents 1/fps seconds
  time_per_frame <- 1 / fps

  shots$start_time <- (shots$start_frame - 1) * time_per_frame
  shots$end_time <- shots$end_frame * time_per_frame
  shots$duration <- shots$end_time - shots$start_time

  # Ensure end_time doesn't exceed video duration
  shots$end_time <- pmin(shots$end_time, duration)
  shots$duration <- shots$end_time - shots$start_time

  # Get representative frame for each shot
  if (!position %in% c("first", "middle", "last")) {
    cli::cli_abort("{.arg position} must be {.val first}, {.val middle}, or {.val last}.")
  }
  frame_indices <- switch(
    position,
    "first" = shots$start_frame,
    "last" = shots$end_frame,
    "middle" = as.integer((shots$start_frame + shots$end_frame) / 2)
  )

  # Get the representative frame's tl_frames data
  shot_frames <- frames[frame_indices, ]

  # Classify shot styles if requested
  if (include_style) {
    shot_frames <- frame_classify_scale(shot_frames)
    shots$shot_scale <- shot_frames$shot_scale
    shots$shot_scale_confidence <- shot_frames$shot_scale_confidence
  }
  
  # Combine representative frame's tl_frames columns with shot timing columns
  shot_cols <- shots[, c("shot_id", "start_time", "end_time", "duration",
                         "start_frame", "end_frame", "n_frames")]
  if (include_style) {
    shot_cols$shot_scale <- shots$shot_scale
    shot_cols$shot_scale_confidence <- shots$shot_scale_confidence
  }
  result <- dplyr::bind_cols(
    shot_frames,
    tibble::tibble(video_source = video_source_path),
    shot_cols
  )

  # Add the tl_frames class so frame_extract_* functions work on it
  class(result) <- c("tl_frames", class(result))

  cli::cli_alert_success("Extracted {nrow(result)} shots with timing")

  result
}

#' Classify shot scale
#'
#' Classify the cinematographic shot scale of each frame using a classical
#' Random Forest trained on engineered features. The classifier follows
#' Canini, Benini & Leonardi (2011): it extracts interpretable, formula-based
#' features — spectral residual saliency (Hou & Zhang, 2007), face coverage
#' ratio (cascade detector, non-CNN), geometric and texture cues — and passes
#' them to a Random Forest trained on the CineScale
#' benchmark. The entire pipeline runs on CPU with no deep-learning dependency.
#'
#' ## Shot Scale Categories
#'
#' The classifier assigns one of three broad shot scale categories:
#'
#' | Group | What's in Frame |
#' |-------|-----------------|
#' | Close | Face or detail fills the frame (ECU, CU, MCU) |
#' | Medium | Waist to knees (MS, MLS) |
#' | Long | Full body or landscape (LS, ELS) |
#'
#' @param tl_frames A tl_frames tibble.
#'
#' @return The input tibble with added columns:
#'   - `shot_scale`: Broad shot scale group: Close, Medium, or Long.
#'
#'   - `shot_scale_confidence`: Random Forest class probability for the
#'     predicted class (a value between 0 and 1).
#'
#' @references
#' Canini, L., Benini, S., & Leonardi, R. (2013). Classifying cinematographic
#' shot types. *Multimedia Tools and Applications*, 62(1), 51-73.
#' \doi{10.1007/s11042-011-0916-9}
#'
#' Hou, X., & Zhang, L. (2007). Saliency detection: A spectral residual
#' approach. *CVPR 2007*.
#'
#' Savardi, M., Kovacs, A.B., Signoroni, A., & Benini, S. (2021). CineScale:
#' A dataset of cinematic shot scale in movies. *Data in Brief*, 36, 107002.
#' \doi{10.1016/j.dib.2021.107002}
#'
#' @family classification
#' @export
frame_classify_scale <- function(tl_frames) {
  validate_tl_frames(tl_frames)

  if (!requireNamespace("ranger", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg ranger} is required for shot scale classification. Install with: install.packages('ranger')")
  }

  model_path <- system.file("models", "shot_scale_classical.rds",
                            package = "tidylens")
  if (!nzchar(model_path)) {
    cli::cli_abort(
      "Shot scale model not found in package installation.",
      "i" = "Reinstall the package or run tools/train_shot_scale_classical.R"
    )
  }
  bundle <- readRDS(model_path)

  results <- map_images(tl_frames, function(img) {
    tryCatch({
      info <- magick::image_info(img)
      feats <- extract_shot_scale_features(img, info)
      feats_df <- as.data.frame(as.list(feats))
      if (!is.null(bundle$feature_names)) {
        feats_df <- feats_df[, bundle$feature_names, drop = FALSE]
      }
      probs <- predict(bundle$model, feats_df)$predictions
      pred_idx <- max.col(probs)
      list(
        shot_scale = colnames(probs)[pred_idx],
        shot_scale_confidence = as.numeric(probs[1, pred_idx])
      )
    }, error = function(e) {
      list(shot_scale = NA_character_,
           shot_scale_confidence = NA_real_)
    })
  }, downsample = 400, msg = "Classifying shot scales")

  bind_results(tl_frames, results)
}

#' Extract keyframes (I-frames) from a video
#'
#' Extract the encoder's intra-coded frames (I-frames / keyframes) directly
#' from the video file. Keyframes are full-quality stills embedded by the
#' encoder; their positions only loosely correlate with semantic scene
#' changes, so this is a fast, lightweight alternative to shot detection when
#' you want high-quality representative stills without running the full
#' shot-boundary pipeline.
#'
#' ## Keyframes vs shot frames (ELI5)
#'
#' - `frame_extract_shots()` runs tidylens's own shot detection and picks one
#'   representative frame per detected shot. Slow, semantic.
#' - `frame_extract_keyframes()` reads the encoder's pre-existing I-frames
#'   straight from the file. Fast, no shot detection, but the positions are
#'   decided by the codec (typically every 1-2 seconds), not by content.
#'
#' @param video_path Path to video file (single file or vector of paths).
#' @param output_dir Directory to save extracted keyframes. Default `tempdir()`.
#' @param format Output image format. Default `"jpg"`.
#' @param prefix Filename prefix for extracted frames. Default `"keyframe"`.
#'
#' @return A `tl_frames` tibble of keyframes with `video_source` column.
#'
#' @details
#' Uses [av::av_encode_video()] with the ffmpeg `select=eq(pict_type,I)` filter
#' to pull only I-frames from the video stream. No shot detection is
#' performed. If the `av` path cannot write an image sequence, falls back to
#' `system2("ffmpeg", ...)`.
#'
#' @references
#' ffmpeg select filter: <https://ffmpeg.org/ffmpeg-filters.html#select>
#'
#' @family video
#' @export
#' @examples
#' \dontrun{
#' keyframes <- frame_extract_keyframes("film.mp4")
#' }
frame_extract_keyframes <- function(video_path,
                                     output_dir = tempdir(),
                                     format = "jpg",
                                     prefix = "keyframe") {
  if (!requireNamespace("av", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg av} is required. Install with: install.packages('av')"
    )
  }

  # Handle multiple videos
  if (length(video_path) > 1) {
    all_kf <- lapply(seq_along(video_path), function(i) {
      frame_extract_keyframes(
        video_path[i],
        output_dir = output_dir,
        format = format,
        prefix = paste0(prefix, "_v", i)
      )
    })
    result <- dplyr::bind_rows(all_kf)
    class(result) <- c("tl_frames", class(result)[class(result) != "tl_frames"])
    return(result)
  }

  if (!file.exists(video_path)) {
    cli::cli_abort("Video file not found: {.file {video_path}}")
  }

  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

  video_source_path <- normalizePath(video_path, mustWork = FALSE)
  out_pattern <- file.path(output_dir, sprintf("%s_%%06d.%s", prefix, format))
  unlink(list.files(output_dir, pattern = sprintf("^%s_.*\\.%s$", prefix, format),
                    full.names = TRUE))

  cli::cli_alert_info("Extracting keyframes (I-frames) from {basename(video_path)}...")

  # Primary path: av_encode_video with the select filter. av uses its own
  # bundled ffmpeg libs, so this works even when system ffmpeg is missing/broken.
  extracted <- tryCatch({
    av::av_encode_video(video_path, output = out_pattern,
                        vfilter = "select='eq(pict_type,I)'", verbose = FALSE)
    list.files(output_dir, pattern = sprintf("^%s_.*\\.%s$", prefix, format),
              full.names = TRUE)
  }, error = function(e) NULL)

  # Fallback: system2 ffmpeg if av produced nothing and ffmpeg is available.
  if (is.null(extracted) || length(extracted) == 0) {
    ff <- Sys.which("ffmpeg")
    if (nzchar(ff)) {
      args <- c("-y", "-i", video_path, "-vf", "select=eq(pict_type,I)",
                 "-vsync", "vfr", "-q:v", "2", out_pattern)
      tryCatch(system2(ff, args, stdout = FALSE, stderr = FALSE),
               error = function(e) NULL)
      extracted <- list.files(output_dir,
                              pattern = sprintf("^%s_.*\\.%s$", prefix, format),
                              full.names = TRUE)
    }
  }

  if (is.null(extracted) || length(extracted) == 0) {
    cli::cli_warn("No keyframes extracted from {basename(video_path)}.")
    return(load_frame_files(character(0)))
  }

  # Sort by numeric suffix so frames are in temporal order.
  extracted <- sort(extracted)

  cli::cli_alert_success("Extracted {length(extracted)} keyframes")

  result <- load_frame_files(extracted)
  result$video_source <- video_source_path
  result
}
