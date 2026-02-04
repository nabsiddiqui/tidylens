#' Internal utility functions for tinylens
#'
#' @keywords internal
#' @name utils
#' @noRd
NULL

# Global variable declarations for R CMD check
# These are column names used in dplyr pipelines
utils::globalVariables(c(
  "shot_scale",
  "count",
  "proportion",
  "pct"
))

#' Downsample an image for analysis
#'
#' @param img A magick image object.
#' @param max_side Maximum side length in pixels.
#'
#' @return Downsampled magick image.
#'
#' @keywords internal
#' @noRd
downsample_image <- function(img, max_side = 200) {
  info <- magick::image_info(img)
  current_max <- max(info$width, info$height)

  if (current_max <= max_side) {
    return(img)
  }

  # Calculate new dimensions preserving aspect ratio
  scale <- max_side / current_max
  new_width <- round(info$width * scale)
  new_height <- round(info$height * scale)

  magick::image_resize(img, paste0(new_width, "x", new_height))
}

#' Convert magick image to matrix
#'
#' @param img A magick image object.
#' @param channel Which channel(s) to extract.
#'
#' @return Numeric matrix or array.
#'
#' @keywords internal
#' @noRd
image_to_matrix <- function(img, channel = "rgb") {
  arr <- as.integer(magick::image_data(img, channels = "rgb"))
  arr <- arr / 255.0
  arr
}

#' Read and optionally downsample an image
#'
#' @param path Path to image file.
#' @param downsample Maximum side length, or `NULL` for no downsampling.
#'
#' @return Magick image object.
#'
#' @keywords internal
#' @noRd
read_image <- function(path, downsample = NULL) {
  img <- magick::image_read(path)

  if (!is.null(downsample) && downsample > 0) {
    img <- downsample_image(img, downsample)
  }

  img
}

#' Apply a function over images with progress
#'
#' @param tl_images A tl_images tibble.
#' @param fn Function to apply to each image path.
#' @param downsample Optional downsampling.
#' @param msg Progress bar message.
#'
#' @return List of results.
#'
#' @keywords internal
#' @noRd
map_images <- function(tl_images, fn, downsample = NULL, msg = "Processing images") {
  validate_tl_images(tl_images)

  n <- nrow(tl_images)
  results <- vector("list", n)

  cli::cli_progress_bar(msg, total = n)

  for (i in seq_len(n)) {
    path <- tl_images$local_path[i]

    tryCatch({
      img <- read_image(path, downsample = downsample)
      results[[i]] <- fn(img)
    }, error = function(e) {
      cli::cli_warn("Error processing {basename(path)}: {e$message}")
      results[[i]] <<- NULL
    })

    cli::cli_progress_update()
  }

  cli::cli_progress_done()
  results
}
