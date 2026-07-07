#' Texture and Tone Features
#'
#' Classical, no-CNN texture and tone descriptors for film frames.
#'
#' @name texture
#' @keywords internal
NULL

#' Extract GLCM (Haralick) texture features
#'
#' Compute Gray-Level Co-occurrence Matrix (GLCM) descriptors following
#' Haralick, Shanmugam & Dinstein (1973). A co-occurrence matrix counts how
#' often pairs of neighbouring gray levels occur along a given offset, then
#' summary statistics are derived from it. The five most-used Haralick
#' features are returned.
#'
#' ## What it tells you (ELI5)
#' GLCM describes the *texture* of a frame: coarse vs. fine, smooth vs. busy,
#' directional vs. uniform. A close-up of fabric will score high contrast
#' and entropy; a flat sky will score near zero on everything.
#'
#' @param tl_frames A tl_frames tibble.
#' @param levels Number of gray levels to quantise to (co-occurrence matrix is
#'   `levels x levels`). Default 32.
#' @param dx Horizontal offset of the co-occurrence pair. Default 1.
#' @param dy Vertical offset of the co-occurrence pair. Default 0.
#' @param downsample Maximum side length for analysis. Default 200.
#'
#' @return The input tibble with added columns:
#'   - `glcm_contrast`: Local variation. 0 for a constant image; higher = busier.
#'
#'   - `glcm_homogeneity`: Inverse of contrast weighted by closeness to the
#'     diagonal. 1 for a constant image; lower = more variation.
#'
#'   - `glcm_energy` (a.k.a. angular second moment): Uniformity of the
#'     co-occurrence distribution. 1 for a constant image; lower = more spread.
#'
#'   - `glcm_entropy`: Shannon entropy of the normalised GLCM. 0 for a constant
#'     image; higher = more disordered texture.
#'
#'   - `glcm_correlation`: Linear dependence of neighbouring gray levels,
#'     in \[-1, 1]. Near 1 = smoothly varying; near 0 = uncorrelated or
#'     constant (sd = 0 returns 0 by convention).
#'
#' @references
#' Haralick, R. M., Shanmugam, K., & Dinstein, I. (1973). Textural features
#' for image classification. *IEEE Transactions on Systems, Man, and
#' Cybernetics*, SMC-3(6), 610-621.
#'
#' @family texture
#' @export
frame_extract_glcm <- function(tl_frames, levels = 32, dx = 1, dy = 0,
                               downsample = 200) {
  validate_tl_frames(tl_frames)

  results <- map_images(tl_frames, function(img) {
    gray <- magick::image_convert(img, colorspace = "gray")
    data <- as.integer(magick::image_data(gray))
    if (length(dim(data)) == 3) data <- data[, , 1]

    # Quantise to `levels` gray levels (0..levels-1). as.integer() strips
    # dims, so reassign the matrix dims afterwards.
    q <- as.integer(data / 256 * (levels - 0.001))
    dim(q) <- dim(data)
    nr <- nrow(q); nc <- ncol(q)

    # Build the GLCM. The co-occurrence counts pairs (q[i,j], q[i+dy, j+dx])
    # for every (i,j) where both positions are in bounds.
    i_lo <- max(1, 1 - dy)
    i_hi <- min(nr, nr - dy)
    j_lo <- max(1, 1 - dx)
    j_hi <- min(nc, nc - dx)

    glcm <- matrix(0L, nrow = levels, ncol = levels)
    if (i_hi >= i_lo && j_hi >= j_lo) {
      a <- q[i_lo:i_hi, j_lo:j_hi, drop = FALSE]
      b <- q[(i_lo + dy):(i_hi + dy), (j_lo + dx):(j_hi + dx), drop = FALSE]
      idx <- as.integer(a) * levels + as.integer(b) + 1L
      counts <- tabulate(idx, nbins = levels * levels)
      glcm <- matrix(counts, nrow = levels, ncol = levels, byrow = FALSE)
      glcm <- glcm + t(glcm)  # symmetrise
    }

    total <- sum(glcm)
    if (total == 0) {
      return(list(glcm_contrast = 0.0, glcm_homogeneity = 1.0,
                  glcm_energy = 1.0, glcm_entropy = 0.0,
                  glcm_correlation = 0.0))
    }
    p <- glcm / total
    k <- 0:(levels - 1)
    ik <- matrix(rep(k, each = levels), levels, levels)
    jk <- matrix(rep(k, times = levels), levels, levels)
    diff2 <- (ik - jk)^2

    contrast <- sum(p * diff2)
    homogeneity <- sum(p / (1 + diff2))
    energy <- sqrt(sum(p^2))
    nz <- p[p > 0]
    entropy <- -sum(nz * log2(nz))

    # Correlation: cov(i,j) / (sd_i * sd_j). A constant image has sd = 0;
    # convention here is to report 0 (no measurable linear dependence) rather
    # than NA, so the column stays numeric for downstream aggregation.
    mu_i <- as.numeric(p %*% k)            # E[i]
    mu_j <- as.numeric(k %*% p)            # E[j]  (== mu_i for symmetric GLCM)
    sd_i <- sqrt(sum(p * (ik - mu_i)^2))
    sd_j <- sqrt(sum(p * (jk - mu_j)^2))
    if (sd_i > 0 && sd_j > 0) {
      corr <- sum(p * (ik - mu_i) * (jk - mu_j)) / (sd_i * sd_j)
    } else {
      corr <- 0
    }

    list(
      glcm_contrast = as.numeric(contrast),
      glcm_homogeneity = as.numeric(homogeneity),
      glcm_energy = as.numeric(energy),
      glcm_entropy = as.numeric(entropy),
      glcm_correlation = as.numeric(corr)
    )
  }, downsample = downsample, msg = "Extracting GLCM texture features")

  bind_results(tl_frames, results)
}

#' Extract sharpness (variance-of-Laplacian)
#'
#' Estimate focus / sharpness with the variance-of-Laplacian measure, a
#' standard classical focus measure. A soft-focus or blurred frame scores
#' low; a crisp, detail-rich frame scores high. Reuses the package gradient
#' infrastructure (`grad_mag()`).
#'
#' ## What it tells you (ELI5)
#' One number per frame: how crisp it is. Soft-focus close-ups, haze, and
#' motion blur score low; sharp architectural shots score high. Useful for
#' tracking depth-of-field shifts across a film.
#'
#' @param tl_frames A tl_frames tibble.
#' @param downsample Maximum side length for analysis. Default 200.
#'
#' @return The input tibble with added column:
#'   - `sharpness`: Variance of the gradient magnitude. 0 for a constant
#'     image; higher = sharper. Scale depends on resolution and downsample.
#'
#' @references
#' Pech-Pacheco, J. L., Alvarez-Rodriguez, J., & Cristobal, G. (2000).
#' Diatom autofocusing in brightfield microscopy: a comparative study.
#' *IEEE ICIP*, 2000.
#'
#' @family texture
#' @export
frame_extract_sharpness <- function(tl_frames, downsample = 200) {
  validate_tl_frames(tl_frames)

  results <- map_images(tl_frames, function(img) {
    gray <- magick::image_convert(img, colorspace = "gray")
    data <- as.integer(magick::image_data(gray))
    if (length(dim(data)) == 3) data <- data[, , 1]
    mat <- data / 255.0

    gm <- grad_mag(mat)
    list(sharpness = as.numeric(stats::var(as.numeric(gm))))
  }, downsample = downsample, msg = "Extracting sharpness")

  bind_results(tl_frames, results)
}

#' Extract contrast (RMS and Michelson)
#'
#' Two classical scalar contrast measures computed on luminance:
#' - **RMS contrast** is the standard deviation of normalised luminance
#'   (between 0 and 1). Sensitive to overall tonal spread.
#' - **Michelson contrast** is `(max - min) / (max + min)` on the same
#'   normalised scale. Bounded in \[0, 1]; emphasises the extreme range.
#'
#' ## What it tells you (ELI5)
#' How punchy / high-contrast a frame looks. Flat, low-contrast scenes (fog,
#' flat colour) score near 0; hard-lit noir or high-key graphic shots score
#' high.
#'
#' @param tl_frames A tl_frames tibble.
#' @param downsample Maximum side length for analysis. Default 200.
#'
#' @return The input tibble with added columns:
#'   - `rms_contrast`: Standard deviation of normalised luminance (>= 0).
#'
#'   - `michelson_contrast`: `(L_max - L_min) / (L_max + L_min)` on normalised
#'     luminance, in \[0, 1]. Returns 0 for a constant image.
#'
#' @references
#' Michelson, A. A. (1927). *Studies in Optics.* University of Chicago Press.
#'
#' @family texture
#' @export
frame_extract_contrast <- function(tl_frames, downsample = 200) {
  validate_tl_frames(tl_frames)

  results <- map_images(tl_frames, function(img) {
    gray <- magick::image_convert(img, colorspace = "gray")
    data <- as.integer(magick::image_data(gray))
    if (length(dim(data)) == 3) data <- data[, , 1]
    l <- as.numeric(data) / 255.0

    rms <- stats::sd(l)
    lo <- min(l); hi <- max(l)
    mich <- if ((lo + hi) > 0) (hi - lo) / (hi + lo) else 0

    list(
      rms_contrast = as.numeric(rms),
      michelson_contrast = as.numeric(mich)
    )
  }, downsample = downsample, msg = "Extracting contrast")

  bind_results(tl_frames, results)
}

#' Extract Local Binary Pattern (LBP) histogram
#'
#' Compute a uniform-LBP histogram (Ojala, Pietikainen & Maenpaa, 2002) as a
#' rotation-invariant micro-texture descriptor. This is a no-CNN *vector
#' representation*: one fixed-length histogram per frame, comparable across
#' frames and usable for similarity / clustering / nearest-neighbour search
#' alongside the existing `frame_extract_color_histogram()`.
#'
#' ## What it tells you (ELI5)
#' A compact fingerprint of local texture patterns: how often each small
#' 3x3 pattern of brighter/darker neighbours occurs. Two frames with similar
#' micro-texture (e.g. same film stock, same fabric) will have similar LBP
#' histograms.
#'
#' @param tl_frames A tl_frames tibble.
#' @param radius Radius of the LBP neighbourhood. Default 1 (3x3 patch).
#'   Larger radii capture coarser texture but are slower and less stable
#'   on small images.
#' @param n_points Number of sampling points around each pixel at the given
#'   radius. Default 8. The uniform-LBP mapping yields
#'   `n_points * (n_points - 1) + 3` bins (e.g. 59 for `n_points = 8`).
#' @param bins Number of histogram bins to return. Default `NULL` = the full
#'   uniform-LBP count (`n_points * (n_points - 1) + 3`). If fewer bins are
#'   requested, the excess uniform patterns are folded into the final
#'   non-uniform catch-all bin.
#' @param downsample Maximum side length for analysis. Default 200.
#'
#' @return The input tibble with added columns:
#'   - `lbp_1`, `lbp_2`, ..., `lbp_{bins}`: normalised histogram bin counts
#'     (sum to 1 per frame). Frames where the LBP could not be computed
#'     return all-zero bins.
#'
#' @references
#' Ojala, T., Pietikainen, M., & Maenpaa, T. (2002). Multiresolution
#' gray-scale and rotation invariant texture classification with local
#' binary patterns. *IEEE Transactions on Pattern Analysis and Machine
#' Intelligence*, 24(7), 971-987.
#'
#' @family texture
#' @export
frame_extract_lbp_histogram <- function(tl_frames, radius = 1, n_points = 8,
                                        bins = NULL, downsample = 200) {
  validate_tl_frames(tl_frames)

  # Uniform patterns (Ojala et al. 2002): a pattern is uniform if it has at
  # most 2 bitwise 0<->1 transitions around the circular bit string. There
  # are n_points*(n_points-1) + 2 uniform patterns; plus 1 non-uniform
  # catch-all => n_points*(n_points-1) + 3 bins total.
  uniform_lookup <- build_lbp_uniform_lookup(n_points)
  default_bins <- n_points * (n_points - 1L) + 3L
  if (is.null(bins)) bins <- default_bins
  # If fewer bins requested, fold excess ids into the last bin.
  if (bins < default_bins) {
    uniform_lookup <- pmin(uniform_lookup, bins - 1L)
  }

  results <- map_images(tl_frames, function(img) {
    gray <- magick::image_convert(img, colorspace = "gray")
    data <- as.integer(magick::image_data(gray))
    if (length(dim(data)) == 3) data <- data[, , 1]
    mat <- data

    nr <- nrow(mat); nc <- ncol(mat)
    if (nr < (2 * radius + 1) || nc < (2 * radius + 1)) {
      return(as.list(setNames(rep(0, bins), paste0("lbp_", seq_len(bins)))))
    }

    # Sampling offsets on a circle of `radius` (use the simplest radius-1
    # 8-neighbour layout when radius == 1; otherwise bilinear is overkill
    # for an inspectable classical feature).
    if (radius == 1 && n_points == 8) {
      # 8-neighbour offsets (row, col), clockwise from east.
      offs <- cbind(c(0, 1, 1, 1, 0, -1, -1, -1),
                    c(1, 1, 0, -1, -1, -1, 0, 1))
    } else {
      theta <- seq(0, 2 * pi, length.out = n_points + 1)[1:n_points]
      offs <- round(cbind(-radius * sin(theta), radius * cos(theta)))
    }

    centre_rows <- (radius + 1):(nr - radius)
    centre_cols <- (radius + 1):(nc - radius)
    if (length(centre_rows) == 0 || length(centre_cols) == 0) {
      return(as.list(setNames(rep(0, bins), paste0("lbp_", seq_len(bins)))))
    }

    codes <- integer(length(centre_rows) * length(centre_cols))
    m <- 0L
    for (i in centre_rows) {
      for (j in centre_cols) {
        c_val <- mat[i, j]
        bits <- 0L
        for (k in seq_len(n_points)) {
          nb <- mat[i + offs[k, 1], j + offs[k, 2]]
          if (nb >= c_val) {
            bits <- bitwOr(bits, bitwShiftL(1L, k - 1L))
          }
        }
        m <- m + 1L
        codes[m] <- uniform_lookup[bits + 1L]
      }
    }

    h <- tabulate(codes + 1L, nbins = bins) / length(codes)
    as.list(setNames(as.numeric(h), paste0("lbp_", seq_len(bins))))
  }, downsample = downsample, msg = "Extracting LBP histograms")

  bind_results(tl_frames, results)
}

# ---- LBP internals ---------------------------------------------------------

# Build the uniform-LBP lookup: for an n-bit LBP code, map to a bin id in
# [0, n_bins - 1] where n_bins = n_points * (n_points - 1) + 3. A pattern is
# "uniform" (Ojala et al. 2002) if the number of 0<->1 transitions around the
# circular bit string is at most 2. All uniform patterns get distinct ids
# 0..(n_uniform-1); every non-uniform pattern falls into the final catch-all
# bin (id = n_uniform). For n_points = 8 this gives 58 uniform + 1 catch-all
# = 59 bins.
build_lbp_uniform_lookup <- function(n_points) {
  n_codes <- 2L ^ n_points
  lookup <- integer(n_codes)
  uniform_id <- 0L

  for (code in seq_len(n_codes) - 1L) {
    bits <- as.integer(intToBits(code)[1:n_points])
    b <- c(bits, bits[1])
    transitions <- sum(diff(b) != 0)
    if (transitions <= 2) {
      lookup[code + 1L] <- uniform_id
      uniform_id <- uniform_id + 1L
    } else {
      # Catch-all: this will be folded to the final bin in the caller.
      lookup[code + 1L] <- .Machine$integer.max
    }
  }

  # Replace the catch-all sentinel with the final bin id (= n_uniform).
  n_uniform <- uniform_id
  lookup[lookup == .Machine$integer.max] <- n_uniform
  lookup
}