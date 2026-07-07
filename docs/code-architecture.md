# Code Architecture

Tidylens is an R package for classical film-frame analysis. The package turns video files into a `tl_frames` tibble, adds inspectable visual features, and detects shots and shot scales from frame rows.

## Principles

1. Film-first public API: users start from `video_*()` and `frame_extract_*()`.
2. One row per frame or representative shot frame.
3. Classical, inspectable algorithms only: no CNNs, no cloud APIs, no opaque model services.
4. Tidy outputs: analysis functions add columns and return tibbles.
5. Optional dependencies stay optional: `av` for video extraction, `image.libfacedetection` for face detection, `ranger` for the packaged shot-scale model.

## Main Files

| File | Purpose |
|------|---------|
| `R/video.R` | Video probing, frame extraction, shot detection, shot-scale classification |
| `R/tl_frames.R` | Internal constructor and validator for `tl_frames` |
| `R/color.R` | Color feature extractors |
| `R/fluency.R` | Composition and fluency feature extractors |
| `R/texture.R` | GLCM, sharpness, contrast, and LBP texture feature extractors |
| `R/detection.R` | Face detection |
| `R/vector_representations.R` | Color-histogram vector representation |
| `R/shot_scale_features.R` | Internal engineered features for shot scale |
| `R/utils.R` | Shared helpers |

## Pipeline

```r
shots <- video_extract_shots("film.mp4") |>
  frame_classify_scale() |>
  frame_extract_colourfulness() |>
  frame_extract_fluency_metrics()
```

## Data Flow

1. `video_extract_*()` writes frame files and returns `tl_frames`.
2. Per-frame functions validate `tl_frames`, read `local_path`, compute features, and bind result columns.
3. Shot-level extractors add timing columns (`start_time`, `end_time`, `duration`) and a representative frame per shot.

## Removed In v3.x

Non-visual modules are out of scope to keep the package focused on classical visual film analysis. The internal file loader remains only as infrastructure for frame extraction.
