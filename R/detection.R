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
#' @param tl_frames A tl_frames tibble.
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
frame_detect_faces <- function(tl_frames, min_size = 20) {
  validate_tl_frames(tl_frames)
  
  if (!requireNamespace("image.libfacedetection", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg image.libfacedetection} is required. Install with: install.packages('image.libfacedetection', repos = 'https://bnosac.r-universe.dev')")
  }
  
  n <- nrow(tl_frames)
  n_faces <- integer(n)
  faces <- vector("list", n)
  face_area_prop <- numeric(n)
  
  cli::cli_progress_bar("Detecting faces", total = n)
  
  for (i in seq_len(n)) {
    path <- tl_frames$local_path[i]
    img_width <- tl_frames$width[i]
    img_height <- tl_frames$height[i]
    
    tryCatch({
      img <- magick::image_read(path)

      # Detect faces (image.libfacedetection accepts a magick image directly)
      result <- image.libfacedetection::image_detect_faces(img)
      
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
  
  tl_frames$n_faces <- n_faces
  tl_frames$faces <- faces
  tl_frames$face_area_prop <- face_area_prop
  
  tl_frames
}
