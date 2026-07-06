#' Camera Angle Classification
#'
#' Functions for classifying camera angle from frame images.
#'
#' @name camera_angle
#' @keywords internal
NULL

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
#' @param tl_frames A tl_frames tibble
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
#' @export
frame_classify_angle <- function(tl_frames, downsample = 300) {
  # Validate input
  if (!inherits(tl_frames, "data.frame")) {
    cli::cli_abort("{.arg tl_frames} must be a data frame.")
  }
  if (!"local_path" %in% names(tl_frames)) {
    cli::cli_abort("{.arg tl_frames} must have a {.field local_path} column.")
  }
  
  n <- nrow(tl_frames)
  if (n == 0) {
    tl_frames$camera_angle <- character(0)
    tl_frames$horizon_position <- numeric(0)
    tl_frames$tilt_angle <- numeric(0)
    return(tl_frames)
  }
  
  # Initialize result vectors
  camera_angles <- character(n)
  horizon_positions <- numeric(n)
  tilt_angles <- numeric(n)
  
  cli::cli_progress_bar("Classifying camera angles", total = n)
  
  for (i in seq_len(n)) {
    img_path <- tl_frames$local_path[i]
    
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

      # Compute gradient (need components for edge direction, not just magnitude)
      g <- grad_xy(mat)
      gx <- g$gx
      gy <- g$gy

      grad_mag <- sqrt(as.numeric(gx)^2 + as.numeric(gy)^2)
      dim(grad_mag) <- c(nrow(mat), ncol(mat))
      
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
  tl_frames$camera_angle <- camera_angles
  tl_frames$horizon_position <- horizon_positions
  tl_frames$tilt_angle <- tilt_angles
  
  tl_frames
}
