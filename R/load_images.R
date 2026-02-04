#' Load images into a tl_images tibble
#'
#' Create a tidy tibble containing image metadata from a directory, file paths,
#' or manifest file. When loading from a manifest CSV, any additional columns
#' in the CSV are preserved in the resulting tl_images tibble.
#'
#' @param path Path to a directory containing images, a single image file,
#'   or a manifest file (CSV/TSV with a `source` column).
#' @param pattern File pattern to match when scanning directories.
#'   Default matches common image formats.
#' @param recursive Scan directories recursively? Default `FALSE`.
#' @param preserve_metadata When loading from a manifest CSV, preserve
#'   additional columns (e.g., video_source, custom annotations). Default `TRUE`.
#'
#' @return A tibble of class `tl_images` with columns:
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
#'   - Plus any additional columns from manifest CSV (if preserve_metadata = TRUE).
#'
#' @family io
#' @export
#' @examples
#' \dontrun{
#' # Load from directory
#' images <- load_images("images/")
#'
#' # Load specific files
#' images <- load_images(c("img1.jpg", "img2.png"))
#'
#' # Load from manifest with extra metadata preserved
#' # manifest.csv has: source, video_source, scene_name, etc.
#' images <- load_images("manifest.csv")
#' # Result includes video_source and scene_name columns
#' }
load_images <- function(path,
                        pattern = "\\.(jpg|jpeg|png|gif|bmp|tiff|webp)$",
                        recursive = FALSE,
                        preserve_metadata = TRUE) {
  # Will hold extra columns from manifest
  manifest_data <- NULL

  if (length(path) > 1) {
    files <- path[file.exists(path)]
    if (length(files) == 0) {
      cli::cli_abort("No valid files found in provided paths.")
    }
  } else if (dir.exists(path)) {
    # Directory: scan for images
    files <- list.files(path, pattern = pattern, full.names = TRUE,
                        recursive = recursive, ignore.case = TRUE)
    if (length(files) == 0) {
      cli::cli_abort("No images found in directory: {path}")
    }
  } else if (file.exists(path)) {
    # Single file or manifest
    ext <- tolower(tools::file_ext(path))
    if (ext %in% c("csv", "tsv", "txt")) {
      # Manifest file - preserve extra columns
      manifest <- utils::read.csv(path, stringsAsFactors = FALSE)
      if (!"source" %in% names(manifest)) {
        cli::cli_abort("Manifest must contain a 'source' column.")
      }
      
      # Check which files exist
      exists_mask <- file.exists(manifest$source)
      if (!any(exists_mask)) {
        cli::cli_abort("No valid files found in manifest.")
      }
      
      files <- manifest$source[exists_mask]
      
      # Preserve extra columns (excluding standard tl_images columns we'll recompute)
      standard_cols <- c("source", "id", "local_path", "width", "height", 
                         "format", "aspect_ratio", "file_size_bytes")
      extra_cols <- setdiff(names(manifest), standard_cols)
      if (length(extra_cols) > 0 && preserve_metadata) {
        manifest_data <- manifest[exists_mask, extra_cols, drop = FALSE]
        cli::cli_alert_info("Preserving {length(extra_cols)} metadata columns from manifest")
      }
    } else {
      files <- path
    }
  } else {
    cli::cli_abort("Path does not exist: {path}")
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

  # Append preserved metadata from manifest if present
  if (!is.null(manifest_data) && nrow(manifest_data) == nrow(tbl)) {
    for (col in names(manifest_data)) {
      tbl[[col]] <- manifest_data[[col]]
    }
  }

  # Add class
  class(tbl) <- c("tl_images", class(tbl))

  tbl
}

#' Print method for tl_images
#'
#' @param x A tl_images tibble.
#' @param ... Additional arguments passed to print methods.
#'
#' @return The input `x` invisibly.
#'
#' @family io
#' @export
print.tl_images <- function(x, ...) {
  cli::cli_h1("Tidylens Image Collection")
  cli::cli_text("{.val {nrow(x)}} images")

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

#' Check if object is tl_images
#'
#' @param x Object to check.
#'
#' @return `TRUE` if `x` is a tl_images tibble, `FALSE` otherwise.
#'
#' @family io
#' @export
is_tl_images <- function(x) {
  inherits(x, "tl_images")
}

#' Validate tl_images input
#'
#' @param tl_images A tl_images tibble.
#'
#' @return The validated tibble invisibly.
#'
#' @keywords internal
#' @noRd
validate_tl_images <- function(tl_images) {
  if (!is_tl_images(tl_images)) {
    cli::cli_abort("Input must be a tl_images tibble. Use load_images() first.")
  }

  required_cols <- c("id", "local_path")
  missing <- setdiff(required_cols, names(tl_images))

  if (length(missing) > 0) {
    cli::cli_abort("Missing required columns: {missing}")
  }

  invisible(tl_images)
}
