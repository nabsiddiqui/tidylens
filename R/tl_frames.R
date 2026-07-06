#' Load frame files into a tl_frames tibble
#'
#' Internal helper used by video frame extractors. The public API starts from
#' video files with `frame_extract_*()` functions.
#'
#' @param paths Character vector of image file paths. Length-0 is allowed and
#'   returns an empty `tl_frames` tibble. Nonexistent paths are dropped.
#'
#' @return A tibble of class `tl_frames` with columns:
#'   - `id`: Filename without extension.
#'
#'   - `source`: Original path.
#'
#'   - `local_path`: Full local path.
#'
#'   - `width`, `height`: Image dimensions.
#'
#'   - `format`: File format.
#'
#'   - `aspect_ratio`, `file_size_bytes`.
#'
#' @keywords internal
#' @noRd
load_frame_files <- function(paths) {
  if (length(paths) == 0) {
    tbl <- tibble::tibble(
      id = character(),
      source = character(),
      local_path = character(),
      width = integer(),
      height = integer(),
      format = character(),
      aspect_ratio = numeric(),
      file_size_bytes = integer()
    )
    class(tbl) <- c("tl_frames", class(tbl))
    return(tbl)
  }

  files <- paths[file.exists(paths)]
  if (length(files) == 0) {
    cli::cli_abort("No valid files found in provided paths.")
  }

  # Build tibble with metadata
  tbl <- tibble::tibble(
    id = tools::file_path_sans_ext(basename(files)),
    source = files,
    local_path = normalizePath(files, mustWork = FALSE)
  )

  # Get image metadata using magick + file info
  n <- nrow(tbl)
  widths <- integer(n)
  heights <- integer(n)
  formats <- character(n)
  aspect_ratios <- numeric(n)
  file_sizes <- integer(n)
  
  cli::cli_progress_bar("Reading image metadata", total = n)
  
  for (i in seq_len(n)) {
    p <- tbl$local_path[i]
    tryCatch({
      # Image dimensions
      img <- magick::image_read(p)
      info <- magick::image_info(img)
      widths[i] <- as.integer(info$width)
      heights[i] <- as.integer(info$height)
      formats[i] <- tolower(info$format)
      aspect_ratios[i] <- info$width / info$height
      
      # File size
      file_sizes[i] <- as.integer(file.info(p)$size)
    }, error = function(e) {
      widths[i] <<- NA_integer_
      heights[i] <<- NA_integer_
      formats[i] <<- NA_character_
      aspect_ratios[i] <<- NA_real_
      file_sizes[i] <<- NA_integer_
    })
    cli::cli_progress_update()
  }
  
  cli::cli_progress_done()

  tbl$width <- widths
  tbl$height <- heights
  tbl$format <- formats
  tbl$aspect_ratio <- aspect_ratios
  tbl$file_size_bytes <- file_sizes

  class(tbl) <- c("tl_frames", class(tbl))

  tbl
}

#' Print method for tl_frames
#'
#' @param x A tl_frames tibble.
#' @param ... Additional arguments passed to print methods.
#'
#' @return The input `x` invisibly.
#'
#' @family io
#' @export
print.tl_frames <- function(x, ...) {
  cli::cli_h1("Tidylens Frame Collection")
  cli::cli_text("{.val {nrow(x)}} frames")

  # Show formats (nolint: used in cli_text below)
  formats <- table(x$format)
  format_str <- paste(names(formats), formats, sep = ": ", collapse = ", ")
  cli::cli_text("Formats: {format_str}")

  # Show dimensions range
  if (any(!is.na(x$width))) {
    cli::cli_text(
      "Dimensions: {min(x$width, na.rm = TRUE)}-{max(x$width, na.rm = TRUE)} x {min(x$height, na.rm = TRUE)}-{max(x$height, na.rm = TRUE)}"
    )
  }

  cli::cli_text("")
  NextMethod()
}

#' Check if object is tl_frames
#'
#' @param x Object to check.
#'
#' @return `TRUE` if `x` is a tl_frames tibble, `FALSE` otherwise.
#'
#' @family io
#' @export
is_tl_frames <- function(x) {
  inherits(x, "tl_frames")
}

#' Validate tl_frames input
#'
#' @param tl_frames A tl_frames tibble.
#'
#' @return The validated tibble invisibly.
#'
#' @keywords internal
#' @noRd
validate_tl_frames <- function(tl_frames) {
  if (!is_tl_frames(tl_frames)) {
    cli::cli_abort("Input must be a tl_frames tibble. Use a frame_extract_*() function to build one from a video first.")
  }

  required_cols <- c("id", "local_path")
  missing <- setdiff(required_cols, names(tl_frames))

  if (length(missing) > 0) {
    cli::cli_abort("Missing required columns: {missing}")
  }

  invisible(tl_frames)
}
