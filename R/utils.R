#' Internal utility functions for tidylens
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
      img <- magick::image_read(path)
      if (!is.null(downsample) && downsample > 0) {
        img <- downsample_image(img, downsample)
      }
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

#' Bind per-image results onto a tl_images tibble as columns
#'
#' Converts a list of named lists (one per image, possibly NULL on failure)
#' into typed columns appended to `tl_images`. Column types are inferred
#' from the first non-NULL result: doubles stay doubles, integers stay
#' integers, characters stay characters. NULL/missing entries become the
#' appropriate NA for the column type.
#'
#' @param tl_images A tl_images tibble.
#' @param results List of named lists from [map_images()].
#' @return `tl_images` with result fields added as columns.
#'
#' @keywords internal
#' @noRd
bind_results <- function(tl_images, results) {
  non_null <- purrr::discard(results, is.null)
  if (length(non_null) == 0) return(tl_images)
  first <- non_null[[1]]

  for (field in names(first)) {
    vals <- lapply(results, function(x) {
      if (is.null(x)) return(NA) else x[[field]]
    })
    tl_images[[field]] <- coerce_column(vals)
  }

  tl_images
}

coerce_column <- function(vals) {
  non_na <- purrr::discard(vals, function(v) length(v) == 0 || (length(v) == 1 && is.na(v)))
  template <- non_na[[1]]
  if (is.null(template)) return(NA_real_)          # all failed -> numeric NA
  if (is.integer(template)) return(vapply(vals, function(v) if (is.null(v) || is.na(v)) NA_integer_ else as.integer(v), integer(1)))
  if (is.character(template)) return(vapply(vals, function(v) if (is.null(v) || is.na(v)) NA_character_ else as.character(v), character(1)))
  vapply(vals, function(v) if (is.null(v) || is.na(v)) NA_real_ else as.numeric(v), numeric(1))
}
