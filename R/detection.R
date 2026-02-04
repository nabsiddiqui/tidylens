#' Detection Functions
#'
#' Functions for detecting faces and objects in images.
#'
#' @name detection
#' @keywords internal
NULL

#' Detect faces in images
#'
#' Detect faces using the image.libfacedetection package.
#'
#' @param tl_images A tl_images tibble.
#' @param min_size Minimum face size in pixels. Default 20.
#'
#' @return The input tibble with added columns:
#'   - `n_faces`: Number of faces detected.
#'
#'   - `faces`: List column with face bounding boxes (x, y, w, h, confidence).
#'
#'   - `face_area_prop`: Total face area as proportion of image.
#'
#' @family detection
#' @export
detect_faces <- function(tl_images, min_size = 20) {
  validate_tl_images(tl_images)
  
  if (!requireNamespace("image.libfacedetection", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg image.libfacedetection} is required. Install with: install.packages('image.libfacedetection', repos = 'https://bnosac.r-universe.dev')")
  }
  
  n <- nrow(tl_images)
  n_faces <- integer(n)
  faces <- vector("list", n)
  face_area_prop <- numeric(n)
  
  cli::cli_progress_bar("Detecting faces", total = n)
  
  for (i in seq_len(n)) {
    path <- tl_images$local_path[i]
    img_width <- tl_images$width[i]
    img_height <- tl_images$height[i]
    
    tryCatch({
      img <- magick::image_read(path)
      
      # Convert to raw
      raw_data <- magick::image_data(img, channels = "rgb")
      
      # Detect faces
      result <- image.libfacedetection::image_detect_faces(raw_data)
      
      if (nrow(result$detections) > 0) {
        # Filter by minimum size
        dets <- result$detections
        dets <- dets[dets$width >= min_size & dets$height >= min_size, ]
        
        n_faces[i] <- nrow(dets)
        faces[[i]] <- dets
        
        # Calculate face area proportion
        face_areas <- dets$width * dets$height
        total_face_area <- sum(face_areas)
        img_area <- img_width * img_height
        face_area_prop[i] <- total_face_area / img_area
      } else {
        n_faces[i] <- 0
        faces[[i]] <- data.frame()
        face_area_prop[i] <- 0
      }
    }, error = function(e) {
      cli::cli_warn("Face detection failed for {path}: {e$message}")
      n_faces[i] <<- NA_integer_
      faces[[i]] <<- data.frame()
      face_area_prop[i] <<- NA_real_
    })
    
    cli::cli_progress_update()
  }
  
  cli::cli_progress_done()
  
  tl_images$n_faces <- n_faces
  tl_images$faces <- faces
  tl_images$face_area_prop <- face_area_prop
  
  tl_images
}

#' Simple person detection heuristic
#'
#' A simple heuristic-based approach to estimate if people are present
#' based on skin tone detection.
#'
#' @param tl_images A tl_images tibble.
#' @param downsample Maximum side length for analysis. Default 200.
#'
#' @return The input tibble with added column:
#'   - `skin_tone_prop`: Proportion of pixels matching skin tone ranges.
#'
#' @family detection
#' @export
detect_skin_tones <- function(tl_images, downsample = 200) {
  validate_tl_images(tl_images)
  
  results <- map_images(tl_images, function(img) {
    data <- as.integer(magick::image_data(img, channels = "rgb"))
    # data is HxWxC after as.integer
    r <- data[, , 1]
    g <- data[, , 2]
    b <- data[, , 3]
    
    # Simple skin tone detection in RGB space
    # Based on: Skin detection using color pixel classification
    # Skin pixels typically have: R > 95, G > 40, B > 20
    # R > G, R > B, |R - G| > 15
    skin_mask <- (r > 95) & (g > 40) & (b > 20) &
                 (r > g) & (r > b) &
                 (abs(as.integer(r) - as.integer(g)) > 15)
    
    skin_prop <- sum(skin_mask) / length(skin_mask)
    
    list(skin_tone_prop = skin_prop)
  }, downsample = downsample, msg = "Detecting skin tones")
  
  tl_images$skin_tone_prop <- purrr::map_dbl(results, ~ .x$skin_tone_prop %||% NA_real_)
  
  tl_images
}

# Null-coalescing operator
if (!exists("%||%")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}
