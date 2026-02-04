<p align="center">
  <img src="logo.png" alt="Tinylens Logo" width="350">
  <br>
  <em>Tidy image-first analysis for digital humanities and film studies</em>
</p>

<p align="center">
<a href="https://github.com/nabsiddiqui/tinylens"><img src="https://img.shields.io/badge/R--CMD--check-passing-brightgreen" alt="R-CMD-check"></a>
<a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
</p>

---

## Installation

```r
devtools::install_github("nabsiddiqui/tinylens")
```

**Optional dependencies** for enhanced features:
```r
install.packages("av")        # Video processing
install.packages("tuneR")     # Audio analysis
install.packages("image.libfacedetection", repos = "https://bnosac.r-universe.dev")  # Face detection
install.packages(c("torch", "torchvision"))  # Neural embeddings
```

---

## Quick Start

```r
library(tinylens)

# Load images from folder
images <- load_images("path/to/images/")

# Or from specific files
images <- load_images(c("image1.jpg", "image2.png"))

# Result: tl_images tibble with one row per image
images
#> ── Tinylens Image Collection ─────────────────────
#> 50 images
#> Formats: jpeg: 50
#> Dimensions: 1280-1280 x 536-536
```

---

## Color Analysis

```r
images <- images |>
  extract_brightness() |>        # brightness, brightness_std
  extract_colourfulness() |>     # colourfulness (Hasler & Süsstrunk M3)
  extract_warmth() |>            # warmth, tint
  extract_dominant_color() |>    # dominant_color_r/g/b, dominant_color_hex
  extract_hue_histogram()        # dominant_hue, hue_entropy
```

| Function | What It Measures | Example Use |
|----------|-----------------|-------------|
| `extract_brightness()` | How light/dark (0-255) | Night vs. day scenes |
| `extract_colourfulness()` | How vivid the colors | Wes Anderson vs. gritty drama |
| `extract_warmth()` | Orange vs. blue tones | Morning vs. night |
| `extract_dominant_color()` | Single most common color | Scene classification |

---

## Composition & Fluency

```r
images <- images |>
  extract_fluency_metrics() |>   # simplicity, symmetry_h, symmetry_v, balance
  extract_rule_of_thirds() |>    # rule_of_thirds score
  extract_center_bias()          # center_bias, center_brightness
```

| Function | What It Measures | Example Use |
|----------|-----------------|-------------|
| `extract_fluency_metrics()` | Symmetry and balance | Classical vs. dynamic composition |
| `extract_rule_of_thirds()` | Alignment with thirds | Professional photography score |
| `extract_center_bias()` | Subject centering | Portrait vs. landscape framing |

---

## Video Analysis

```r
library(av)

# Get video info
video_get_info("movie.mp4")
#> duration: 237s, fps: 24, resolution: 1280x536

# Extract frames at 1 fps
frames <- video_extract_frames("movie.mp4", fps = 1)

# Or sample 100 evenly-spaced frames
frames <- video_sample_frames("movie.mp4", n = 100)

# Analyze like regular images
frames <- frames |>
  extract_brightness() |>
  extract_colourfulness()
```

---

## Shot Detection

```r
# Automatically detect shot boundaries
shots <- video_extract_shots("movie.mp4", threshold = 0.4)

# Returns: shot_id, start_time, end_time, duration, shot_scale
```

### Shot Scale Classification

Tinylens classifies each shot into **9 standard cinematography scales**:

| Scale | Abbrev | What's in Frame |
|-------|--------|-----------------|
| Extreme Close-Up | ECU | Eyes, mouth, or detail |
| Close-Up | CU | Face fills frame |
| Medium Close-Up | MCU | Head and shoulders |
| Medium Shot | MS | Waist up |
| Cowboy Shot | CS | Mid-thigh up |
| Medium Full Shot | MFS | Knees up |
| Full Shot | FS | Full body |
| Wide Shot | WS | Full body + environment |
| Extreme Wide Shot | EWS | Small figure in landscape |

---

## Film Metrics

```r
library(dplyr)

# Pacing metrics
shots |> summarise(
  asl = mean(duration),              # Average shot length
  shot_count = n(),
  shots_per_minute = n() / (sum(duration) / 60)
)
```

**ASL Reference Values:**
| Style | Typical ASL |
|-------|-------------|
| Fast action (Mad Max) | 2-3 seconds |
| Modern blockbuster | 3-5 seconds |
| Classical Hollywood | 5-8 seconds |
| Art cinema | 10-30+ seconds |

---

## Audio Analysis

```r
# Add audio features to shots
shots <- extract_audio_features(shots, "movie.mp4")

# Columns: audio_rms, audio_peak, audio_zcr, audio_silence_ratio,
#          audio_low_freq_energy, audio_high_freq_energy, audio_spectral_centroid
```

| Column | What It Measures |
|--------|-----------------|
| `audio_rms` | Loudness (0-1) |
| `audio_peak` | Loudest moment |
| `audio_zcr` | Noisy/percussive content |
| `audio_low_freq_energy` | Bass content |
| `audio_high_freq_energy` | Treble content |

---

## Detection

```r
images <- detect_skin_tones(images)   # skin_tone_prop (0-1)
images <- detect_faces(images)        # face_count, face_areas (requires package)
```

---

## LLM Vision (Ollama)

```bash
# Setup
brew install ollama && ollama serve
ollama pull qwen2.5vl:7b
```

```r
llm_check_dependencies()

images <- llm_describe(images)    # Natural language descriptions
images <- llm_classify(images, categories = c("indoor", "outdoor"))
images <- llm_sentiment(images)   # Mood analysis
images <- llm_recognize(images)   # Object recognition
```

---

## Complete Pipeline

```r
library(tinylens)
library(dplyr)

# 1. Extract and analyze frames
frames <- video_extract_frames("movie.mp4", fps = 1) |>
  extract_brightness() |>
  extract_colourfulness() |>
  extract_warmth()

# 2. Detect shots with audio
shots <- video_extract_shots("movie.mp4") |>
  extract_audio_features("movie.mp4")

# 3. Compute metrics
pacing <- shots |> summarise(
  asl = mean(duration),
  shot_count = n(),
  avg_loudness = mean(audio_rms, na.rm = TRUE)
)

# 4. Export
write.csv(frames, "frame_analysis.csv")
write.csv(shots, "shot_data.csv")
```

---

## Function Reference

### Core I/O
`load_images()`, `is_tl_images()`

### Video (`video_*`)
`video_get_info()`, `video_extract_frames()`, `video_sample_frames()`, `video_extract_shots()`, `video_extract_shot_frames()`

### Film (`film_*`)
`film_classify_scale()` (per-image shot scale classification)

### Color (`extract_*`)
`extract_brightness()`, `extract_color_mean()`, `extract_color_median()`, `extract_color_mode()`, `extract_saturation()`, `extract_colourfulness()`, `extract_warmth()`, `extract_dominant_color()`, `extract_color_variance()`, `extract_color_moments()`, `extract_hue_histogram()`

### Composition
`extract_fluency_metrics()`, `extract_rule_of_thirds()`, `extract_visual_complexity()`, `extract_center_bias()`

### Detection
`detect_faces()`, `detect_skin_tones()`

### Audio
`extract_audio_features()`, `extract_audio_rms()`

### Embeddings
`extract_embeddings()`, `extract_color_histogram()`

### LLM Vision
`llm_describe()`, `llm_classify()`, `llm_sentiment()`, `llm_recognize()`, `llm_check_ollama()`, `llm_list_models()`, `llm_pull_model()`, `llm_check_dependencies()`

---

## License

MIT © Nabeel Siddiqui

## Citation

```
Siddiqui, N. (2026). tinylens: Tidy Image Analysis for Digital Humanities.
R package. https://github.com/nabsiddiqui/tinylens
```
