#' tidylens: Tidy Image Analysis for Digital Humanities
#'
#' A tidy, pipeable toolkit for image-first analysis targeting digital 
#' humanities and film studies. Provides functions for loading image collections,
#' extracting color metrics, composition analysis, face/object detection, 
#' and neural embeddings.
#'
#' @keywords internal
#'
#' @import magick
#' @import tibble
#' @importFrom rlang .data "%||%"
#' @importFrom dplyr mutate count arrange bind_cols
#' @importFrom purrr map discard
#' @importFrom cli cli_alert_info cli_alert_success cli_alert_warning cli_abort cli_progress_bar cli_progress_update cli_progress_done
#' @importFrom tools file_ext file_path_sans_ext
#' @importFrom stats kmeans var sd median quantile fft predict setNames
#' @importFrom utils adist head
"_PACKAGE"
