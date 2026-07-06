<p align="center">
  <img src="man/figures/logo.png" alt="Tidylens Logo" width="350">
  <br>
  <em>Classical, tidy film-frame analysis in R</em>
</p>

<p align="center">
<a href="https://github.com/nabsiddiqui/tidylens"><img src="https://img.shields.io/badge/R--CMD--check-passing-brightgreen" alt="R-CMD-check"></a>
<a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
</p>

---

## Installation

```r
devtools::install_github("nabsiddiqui/tidylens")
```

Optional packages for video extraction and face detection:

```r
install.packages("av")
install.packages("image.libfacedetection", repos = "https://bnosac.r-universe.dev")
```

---

## What tidylens Does

Tidylens is a local-first toolkit for film analysis in R. It turns a video file into a `tl_frames` tibble, then lets you add classical, inspectable visual features and detect shots and shot scales.

The default path uses no CNNs, no cloud APIs, and no opaque model services.

```r
library(tidylens)

frames <- frame_extract_by_seconds("movie.mp4", every = 5)
#> tl_frames tibble: one row per extracted frame
```

---

## Video To Frames

```r
# Get video info
video_get_info("movie.mp4")

# Extract one frame every 5 seconds
frames <- frame_extract_by_seconds("movie.mp4", every = 5)

# Sample 100 evenly spaced frames
frames <- frame_extract_evenly("movie.mp4", n = 100)

# Pull encoder I-frames; fast, no shot detection
keyframes <- frame_extract_keyframes("movie.mp4")
```

`frame_extract_by_seconds()`, `frame_extract_evenly()`, and `frame_extract_keyframes()` produce frame rows. These are useful for color, composition, face, camera-angle, and vector-representation features.

---

## Shot Analysis

```r
shots <- frame_extract_shots("movie.mp4")
# columns include: shot_id, start_time, end_time, duration, shot_scale
```

`frame_extract_shots()` detects shot boundaries and returns one representative frame per shot. Shot rows carry `duration`, `start_time`, and `end_time` for downstream pacing analysis you do yourself.

Shot scale is classified with a classical Random Forest trained on engineered features: spectral residual saliency, face coverage, geometry, color, and texture. It runs locally on CPU and returns three broad classes: `Close`, `Medium`, and `Long`.

---

## Per-Frame Features

```r
frames <- frames |>
  frame_extract_brightness() |>
  frame_extract_colourfulness() |>
  frame_extract_warmth() |>
  frame_extract_dominant_color() |>
  frame_extract_fluency_metrics() |>
  frame_extract_color_histogram()
```

Selected feature families:

| Family | Examples |
|--------|----------|
| Color | `frame_extract_brightness()`, `frame_extract_warmth()`, `frame_extract_hue_histogram()` |
| Composition | `frame_extract_fluency_metrics()`, `frame_extract_rule_of_thirds()`, `frame_extract_center_bias()` |
| Detection | `frame_detect_faces()` |
| Classification | `frame_classify_scale()`, `frame_classify_angle()` |
| Vector representations | `frame_extract_color_histogram()` |

---

## Complete Pipeline

```r
library(tidylens)

shots <- frame_extract_shots("movie.mp4") |>
  frame_extract_colourfulness() |>
  frame_extract_warmth() |>
  frame_extract_fluency_metrics()
```

---

## Function Reference

### Video

`video_download()`, `video_get_info()`, `frame_extract_by_seconds()`, `frame_extract_evenly()`, `frame_extract_shots()`, `frame_extract_keyframes()`

### Frame Features

`frame_extract_brightness()`, `frame_extract_color_mean()`, `frame_extract_color_median()`, `frame_extract_color_mode()`, `frame_extract_saturation()`, `frame_extract_colourfulness()`, `frame_extract_warmth()`, `frame_extract_dominant_color()`, `frame_extract_color_variance()`, `frame_extract_color_moments()`, `frame_extract_hue_histogram()`, `frame_extract_fluency_metrics()`, `frame_extract_rule_of_thirds()`, `frame_extract_visual_complexity()`, `frame_extract_center_bias()`, `frame_extract_color_histogram()`

### Detection And Classification

`frame_detect_faces()`, `frame_classify_scale()`, `frame_classify_angle()`

### Utilities

`is_tl_frames()`

---

## License

MIT (c) Nabeel Siddiqui

## Citation

```text
Siddiqui, N. (2026). tidylens: Classical Film-Frame Analysis in R.
R package. https://github.com/nabsiddiqui/tidylens
```
