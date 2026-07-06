# Tidylens Naming Convention

Tidylens v3.x uses a film-first, classical-only vocabulary.

## Prefixes

| Prefix | Meaning | Examples |
|--------|---------|----------|
| `frame_` | Per-frame operations and video-to-frame extraction | `frame_extract_shots()`, `frame_extract_brightness()`, `frame_classify_scale()` |
| `video_` | Video file download/probe utilities | `video_download()`, `video_get_info()` |

Unprefixed helpers are limited to object checks and sequence operations: `is_tl_frames()` and `detect_shot_changes()`.

## Core Data Contract

All public analysis functions operate on a `tl_frames` tibble. A row is one extracted frame or representative shot frame with at least `id` and `local_path`; shot rows also include timing columns such as `start_time`, `end_time`, and `duration`.

The internal file loader is not part of the public API in v3.x. Users should start from video files with `frame_extract_*()`.

## Public Families

```r
# Video to frames/shots
frame_extract_by_seconds()
frame_extract_evenly()
frame_extract_keyframes()
frame_extract_shots()

# Frame features
frame_extract_brightness()
frame_extract_colourfulness()
frame_extract_warmth()
frame_extract_color_histogram()
frame_detect_faces()
frame_classify_scale()
frame_classify_angle()
```

## v3.x Removals

Tidylens is a classical, local, no-CNN film-frame analysis toolkit. The public workflow starts from video files rather than still-image collections.

The remaining vector representation is `frame_extract_color_histogram()`.

## v3.1 Removals

The film-level summary layer (`film_compute_asl()`, `film_compute_rhythm()`, `film_summarize_scales()`) and the standalone `frame_extract_shot_frames()` helper were removed. The `film_` prefix is retired. `frame_extract_shots(position=)` accepts `"first"`, `"middle"`, or `"last"`.