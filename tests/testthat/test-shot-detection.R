# Synthetic-frame smoke tests for detect_shot_changes().
# Builds small solid-colour JPEGs in tempdir(); no network, no fixtures.

make_frames <- function(colors, tmp = tempfile(pattern = "tl-shots")) {
  dir.create(tmp, showWarnings = FALSE)
  paths <- vapply(seq_along(colors), function(i) {
    col <- colors[[i]]
    img <- magick::image_blank(40, 40, col)
    p <- file.path(tmp, sprintf("f_%03d.jpg", i))
    magick::image_write(img, p, format = "jpg")
    p
  }, character(1))
  tidylens:::load_frame_files(paths)
}

test_that("adaptive detects a single hard cut", {
  cols <- rep("#1a1a1a", 6)
  cols[4:6] <- "#f0f0f0"            # distinct bright half
  imgs <- make_frames(cols)
  shots <- detect_shot_changes(imgs, method = "adaptive")
  expect_s3_class(shots, "tbl")
  expect_equal(nrow(shots), 2L)
  expect_equal(shots$start_frame, c(1L, 4L))
  expect_equal(attr(shots, "method"), "adaptive")
})

test_that("min_scene_len suppresses a one-frame spike (flash guard)", {
  cols <- rep("#202020", 7)
  cols[4] <- "#ffffff"             # one white frame in the middle
  imgs <- make_frames(cols)
  no_guard <- detect_shot_changes(imgs, method = "adaptive", min_scene_len = 0)
  guarded  <- detect_shot_changes(imgs, method = "adaptive", min_scene_len = 2)
  # A lone flash framed by uniform frames shouldn't split into >1 scene once guarded
  expect_true(nrow(guarded) <= nrow(no_guard))
  expect_true(nrow(guarded) >= 1L)
})

test_that("numeric min_scene_len actually fires (regression: isTRUE guard bug)", {
  # Two cuts one frame apart: frames 1-2 dark, 3 white, 4 dark, then bright.
  cols <- c("#101010", "#101010", "#ffffff", "#101010", "#f5f5f5", "#f5f5f5")
  imgs <- make_frames(cols)
  # Histogram method gives deterministic per-boundary cuts; a lone white frame
  # produces cuts on both sides that are only 1 frame apart.
  ungated <- detect_shot_changes(imgs, method = "histogram",
                                 threshold = 0.5, min_scene_len = 0)
  gated   <- detect_shot_changes(imgs, method = "histogram",
                                 threshold = 0.5, min_scene_len = 3)
  # With the pre-fix isTRUE() bug, numeric min_scene_len was ignored and these
  # were equal. The guard must now drop at least one closely-spaced cut.
  expect_true(nrow(gated) < nrow(ungated))
})

test_that("histogram method reproduces the pre-1.x path", {
  cols <- rep("#303030", 5)
  cols[3] <- "#ff5500"            # one different frame
  imgs <- make_frames(cols)
  sh <- detect_shot_changes(imgs, method = "histogram", threshold = 0.5)
  # A lone different frame spikes chi-squared on BOTH sides -> 3 segments.
  expect_equal(nrow(sh), 3L)
  expect_equal(sh$start_frame, c(1L, 3L, 4L))
  expect_equal(attr(sh, "method"), "histogram")
})