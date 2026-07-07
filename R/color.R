#' Color Analysis Functions
#'
#' Functions for extracting color metrics from images.
#'
#' @name color
#' @keywords internal
NULL

#' Extract brightness from images
#'
#' Compute overall image brightness (mean pixel intensity).
#'
#' @param tl_frames A tl_frames tibble.
#' @param downsample Maximum side length for analysis. Default 200.
#' @param method `"mean"` or `"median"`.
#'
#' @return The input tibble with added columns:
#'   - `brightness`: Mean/median brightness (0-1).
#'
#'   - `brightness_std`: Standard deviation of brightness.
#'
#' @family color
#' @export
#' @examples
#' \dontrun{
#' frames <- video_extract_frames_by_seconds("film.mp4", every = 5) |>
#'   frame_extract_brightness()
#' }
frame_extract_brightness <- function(tl_frames, downsample = 200, method = "mean") {
  validate_tl_frames(tl_frames)
  
  results <- map_images(tl_frames, function(img) {
    # Convert to grayscale
    gray <- magick::image_convert(img, colorspace = "gray")
    # as.integer on image_data returns HxWxC array
    data <- as.integer(magick::image_data(gray))
    vals <- as.numeric(data) / 255.0
    
    if (method == "median") {
      list(
        brightness = stats::median(vals),
        brightness_std = stats::sd(vals)
      )
    } else {
      list(
        brightness = mean(vals),
        brightness_std = stats::sd(vals)
      )
    }
  }, downsample = downsample, msg = "Extracting brightness")
  
  bind_results(tl_frames, results)
}

#' Extract mean color from images
#'
#' Compute per-image mean color in RGB color space.
#'
#' @param tl_frames A tl_frames tibble.
#' @param downsample Maximum side length for analysis. Default 200.
#'
#' @return The input tibble with added columns:
#'   - `mean_r`, `mean_g`, `mean_b`: Mean RGB values (0-1).
#'
#'   - `mean_hex`: Mean color as hex string.
#'
#' @family color
#' @export
frame_extract_color_mean <- function(tl_frames, downsample = 200) {
  validate_tl_frames(tl_frames)
  
  results <- map_images(tl_frames, function(img) {
    # as.integer converts to HxWxC format
    data <- as.integer(magick::image_data(img, channels = "rgb"))
    # data is [height, width, channels] after as.integer
    r_vals <- data[, , 1] / 255.0
    g_vals <- data[, , 2] / 255.0
    b_vals <- data[, , 3] / 255.0
    
    mean_r <- mean(r_vals)
    mean_g <- mean(g_vals)
    mean_b <- mean(b_vals)
    
    # Convert to hex
    mean_hex <- grDevices::rgb(mean_r, mean_g, mean_b)
    
    list(
      mean_r = mean_r,
      mean_g = mean_g,
      mean_b = mean_b,
      mean_hex = mean_hex
    )
  }, downsample = downsample, msg = "Extracting mean color")
  
  bind_results(tl_frames, results)
}

#' Extract saturation from images
#'
#' Compute overall image saturation in HSV color space.
#'
#' @param tl_frames A tl_frames tibble.
#' @param downsample Maximum side length for analysis. Default 200.
#'
#' @return The input tibble with added columns:
#'   - `saturation_mean`: Mean saturation (0-1).
#'
#'   - `saturation_median`: Median saturation.
#'
#'   - `saturation_std`: Standard deviation.
#'
#' @family color
#' @export
frame_extract_saturation <- function(tl_frames, downsample = 200) {
  validate_tl_frames(tl_frames)
  
  results <- map_images(tl_frames, function(img) {
    data <- as.integer(magick::image_data(img, channels = "rgb"))
    # data is HxWxC after as.integer
    r_vals <- data[, , 1] / 255.0
    g_vals <- data[, , 2] / 255.0
    b_vals <- data[, , 3] / 255.0
    
    # Convert RGB to HSV
    # Saturation = (max - min) / max, or 0 if max = 0
    max_rgb <- pmax(r_vals, g_vals, b_vals)
    min_rgb <- pmin(r_vals, g_vals, b_vals)
    
    sat <- ifelse(max_rgb == 0, 0, (max_rgb - min_rgb) / max_rgb)
    
    list(
      saturation_mean = mean(sat),
      saturation_median = stats::median(sat),
      saturation_std = stats::sd(sat)
    )
  }, downsample = downsample, msg = "Extracting saturation")
  
  bind_results(tl_frames, results)
}

#' Compute colourfulness (M3 metric)
#'
#' Compute the Hasler & Süsstrunk M3 colourfulness metric.
#'
#' @param tl_frames A tl_frames tibble.
#' @param downsample Maximum side length for analysis. Default 200.
#'
#' @return The input tibble with added column:
#'   - `colourfulness`: M3 metric value.
#'
#' @references
#' Hasler, D. and Süsstrunk, S. E. (2003). Measuring colorfulness in natural images.
#'
#' @family color
#' @export
frame_extract_colourfulness <- function(tl_frames, downsample = 200) {
  validate_tl_frames(tl_frames)
  
  results <- map_images(tl_frames, function(img) {
    data <- as.integer(magick::image_data(img, channels = "rgb"))
    # data is HxWxC after as.integer
    r <- as.numeric(data[, , 1])
    g <- as.numeric(data[, , 2])
    b <- as.numeric(data[, , 3])
    
    # M3 formula: sqrt(sigma_rg^2 + sigma_yb^2) + 0.3 * sqrt(mu_rg^2 + mu_yb^2)
    rg <- r - g
    yb <- 0.5 * (r + g) - b
    
    sigma_rg <- stats::sd(rg)
    sigma_yb <- stats::sd(yb)
    mu_rg <- mean(rg)
    mu_yb <- mean(yb)
    
    M3 <- sqrt(sigma_rg^2 + sigma_yb^2) + 0.3 * sqrt(mu_rg^2 + mu_yb^2)
    
    list(colourfulness = M3)
  }, downsample = downsample, msg = "Computing colourfulness")
  
  bind_results(tl_frames, results)
}

#' Extract color warmth/coolness
#'
#' Measure how warm (red/orange/yellow) or cool (blue/cyan) an image appears.
#'
#' @param tl_frames A tl_frames tibble.
#' @param downsample Maximum side length for analysis. Default 200.
#'
#' @return The input tibble with added columns:
#'   - `warmth`: Warmth score. Positive = warm (toward red/orange),
#'               Negative = cool (toward blue). Range approx -1 to 1.
#'
#'   - `tint`: Green-magenta tint. Positive = magenta, Negative = green.
#'             Range approx -1 to 1.
#'
#' @export
frame_extract_warmth <- function(tl_frames, downsample = 200) {
  validate_tl_frames(tl_frames)
  
  results <- map_images(tl_frames, function(img) {
    data <- as.integer(magick::image_data(img, channels = "rgb"))
    # data is HxWxC after as.integer
    r <- as.numeric(data[, , 1])
    g <- as.numeric(data[, , 2])
    b <- as.numeric(data[, , 3])

    mean_r <- mean(r); mean_g <- mean(g); mean_b <- mean(b)

    # Warmth: Red vs Blue channel difference, normalized to approx -1..1
    warmth <- (mean_r - mean_b) / 255
    
    # Tint: Magenta vs Green, normalized to approx -1..1
    # Magenta: high R and B relative to G; Green: high G relative to R and B
    tint <- ((mean_r + mean_b) / 2 - mean_g) / 255
    
    list(warmth = warmth, tint = tint)
  }, downsample = downsample, msg = "Extracting warmth")
  
  bind_results(tl_frames, results)
}

#' Extract dominant color
#'
#' Find the most common color in an image using k-means clustering.
#'
#' @param tl_frames A tl_frames tibble.
#' @param downsample Maximum side length for analysis. Default 100.
#'
#' @return The input tibble with added columns:
#'   - `dominant_color_hex`: Hex code of the dominant color.
#'   - `dominant_color_r/g/b`: RGB components (0-255).
#'   - `dominant_color_proportion`: What fraction of pixels are this color.
#'
#' @family color
#' @export
frame_extract_dominant_color <- function(tl_frames, downsample = 100) {
  validate_tl_frames(tl_frames)

  results <- map_images(tl_frames, function(img) {
    data <- as.integer(magick::image_data(img, channels = "rgb"))
    # data is HxWxC after as.integer
    n_pixels <- prod(dim(data)[1:2])

    # Reshape to n_pixels x 3 matrix
    rgb_matrix <- matrix(
      c(as.vector(data[,,1]), as.vector(data[,,2]), as.vector(data[,,3])),
      ncol = 3
    )

    # K-means clustering (single dominant cluster)
    tryCatch({
      km <- stats::kmeans(rgb_matrix, centers = 1, nstart = 3, iter.max = 20)

      dominant_rgb <- km$centers[1, ]
      # Single cluster covers the whole image; proportion is 1.
      proportion <- 1
      
      list(
        dominant_color_r = as.integer(round(dominant_rgb[1])),
        dominant_color_g = as.integer(round(dominant_rgb[2])),
        dominant_color_b = as.integer(round(dominant_rgb[3])),
        dominant_color_hex = grDevices::rgb(
          dominant_rgb[1]/255, dominant_rgb[2]/255, dominant_rgb[3]/255
        ),
        dominant_color_proportion = proportion
      )
    }, error = function(e) {
      list(
        dominant_color_r = NA_integer_,
        dominant_color_g = NA_integer_,
        dominant_color_b = NA_integer_,
        dominant_color_hex = NA_character_,
        dominant_color_proportion = NA_real_
      )
    })
  }, downsample = downsample, msg = "Extracting dominant color")
  
  bind_results(tl_frames, results)
}

#' Extract color variance
#'
#' Measure the variance/spread of colors in the image.
#'
#' @param tl_frames A tl_frames tibble.
#' @param downsample Maximum side length for analysis. Default 200.
#'
#' @return The input tibble with added columns:
#'   - `color_variance`: Overall color variance (higher = more varied colors).
#'   - `color_range_r/g/b`: Range (max - min) for each channel.
#'
#' @family color
#' @export
frame_extract_color_variance <- function(tl_frames, downsample = 200) {
  validate_tl_frames(tl_frames)
  
  results <- map_images(tl_frames, function(img) {
    data <- as.integer(magick::image_data(img, channels = "rgb"))
    r <- as.numeric(data[, , 1])
    g <- as.numeric(data[, , 2])
    b <- as.numeric(data[, , 3])
    
    # Variance in each channel
    var_r <- stats::var(r)
    var_g <- stats::var(g)
    var_b <- stats::var(b)
    
    # Overall color variance (mean of channel variances)
    color_variance <- (var_r + var_g + var_b) / 3
    
    # Range in each channel
    range_r <- max(r) - min(r)
    range_g <- max(g) - min(g)
    range_b <- max(b) - min(b)
    
    list(
      color_variance = color_variance,
      color_range_r = range_r,
      color_range_g = range_g,
      color_range_b = range_b
    )
  }, downsample = downsample, msg = "Extracting color variance")
  
  bind_results(tl_frames, results)
}

#' Extract median color
#'
#' Compute per-image median color in RGB.
#'
#' @param tl_frames A tl_frames tibble.
#' @param downsample Maximum side length for analysis. Default 200.
#'
#' @return The input tibble with added columns:
#'   - `median_r`, `median_g`, `median_b`: Median RGB values (0-1).
#'   - `median_hex`: Median color as hex string.
#'
#' @family color
#' @export
frame_extract_color_median <- function(tl_frames, downsample = 200) {
  validate_tl_frames(tl_frames)
  
  results <- map_images(tl_frames, function(img) {
    data <- as.integer(magick::image_data(img, channels = "rgb"))
    r_vals <- data[, , 1] / 255.0
    g_vals <- data[, , 2] / 255.0
    b_vals <- data[, , 3] / 255.0
    
    med_r <- stats::median(r_vals)
    med_g <- stats::median(g_vals)
    med_b <- stats::median(b_vals)
    
    med_hex <- grDevices::rgb(med_r, med_g, med_b)
    
    list(
      median_r = med_r,
      median_g = med_g,
      median_b = med_b,
      median_hex = med_hex
    )
  }, downsample = downsample, msg = "Extracting median color")
  
  bind_results(tl_frames, results)
}

#' Extract mode color
#'
#' Compute per-image mode (most frequent) color after binning.
#'
#' @param tl_frames A tl_frames tibble.
#' @param n_bins Number of bins per channel. Default 32.
#' @param downsample Maximum side length for analysis. Default 200.
#'
#' @return The input tibble with added columns:
#'   - `mode_r`, `mode_g`, `mode_b`: Mode RGB values (0-1).
#'   - `mode_hex`: Mode color as hex string.
#'   - `mode_frequency`: Proportion of pixels with this binned color.
#'
#' @family color
#' @export
frame_extract_color_mode <- function(tl_frames, n_bins = 32, downsample = 200) {
  validate_tl_frames(tl_frames)
  
  results <- map_images(tl_frames, function(img) {
    data <- as.integer(magick::image_data(img, channels = "rgb"))
    r_vals <- as.vector(data[, , 1])
    g_vals <- as.vector(data[, , 2])
    b_vals <- as.vector(data[, , 3])
    
    # Bin colors
    bin_size <- 256 / n_bins
    r_binned <- floor(r_vals / bin_size)
    g_binned <- floor(g_vals / bin_size)
    b_binned <- floor(b_vals / bin_size)
    
    # Composite bin ID (integer encoding avoids paste/strsplit round-trip)
    bin_id <- r_binned + g_binned * n_bins + b_binned * n_bins * n_bins

    # Find most frequent bin
    freq_table <- tabulate(bin_id + 1L)
    mode_idx <- which.max(freq_table)
    mode_freq <- freq_table[mode_idx] / length(bin_id)

    # Decode bin ID back to per-channel bins
    mode_bin <- mode_idx - 1L
    mode_r <- (mode_bin %% n_bins + 0.5) * bin_size / 255
    mode_g <- (floor(mode_bin / n_bins) %% n_bins + 0.5) * bin_size / 255
    mode_b <- (floor(mode_bin / (n_bins * n_bins)) + 0.5) * bin_size / 255
    
    mode_hex <- grDevices::rgb(mode_r, mode_g, mode_b)
    
    list(
      mode_r = mode_r,
      mode_g = mode_g,
      mode_b = mode_b,
      mode_hex = mode_hex,
      mode_frequency = mode_freq
    )
  }, downsample = downsample, msg = "Extracting mode color")
  
  bind_results(tl_frames, results)
}

#' Extract hue histogram from images
#'
#' Compute hue distribution and statistics from HSV color space.
#'
#' @param tl_frames A tl_frames tibble.
#' @param n_bins Number of hue bins. Default 12 (30-degree bins).
#' @param downsample Maximum side length for analysis. Default 200.
#'
#' @return The input tibble with added columns:
#'   - `dominant_hue`: Most frequent hue bin center (0-360 degrees).
#'   - `dominant_hue_name`: Color name for dominant hue.
#'   - `dominant_hue_proportion`: Proportion of pixels in dominant hue bin.
#'   - `hue_entropy`: Shannon entropy of hue distribution (higher = more varied).
#'   - `hue_concentration`: Opposite of entropy (higher = more uniform hue).
#'
#' @family color
#' @export
frame_extract_hue_histogram <- function(tl_frames, n_bins = 12, downsample = 200) {
  validate_tl_frames(tl_frames)
  
  # Hue names for 12 bins (30-degree each)
  hue_names <- c("red", "orange", "yellow", "chartreuse", "green", "spring",
                 "cyan", "azure", "blue", "violet", "magenta", "rose")
  
  results <- map_images(tl_frames, function(img) {
    data <- as.integer(magick::image_data(img, channels = "rgb"))
    r_vals <- data[, , 1] / 255.0
    g_vals <- data[, , 2] / 255.0
    b_vals <- data[, , 3] / 255.0
    
    # Convert RGB to HSV
    max_rgb <- pmax(r_vals, g_vals, b_vals)
    min_rgb <- pmin(r_vals, g_vals, b_vals)
    delta <- max_rgb - min_rgb
    
    # Only compute hue for pixels with some saturation
    sat <- ifelse(max_rgb == 0, 0, delta / max_rgb)
    valid_mask <- sat > 0.1 & max_rgb > 0.1  # Filter out grays and blacks
    
    if (sum(valid_mask) < 10) {
      return(list(
        dominant_hue = NA_real_,
        dominant_hue_name = "gray",
        dominant_hue_proportion = NA_real_,
        hue_entropy = 0,
        hue_concentration = 1
      ))
    }
    
    # Compute hue for valid pixels
    r_v <- r_vals[valid_mask]
    g_v <- g_vals[valid_mask]
    b_v <- b_vals[valid_mask]
    max_v <- max_rgb[valid_mask]
    delta_v <- delta[valid_mask]
    
    hue <- numeric(length(r_v))
    
    # Hue calculation
    is_r_max <- abs(max_v - r_v) < 1e-6
    is_g_max <- abs(max_v - g_v) < 1e-6
    
    hue[is_r_max] <- ((g_v[is_r_max] - b_v[is_r_max]) / delta_v[is_r_max]) %% 6
    hue[is_g_max & !is_r_max] <- (b_v[is_g_max & !is_r_max] - r_v[is_g_max & !is_r_max]) / delta_v[is_g_max & !is_r_max] + 2
    hue[!is_r_max & !is_g_max] <- (r_v[!is_r_max & !is_g_max] - g_v[!is_r_max & !is_g_max]) / delta_v[!is_r_max & !is_g_max] + 4
    
    hue_degrees <- (hue * 60) %% 360
    
    # Bin hue
    bin_width <- 360 / n_bins
    hue_bins <- floor(hue_degrees / bin_width) + 1
    hue_bins[hue_bins > n_bins] <- n_bins
    
    # Histogram
    hist_counts <- tabulate(hue_bins, nbins = n_bins)
    hist_probs <- hist_counts / sum(hist_counts)
    
    # Find dominant
    dominant_bin <- which.max(hist_counts)
    dominant_hue <- (dominant_bin - 0.5) * bin_width
    dominant_prop <- hist_probs[dominant_bin]
    
    # Get hue name
    if (n_bins == 12) {
      hue_name <- hue_names[dominant_bin]
    } else {
      hue_name <- paste0(round(dominant_hue), "deg")
    }
    
    # Shannon entropy
    nonzero_probs <- hist_probs[hist_probs > 0]
    hue_entropy <- -sum(nonzero_probs * log2(nonzero_probs))
    max_entropy <- log2(n_bins)
    hue_concentration <- 1 - (hue_entropy / max_entropy)
    
    list(
      dominant_hue = dominant_hue,
      dominant_hue_name = hue_name,
      dominant_hue_proportion = dominant_prop,
      hue_entropy = hue_entropy,
      hue_concentration = hue_concentration
    )
  }, downsample = downsample, msg = "Extracting hue histogram")
  
  bind_results(tl_frames, results)
}

#' Extract Color Moments
#'
#' @description
#' Computes statistical color moments for each image. Color moments are a
#' compact way to characterize color distributions, widely used in image
#' retrieval systems (CBIR).
#'
#' **What are Color Moments?**
#' Think of them like summary statistics for colors:
#' - **Mean**: The "average" color of each channel.
#' - **Standard deviation**: How spread out the colors are.
#' - **Skewness**: Whether colors lean toward dark or bright.
#'
#' @param tl_frames A tl_frames tibble.
#' @param downsample Maximum side length for analysis. Default 200.
#'
#' @return The input tibble with added columns:
#'   - `cm_r_mean`, `cm_r_std`, `cm_r_skew` (and same for g, b).
#'
#' @details
#' Color moments provide a more compact representation than full histograms.
#' The first three moments (mean, std, skewness) capture most of the
#' discriminative information for image retrieval tasks.
#'
#' Skewness interpretation:
#' - Negative skew: distribution leans toward higher values (brighter).
#' - Positive skew: distribution leans toward lower values (darker).
#' - Zero: symmetric distribution.
#'
#' @references
#' Stricker, M. & Orengo, M. (1995). Similarity of Color Images.
#' SPIE Storage and Retrieval for Image and Video Databases III.
#'
#' @family color
#' @export
#' @examples
#' \dontrun{
#' frames <- video_extract_frames_by_seconds("film.mp4", every = 5) |>
#'   frame_extract_color_moments()
#' # Check if image leans warm (high r, low b)
#' images$cm_r_mean > images$cm_b_mean
#' }
frame_extract_color_moments <- function(tl_frames, downsample = 200) {
  validate_tl_frames(tl_frames)

  # Helper for skewness
  calc_skewness <- function(x) {
    n <- length(x)
    m <- mean(x)
    s <- stats::sd(x)
    if (s == 0) return(0)
    sum((x - m)^3) / ((n - 1) * s^3)
  }

  results <- map_images(tl_frames, function(img) {
    data <- as.integer(magick::image_data(img))
    # data is [height, width, channels] after as.integer

    c1 <- as.numeric(data[, , 1]) / 255.0
    c2 <- as.numeric(data[, , 2]) / 255.0
    c3 <- as.numeric(data[, , 3]) / 255.0

    setNames(list(
      mean(c1), stats::sd(c1), calc_skewness(c1),
      mean(c2), stats::sd(c2), calc_skewness(c2),
      mean(c3), stats::sd(c3), calc_skewness(c3)
    ), c(
      paste0("cm_", c("r"), "_", c("mean","std","skew")),
      paste0("cm_", c("g"), "_", c("mean","std","skew")),
      paste0("cm_", c("b"), "_", c("mean","std","skew"))
    ))
  }, downsample = downsample, msg = "Extracting color moments")

  bind_results(tl_frames, results)
}
