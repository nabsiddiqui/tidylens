# Tinylens Output Reference

A complete guide to all columns and metrics produced by Tinylens functions.

---

## Table of Contents

- [Core Image Metadata](#core-image-metadata)
- [Video/Shot Columns](#videoshot-columns)
- [Shot Scale Classification](#shot-scale-classification)
- [Color Features](#color-features)
- [Fluency/Composition Features](#fluencycomposition-features)
- [Detection Features](#detection-features)
- [Audio Features](#audio-features)
- [Embedding Features](#embedding-features)
- [LLM Features](#llm-features)
- [Film Metrics (Aggregate)](#film-metrics-aggregate)

---

## Core Image Metadata

Columns added by `load_images()` or `video_extract_frames()`:

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `id` | character | Unique identifier (filename without extension) | "frame_000001" |
| `source` | character | Original path or URL | "/path/to/image.jpg" |
| `local_path` | character | Full local file path | "/tmp/frame_000001.jpg" |
| `width` | integer | Image width in pixels | 1920 |
| `height` | integer | Image height in pixels | 1080 |
| `format` | character | File format | "jpeg", "png" |
| `aspect_ratio` | numeric | Width / Height | 1.78 (16:9) |
| `file_size_bytes` | integer | File size in bytes | 125000 |

---

## Video/Shot Columns

Columns added by `video_extract_shots()`:

| Column | Type | Description | Range/Units |
|--------|------|-------------|-------------|
| `video_source` | character | Path to source video file | File path |
| `shot_id` | integer | Sequential shot number | 1, 2, 3, ... |
| `start_time` | numeric | Shot start in seconds | 0.0+ |
| `end_time` | numeric | Shot end in seconds | 0.0+ |
| `duration` | numeric | Shot length in seconds | 0.5 - 300+ |
| `start_frame` | integer | First frame number | 1+ |
| `end_frame` | integer | Last frame number | 1+ |
| `n_frames` | integer | Number of frames in shot | 1+ |

---

## Camera Angle Classification

Columns added by `film_classify_angle()`:

| Column | Type | Description |
|--------|------|-------------|
| `camera_angle` | character | Detected camera angle type (see table below) |
| `horizon_position` | numeric | Estimated horizon position (0=bottom, 1=top) |
| `tilt_angle` | numeric | Camera tilt in degrees (0=level, positive=tilted right) |

### Camera Angle Types (6 types)

| Angle | Description | How It's Detected |
|-------|-------------|-------------------|
| **eye_level** | Neutral, straight-on shot | Horizon at frame center (0.4-0.6) |
| **high_angle** | Looking down at subject | Horizon high (0.6-0.75) |
| **low_angle** | Looking up at subject | Horizon low (0.25-0.4) |
| **birds_eye** | Directly overhead (top-down) | Horizon very high (>0.75) or absent |
| **worms_eye** | Directly from below (ground up) | Horizon very low (<0.25) |
| **dutch_angle** | Tilted camera (canted frame) | Tilt >15° and <75° |
| **unknown** | Couldn't determine | Insufficient edge data |

---

## Shot Scale Classification

Columns added by `film_classify_scale()` or `video_extract_shots()`:

| Column | Type | Description |
|--------|------|-------------|
| `shot_scale` | character | Shot scale code (see table below) |
| `shot_scale_name` | character | Full name of shot scale |
| `subject_coverage` | numeric | Fraction of frame covered by subject (0-1) |

### Shot Scale Types (StudioBinder Standard - 9 scales)

Based on [StudioBinder's Ultimate Guide to Camera Shots](https://www.studiobinder.com/blog/ultimate-guide-to-camera-shots/).

| Code | Name | What's in Frame | Coverage |
|------|------|-----------------|----------|
| **ECU** | Extreme Close-Up | Eyes, mouth, or small detail fills frame | >55% |
| **CU** | Close-Up | Face fills the frame | 40-55% |
| **MCU** | Medium Close-Up | Head and shoulders (chest up) | 30-40% |
| **MS** | Medium Shot | Waist up | 22-30% |
| **CS** | Cowboy Shot | Mid-thigh up (named for Western holster framing) | 15-22% |
| **MFS** | Medium Full Shot | Knees up (also called Medium Wide Shot) | 10-15% |
| **FS** | Full Shot | Full body, head to toe with minimal space | 5-10% |
| **WS** | Wide Shot | Full body with surrounding environment | 2-5% |
| **EWS** | Extreme Wide Shot | Small figure in vast landscape | <2% |

*Note: "Establishing Shot" is a narrative type (first shot of a scene showing location) rather than a coverage-based classification, so it's not included in automated detection.*

---

## Color Features

### `extract_brightness()`
| Column | Type | Range | Description |
|--------|------|-------|-------------|
| `brightness` | numeric | 0-1 | Average luminance (0=black, 1=white) |
| `brightness_std` | numeric | 0-0.5 | Standard deviation of brightness |

### `extract_color_mean()`
| Column | Type | Range | Description |
|--------|------|-------|-------------|
| `mean_r` | integer | 0-255 | Mean red channel value |
| `mean_g` | integer | 0-255 | Mean green channel value |
| `mean_b` | integer | 0-255 | Mean blue channel value |
| `mean_hex` | character | #RRGGBB | Hex color code |

### `extract_color_median()`
| Column | Type | Range | Description |
|--------|------|-------|-------------|
| `median_r` | integer | 0-255 | Median red channel value |
| `median_g` | integer | 0-255 | Median green channel value |
| `median_b` | integer | 0-255 | Median blue channel value |
| `median_hex` | character | #RRGGBB | Hex color code |

### `extract_color_mode()`
| Column | Type | Range | Description |
|--------|------|-------|-------------|
| `mode_r` | integer | 0-255 | Most frequent red value |
| `mode_g` | integer | 0-255 | Most frequent green value |
| `mode_b` | integer | 0-255 | Most frequent blue value |
| `mode_hex` | character | #RRGGBB | Hex color code |
| `mode_frequency` | numeric | 0-1 | How often this color appears |

### `extract_saturation()`
| Column | Type | Range | Description |
|--------|------|-------|-------------|
| `saturation_mean` | numeric | 0-1 | Average color saturation |
| `saturation_median` | numeric | 0-1 | Median saturation |
| `saturation_std` | numeric | 0-0.5 | Saturation variation |

### `extract_colourfulness()`
| Column | Type | Range | Description |
|--------|------|-------|-------------|
| `colourfulness` | numeric | 0-200+ | Hasler & Süsstrunk M3 metric. <15 = grayscale, 15-33 = neutral, 33-45 = colorful, 45-59 = vivid, >59 = very vivid |

### `extract_warmth()`
| Column | Type | Range | Description |
|--------|------|-------|-------------|
| `warmth` | numeric | -1 to +1 | Color temperature. Negative = cool/blue, Positive = warm/orange |
| `tint` | numeric | -1 to +1 | Green-magenta balance. Negative = green, Positive = magenta |

### `extract_dominant_color()`
| Column | Type | Range | Description |
|--------|------|-------|-------------|
| `dominant_color_r` | integer | 0-255 | Dominant color red |
| `dominant_color_g` | integer | 0-255 | Dominant color green |
| `dominant_color_b` | integer | 0-255 | Dominant color blue |
| `dominant_color_hex` | character | #RRGGBB | Hex color code |
| `dominant_color_proportion` | numeric | 0-1 | Fraction of pixels with this color |

### `extract_hue_histogram()`
| Column | Type | Range | Description |
|--------|------|-------|-------------|
| `dominant_hue` | integer | 0-360 | Most common hue angle in degrees |
| `dominant_hue_name` | character | - | Color name (red, orange, yellow, green, cyan, blue, purple, magenta) |
| `hue_entropy` | numeric | 0-4 | Hue diversity (0 = single color, 4 = many colors) |
| `hue_concentration` | numeric | 0-1 | How concentrated hues are (1 = all same hue) |

### `extract_color_variance()`
| Column | Type | Range | Description |
|--------|------|-------|-------------|
| `color_variance` | numeric | 0-1 | Overall color variation |
| `r_range`, `g_range`, `b_range` | integer | 0-255 | Range of each channel |

### `extract_color_moments()`
| Column | Type | Range | Description |
|--------|------|-------|-------------|
| `cm_r_mean`, `cm_g_mean`, `cm_b_mean` | numeric | 0-255 | Mean of each channel |
| `cm_r_std`, `cm_g_std`, `cm_b_std` | numeric | 0-128 | Standard deviation |
| `cm_r_skew`, `cm_g_skew`, `cm_b_skew` | numeric | -3 to +3 | Skewness (asymmetry) |

---

## Fluency/Composition Features

### `extract_fluency_metrics()`
| Column | Type | Range | Description |
|--------|------|-------|-------------|
| `simplicity` | numeric | 0-1 | Inverse of complexity. 1 = very simple |
| `symmetry_h` | numeric | 0-1 | Horizontal symmetry. 1 = perfectly symmetric |
| `symmetry_v` | numeric | 0-1 | Vertical symmetry. 1 = perfectly symmetric |
| `balance` | numeric | 0-1 | Visual weight distribution. 1 = perfectly balanced |

### `extract_rule_of_thirds()`
| Column | Type | Range | Description |
|--------|------|-------|-------------|
| `rule_of_thirds` | numeric | 0-1 | How well key elements align with thirds lines |

### `extract_visual_complexity()`
| Column | Type | Range | Description |
|--------|------|-------|-------------|
| `visual_complexity` | numeric | 0-1 | Combined complexity score |

### `extract_center_bias()`
| Column | Type | Range | Description |
|--------|------|-------|-------------|
| `center_bias` | numeric | -1 to +1 | Positive = center-weighted, Negative = peripheral |
| `center_brightness` | numeric | 0-1 | Average brightness in center region |
| `peripheral_brightness` | numeric | 0-1 | Average brightness in outer regions |

---

## Detection Features

### `detect_skin_tones()`
| Column | Type | Range | Description |
|--------|------|-------|-------------|
| `skin_tone_prop` | numeric | 0-1 | Proportion of pixels with skin-like colors |

### `detect_faces()` (requires image.libfacedetection)
| Column | Type | Description |
|--------|------|-------------|
| `face_count` | integer | Number of detected faces |
| `face_areas` | list | Area of each face in pixels |
| `face_positions` | list | Bounding box coordinates |

---

## Audio Features

### `extract_audio_features()`
| Column | Type | Range | Description |
|--------|------|-------|-------------|
| `audio_rms` | numeric | 0-1 | **Root Mean Square loudness**. Higher = louder. Formula: $\sqrt{\frac{1}{N}\sum x_i^2}$ |
| `audio_peak` | numeric | 0-1 | **Peak amplitude**. Loudest moment in segment |
| `audio_zcr` | numeric | 0-0.5 | **Zero Crossing Rate**. How often signal crosses zero. High = noisy/percussive |
| `audio_silence_ratio` | numeric | 0-1 | **Silence ratio**. Proportion of near-silent samples |
| `audio_low_freq_energy` | numeric | 0-1 | **Bass content**. Energy below 500 Hz. High = deep/booming sounds |
| `audio_high_freq_energy` | numeric | 0-1 | **Treble content**. Energy above 4000 Hz. High = bright/sibilant sounds |
| `audio_spectral_centroid` | numeric | 0-22050 | **Spectral brightness** in Hz. Low (~200) = muffled, High (~2000+) = bright |

### `extract_audio_rms()` (lightweight version)
| Column | Type | Range | Description |
|--------|------|-------|-------------|
| `audio_rms` | numeric | 0-1 | Root Mean Square loudness |

---

## Embedding Features

### `extract_embeddings()` (requires torch)
| Column | Type | Description |
|--------|------|-------------|
| `embedding` | list | Neural network feature vector (512-2048 dimensions) |

### `extract_color_histogram()`
| Column | Type | Description |
|--------|------|-------------|
| `color_histogram` | list | Color distribution vector (typically 256 or 768 dimensions) |

---

## LLM Features

### `llm_describe()`
| Column | Type | Description |
|--------|------|-------------|
| `llm_description` | character | Natural language description of image content |

### `llm_classify()`
| Column | Type | Description |
|--------|------|-------------|
| `llm_category` | character | Assigned category from provided options |

### `llm_sentiment()`
| Column | Type | Description |
|--------|------|-------------|
| `llm_mood` | character | Detected mood (e.g., "tense", "peaceful", "exciting") |
| `llm_sentiment` | character | Overall sentiment (positive/negative/neutral) |

### `llm_recognize()`
| Column | Type | Description |
|--------|------|-------------|
| `llm_objects` | character | List of recognized objects in image |

---

## Film Metrics (Aggregate)

These functions return **summary tibbles**, not per-image columns.

### `film_compute_asl()`
| Column | Type | Description |
|--------|------|-------------|
| `asl` | numeric | Average Shot Length in seconds |
| `asl_median` | numeric | Median shot length |
| `asl_std` | numeric | Standard deviation of shot lengths |
| `shot_count` | integer | Total number of shots |
| `total_duration` | numeric | Total film duration in seconds |
| `shortest_shot` | numeric | Duration of shortest shot |
| `longest_shot` | numeric | Duration of longest shot |
| `shots_per_minute` | numeric | Cutting rate |

### `film_compute_rhythm()`
| Column | Type | Description |
|--------|------|-------------|
| `rhythm_entropy` | numeric | Randomness of shot lengths (0-1) |
| `rhythm_regularity` | numeric | Consistency of shot lengths (0-1) |
| `rhythm_acceleration` | numeric | Is cutting speeding up (+) or slowing (-) |
| `rhythm_range_ratio` | numeric | Ratio of longest to shortest shot |
| `rhythm_quartile_25` | numeric | 25th percentile shot duration |
| `rhythm_quartile_75` | numeric | 75th percentile shot duration |

### `film_summarize_scales()`
| Column | Type | Description |
|--------|------|-------------|
| `shot_scale` | character | Shot scale code |
| `count` | integer | Number of shots at this scale |
| `proportion` | numeric | Fraction of total shots |
| `pct` | numeric | Percentage of total shots |

---

## Recommended LLM Models

For image captioning with Ollama, we recommend:

| Model | Size | Quality | Speed | Use Case |
|-------|------|---------|-------|----------|
| **qwen2.5vl:7b** ⭐ | 4.5 GB | Excellent | Medium | **Default** - Best balance of quality/speed |
| **qwen3-vl:7b** | 5 GB | Best | Medium | Latest Qwen vision model |
| **llama3.2-vision:11b** | 8 GB | Very Good | Slow | Meta's reasoning model |
| **llava:7b** | 4.7 GB | Good | Fast | Lightweight, quick results |
| **moondream** | 1.5 GB | Basic | Very Fast | Testing/prototyping |

Install with: `ollama pull qwen2.5vl:7b`
