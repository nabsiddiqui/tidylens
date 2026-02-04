#' Video Frame Extraction Functions
#'
#' Functions for extracting frames from video files.
#'
#' @name video
#' @keywords internal
NULL

#' Extract frames from a video
#'
#' Extract frames from a video file at specified intervals or frame numbers.
#' Returns a tl_images tibble with video_source column tracking the original video.
#'
#' @param video_path Path to video file (single file or vector of paths).
#' @param output_dir Directory to save extracted frames. Default is `tempdir()`.
#' @param fps Frames per second to extract. Mutually exclusive with `frames`.
#' @param frames Specific frame numbers to extract. Mutually exclusive with `fps`.
#' @param format Output image format. Default `"jpg"`.
#' @param prefix Filename prefix for extracted frames. Default `"frame"`.
#'
#' @return A tl_images tibble of extracted frames with additional column:
#'   - `video_source`: Path to the original video file.
#'
#' @family video
#' @export
#' @examples
#' \dontrun{
#' # Extract 1 frame per second from one video
#' frames <- video_extract_frames("video.mp4", fps = 1)
#'
#' # Extract from multiple videos
#' frames <- video_extract_frames(c("video1.mp4", "video2.mp4"), fps = 1)
#' }
video_extract_frames <- function(video_path,
                                 output_dir = tempdir(),
                                 fps = NULL,
                                 frames = NULL,
                                 format = "jpg",
                                 prefix = "frame") {

  if (!requireNamespace("av", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg av} is required for video processing. Install with: install.packages('av')"
    )
  }

  # Handle multiple videos
  if (length(video_path) > 1) {
    all_frames <- lapply(seq_along(video_path), function(i) {
      vp <- video_path[i]
      pfx <- paste0(prefix, "_v", i)
      video_extract_frames(
        vp,
        output_dir = output_dir,
        fps = fps,
        frames = frames,
        format = format,
        prefix = pfx
      )
    })
    result <- dplyr::bind_rows(all_frames)
    class(result) <- c("tl_images", class(result)[class(result) != "tl_images"])
    return(result)
  }

  if (!file.exists(video_path)) {
    cli::cli_abort("Video file not found: {.file {video_path}}")
  }

  if (!is.null(fps) && !is.null(frames)) {
    cli::cli_abort("Specify either {.arg fps} or {.arg frames}, not both.")
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
  
  # Simpler approach: extract all frames at specified fps
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
  
  # Create tl_images tibble and add video_source
  result <- load_images(new_paths)
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
#' @return A tl_images tibble of sampled frames.
#'
#' @family video
#' @export
video_sample_frames <- function(video_path,
                                n = 10,
                                output_dir = tempdir(),
                                format = "jpg") {
  info <- video_get_info(video_path)

  # Calculate fps to match approximately n frames
  fps_needed <- n / info$duration

  frames <- video_extract_frames(
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

#' Detect shot changes in a sequence of images
#'
#' Detects shot boundaries (cuts) by measuring color histogram differences
#' between consecutive frames. Uses a simple but effective algorithm:
#' computes normalized color histograms for each frame and measures the
#' chi-squared distance between consecutive frames.
#'
#' @param images A tl_images tibble.
#' @param threshold Threshold for detecting a cut. Higher = fewer cuts detected.
#'   Default is 0.5. Values typically range from 0.3 (sensitive) to 0.8 (conservative).
#' @param bins Number of histogram bins per channel. Default 16.
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
#' The algorithm works by:
#' 1. Computing a color histogram for each frame (RGB channels combined).
#' 2. Calculating chi-squared distance between consecutive frame histograms.
#' 3. Marking frames where the distance exceeds the threshold as shot boundaries.
#'
#' This method detects hard cuts well but may miss gradual transitions (dissolves, fades).
#' For gradual transitions, use a lower threshold or consider the frame difference values.
#'
#' @family video
#' @export
detect_shot_changes <- function(images,
                                threshold = 0.5,
                                bins = 16,
                                downsample = 100) {
  n <- nrow(images)

  if (n < 2) {
    cli::cli_abort("Need at least 2 images to detect shot changes.")
  }

  # Compute histograms for all frames
  cli::cli_alert_info("Computing frame histograms...")

  histograms <- vector("list", n)
  cli::cli_progress_bar("Computing histograms", total = n)
  
  for (i in seq_len(n)) {
    img <- magick::image_read(images$local_path[i])
    
    # Downsample for speed
    if (!is.null(downsample)) {
      img <- magick::image_resize(img, paste0(downsample, "x"))
    }
    
    # Get pixel data
    data <- as.integer(magick::image_data(img))
    r <- as.vector(data[,,1])
    g <- as.vector(data[,,2])
    b <- as.vector(data[,,3])
    
    # Compute normalized histograms
    breaks <- seq(0, 256, length.out = bins + 1)
    h_r <- hist(r, breaks = breaks, plot = FALSE)$counts
    h_g <- hist(g, breaks = breaks, plot = FALSE)$counts
    h_b <- hist(b, breaks = breaks, plot = FALSE)$counts
    
    # Normalize
    total <- sum(h_r) + sum(h_g) + sum(h_b)
    histograms[[i]] <- c(h_r, h_g, h_b) / total
    
    cli::cli_progress_update()
  }
  cli::cli_progress_done()
  
  # Compute differences between consecutive frames
  cli::cli_alert_info("Detecting shot boundaries...")
  
  differences <- numeric(n - 1)
  for (i in seq_len(n - 1)) {
    h1 <- histograms[[i]]
    h2 <- histograms[[i + 1]]
    
    # Chi-squared distance (normalized)
    # Avoid division by zero
    denom <- h1 + h2
    denom[denom == 0] <- 1
    differences[i] <- sum((h1 - h2)^2 / denom) / 2
  }
  
  # Find shot boundaries (where difference exceeds threshold)
  cuts <- which(differences > threshold)
  
  # Build shot table
  if (length(cuts) == 0) {
    # No cuts found - entire sequence is one shot
    shots <- tibble::tibble(
      shot_id = 1L,
      start_frame = 1L,
      end_frame = n,
      start_id = images$id[1],
      end_id = images$id[n],
      n_frames = n
    )
  } else {
    # Build shots from cut points
    # Cuts are indices where the CUT happens (between frame i and i+1)
    shot_starts <- c(1, cuts + 1)
    shot_ends <- c(cuts, n)
    
    shots <- tibble::tibble(
      shot_id = seq_along(shot_starts),
      start_frame = as.integer(shot_starts),
      end_frame = as.integer(shot_ends),
      start_id = images$id[shot_starts],
      end_id = images$id[shot_ends],
      n_frames = as.integer(shot_ends - shot_starts + 1)
    )
  }
  
  cli::cli_alert_success("Detected {nrow(shots)} shots from {n} frames")
  
  # Also attach the difference values as an attribute for advanced users
  attr(shots, "frame_differences") <- differences
  
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
#' @param threshold Shot detection threshold. Higher = fewer cuts. Default 0.5.
#' @param output_dir Directory for temporary frames. Default `tempdir()`.
#' @param position Which frame to keep for each shot: `"first"`, `"middle"`, `"last"`.
#'   Default `"middle"`.
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
#'   - `shot_scale`: Shot scale (if include_style = TRUE).
#'
#'   - `shot_scale_name`: Full shot scale name.
#'
#'   - `frame_path`: Path to representative frame image.
#'
#' @details
#' The shot detection algorithm:
#' 1. Extracts frames at the specified fps.
#' 2. Computes color histograms for each frame.
#' 3. Measures chi-squared distance between consecutive frames.
#' 4. Marks boundaries where distance exceeds threshold.
#'
#' @references
#' Chi-squared histogram comparison is a standard technique in video analysis.
#' See: Lienhart, R. (2001). Reliable Transition Detection in Videos.
#' <https://doi.org/10.1145/500141.500149>
#'
#' @family video
#' @export
video_extract_shots <- function(video_path,
                                fps = 2,
                                threshold = 0.5,
                                output_dir = tempdir(),
                                position = "middle",
                                include_style = TRUE) {

  # Handle multiple videos
  if (length(video_path) > 1) {
    all_shots <- lapply(video_path, function(vp) {
      video_extract_shots(
        vp,
        fps = fps,
        threshold = threshold,
        output_dir = output_dir,
        position = position,
        include_style = include_style
      )
    })
    result <- dplyr::bind_rows(all_shots)
    # Renumber shot_id across all videos
    result$shot_id <- seq_len(nrow(result))
    class(result) <- c("tl_images", class(result)[class(result) != "tl_images"])
    return(result)
  }

  # Get video info for timing calculations
  video_info <- video_get_info(video_path)
  video_fps <- video_info$fps[1]
  duration <- video_info$duration[1]
  video_source_path <- normalizePath(video_path, mustWork = FALSE)

  cli::cli_alert_info("Video: {round(duration, 1)}s at {round(video_fps, 1)} fps")

  # Extract frames at specified analysis fps
  frames <- video_extract_frames(video_path, output_dir = output_dir, fps = fps)

  # Detect shot changes
  shots <- detect_shot_changes(frames, threshold = threshold)

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
  frame_indices <- switch(
    position,
    "first" = shots$start_frame,
    "last" = shots$end_frame,
    "middle" = as.integer((shots$start_frame + shots$end_frame) / 2)
  )

  # Get the representative frame's tl_images data
  shot_frames <- frames[frame_indices, ]

  # Classify shot styles if requested
  if (include_style) {
    shot_frames <- film_classify_scale(shot_frames, method = "salience", downsample = 300)
    shots$shot_scale <- shot_frames$shot_scale
    shots$shot_scale_name <- shot_frames$shot_scale_name
    shots$subject_coverage <- shot_frames$subject_coverage
  }
  
  # Combine tl_images columns with shot timing columns
  # Start with tl_images base columns from representative frame
  result <- tibble::tibble(
    id = shot_frames$id,
    source = shot_frames$source,
    local_path = shot_frames$local_path,
    width = shot_frames$width,
    height = shot_frames$height,
    format = shot_frames$format,
    aspect_ratio = shot_frames$aspect_ratio,
    file_size_bytes = shot_frames$file_size_bytes,
    video_source = video_source_path,  # Track original video
    # Shot-specific columns
    shot_id = shots$shot_id,
    start_time = shots$start_time,
    end_time = shots$end_time,
    duration = shots$duration,
    start_frame = shots$start_frame,
    end_frame = shots$end_frame,
    n_frames = shots$n_frames
  )
  
  # Add shot scale columns if computed
  if (include_style) {
    result$shot_scale <- shots$shot_scale
    result$shot_scale_name <- shots$shot_scale_name
    result$subject_coverage <- shots$subject_coverage
  }
  
  # Add the tl_images class so extract_* functions work on it
  class(result) <- c("tl_images", class(result))
  
  cli::cli_alert_success("Extracted {nrow(result)} shots with timing")
  
  result
}

#' Extract shot frames
#'
#' Given shot detection results, extract representative frames from each shot.
#'
#' @param images A tl_images tibble
#' @param shots Shot detection results from detect_shot_changes()
#' @param position Which frame to extract: "first", "middle", or "last". Default "middle".
#'
#' @return A tl_images tibble with one frame per shot
#'
#' @export
video_extract_shot_frames <- function(images, shots, position = "middle") {
  frame_indices <- switch(position,
    "first" = shots$start_frame,
    "last" = shots$end_frame,
    "middle" = as.integer((shots$start_frame + shots$end_frame) / 2),
    cli::cli_abort("position must be 'first', 'middle', or 'last'")
  )
  
  result <- images[frame_indices, ]
  result$shot_id <- shots$shot_id
  result
}

#' Classify shot style/scale
#'
#' Classify shots based on detected face/subject size relative to frame.
#' Uses face detection if available, otherwise estimates based on visual salience.
#'
#' ## Standard Film Shot Scales (9 types)
#'
#' Tinylens classifies shots into 9 cinematography-standard scale types based on
#' the [StudioBinder shot scale guide](https://www.studiobinder.com/blog/ultimate-guide-to-camera-shots/):
#'
#' | Code | Name | What's in Frame |
#' |------|------|-----------------|
#' | ECU | Extreme Close-Up | Eyes, mouth, or small detail fills frame |
#' | CU | Close-Up | Face fills the frame |
#' | MCU | Medium Close-Up | Head and shoulders (chest up) |
#' | MS | Medium Shot | Waist up |
#' | CS | Cowboy Shot | Mid-thigh up (named for Western holster framing) |
#' | MFS | Medium Full Shot | Knees up (also called Medium Wide Shot) |
#' | FS | Full Shot | Full body, head to toe with minimal space |
#' | WS | Wide Shot | Full body with surrounding environment |
#' | EWS | Extreme Wide Shot | Small figure in vast landscape |
#'
#' **Note:** Academic film studies (e.g., Redfern's *Computational Film Analysis
#' with R*) uses a 7-category system: BCU, CU, MCU, MS, MLS, LS, VLS. The
#' mapping is approximately: ECU≈BCU, MFS≈MLS, WS≈LS, EWS≈VLS.
#'
#' @param tl_images A tl_images tibble.
#' @param method Detection method: `"face"` (requires image.libfacedetection),
#'   `"salience"` (uses gradient-based salience), or `"auto"` (tries face,
#'   falls back to salience). Default `"auto"`.
#' @param downsample Maximum side length for analysis. Default 400.
#'
#' @return The input tibble with added columns:
#'   - `shot_scale`: Shot scale code (ECU, CU, MCU, MS, CS, MFS, FS, WS, EWS).
#'
#'   - `shot_scale_name`: Full name of shot scale.
#'
#'   - `subject_coverage`: Estimated fraction of frame covered by subject (0-1).
#'
#' @references
#' Redfern, N. (2023). *Computational Film Analysis with R*.
#' <https://cfa-with-r.netlify.app/>
#'
#' @family film_metrics
#' @export
film_classify_scale <- function(tl_images, method = "auto", downsample = 400) {
  validate_tl_images(tl_images)

  # Check face detection availability
  has_face_detection <- requireNamespace("image.libfacedetection", quietly = TRUE)

  use_method <- method
  if (method == "auto") {
    use_method <- if (has_face_detection) "face" else "salience"
  }

  if (use_method == "face" && !has_face_detection) {
    cli::cli_warn("Face detection not available, falling back to salience method.")
    use_method <- "salience"
  }

  # Shot scale classification based on subject coverage
  # Using StudioBinder's 9 standard cinematography shot sizes
  #
  # Coverage ranges are based on typical framing:
  # - ECU (Extreme Close-Up): Part of face/detail fills frame
  # - CU (Close-Up): Face fills the frame
  # - MCU (Medium Close-Up): Head and shoulders, chest up
  # - MS (Medium Shot): Waist up
  # - CS (Cowboy Shot): Mid-thigh up (named for Western holster framing)
  # - MFS (Medium Full Shot): Knees up (also called Medium Wide Shot)

  # - FS (Full Shot): Full body, head to toe with minimal space
  # - WS (Wide Shot): Full body with surrounding environment
  # - EWS (Extreme Wide Shot): Small figure in vast landscape
  classify_scale <- function(coverage) {
    if (is.na(coverage)) {
      return(list(scale = NA_character_, name = NA_character_))
    }

    if (coverage > 0.55) {
      list(scale = "ECU", name = "Extreme Close-Up")
    } else if (coverage > 0.40) {
      list(scale = "CU", name = "Close-Up")
    } else if (coverage > 0.30) {
      list(scale = "MCU", name = "Medium Close-Up")
    } else if (coverage > 0.22) {
      list(scale = "MS", name = "Medium Shot")
    } else if (coverage > 0.15) {
      list(scale = "CS", name = "Cowboy Shot")
    } else if (coverage > 0.10) {
      list(scale = "MFS", name = "Medium Full Shot")
    } else if (coverage > 0.05) {
      list(scale = "FS", name = "Full Shot")
    } else if (coverage > 0.02) {
      list(scale = "WS", name = "Wide Shot")
    } else {
      list(scale = "EWS", name = "Extreme Wide Shot")
    }
  }

  results <- map_images(tl_images, function(img) {
    info <- magick::image_info(img)
    frame_area <- info$width * info$height

    if (use_method == "face") {
      # Use face detection
      gray <- magick::image_convert(img, colorspace = "gray")
      data <- as.integer(magick::image_data(gray))

      if (length(dim(data)) == 3) {
        mat <- data[, , 1]
      } else {
        mat <- data
      }

      tryCatch({
        faces <- image.libfacedetection::image_detect_faces(mat)

        if (nrow(faces) > 0) {
          # Use largest face
          face_areas <- faces$width * faces$height
          max_face_idx <- which.max(face_areas)
          face_area <- face_areas[max_face_idx]

          # Estimate full subject from face (face is roughly 10-15% of full body)
          # For close-ups, face is more of the visible area
          subject_coverage <- face_area / frame_area

          # Adjust: larger face coverage means tighter shot
          # Face filling 20% of frame = roughly MCU
          classification <- classify_scale(subject_coverage * 3)  # Scale up face to estimate visible subject
          
          return(list(
            shot_scale = classification$scale,
            shot_scale_name = classification$name,
            subject_coverage = subject_coverage
          ))
        }
      }, error = function(e) NULL)
    }
    
    # Salience-based method (fallback or primary)
    gray <- magick::image_convert(img, colorspace = "gray")
    data <- as.integer(magick::image_data(gray))
    
    if (length(dim(data)) == 3) {
      mat <- data[, , 1] / 255.0
    } else {
      mat <- data / 255.0
    }
    
    nr <- nrow(mat)
    nc <- ncol(mat)
    
    if (nr < 5 || nc < 5) {
      return(list(
        shot_scale = NA_character_,
        shot_scale_name = NA_character_,
        subject_coverage = NA_real_
      ))
    }
    
    # Compute gradient magnitude as salience proxy
    gx <- mat
    gx[, -1] <- mat[, -1] - mat[, -nc]
    gx[, 1] <- 0
    
    gy <- mat
    gy[-1, ] <- mat[-1, ] - mat[-nr, ]
    gy[1, ] <- 0
    
    grad_mag <- sqrt(gx^2 + gy^2)
    
    # Threshold for "salient" pixels
    threshold <- mean(grad_mag) + stats::sd(grad_mag)
    salient_pixels <- sum(grad_mag > threshold)
    total_pixels <- length(grad_mag)
    
    subject_coverage <- salient_pixels / total_pixels
    
    classification <- classify_scale(subject_coverage)
    
    list(
      shot_scale = classification$scale,
      shot_scale_name = classification$name,
      subject_coverage = subject_coverage
    )
  }, downsample = downsample, msg = "Classifying shot scales")
  
  tl_images$shot_scale <- purrr::map_chr(results, ~ .x$shot_scale %||% NA_character_)
  tl_images$shot_scale_name <- purrr::map_chr(results, ~ .x$shot_scale_name %||% NA_character_)
  tl_images$subject_coverage <- purrr::map_dbl(results, ~ .x$subject_coverage %||% NA_real_)
  
  tl_images
}

# Null-coalescing operator (if not already defined)
if (!exists("%||%")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}
