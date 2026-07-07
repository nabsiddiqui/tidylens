# Tests for frame extraction methods: video_extract_keyframes (new),
# video_extract_frames_by_seconds `every` argument, and video_extract_shots
# position validation.
library(tidylens)
suppressPackageStartupMessages({library(magick); library(av)})

# Helper: build a tiny mp4 video at a given fps.
write_test_video <- function(n = 12, fps = 6, dir = tempdir(), prefix = "ft") {
  colors <- rainbow(n)
  paths <- file.path(dir, sprintf("%s_src_%04d.png", prefix, seq_len(n)))
  for (i in seq_len(n)) {
    img <- image_graph(width = 80, height = 60)
    par(mar = rep(0, 4)); plot.new()
    rect(0, 0, 1, 1, col = colors[i], border = NA)
    text(0.5, 0.5, sprintf("f%02d", i), col = "white", cex = 1.2)
    dev.off()
    image_write(img, paths[i])
  }
  vid <- file.path(dir, sprintf("%s_video.mp4", prefix))
  av_encode_video(paths, output = vid, framerate = fps, verbose = FALSE)
  vid
}

# ── video_extract_keyframes() ──────────────────────────────────────────────

test_that("video_extract_keyframes returns a tl_frames tibble", {
  skip_if_not_installed("av")
  vid <- write_test_video(prefix = "kf")
  kf <- video_extract_keyframes(vid, output_dir = tempdir(), prefix = "kfout")
  expect_s3_class(kf, "tl_frames")
  expect_true("video_source" %in% names(kf))
  # At least one keyframe should be present (encoders always emit >=1 I-frame)
  expect_gt(nrow(kf), 0)
})

test_that("video_extract_keyframes errors on missing file", {
  expect_error(video_extract_keyframes("nonexistent.mp4"), "not found")
})

# ── video_extract_frames_by_seconds() `every` argument ───────────────────────────

test_that("video_extract_frames_by_seconds every=1 extracts approximately one fps", {
  skip_if_not_installed("av")
  vid <- write_test_video(n = 12, fps = 6, prefix = "bs1")
  fr <- video_extract_frames_by_seconds(vid, every = 1, output_dir = tempdir(),
                                  prefix = "bs1out")
  expect_s3_class(fr, "tl_frames")
  # 12 frames at 6 fps = 2s video; every=1s should yield ~2 frames
  expect_gte(nrow(fr), 1)
  expect_lte(nrow(fr), 4)
})

test_that("video_extract_frames_by_seconds every=2 extracts fewer frames than every=1", {
  skip_if_not_installed("av")
  vid <- write_test_video(n = 24, fps = 6, prefix = "bs2")
  fr1 <- video_extract_frames_by_seconds(vid, every = 1, output_dir = tempdir(),
                                   prefix = "bs2a")
  fr2 <- video_extract_frames_by_seconds(vid, every = 2, output_dir = tempdir(),
                                   prefix = "bs2b")
  expect_gte(nrow(fr1), nrow(fr2))
})

test_that("video_extract_frames_by_seconds rejects non-positive every", {
  skip_if_not_installed("av")
  vid <- write_test_video(prefix = "bs3")
  expect_error(video_extract_frames_by_seconds(vid, every = 0), "positive")
  expect_error(video_extract_frames_by_seconds(vid, every = -1), "positive")
})

test_that("video_extract_frames_by_seconds rejects both every and fps", {
  skip_if_not_installed("av")
  vid <- write_test_video(prefix = "bs4")
  expect_error(video_extract_frames_by_seconds(vid, every = 1, fps = 2), "both")
})

# ── video_extract_shots(position=...) ──────────────────────────────────────

test_that("video_extract_shots rejects a bad position", {
  skip_if_not_installed("av")
  vid <- write_test_video(prefix = "pos")
  expect_error(video_extract_shots(vid, position = "bad"),
               "position")
})

test_that("video_extract_shots position='middle' returns one row per shot", {
  skip_if_not_installed("av")
  vid <- write_test_video(n = 12, fps = 6, prefix = "pmid")
  shots <- video_extract_shots(vid, fps = 6, position = "middle",
                               output_dir = tempdir())
  expect_s3_class(shots, "tl_frames")
  expect_gt(nrow(shots), 0)
  expect_true("shot_id" %in% names(shots))
})