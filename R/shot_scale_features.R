#' Shot Scale Feature Extractors (Internal)
#'
#' Engineered features for classical shot-scale classification, following
#' Canini, Benini & Leonardi (2011) and Hou & Zhang (2007). All functions
#' operate on a single magick image and return a numeric vector. No CNN,
#' no torch, no deep learning. Pure signal processing and statistics.
#'
#' @name shot_scale_features
#' @keywords internal
#' @noRd
NULL

#' Spectral residual saliency map
#'
#' Computes a saliency map via the spectral residual method of Hou & Zhang
#' (CVPR 2007): FFT -> log spectrum -> subtract locally-averaged log
#' spectrum -> IFFT -> squared magnitude. The resulting saliency map
#' highlights figure-ground structure without any learned parameters.
#'
#' @param gray_mat A numeric matrix of grayscale values in 0..1, H x W.
#' @return A list with: `map` (H x W saliency matrix), `coverage` (fraction
#'   of pixels above a threshold), `centroid_x` and `centroid_y` (normalised
#'   to 0..1), `peak` (max saliency value).
#'
#' @keywords internal
#' @noRd
spectral_residual_saliency <- function(gray_mat) {
  # Downsample to ~128x128 max for speed. Saliency summary features
  # (coverage, centroid) are scale-invariant, so 128px is fine.
  nr <- nrow(gray_mat); nc <- ncol(gray_mat)
  if (nr < 8 || nc < 8) {
    return(list(map = matrix(0, nr, nc), coverage = 0,
                centroid_x = 0.5, centroid_y = 0.5, peak = 0))
  }
  max_side <- 128L
  if (max(nr, nc) > max_side) {
    ratio <- max_side / max(nr, nc)
    new_nr <- max(8L, round(nr * ratio))
    new_nc <- max(8L, round(nc * ratio))
    idx_r <- round(seq(1, nr, length.out = new_nr))
    idx_c <- round(seq(1, nc, length.out = new_nc))
    gray_mat <- gray_mat[idx_r, idx_c, drop = FALSE]
    nr <- nrow(gray_mat); nc <- ncol(gray_mat)
  }

  F_mat <- stats::fft(as.complex(gray_mat))
  log_amp <- log(Mod(F_mat) + 1e-8)
  phase <- Arg(F_mat)

  # Box-filter averaging via direct convolution with reflection padding
  k <- min(3L, floor(min(nr, nc) / 8))
  if (k < 1L) k <- 1L
  sz <- 2 * k + 1L
  pad <- k
  # Reflect-pad to avoid wraparound artifacts
  rp <- c((nr - pad + 1L):1L, seq_len(nr), nr:(nr - pad + 1L))
  rp[rp < 1] <- 1; rp[rp > nr] <- nr
  cp <- c((nc - pad + 1L):1L, seq_len(nc), nc:(nc - pad + 1L))
  cp[cp < 1] <- 1; cp[cp > nc] <- nc
  padded <- gray_mat[rp, cp, drop = FALSE]
  avg <- matrix(0, nr, nc)
  for (i in seq_len(nr)) {
    for (j in seq_len(nc)) {
      avg[i, j] <- mean(padded[i:(i + 2 * pad), j:(j + 2 * pad)])
    }
  }

  spectral_residual <- log_amp - avg
  S <- Re(stats::fft(spectral_residual * exp(1i * phase), inverse = TRUE))
  S <- (abs(S) / (nr * nc))^2
  S <- (S - min(S)) / (diff(range(S)) + 1e-8)

  threshold <- mean(S) + stats::sd(S)
  salient <- S > threshold
  coverage <- mean(salient)
  if (coverage > 1e-8) {
    total_salience <- sum(S)
    centroid_y <- sum(row(S) * S) / total_salience / nr
    centroid_x <- sum(col(S) * S) / total_salience / nc
  } else {
    centroid_y <- 0.5; centroid_x <- 0.5
  }
  peak <- max(S)
  list(map = S, coverage = coverage,
       centroid_x = centroid_x, centroid_y = centroid_y, peak = peak)
}

#' Face coverage ratio from cascade face detection
#'
#' Wraps image.libfacedetection (Haar/LBP cascade, not a CNN) to compute
#' the largest detected face bounding-box area as a fraction of frame area.
#'
#' @param img A magick image object.
#' @param info Image info list from `magick::image_info()`.
#' @return Numeric scalar in 0..1, or 0 if no face is detected or the
#'   package is unavailable.
#'
#' @keywords internal
#' @noRd
face_coverage_ratio <- function(img, info) {
  if (!requireNamespace("image.libfacedetection", quietly = TRUE)) {
    return(c(face_coverage = 0, n_faces = 0, face_y_center = 0.5))
  }
  tryCatch({
    # Downsample to ~300px for face detection speed
    max_side <- 300L
    if (max(info$height, info$width) > max_side) {
      img <- magick::image_resize(img, paste0(max_side, "x"))
      info <- magick::image_info(img)
    }
    # image.libfacedetection can take a magick image directly
    faces <- image.libfacedetection::image_detect_faces(img)
    if (nrow(faces$detections) > 0) {
      frame_area <- info$width * info$height
      areas <- faces$detections$width * faces$detections$height
      max_idx <- which.max(areas)
      face_cov <- areas[max_idx] / frame_area
      # Vertical center of the largest face (0=top, 1=bottom)
      face_y <- (faces$detections$y[max_idx] + faces$detections$height[max_idx] / 2) / info$height
      c(face_coverage = face_cov,
        n_faces = nrow(faces$detections),
        face_y_center = face_y)
    } else {
      c(face_coverage = 0, n_faces = 0, face_y_center = 0.5)
    }
  }, error = function(e) c(face_coverage = 0, n_faces = 0, face_y_center = 0.5))
}

#' Skin-tone pixel proportion
#'
#' Classic RGB threshold rules (Kovac et al. / Peer et al.) for skin
#' detection. Pure color, no model.
#'
#' @param img A magick image object.
#' @return Numeric scalar in 0..1 (fraction of skin-tone pixels).
#'
#' @keywords internal
#' @noRd
skin_tone_ratio <- function(img) {
  tryCatch({
    data <- as.integer(magick::image_data(img, channels = "rgb"))
    r <- data[, , 1]; g <- data[, , 2]; b <- data[, , 3]
    skin_mask <- (r > 95) & (g > 40) & (b > 20) &
                 (r > g) & (r > b) &
                 (abs(as.integer(r) - as.integer(g)) > 15)
    sum(skin_mask) / length(skin_mask)
  }, error = function(e) NA_real_)
}

#' Geometric and texture features for shot scale
#'
#' Combines saliency-derived geometric cues with spatial texture features
#' from the grayscale image. Returns a named numeric vector.
#'
#' @param img A magick image object.
#' @return A named numeric vector of features.
#'
#' @keywords internal
#' @noRd
geometric_features <- function(img) {
  info <- magick::image_info(img)
  w <- info$width; h <- info$height

  # Downsample to max ~128px for speed. Texture/saliency summary
  # features don't need full resolution.
  max_side <- 128L
  if (max(h, w) > max_side) {
    img <- magick::image_resize(img, paste0(max_side, "x"))
    info <- magick::image_info(img)
  }

  gray_img <- magick::image_convert(img, colorspace = "gray")
  gray_data <- as.integer(magick::image_data(gray_img))
  mat <- if (length(dim(gray_data)) == 3) gray_data[, , 1] / 255 else gray_data / 255
  nr <- nrow(mat); nc <- ncol(mat)
  if (nr < 10 || nc < 10) {
    return(c(salience_coverage = 0, salience_centroid_x = 0.5,
             salience_centroid_y = 0.5, salience_peak = 0,
             upper_mass_ratio = 0.5, center_periphery_ratio = 1,
             laplacian_variance = 0, edge_density = 0,
             spatial_detail = 0, spatial_cv = 0, color_entropy = 0))
  }

  sal <- spectral_residual_saliency(mat)
  sal_map <- sal$map
  sal_nr <- nrow(sal_map)
  upper_half <- sal$map[1:(sal_nr %/% 2), ]
  upper_mass_ratio <- sum(upper_half) / (sum(sal$map) + 1e-8)

  gx <- abs(mat[, -1, drop = FALSE] - mat[, -nc, drop = FALSE])
  gy <- abs(mat[-1, , drop = FALSE] - mat[-nr, , drop = FALSE])
  min_r <- min(nrow(gx), nrow(gy)); min_c <- min(ncol(gx), ncol(gy))
  edge_mag <- gx[seq_len(min_r), seq_len(min_c)] + gy[seq_len(min_r), seq_len(min_c)]
  cr1 <- max(1L, round(min_r * 0.25)); cr2 <- min(min_r, round(min_r * 0.75))
  cc1 <- max(1L, round(min_c * 0.25)); cc2 <- min(min_c, round(min_c * 0.75))
  center_energy <- mean(edge_mag[cr1:cr2, cc1:cc2])
  n_periph <- length(edge_mag) - length(edge_mag[cr1:cr2, cc1:cc2])
  periph_energy <- if (n_periph > 0)
    (sum(edge_mag) - sum(edge_mag[cr1:cr2, cc1:cc2])) / n_periph else center_energy
  center_periphery_ratio <- if (periph_energy > 1e-8) center_energy / periph_energy else 1

  lap <- mat[2:(nr - 1), 2:(nc - 1)] * (-4) +
         mat[1:(nr - 2), 2:(nc - 1)] + mat[3:nr, 2:(nc - 1)] +
         mat[2:(nr - 1), 1:(nc - 2)] + mat[2:(nr - 1), 3:nc]
  laplacian_variance <- stats::var(as.vector(lap))

  edge_threshold_val <- mean(edge_mag) + stats::sd(edge_mag)
  edge_density <- sum(edge_mag > edge_threshold_val) / length(edge_mag)

  block_size <- max(4L, min(nr, nc) %/% 8L)
  n_br <- nr %/% block_size; n_bc <- nc %/% block_size
  if (n_br > 0 && n_bc > 0) {
    block_vars <- numeric(n_br * n_bc); k <- 1L
    for (bi in seq_len(n_br)) for (bj in seq_len(n_bc)) {
      ri <- ((bi - 1L) * block_size + 1L):(bi * block_size)
      ci <- ((bj - 1L) * block_size + 1L):(bj * block_size)
      block_vars[k] <- stats::var(as.vector(mat[ri, ci])); k <- k + 1L
    }
    spatial_detail <- mean(block_vars, na.rm = TRUE)
    bv_mean <- mean(block_vars, na.rm = TRUE)
    spatial_cv <- if (bv_mean > 1e-8) stats::sd(block_vars, na.rm = TRUE) / bv_mean else 1
  } else {
    spatial_detail <- stats::var(as.vector(mat)); spatial_cv <- 1
  }

  c(salience_coverage = sal$coverage,
    salience_centroid_x = sal$centroid_x,
    salience_centroid_y = sal$centroid_y,
    salience_peak = sal$peak,
    upper_mass_ratio = upper_mass_ratio,
    center_periphery_ratio = center_periphery_ratio,
    laplacian_variance = laplacian_variance,
    edge_density = edge_density,
    spatial_detail = spatial_detail,
    spatial_cv = spatial_cv)
}

#' Color entropy of an image
#'
#' Shannon entropy of a 16-bin-per-channel concatenated RGB histogram.
#'
#' @param img A magick image object.
#' @return Numeric scalar (entropy in bits).
#'
#' @keywords internal
#' @noRd
color_entropy <- function(img) {
  tryCatch({
    rgb_data <- as.integer(magick::image_data(img, channels = "rgb"))
    r_hist <- tabulate(as.integer(rgb_data[, , 1] / 255 * 15) + 1L, nbins = 16L)
    g_hist <- tabulate(as.integer(rgb_data[, , 2] / 255 * 15) + 1L, nbins = 16L)
    b_hist <- tabulate(as.integer(rgb_data[, , 3] / 255 * 15) + 1L, nbins = 16L)
    combined <- c(r_hist, g_hist, b_hist)
    p <- combined / sum(combined); p <- p[p > 0]
    -sum(p * log2(p))
  }, error = function(e) NA_real_)
}

#' Extract the full shot-scale feature vector for one image
#'
#' Combines all engineered features into a single named numeric vector
#' suitable for feeding to a trained Random Forest classifier.
#'
#' @param img A magick image object.
#' @param info Image info list from `magick::image_info()`.
#' @return A named numeric vector of length 13.
#'
#' @keywords internal
#' @noRd
extract_shot_scale_features <- function(img, info = NULL) {
  if (is.null(info)) info <- magick::image_info(img)
  geo <- geometric_features(img)
  face_feats <- face_coverage_ratio(img, info)
  skin <- skin_tone_ratio(img)
  cent <- color_entropy(img)

  # Derived interaction features that help when face detection fails:
  # close-ups without detectable faces still have skin-tone concentrated
  # centrally and higher high-frequency detail.
  skin_center_interaction <- unname(skin) * geo["center_periphery_ratio"]
  laplacian_per_edge <- geo["laplacian_variance"] / (geo["edge_density"] + 1e-8)

  c(geo,
    face_coverage = face_feats["face_coverage"],
    n_faces = face_feats["n_faces"],
    face_y_center = face_feats["face_y_center"],
    skin_tone = unname(skin),
    color_entropy = cent,
    skin_center = skin_center_interaction,
    laplacian_per_edge = laplacian_per_edge)
}