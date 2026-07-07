# Texture feature tests
# Covers: frame_extract_glcm(), frame_extract_sharpness(),
# frame_extract_contrast(), frame_extract_lbp_histogram()

make_test_image <- function(w = 40, h = 40, col = "#336699") {
  magick::image_blank(w, h, col)
}

make_checker_image <- function(w = 40, h = 40, cell = 4) {
  mat <- matrix(0, nrow = h, ncol = w)
  for (i in seq_len(h)) for (j in seq_len(w)) {
    if ((floor((i - 1) / cell) + floor((j - 1) / cell)) %% 2 == 0) mat[i, j] <- 255
  }
  arr <- array(0, dim = c(h, w, 3))
  arr[, , 1] <- arr[, , 2] <- arr[, , 3] <- mat
  magick::image_read(arr / 255)
}

make_gradient_image <- function(w = 40, h = 40) {
  mat <- matrix(seq(0, 1, length.out = w * h), nrow = h, ncol = w)
  arr <- array(0, dim = c(h, w, 3))
  arr[, , 1] <- mat
  arr[, , 2] <- 1 - mat
  arr[, , 3] <- 0.5
  magick::image_read(arr / 255)
}

make_lr_symmetric_image <- function(w = 40, h = 40) {
  # Random left half mirrored to the right -> high LR symmetry.
  left <- matrix(runif(h * (w / 2)), nrow = h)
  mat <- cbind(left, left[, (w / 2):1])
  arr <- array(0, dim = c(h, w, 3))
  arr[, , 1] <- arr[, , 2] <- arr[, , 3] <- mat
  magick::image_read(arr)
}

write_test_images <- function(imgs, prefix = "tl-texture") {
  tmp <- tempfile(pattern = prefix)
  dir.create(tmp, showWarnings = FALSE)
  paths <- vapply(seq_along(imgs), function(i) {
    p <- file.path(tmp, sprintf("f_%03d.jpg", i))
    magick::image_write(imgs[[i]], p, format = "jpg")
    p
  }, character(1))
  paths
}

as_tl_frames <- function(paths) {
  res <- tibble::tibble(id = seq_along(paths), local_path = paths)
  class(res) <- c("tl_frames", class(res))
  res
}

# ── frame_extract_glcm() ───────────────────────────────────────────────────

test_that("frame_extract_glcm adds the five Haralick columns", {
  paths <- write_test_images(list(make_test_image(), make_gradient_image()))
  frames <- as_tl_frames(paths)
  out <- frame_extract_glcm(frames)
  for (col in c("glcm_contrast", "glcm_homogeneity", "glcm_energy",
                "glcm_entropy", "glcm_correlation")) {
    expect_true(col %in% names(out), info = col)
  }
  expect_s3_class(out, "tl_frames")
})

test_that("GLCM features are finite or NA", {
  paths <- write_test_images(list(make_test_image(), make_gradient_image()))
  frames <- as_tl_frames(paths)
  out <- frame_extract_glcm(frames)
  cols <- c("glcm_contrast", "glcm_homogeneity", "glcm_energy", "glcm_entropy")
  for (col in cols) {
    expect_true(all(is.finite(out[[col]]) | is.na(out[[col]])), info = col)
  }
})

test_that("GLCM: constant image has zero contrast and energy 1", {
  paths <- write_test_images(list(make_test_image()))
  frames <- as_tl_frames(paths)
  out <- frame_extract_glcm(frames)
  expect_equal(out$glcm_contrast[1], 0)
  expect_equal(out$glcm_energy[1], 1)
  expect_equal(out$glcm_homogeneity[1], 1)
  expect_equal(out$glcm_entropy[1], 0)
})

test_that("GLLM: checkerboard has higher contrast than solid image", {
  paths <- write_test_images(list(make_test_image(), make_checker_image()))
  frames <- as_tl_frames(paths)
  out <- frame_extract_glcm(frames)
  expect_gt(out$glcm_contrast[2], out$glcm_contrast[1])
  expect_gt(out$glcm_entropy[2], out$glcm_entropy[1])
})

# ── frame_extract_sharpness() ──────────────────────────────────────────────

test_that("frame_extract_sharpness adds a sharpness column", {
  paths <- write_test_images(list(make_test_image(), make_checker_image()))
  frames <- as_tl_frames(paths)
  out <- frame_extract_sharpness(frames)
  expect_true("sharpness" %in% names(out))
  expect_true(all(is.finite(out$sharpness)))
})

test_that("Sharpness: constant image is ~0; checkerboard is higher", {
  paths <- write_test_images(list(make_test_image(), make_checker_image()))
  frames <- as_tl_frames(paths)
  out <- frame_extract_sharpness(frames)
  expect_lt(out$sharpness[1], 1e-6)
  expect_gt(out$sharpness[2], out$sharpness[1])
})

# ── frame_extract_contrast() ────────────────────────────────────────────────

test_that("frame_extract_contrast adds RMS and Michelson columns", {
  paths <- write_test_images(list(make_test_image(), make_gradient_image()))
  frames <- as_tl_frames(paths)
  out <- frame_extract_contrast(frames)
  expect_true("rms_contrast" %in% names(out))
  expect_true("michelson_contrast" %in% names(out))
  expect_true(all(is.finite(out$rms_contrast)))
  expect_true(all(is.finite(out$michelson_contrast)))
})

test_that("Contrast: constant image is 0; Michelson in [0,1]", {
  paths <- write_test_images(list(make_test_image(), make_gradient_image()))
  frames <- as_tl_frames(paths)
  out <- frame_extract_contrast(frames)
  expect_equal(out$rms_contrast[1], 0)
  expect_equal(out$michelson_contrast[1], 0)
  for (i in seq_len(nrow(out))) {
    expect_gte(out$michelson_contrast[i], 0)
    expect_lte(out$michelson_contrast[i], 1)
  }
})

# ── frame_extract_lbp_histogram() ──────────────────────────────────────────

test_that("frame_extract_lbp_histogram adds lbp_* columns", {
  paths <- write_test_images(list(make_test_image(), make_checker_image()))
  frames <- as_tl_frames(paths)
  out <- frame_extract_lbp_histogram(frames)
  expect_true("lbp_1" %in% names(out))
  n_lbp <- sum(grepl("^lbp_[0-9]+$", names(out)))
  expect_equal(n_lbp, 59)  # n_points=8 -> 59 uniform bins
})

test_that("LBP histogram bins are non-negative and sum to ~1 per row", {
  paths <- write_test_images(list(make_test_image(), make_checker_image()))
  frames <- as_tl_frames(paths)
  out <- frame_extract_lbp_histogram(frames)
  lbp_cols <- grep("^lbp_[0-9]+$", names(out), value = TRUE)
  for (i in seq_len(nrow(out))) {
    expect_true(all(out[i, lbp_cols] >= 0))
    expect_equal(sum(as.numeric(out[i, lbp_cols])), 1, tolerance = 1e-6)
  }
})

test_that("LBP: constant image concentrates mass in a single bin", {
  paths <- write_test_images(list(make_test_image()))
  frames <- as_tl_frames(paths)
  out <- frame_extract_lbp_histogram(frames)
  lbp_cols <- grep("^lbp_[0-9]+$", names(out), value = TRUE)
  vals <- as.numeric(out[1, lbp_cols])
  # The all-equal pattern (uniform) is one of the uniform patterns.
  expect_equal(sum(vals), 1, tolerance = 1e-6)
  # All mass should be in a single bin.
  expect_equal(sum(vals > 0), 1)
})

test_that("LBP: checkerboard pattern differs from constant image", {
  paths <- write_test_images(list(make_test_image(), make_checker_image()))
  frames <- as_tl_frames(paths)
  out <- frame_extract_lbp_histogram(frames)
  lbp_cols <- grep("^lbp_[0-9]+$", names(out), value = TRUE)
  v1 <- as.numeric(out[1, lbp_cols])
  v2 <- as.numeric(out[2, lbp_cols])
  # Different distributions.
  expect_gt(sum((v1 - v2)^2), 0)
})