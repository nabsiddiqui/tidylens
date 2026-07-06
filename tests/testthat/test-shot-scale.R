# Shot scale classification tests
# Covers: extract_shot_scale_features(), frame_classify_scale(), model compatibility

make_test_image <- function(w = 40, h = 40, col = "#336699") {
  magick::image_blank(w, h, col)
}

make_gradient_image <- function(w = 40, h = 40) {
  mat <- matrix(seq(0, 1, length.out = w * h), nrow = h, ncol = w)
  arr <- array(0, dim = c(h, w, 3))
  arr[, , 1] <- mat
  arr[, , 2] <- 1 - mat
  arr[, , 3] <- 0.5
  magick::image_read(arr / 255)
}

write_test_images <- function(imgs, prefix = "tl-scale") {
  tmp <- tempfile(pattern = prefix)
  dir.create(tmp, showWarnings = FALSE)
  paths <- vapply(seq_along(imgs), function(i) {
    p <- file.path(tmp, sprintf("f_%03d.jpg", i))
    magick::image_write(imgs[[i]], p, format = "jpg")
    p
  }, character(1))
  paths
}

# ── extract_shot_scale_features() unit tests ──────────────────────────────

test_that("extract_shot_scale_features returns named numeric vector", {
  img <- make_test_image()
  feats <- extract_shot_scale_features(img)
  expect_type(feats, "double")
  expect_named(feats)
  expect_true(length(feats) >= 13)
})

test_that("extract_shot_scale_features values are finite or NA", {
  img <- make_test_image()
  feats <- extract_shot_scale_features(img)
  expect_true(all(is.finite(feats) | is.na(feats)))
})

test_that("salience_coverage is in 0..1", {
  img <- make_test_image()
  feats <- extract_shot_scale_features(img)
  expect_true(feats[["salience_coverage"]] >= 0)
  expect_true(feats[["salience_coverage"]] <= 1)
})

test_that("salience centroids are in 0..1", {
  img <- make_test_image()
  feats <- extract_shot_scale_features(img)
  expect_true(feats[["salience_centroid_x"]] >= 0 && feats[["salience_centroid_x"]] <= 1)
  expect_true(feats[["salience_centroid_y"]] >= 0 && feats[["salience_centroid_y"]] <= 1)
})

test_that("face_coverage is in 0..1", {
  img <- make_test_image()
  feats <- extract_shot_scale_features(img)
  expect_true(feats[["face_coverage"]] >= 0)
  expect_true(feats[["face_coverage"]] <= 1)
})

test_that("edge_density is in 0..1", {
  img <- make_test_image()
  feats <- extract_shot_scale_features(img)
  expect_true(feats[["edge_density"]] >= 0)
  expect_true(feats[["edge_density"]] <= 1)
})

test_that("upper_mass_ratio is in 0..1", {
  img <- make_test_image()
  feats <- extract_shot_scale_features(img)
  expect_true(feats[["upper_mass_ratio"]] >= 0)
  expect_true(feats[["upper_mass_ratio"]] <= 1)
})

test_that("salience bounding box features are sane", {
  img <- make_test_image()
  feats <- extract_shot_scale_features(img)
  expect_true(feats[["salience_bbox_width"]] >= 0 && feats[["salience_bbox_width"]] <= 1)
  expect_true(feats[["salience_bbox_height"]] >= 0 && feats[["salience_bbox_height"]] <= 1)
  expect_true(feats[["salience_bbox_area"]] >= 0 && feats[["salience_bbox_area"]] <= 1)
  expect_true(feats[["salience_bbox_aspect"]] >= 0)
})

test_that("tiny image does not error", {
  img <- make_test_image(w = 4, h = 4)
  expect_no_error(extract_shot_scale_features(img))
})

test_that("solid-color image produces sane features", {
  img <- make_test_image(col = "#000000")
  feats <- extract_shot_scale_features(img)
  expect_true(all(is.finite(feats) | is.na(feats)))
  expect_equal(feats[["edge_density"]], 0)
})

test_that("gradient image produces non-zero edge features", {
  img <- make_gradient_image()
  feats <- extract_shot_scale_features(img)
  expect_true(feats[["edge_density"]] > 0)
  expect_true(feats[["laplacian_variance"]] > 0)
})

test_that("color_entropy is non-negative", {
  img <- make_test_image()
  feats <- extract_shot_scale_features(img)
  expect_true(is.na(feats[["color_entropy"]]) || feats[["color_entropy"]] >= 0)
})

test_that("laplacian_per_edge is non-negative", {
  img <- make_test_image()
  feats <- extract_shot_scale_features(img)
  expect_true(is.na(feats[["laplacian_per_edge"]]) || feats[["laplacian_per_edge"]] >= 0)
})

# ── frame_classify_scale() smoke tests ─────────────────────────────────────

model_available <- requireNamespace("ranger", quietly = TRUE) &&
  nzchar(system.file("models", "shot_scale_classical.rds", package = "tidylens"))

test_that("frame_classify_scale preserves row count", {
  skip_if_not(model_available, "ranger or model not available")
  paths <- write_test_images(list(
    make_test_image(col = "#111111"),
    make_test_image(col = "#222222"),
    make_test_image(col = "#333333")
  ))
  imgs <- tidylens:::load_frame_files(paths)
  result <- frame_classify_scale(imgs)
  expect_equal(nrow(result), 3L)
})

test_that("frame_classify_scale adds shot_scale and shot_scale_confidence columns", {
  skip_if_not(model_available, "ranger or model not available")
  paths <- write_test_images(list(
    make_test_image(col = "#111111"),
    make_test_image(col = "#222222")
  ))
  imgs <- tidylens:::load_frame_files(paths)
  result <- frame_classify_scale(imgs)
  expect_true("shot_scale" %in% names(result))
  expect_true("shot_scale_confidence" %in% names(result))
})

test_that("frame_classify_scale shot_scale values are valid categories", {
  skip_if_not(model_available, "ranger or model not available")
  paths <- write_test_images(list(
    make_test_image(col = "#111111"),
    make_test_image(col = "#222222")
  ))
  imgs <- tidylens:::load_frame_files(paths)
  result <- frame_classify_scale(imgs)
  valid <- c("Close", "Medium", "Long", NA_character_)
  expect_true(all(result$shot_scale %in% valid))
})

test_that("frame_classify_scale confidence is 0..1 or NA", {
  skip_if_not(model_available, "ranger or model not available")
  paths <- write_test_images(list(
    make_test_image(col = "#111111"),
    make_test_image(col = "#222222")
  ))
  imgs <- tidylens:::load_frame_files(paths)
  result <- frame_classify_scale(imgs)
  ok <- is.na(result$shot_scale_confidence) |
    (result$shot_scale_confidence >= 0 & result$shot_scale_confidence <= 1)
  expect_true(all(ok))
})

test_that("frame_classify_scale errors on non-tl_frames input", {
  skip_if_not(model_available, "ranger or model not available")
  expect_error(frame_classify_scale(mtcars), "tl_frames")
})

# ── Model compatibility: feature names match ──────────────────────────────

test_that("extracted feature names match model training features", {
  skip_if_not(model_available, "ranger or model not available")
  model_path <- system.file("models", "shot_scale_classical.rds", package = "tidylens")
  bundle <- readRDS(model_path)
  model_feats <- bundle$model$forest$independent.variable.names

  img <- make_test_image()
  feats <- extract_shot_scale_features(img)
  feat_names <- names(feats)

  missing <- setdiff(model_feats, feat_names)
  expect_equal(length(missing), 0L,
    info = sprintf("Features missing from extractor: %s", paste(missing, collapse = ", ")))
})
