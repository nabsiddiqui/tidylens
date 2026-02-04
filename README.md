# tinylens <img src="logo.png" align="right" height="139" alt="tinylens logo" />

<!-- badges: start -->
[![R-CMD-check](https://img.shields.io/badge/R--CMD--check-passing-brightgreen)](https://github.com/nabsiddiqui/tinylens)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
<!-- badges: end -->

**tinylens** is an R package for image-first analysis targeting digital humanities and film studies. It provides a tidy, pipeable API for analyzing visual content without requiring Python dependencies.

## Features

- 📹 **Video Processing**: Shot detection, frame extraction, pacing analysis
- 🎨 **Color Analysis**: 11 functions for brightness, saturation, warmth, dominant colors
- 📐 **Composition**: Rule of thirds, visual complexity, center bias
- 🎬 **Film Metrics**: Shot scale classification (9 types), camera angles (6 types), ASL
- 🤖 **Local LLM**: Ollama integration for image descriptions (no cloud APIs)
- 🔊 **Audio**: RMS, ZCR, spectral analysis per shot

All functions return **tidy tibbles** with one row per image.

## Installation

```r
# Install from GitHub
devtools::install_github("nabsiddiqui/tinylens")
```

## Quick Start

```r
library(tinylens)

# Extract shots from a video
shots <- video_extract_shots("my_film.mp4")

# Add color and composition features
results <- shots |>
  extract_brightness() |>
  extract_colourfulness() |>
  extract_warmth() |>
  extract_rule_of_thirds() |>
  film_classify_angle()

# Compute film metrics
film_compute_asl(results)        # Average shot length
film_summarize_scales(results)   # Shot scale distribution
```

## Core Functions

### Video Processing
| Function | Description |
|----------|-------------|
| `video_extract_shots()` | Detect shots with timing and scale classification |
| `video_extract_frames()` | Extract all frames at specified FPS |
| `video_sample_frames()` | Sample N frames evenly |
| `video_get_info()` | Video metadata (duration, fps, resolution) |

### Color Analysis (11 functions)
| Function | Description |
|----------|-------------|
| `extract_brightness()` | Mean brightness with standard deviation |
| `extract_colourfulness()` | Hasler-Süsstrunk colourfulness metric |
| `extract_color_mean()` | Mean RGB values |
| `extract_dominant_color()` | K-means dominant color |
| `extract_warmth()` | Warm/cool tone with tint |
| ... | And 6 more |

### Film Metrics (5 functions)
| Function | Description |
|----------|-------------|
| `film_classify_scale()` | 9 shot types (ECU, CU, MCU, MS, CS, MFS, FS, WS, EWS) |
| `film_classify_angle()` | 6 camera angles (eye_level, high, low, birds_eye, worms_eye, dutch) |
| `film_compute_asl()` | Average Shot Length with median |
| `film_compute_rhythm()` | Editing rhythm metrics |
| `film_summarize_scales()` | Shot scale distribution |

### Composition (4 functions)
| Function | Description |
|----------|-------------|
| `extract_fluency_metrics()` | Processing fluency score |
| `extract_rule_of_thirds()` | Composition adherence |
| `extract_visual_complexity()` | Edge-based complexity |
| `extract_center_bias()` | Center vs periphery salience |

### LLM Vision (requires Ollama)
| Function | Description |
|----------|-------------|
| `llm_describe()` | Natural language image descriptions |
| `llm_classify()` | Category classification |
| `llm_sentiment()` | Mood analysis |
| `llm_recognize()` | Object recognition |

## Output Example

```r
# A tibble: 15 × 62
   id           shot_id duration shot_scale brightness colourfulness warmth ...
   <chr>          <int>    <dbl> <chr>           <dbl>         <dbl>  <dbl> ...
 1 frame_000001       1     12.5 MS              0.456          34.2  0.123 ...
 2 frame_000026       2      8.0 CU              0.512          28.9  0.089 ...
 3 frame_000042       3     15.3 WS              0.389          45.1  0.234 ...
```

## Dependencies

### Required
magick, tibble, dplyr, purrr, cli, rlang, fs, tools

### Optional
| Package | For |
|---------|-----|
| av | Video processing |
| tuneR | Audio analysis |
| torch/torchvision | Neural embeddings |
| image.libfacedetection | Face detection |
| httr2, base64enc, jsonlite | LLM functions |

## Documentation

See the [Getting Started vignette](vignettes/getting-started.Rmd) for detailed examples.

## License

MIT © Nabeel Siddiqui

## Citation

If you use tinylens in academic research, please cite:

```
Siddiqui, N. (2026). tinylens: Tidy Image Analysis for Digital Humanities.
R package. https://github.com/nabsiddiqui/tinylens
```
