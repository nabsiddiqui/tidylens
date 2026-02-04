#' Film Pacing and Rhythm Analysis
#'
#' Functions for analyzing film editing pace, rhythm, and shot patterns.
#' These functions aggregate shot-level data into film-level metrics.
#'
#' @name film_metrics
#' @keywords internal
NULL

#' Compute Average Shot Length (ASL)
#'
#' Calculate pacing metrics from a shots tibble. ASL is a fundamental measure
#' of editing pace in film analysis.
#'
#' ## What is ASL? (ELI5)
#'
#' ASL tells you how fast a film is cut. A low ASL (like 2 seconds) means
#' lots of quick cuts (action movie). A high ASL (like 10+ seconds) means
#' longer, lingering shots (art film).
#'
#' @param shots A tibble with shot data containing a `duration` column.
#'   Typically from [video_extract_shots()] or [detect_shot_changes()].
#'
#' @return A tibble with one row containing:
#'   - `asl`: Average Shot Length in seconds.
#'
#'   - `asl_median`: Median shot length (less affected by outliers).
#'
#'   - `asl_std`: Standard deviation of shot lengths.
#'
#'   - `shot_count`: Total number of shots.
#'
#'   - `total_duration`: Total film/sequence duration.
#'
#'   - `shortest_shot`: Duration of shortest shot.
#'
#'   - `longest_shot`: Duration of longest shot.
#'
#'   - `shots_per_minute`: Average cuts per minute.
#'
#' @details
#' **Academic context:**
#' ASL was popularized by Barry Salt's film style analysis. The Cinemetrics
#' project (cinemetrics.lv) has collected ASL data for thousands of films.
#'
#' **Typical values:**
#' - Modern action film: ASL ~2-3 seconds
#' - Classic Hollywood: ASL ~6-8 seconds
#' - Art house/documentary: ASL ~12+ seconds
#' - Michael Bay films: ASL ~2 seconds
#' - Hitchcock: ASL ~8-10 seconds
#'
#' @references
#' Salt, B. (2009). Film Style and Technology: History and Analysis.
#' Cinemetrics project: <https://www.cinemetrics.lv/>
#'
#' @family film_metrics
#' @export
#' @examples
#' \dontrun{
#' shots <- video_extract_shots("film.mp4")
#' film_compute_asl(shots)
#' }
film_compute_asl <- function(shots) {
  if (!"duration" %in% names(shots)) {
    cli::cli_abort(
      "Input must have a {.field duration} column. Use {.fn video_extract_shots} first."
    )
  }

  durations <- shots$duration
  n <- length(durations)
  total <- sum(durations, na.rm = TRUE)

  tibble::tibble(
    asl = mean(durations, na.rm = TRUE),
    asl_median = stats::median(durations, na.rm = TRUE),
    asl_std = stats::sd(durations, na.rm = TRUE),
    shot_count = n,
    total_duration = total,
    shortest_shot = min(durations, na.rm = TRUE),
    longest_shot = max(durations, na.rm = TRUE),
    shots_per_minute = n / (total / 60)
  )
}

#' Compute Shot Rhythm Metrics
#'
#' Analyze the pattern and regularity of editing rhythm.
#'
#' ## What is editing rhythm? (ELI5)
#'
#' Beyond just "how fast," rhythm describes the *pattern* of editing.
#' Is it steady like a metronome, or unpredictable like jazz?
#' This tells you if the editor is building tension or keeping things calm.
#'
#' @param shots A tibble with shot data containing a `duration` column.
#'
#' @return A tibble with one row containing:
#'   - `rhythm_entropy`: Randomness of shot lengths (0-1, higher = more chaotic).
#'
#'   - `rhythm_regularity`: How consistent shot lengths are (0-1, higher = more regular).
#'
#'   - `rhythm_acceleration`: Is cutting speeding up (positive) or slowing (negative)?
#'
#'   - `rhythm_range_ratio`: Ratio of longest to shortest shot.
#'
#'   - `rhythm_quartile_25`: 25th percentile shot duration.
#'
#'   - `rhythm_quartile_75`: 75th percentile shot duration.
#'
#' @details
#' **Interpretation:**
#' - High regularity + low entropy = Metronomic editing (music videos, TV shows).
#' - Low regularity + high entropy = Chaotic editing (experimental, avant-garde).
#' - Positive acceleration = Building toward climax.
#' - Negative acceleration = Winding down.
#'
#' @family film_metrics
#' @export
#' @examples
#' \dontrun{
#' shots <- video_extract_shots("film.mp4")
#' film_compute_rhythm(shots)
#' }
film_compute_rhythm <- function(shots) {
  if (!"duration" %in% names(shots)) {
    cli::cli_abort(
      "Input must have a {.field duration} column. Use {.fn video_extract_shots} first."
    )
  }

  durations <- shots$duration
  n <- length(durations)

  if (n < 2) {
    cli::cli_warn("Need at least 2 shots for rhythm analysis.")
    return(tibble::tibble(
      rhythm_entropy = NA_real_,
      rhythm_regularity = NA_real_,
      rhythm_acceleration = NA_real_,
      rhythm_range_ratio = NA_real_,
      rhythm_quartile_25 = NA_real_,
      rhythm_quartile_75 = NA_real_
    ))
  }

  # Normalize durations to probabilities for entropy
  p <- durations / sum(durations, na.rm = TRUE)
  p <- p[p > 0]  # Avoid log(0)

  # Shannon entropy (normalized to 0-1)
  entropy_raw <- -sum(p * log2(p))
  max_entropy <- log2(n)  # Maximum possible entropy for n shots
  rhythm_entropy <- entropy_raw / max_entropy

  # Regularity (coefficient of variation inverted)
  cv <- stats::sd(durations, na.rm = TRUE) / mean(durations, na.rm = TRUE)
  rhythm_regularity <- 1 / (1 + cv)

  # Acceleration (slope of shot lengths over time)
  # Positive = getting faster (shorter shots), Negative = getting slower
  if (n >= 3) {
    # Fit linear model to shot durations
    fit <- stats::lm(durations ~ seq_along(durations))
    rhythm_acceleration <- -stats::coef(fit)[2]  # Negate so positive = faster cutting
  } else {
    rhythm_acceleration <- durations[1] - durations[n]  # Simple difference
  }

  tibble::tibble(
    rhythm_entropy = rhythm_entropy,
    rhythm_regularity = rhythm_regularity,
    rhythm_acceleration = as.numeric(rhythm_acceleration),
    rhythm_range_ratio = max(durations, na.rm = TRUE) / min(durations, na.rm = TRUE),
    rhythm_quartile_25 = stats::quantile(durations, 0.25, na.rm = TRUE),
    rhythm_quartile_75 = stats::quantile(durations, 0.75, na.rm = TRUE)
  )
}

#' Summarize Shot Scale Distribution
#'
#' Count and summarize the distribution of shot scales (ECU, CU, MS, etc.).
#'
#' ## What is shot scale distribution? (ELI5)
#'
#' This tells you what kinds of shots a film uses most. Does it prefer
#' close-ups (intimate, emotional) or wide shots (epic, environmental)?
#'
#' @param shots A tibble with shot data containing a `shot_scale` column.
#'   Typically from [video_extract_shots()] or [film_classify_scale()].
#'
#' @return A tibble with one row per shot scale containing:
#'   - `shot_scale`: Shot scale code (ECU, CU, MCU, MS, CS, MFS, FS, WS, EWS).
#'
#'   - `count`: Number of shots at this scale.
#'
#'   - `proportion`: Fraction of total shots.
#'
#'   - `pct`: Percentage of total shots.
#'
#' @family film_metrics
#' @export
#' @examples
#' \dontrun{
#' shots <- video_extract_shots("film.mp4")
#' film_summarize_scales(shots)
#' }
film_summarize_scales <- function(shots) {
  if (!"shot_scale" %in% names(shots)) {
    cli::cli_abort(
      "Input must have a {.field shot_scale} column. Use {.fn video_extract_shots} or {.fn film_classify_scale} first."
    )
  }

  # Define scale order for proper sorting (tight to wide)
  # StudioBinder's 9 standard cinematography shot scales
  scale_order <- c("ECU", "CU", "MCU", "MS", "CS", "MFS", "FS", "WS", "EWS")

  result <- shots |>
    dplyr::count(.data$shot_scale, name = "count") |>
    dplyr::mutate(
      proportion = .data$count / sum(.data$count),
      pct = .data$proportion * 100,
      shot_scale = factor(.data$shot_scale, levels = scale_order)
    ) |>
    dplyr::arrange(.data$shot_scale) |>
    dplyr::mutate(shot_scale = as.character(.data$shot_scale))
  
  result
}


#' Classify camera angle
#'
#' Detect camera angle based on visual cues in the image. Uses line detection
#' to identify horizon line position and vanishing points.
#'
#' ## Camera Angle Types (ELI5)
#' 
#' | Angle | Description | Detection Method |
#' |-------|-------------|------------------|
#' | **high_angle** | Looking down on subject | Horizon high in frame, lines converge up |
#' | **low_angle** | Looking up at subject | Horizon low in frame, lines converge down |
#' | **eye_level** | Neutral, straight-on | Horizon at center |
#' | **dutch_angle** | Tilted camera (diagonal horizon) | Dominant lines are angled 15-75° |
#' | **birds_eye** | Directly overhead | Very high horizon or no horizon visible |
#' | **worms_eye** | Directly from below | Very low/no horizon, extreme upward |
#'
#' @param tl_images A tl_images tibble
#' @param downsample Maximum side length for analysis. Default 300.
#'
#' @return The input tibble with added columns:
#'   - `camera_angle`: Angle type (high_angle, low_angle, eye_level, dutch_angle, birds_eye, worms_eye)
#'   - `horizon_position`: Estimated vertical position of horizon (0=bottom, 1=top, NA if unclear)
#'   - `tilt_angle`: Detected camera tilt in degrees (0 = level, positive = tilted right)
#'
#' @details
#' This is an estimation based on visual heuristics:
#' - High angles tend to have the "ground plane" visible (horizon high)
#' - Low angles tend to show more sky (horizon low)
#' - Dutch angles have tilted horizontal lines
#'
#' For more accurate detection, consider using the LLM functions to classify angles.
#'
#' @export
film_classify_angle <- function(tl_images, downsample = 300) {
  # Validate input
  if (!inherits(tl_images, "data.frame")) {
    cli::cli_abort("{.arg tl_images} must be a data frame.")
  }
  if (!"local_path" %in% names(tl_images)) {
    cli::cli_abort("{.arg tl_images} must have a {.field local_path} column.")
  }
  
  n <- nrow(tl_images)
  if (n == 0) {
    tl_images$camera_angle <- character(0)
    tl_images$horizon_position <- numeric(0)
    tl_images$tilt_angle <- numeric(0)
    return(tl_images)
  }
  
  # Initialize result vectors
  camera_angles <- character(n)
  horizon_positions <- numeric(n)
  tilt_angles <- numeric(n)
  
  cli::cli_progress_bar("Classifying camera angles", total = n)
  
  for (i in seq_len(n)) {
    img_path <- tl_images$local_path[i]
    
    if (!file.exists(img_path)) {
      camera_angles[i] <- NA_character_
      horizon_positions[i] <- NA_real_
      tilt_angles[i] <- NA_real_
      cli::cli_progress_update()
      next
    }
    
    tryCatch({
      img <- magick::image_read(img_path)
      info <- magick::image_info(img)
      
      # Resize for efficiency
      max_dim <- max(info$width, info$height)
      if (max_dim > downsample) {
        scale <- downsample / max_dim
        new_width <- round(info$width * scale)
        new_height <- round(info$height * scale)
        img <- magick::image_resize(img, paste0(new_width, "x", new_height))
        info <- magick::image_info(img)
      }
      
      # Convert to grayscale for edge detection
      gray <- magick::image_convert(img, colorspace = "gray")
      data <- as.integer(magick::image_data(gray))
      
      if (length(dim(data)) == 3) {
        mat <- data[, , 1] / 255.0
      } else {
        mat <- data / 255.0
      }
      
      nr <- nrow(mat)
      nc <- ncol(mat)
      
      # Compute gradient
      gx <- mat
      gy <- mat
      if (nc > 1) {
        gx[, -1] <- mat[, -1] - mat[, -nc]
        gx[, 1] <- 0
      }
      if (nr > 1) {
        gy[-1, ] <- mat[-1, ] - mat[-nr, ]
        gy[1, ] <- 0
      }
      
      grad_mag <- sqrt(gx^2 + gy^2)
      
      # Find strong edges
      threshold <- mean(grad_mag) + 1.5 * stats::sd(grad_mag)
      edge_pixels <- which(grad_mag > threshold, arr.ind = TRUE)
      
      if (nrow(edge_pixels) < 20) {
        # Not enough edges to determine angle
        camera_angles[i] <- "unknown"
        horizon_positions[i] <- NA_real_
        tilt_angles[i] <- NA_real_
        cli::cli_progress_update()
        next
      }
      
      # Compute gradient direction at edge pixels
      edge_gx <- gx[edge_pixels]
      edge_gy <- gy[edge_pixels]
      
      # Angle of each edge (in degrees)
      angles <- atan2(edge_gy, edge_gx) * 180 / pi
      
      # Estimate tilt from dominant line angles
      # Look for lines that should be horizontal (gradient perpendicular to edge)
      # Horizontal edges have gradient pointing up/down (near 90 or -90 degrees)
      horiz_angles <- angles[abs(angles) > 45 & abs(angles) < 135]
      
      if (length(horiz_angles) > 10) {
        # For horizontal lines, gradient angle - 90 gives line direction
        line_angles <- horiz_angles - 90
        line_angles[line_angles < -90] <- line_angles[line_angles < -90] + 180
        line_angles[line_angles > 90] <- line_angles[line_angles > 90] - 180
        
        # Median tells us about camera tilt (0 = level)
        tilt_angles[i] <- round(stats::median(line_angles, na.rm = TRUE), 1)
      } else {
        tilt_angles[i] <- 0
      }
      
      # Estimate horizon position
      # Look at brightness distribution - sky tends to be bright, ground darker
      # Compute average brightness per row
      row_brightness <- rowMeans(mat)
      
      # Find where brightness changes significantly (potential horizon)
      # Use derivative of brightness profile
      bright_diff <- diff(row_brightness)
      
      # Strongest transition
      if (length(bright_diff) > 5) {
        max_change <- which.max(abs(bright_diff))
        horizon_pos <- max_change / nr  # 0 = top, 1 = bottom
        horizon_positions[i] <- round(1 - horizon_pos, 2)  # Convert: 0 = bottom, 1 = top
      } else {
        horizon_positions[i] <- 0.5
      }
      
      # Classify camera angle
      tilt <- abs(tilt_angles[i])
      horizon <- horizon_positions[i]
      
      if (tilt > 15 && tilt < 75) {
        camera_angles[i] <- "dutch_angle"
      } else if (horizon > 0.75 || is.na(horizon)) {
        camera_angles[i] <- "birds_eye"
      } else if (horizon < 0.25) {
        camera_angles[i] <- "worms_eye"
      } else if (horizon > 0.6) {
        camera_angles[i] <- "high_angle"
      } else if (horizon < 0.4) {
        camera_angles[i] <- "low_angle"
      } else {
        camera_angles[i] <- "eye_level"
      }
      
    }, error = function(e) {
      camera_angles[i] <<- NA_character_
      horizon_positions[i] <<- NA_real_
      tilt_angles[i] <<- NA_real_
    })
    
    cli::cli_progress_update()
  }
  
  cli::cli_progress_done()
  
  # Add columns
  tl_images$camera_angle <- camera_angles
  tl_images$horizon_position <- horizon_positions
  tl_images$tilt_angle <- tilt_angles
  
  tl_images
}
