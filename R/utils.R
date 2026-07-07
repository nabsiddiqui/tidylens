#' Internal utility functions for tidylens
#'
#' @keywords internal
#' @name utils
#' @noRd
NULL

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

#' Gradient components of a grayscale matrix
#'
#' Finite-difference Sobel-free gradient (forward difference, zero border).
#' Returns both components so callers that need edge direction (e.g. texture
#' features) don't have to recompute them. `grad_mag()` below derives
#' magnitude from the same components.
#'
#' @param mat Numeric/integer matrix (grayscale).
#' @return List with `gx` and `gy`, each same dims as `mat`.
#'
#' @keywords internal
#' @noRd
grad_xy <- function(mat) {
  nr <- nrow(mat); nc <- ncol(mat)
  gx <- mat
  if (nc > 1) {
    gx[, -1] <- mat[, -1] - mat[, -nc]
    gx[, 1] <- 0
  }
  gy <- mat
  if (nr > 1) {
    gy[-1, ] <- mat[-1, ] - mat[-nr, ]
    gy[1, ] <- 0
  }
  list(gx = gx, gy = gy)
}

#' Gradient magnitude of a grayscale matrix
#'
#' Thin wrapper over `grad_xy()` returning just the magnitude.
#'
#' @param mat Numeric/integer matrix (grayscale).
#' @return Numeric matrix of gradient magnitudes (same dims as `mat`).
#'
#' @keywords internal
#' @noRd
grad_mag <- function(mat) {
  g <- grad_xy(mat)
  gm <- sqrt(as.numeric(g$gx)^2 + as.numeric(g$gy)^2)
  dim(gm) <- c(nrow(mat), ncol(mat))
  gm
}

#' Apply a function over images with progress
#'
#' @param tl_frames A tl_frames tibble.
#' @param fn Function to apply to each image path.
#' @param downsample Optional downsampling.
#' @param msg Progress bar message.
#'
#' @return List of results.
#'
#' @keywords internal
#' @noRd
map_images <- function(tl_frames, fn, downsample = NULL, msg = "Processing images") {
  validate_tl_frames(tl_frames)

  n <- nrow(tl_frames)
  results <- vector("list", n)

  cli::cli_progress_bar(msg, total = n)

  for (i in seq_len(n)) {
    path <- tl_frames$local_path[i]

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

#' Bind per-image results onto a tl_frames tibble as columns
#'
#' Converts a list of named lists (one per image, possibly NULL on failure)
#' into typed columns appended to `tl_frames`. Column types are inferred
#' from the first non-NULL result: doubles stay doubles, integers stay
#' integers, characters stay characters. NULL/missing entries become the
#' appropriate NA for the column type.
#'
#' @param tl_frames A tl_frames tibble.
#' @param results List of named lists from `map_images()`.
#' @return `tl_frames` with result fields added as columns.
#'
#' @keywords internal
#' @noRd
bind_results <- function(tl_frames, results) {
  non_null <- purrr::discard(results, is.null)
  if (length(non_null) == 0) return(tl_frames)
  first <- non_null[[1]]

  for (field in names(first)) {
    vals <- lapply(results, function(x) {
      if (is.null(x)) return(NA) else x[[field]]
    })
    tl_frames[[field]] <- coerce_column(vals)
  }

  tl_frames
}

coerce_column <- function(vals) {
  non_na <- purrr::discard(vals, function(v) length(v) == 0 || (length(v) == 1 && is.na(v)))
  template <- non_na[[1]]
  if (is.null(template)) return(NA_real_)          # all failed -> numeric NA
  if (is.integer(template)) return(vapply(vals, function(v) if (is.null(v) || is.na(v)) NA_integer_ else as.integer(v), integer(1)))
  if (is.character(template)) return(vapply(vals, function(v) if (is.null(v) || is.na(v)) NA_character_ else as.character(v), character(1)))
  vapply(vals, function(v) if (is.null(v) || is.na(v)) NA_real_ else as.numeric(v), numeric(1))
}
