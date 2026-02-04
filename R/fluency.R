#' Fluency and Aesthetic Metrics
#'
#' Functions for computing visual fluency and aesthetic metrics.
#'
#' @name fluency
#' @keywords internal
NULL

#' Extract fluency metrics
#'
#' Compute processing fluency metrics based on imagefluency package methodology.
#'
#' @param tl_images A tl_images tibble.
#' @param downsample Maximum side length for analysis. Default 200.
#'
#' @return The input tibble with added columns:
#'   - `simplicity`: Image simplicity (lower entropy = simpler).
#'
#'   - `symmetry_h`: Horizontal symmetry score.
#'
#'   - `symmetry_v`: Vertical symmetry score.
#'
#'   - `balance`: Visual balance score.
#'
#' @family fluency
#' @export
extract_fluency_metrics <- function(tl_images, downsample = 200) {
  validate_tl_images(tl_images)
  
  results <- map_images(tl_images, function(img) {
    # Convert to grayscale matrix
    gray <- magick::image_convert(img, colorspace = "gray")
    data <- as.integer(magick::image_data(gray))
    
    # Handle both HxW and HxWx1 cases
    if (length(dim(data)) == 3) {
      mat <- data[, , 1] / 255.0
    } else {
      mat <- data / 255.0
    }
    
    nr <- nrow(mat)
    nc <- ncol(mat)
    
    # Simplicity: inverse of entropy
    int_vals <- as.integer(mat * 255)
    hist_counts <- tabulate(int_vals + 1, nbins = 256)
    probs <- hist_counts / sum(hist_counts)
    probs <- probs[probs > 0]
    entropy <- -sum(probs * log2(probs))
    simplicity <- 1 - (entropy / 8)  # Normalize by max entropy (log2(256))
    
    # Horizontal symmetry: compare left half to flipped right half
    mid_c <- nc %/% 2
    if (mid_c > 0) {
      left <- mat[, 1:mid_c]
      right <- mat[, nc:(nc - mid_c + 1)]
      symmetry_h <- 1 - mean(abs(left - right))
    } else {
      symmetry_h <- NA_real_
    }
    
    # Vertical symmetry: compare top half to flipped bottom half
    mid_r <- nr %/% 2
    if (mid_r > 0) {
      top <- mat[1:mid_r, ]
      bottom <- mat[nr:(nr - mid_r + 1), ]
      symmetry_v <- 1 - mean(abs(top - bottom))
    } else {
      symmetry_v <- NA_real_
    }
    
    # Visual balance: compare mean intensity of quadrants
    half_r <- nr %/% 2
    half_c <- nc %/% 2
    if (half_r > 0 && half_c > 0) {
      q1 <- mean(mat[1:half_r, 1:half_c])
      q2 <- mean(mat[1:half_r, (half_c+1):nc])
      q3 <- mean(mat[(half_r+1):nr, 1:half_c])
      q4 <- mean(mat[(half_r+1):nr, (half_c+1):nc])
      
      # Balance is how similar the quadrants are
      quadrant_var <- stats::var(c(q1, q2, q3, q4))
      balance <- 1 - min(quadrant_var * 4, 1)  # Scale and invert
    } else {
      balance <- NA_real_
    }
    
    list(
      simplicity = simplicity,
      symmetry_h = symmetry_h,
      symmetry_v = symmetry_v,
      balance = balance
    )
  }, downsample = downsample, msg = "Extracting fluency metrics")
  
  tl_images$simplicity <- purrr::map_dbl(results, ~ .x$simplicity %||% NA_real_)
  tl_images$symmetry_h <- purrr::map_dbl(results, ~ .x$symmetry_h %||% NA_real_)
  tl_images$symmetry_v <- purrr::map_dbl(results, ~ .x$symmetry_v %||% NA_real_)
  tl_images$balance <- purrr::map_dbl(results, ~ .x$balance %||% NA_real_)
  
  tl_images
}

#' Compute rule of thirds adherence
#'
#' Measure how well the image follows the rule of thirds composition.
#'
#' @param tl_images A tl_images tibble.
#' @param downsample Maximum side length for analysis. Default 200.
#'
#' @return The input tibble with added column:
#'   - `rule_of_thirds`: Score indicating adherence to rule of thirds (0-1).
#'
#' @family fluency
#' @export
extract_rule_of_thirds <- function(tl_images, downsample = 200) {
  validate_tl_images(tl_images)
  
  results <- map_images(tl_images, function(img) {
    # Use gradient magnitude as a proxy for visual interest
    gray <- magick::image_convert(img, colorspace = "gray")
    data <- as.integer(magick::image_data(gray))
    
    # Handle both HxW and HxWx1 cases
    if (length(dim(data)) == 3) {
      mat <- data[, , 1]
    } else {
      mat <- data
    }
    
    nr <- nrow(mat)
    nc <- ncol(mat)
    
    if (nr < 3 || nc < 3) {
      return(list(rule_of_thirds = NA_real_))
    }
    
    # Calculate gradient magnitude
    gx <- mat
    gx[, -1] <- mat[, -1] - mat[, -nc]
    gx[, 1] <- 0
    
    gy <- mat
    gy[-1, ] <- mat[-1, ] - mat[-nr, ]
    gy[1, ] <- 0
    
    grad_mag <- sqrt(as.numeric(gx)^2 + as.numeric(gy)^2)
    dim(grad_mag) <- c(nr, nc)
    
    # Rule of thirds lines
    third_rows <- round(c(nr/3, 2*nr/3))
    third_cols <- round(c(nc/3, 2*nc/3))
    
    # Power points (intersections)
    power_points <- list(
      c(third_rows[1], third_cols[1]),
      c(third_rows[1], third_cols[2]),
      c(third_rows[2], third_cols[1]),
      c(third_rows[2], third_cols[2])
    )
    
    # Sample gradient around power points (5x5 window)
    window_size <- 5
    power_strength <- 0
    
    for (pp in power_points) {
      r1 <- max(1, pp[1] - window_size)
      r2 <- min(nr, pp[1] + window_size)
      c1 <- max(1, pp[2] - window_size)
      c2 <- min(nc, pp[2] + window_size)
      
      power_strength <- power_strength + mean(grad_mag[r1:r2, c1:c2])
    }
    
    power_strength <- power_strength / 4
    
    # Compare to overall gradient
    overall_strength <- mean(grad_mag)
    
    # Rule of thirds score
    score <- if (overall_strength > 0) {
      min(power_strength / overall_strength, 2) / 2  # Normalize to 0-1
    } else {
      0.5
    }
    
    list(rule_of_thirds = score)
  }, downsample = downsample, msg = "Computing rule of thirds")
  
  tl_images$rule_of_thirds <- purrr::map_dbl(results, ~ .x$rule_of_thirds %||% NA_real_)
  
  tl_images
}

#' Extract visual complexity
#'
#' Compute visual complexity using multiple measures.
#'
#' @param tl_images A tl_images tibble.
#' @param downsample Maximum side length for analysis. Default 200.
#'
#' @return The input tibble with added column:
#'   - `visual_complexity`: Combined complexity score (0-1).
#'
#' @family fluency
#' @export
extract_visual_complexity <- function(tl_images, downsample = 200) {
  validate_tl_images(tl_images)
  
  results <- map_images(tl_images, function(img) {
    gray <- magick::image_convert(img, colorspace = "gray")
    data <- as.integer(magick::image_data(gray))
    
    # Handle both HxW and HxWx1 cases
    if (length(dim(data)) == 3) {
      mat <- data[, , 1]
    } else {
      mat <- data
    }
    
    nr <- nrow(mat)
    nc <- ncol(mat)
    
    # 1. Entropy component
    hist_counts <- tabulate(mat + 1, nbins = 256)
    probs <- hist_counts / sum(hist_counts)
    probs <- probs[probs > 0]
    entropy <- -sum(probs * log2(probs)) / 8  # Normalize by max
    
    # 2. Edge density component
    if (nr >= 3 && nc >= 3) {
      gx <- mat
      gx[, -1] <- mat[, -1] - mat[, -nc]
      gx[, 1] <- 0
      
      gy <- mat
      gy[-1, ] <- mat[-1, ] - mat[-nr, ]
      gy[1, ] <- 0
      
      grad_mag <- sqrt(as.numeric(gx)^2 + as.numeric(gy)^2)
      edge_density <- mean(grad_mag > 25) # Threshold for edges
    } else {
      edge_density <- 0
    }
    
    # 3. Color diversity (for color images)
    # We'll use grayscale variance as proxy
    intensity_var <- stats::sd(mat) / 128  # Normalize
    
    # Combined complexity
    complexity <- (entropy + edge_density + min(intensity_var, 1)) / 3
    
    list(visual_complexity = complexity)
  }, downsample = downsample, msg = "Extracting visual complexity")
  
  tl_images$visual_complexity <- purrr::map_dbl(results, ~ .x$visual_complexity %||% NA_real_)
  
  tl_images
}

#' Analyze center bias
#'
#' Measure how much visual activity is concentrated in the center of the image.
#' Center bias is common in film and photography compositions.
#'
#' @param tl_images A tl_images tibble.
#' @param center_ratio Size of center region relative to image. Default 0.5 (central 50%).
#' @param downsample Maximum side length for analysis. Default 200.
#'
#' @return The input tibble with added columns:
#'   - `center_bias`: Ratio of center activity to peripheral activity (>1 = center-weighted).
#'   - `center_brightness`: Mean brightness in center region.
#'   - `peripheral_brightness`: Mean brightness in peripheral region.
#'   - `center_salience`: Center gradient magnitude vs peripheral.
#'
#' @family fluency
#' @export
extract_center_bias <- function(tl_images, center_ratio = 0.5, downsample = 200) {
  validate_tl_images(tl_images)
  
  results <- map_images(tl_images, function(img) {
    gray <- magick::image_convert(img, colorspace = "gray")
    data <- as.integer(magick::image_data(gray))
    
    if (length(dim(data)) == 3) {
      mat <- data[, , 1] / 255.0
    } else {
      mat <- data / 255.0
    }
    
    nr <- nrow(mat)
    nc <- ncol(mat)
    
    # Define center region
    margin_r <- round(nr * (1 - center_ratio) / 2)
    margin_c <- round(nc * (1 - center_ratio) / 2)
    
    r1 <- max(1, margin_r)
    r2 <- min(nr, nr - margin_r)
    c1 <- max(1, margin_c)
    c2 <- min(nc, nc - margin_c)
    
    # Create center mask
    center_mask <- matrix(FALSE, nrow = nr, ncol = nc)
    center_mask[r1:r2, c1:c2] <- TRUE
    
    # Brightness analysis
    center_brightness <- mean(mat[center_mask])
    peripheral_brightness <- mean(mat[!center_mask])
    
    # Gradient/salience analysis
    if (nr >= 3 && nc >= 3) {
      gx <- mat
      gx[, -1] <- mat[, -1] - mat[, -nc]
      gx[, 1] <- 0
      
      gy <- mat
      gy[-1, ] <- mat[-1, ] - mat[-nr, ]
      gy[1, ] <- 0
      
      grad_mag <- sqrt(gx^2 + gy^2)
      
      center_salience <- mean(grad_mag[center_mask])
      peripheral_salience <- mean(grad_mag[!center_mask])
      
      center_bias <- if (peripheral_salience > 0) {
        center_salience / peripheral_salience
      } else {
        NA_real_
      }
    } else {
      center_salience <- NA_real_
      center_bias <- NA_real_
    }
    
    list(
      center_bias = center_bias,
      center_brightness = center_brightness,
      peripheral_brightness = peripheral_brightness,
      center_salience = center_salience
    )
  }, downsample = downsample, msg = "Analyzing center bias")
  
  tl_images$center_bias <- purrr::map_dbl(results, ~ .x$center_bias %||% NA_real_)
  tl_images$center_brightness <- purrr::map_dbl(results, ~ .x$center_brightness %||% NA_real_)
  tl_images$peripheral_brightness <- purrr::map_dbl(results, ~ .x$peripheral_brightness %||% NA_real_)
  tl_images$center_salience <- purrr::map_dbl(results, ~ .x$center_salience %||% NA_real_)
  
  tl_images
}

# Null-coalescing operator
if (!exists("%||%")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}
