#' tinylens: Tidy Image Analysis for Digital Humanities
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
#' @importFrom rlang .data
#' @importFrom dplyr mutate select filter arrange bind_cols count n
#' @importFrom purrr map map_dbl map_chr map_int map_lgl walk
#' @importFrom cli cli_alert_info cli_alert_success cli_alert_warning cli_abort cli_progress_bar cli_progress_update cli_progress_done
#' @importFrom fs path_file path_ext path_ext_remove dir_ls file_exists
#' @importFrom tools file_ext file_path_sans_ext
#' @importFrom stats kmeans var sd median quantile fft
#' @importFrom utils adist head
#' @importFrom graphics hist
"_PACKAGE"
