#' tidylens: Classical Film-Frame Analysis in R
#'
#' A tidy, pipeable toolkit for classical film-frame analysis. Tidylens turns
#' video files into `tl_frames` tibbles, extracts inspectable visual features
#' and vector representations, and detects shots and classifies shot scale.
#' The default path uses no CNNs, cloud APIs, opaque model services, or
#' Python workflows.
#'
#' @keywords internal
#'
#' @import magick
#' @import tibble
#' @importFrom rlang "%||%"
#' @importFrom dplyr bind_cols
#' @importFrom purrr map discard
#' @importFrom cli cli_alert_info cli_alert_success cli_abort cli_progress_bar cli_progress_update cli_progress_done
#' @importFrom tools file_path_sans_ext
#' @importFrom stats kmeans var sd median fft predict setNames
"_PACKAGE"