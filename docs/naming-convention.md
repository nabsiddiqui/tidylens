# Tidylens Naming Convention

Tidylens v3.x uses a film-first, classical-only vocabulary.

## Prefixes

| Prefix | Meaning | Examples |
|--------|---------|----------|
| `frame_` | Per-frame operations on a `tl_frames` tibble | `frame_extract_brightness()`, `frame_extract_glcm()`, `frame_classify_scale()` |
| `video_` | Video file operations: download, probe, and video-to-frame extraction | `video_download()`, `video_get_info()`, `video_extract_shots()`, `video_extract_frames_by_seconds()` |

Unprefixed helpers are limited to object checks and sequence operations: `is_tl_frames()` and `detect_shot_changes()`.

The distinction is by **input type**: `video_*` functions take a video **file path**; `frame_*` functions take an already-extracted `tl_frames` tibble.

## Core Data Contract

All public analysis functions operate on a `tl_frames` tibble. A row is one extracted frame or representative shot frame with at least `id` and `local_path`; shot rows also include timing columns such as `start_time`, `end_time`, and `duration`.

The internal file loader is not part of the public API in v3.x. Users should start from video files with `video_extract_*()`.

## Public Families

```r
# Video to frames/shots
video_extract_frames_by_seconds()
video_extract_frames_evenly()
video_extract_keyframes()
video_extract_shots()

# Frame features
frame_extract_brightness()
frame_extract_colourfulness()
frame_extract_warmth()
frame_extract_color_histogram()
frame_extract_glcm()
frame_extract_sharpness()
frame_extract_contrast()
frame_extract_lbp_histogram()
frame_detect_faces()
frame_classify_scale()
```

## v3.x Removals

Tidylens is a classical, local, no-CNN film-frame analysis toolkit. The public workflow starts from video files rather than still-image collections.

Vector representations are `frame_extract_color_histogram()` and `frame_extract_lbp_histogram()`.

## v3.1 Removals

The film-level summary layer (`film_compute_asl()`, `film_compute_rhythm()`, `film_summarize_scales()`) and the standalone `frame_extract_shot_frames()` helper were removed. The `film_` prefix is retired. The shot extractor's `position=` argument accepts `"first"`, `"middle"`, or `"last"` (the extractor was named `frame_extract_shots()` at the time; renamed to `video_extract_shots()` in v3.3).

## v3.2 Removals

`frame_classify_angle()` (unvalidated camera-angle heuristic) was removed. Shot-scale classification was decoupled from the shot extractor: the `include_style` argument was dropped and the extractor now returns shots only. Use `frame_classify_scale()` on the result to add `shot_scale` and `shot_scale_confidence`. (The extractor was named `frame_extract_shots()` at the time; renamed to `video_extract_shots()` in v3.3.)

## v3.3 Renames

The four video-to-frame extraction functions moved from the `frame_` prefix to the `video_` prefix, because they take a video **file path** as input, not a `tl_frames` tibble. This aligns them with the existing `video_download()` / `video_get_info()` file utilities and reserves `frame_*` for operations on already-extracted frames.

| v3.2 name | v3.3 name |
|-----------|-----------|
| `frame_extract_by_seconds()` | `video_extract_frames_by_seconds()` |
| `frame_extract_evenly()` | `video_extract_frames_evenly()` |
| `frame_extract_keyframes()` | `video_extract_keyframes()` |
| `frame_extract_shots()` | `video_extract_shots()` |

The two generic frame extractors gained an explicit `frames` object word (`video_extract_frames_*`) for readability; `keyframes` and `shots` already name their object. Hard rename, no deprecated aliases. v3.3.0 is a breaking release.