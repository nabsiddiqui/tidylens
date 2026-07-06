#' Frame Vector Representations
#'
#' Functions for computing frame vector representations.
#'
#' @name vector_representations
#' @keywords internal
NULL

#' Extract color histogram vector representation
#'
#' A lightweight no-CNN vector representation using color histograms.
#' Color histograms capture the distribution of colors in a frame and can
#' be used for simple similarity comparisons or as features for clustering.
#'
#' @param tl_frames A tl_frames tibble.
#' @param bins Number of bins per channel. Default 16.
#' @param downsample Maximum side length for analysis. Default 100.
#'
#' @return The input tibble with added column:
#'   - `color_hist`: List column with color histogram vectors (length = bins * 3).
#'
#' @family vector_representations
#' @export
frame_extract_color_histogram <- function(tl_frames, bins = 16, downsample = 100) {
  validate_tl_frames(tl_frames)
  
  results <- map_images(tl_frames, function(img) {
    data <- as.integer(magick::image_data(img, channels = "rgb"))
    # data is HxWxC after as.integer
    r <- data[, , 1]
    g <- data[, , 2]
    b <- data[, , 3]
    
    # Quantize to bins
    r_bin <- floor(r / (256 / bins))
    g_bin <- floor(g / (256 / bins))
    b_bin <- floor(b / (256 / bins))
    
    # Create histograms
    r_hist <- tabulate(r_bin + 1, nbins = bins)
    g_hist <- tabulate(g_bin + 1, nbins = bins)
    b_hist <- tabulate(b_bin + 1, nbins = bins)
    
    # Normalize
    total <- length(r)
    hist_vec <- c(r_hist, g_hist, b_hist) / total
    
    list(color_hist = hist_vec)
  }, downsample = downsample, msg = "Computing color histograms")
  
  tl_frames$color_hist <- purrr::map(results, function(x) {
    if (is.null(x)) rep(NA_real_, bins * 3) else x$color_hist
  })
  
  tl_frames
}
