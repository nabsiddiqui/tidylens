# Tinylens Code Architecture

A comprehensive guide to understanding how tinylens works internally.

## Table of Contents
1. [Package Overview](#package-overview)
2. [Core Data Structure](#core-data-structure)
3. [Function Categories](#function-categories)
4. [Internal Architecture](#internal-architecture)
5. [Data Flow Patterns](#data-flow-patterns)
6. [Key Algorithms](#key-algorithms)
7. [Dependencies](#dependencies)
8. [Adding New Features](#adding-new-features)

---

## Package Overview

**Tinylens** is an R package for image-first analysis targeting digital humanities and film studies. The package follows these core principles:

1. **Tidy outputs**: All functions return tibbles with one row per image
2. **Scalar columns**: Feature extraction produces scalar columns (not nested lists)
3. **R-first**: No Python dependencies for core functionality
4. **Composability**: Small focused functions that chain with pipes
5. **Local-only LLM**: All LLM functions use Ollama (no cloud providers)

### Design Philosophy

The package is designed around the concept of a "tidy lens" - looking at visual data through a tidy data framework. Every function:
- Takes a `tl_images` tibble as input
- Returns the same tibble with additional columns
- Works with the pipe operator (`|>` or `%>%`)

---

## Core Data Structure

### The `tl_images` Tibble

The fundamental data structure is a tibble with class `tl_images`. It contains one row per image with these standard columns:

| Column | Type | Description |
|--------|------|-------------|
| `id` | character | Filename without extension |
| `source` | character | Original path provided |
| `local_path` | character | Full normalized path to file |
| `width` | integer | Image width in pixels |
| `height` | integer | Image height in pixels |
| `format` | character | File format (jpg, png, etc.) |
| `aspect_ratio` | numeric | Width / height |
| `file_size_bytes` | integer | File size in bytes |

Additional columns are added by various extraction functions (e.g., `brightness`, `mean_r`, `n_faces`, etc.).

### Creating tl_images

```r
# From a directory
images <- load_images("path/to/images/")

# From specific files
images <- load_images(c("img1.jpg", "img2.png"))

# From a manifest CSV (preserves additional columns)
images <- load_images("manifest.csv")

# From video extraction
frames <- video_extract_frames("video.mp4", fps = 1)
shots <- video_extract_shots("video.mp4")
```

---

## Function Categories

### Naming Convention

Functions follow a consistent prefix-based naming:

| Prefix | Purpose | Example |
|--------|---------|---------|
| `load_*` | I/O operations | `load_images()` |
| `video_*` | Video file operations | `video_extract_frames()` |
| `film_*` | Film/editing analysis | `film_compute_asl()` |
| `extract_*` | Feature extraction | `extract_brightness()` |
| `detect_*` | Object/feature detection | `detect_faces()` |
| `llm_*` | LLM-based analysis | `llm_describe()` |

### File Organization

```
R/
├── load_images.R      # Core I/O (load_images, print.tl_images, is_tl_images)
├── utils.R            # Internal helpers (downsample_image, map_images, read_image)
├── video.R            # Video functions + film_classify_scale, film_classify_angle
├── film_metrics.R     # ASL, rhythm, scale distribution
├── color.R            # 11 color extraction functions
├── fluency.R          # 4 composition/fluency functions
├── detection.R        # Face and skin tone detection
├── embeddings.R       # Neural embeddings (requires torch)
├── audio.R            # Audio feature extraction
├── llm.R              # Vision LLM functions
└── llm_setup.R        # Ollama setup helpers
```

### Complete Function Reference

#### I/O Functions
- `load_images(path, pattern, recursive, preserve_metadata)` - Load images into tl_images tibble
- `is_tl_images(x)` - Check if object is tl_images
- `print.tl_images(x)` - Pretty print method

#### Video Functions
- `video_extract_frames(video_path, output_dir, fps, frames, format, prefix)` - Extract frames from video
- `video_extract_shots(video_path, output_dir, threshold, min_duration, format, prefix)` - Extract shots with scene detection
- `video_get_info(video_path)` - Get video metadata
- `video_sample_frames(video_path, n, output_dir, format)` - Sample N evenly-spaced frames
- `video_download(url, destfile, overwrite)` - Download video from URL

#### Film Metrics (Aggregate)
- `film_compute_asl(shots)` - Average shot length and pacing metrics
- `film_compute_rhythm(shots)` - Editing rhythm analysis (entropy, regularity, acceleration)
- `film_summarize_scales(shots)` - Shot scale distribution summary

#### Film Metrics (Per-Image)
- `film_classify_scale(tl_images, method, downsample)` - Classify shot scale (ECU, CU, MCU, etc.)
- `film_classify_angle(tl_images, method, downsample)` - Classify camera angle

#### Color Extraction
- `extract_brightness(tl_images, downsample, method)` - Mean brightness and std
- `extract_color_mean(tl_images, downsample)` - Mean RGB values + hex
- `extract_saturation(tl_images, downsample)` - Mean/median/std saturation
- `extract_colourfulness(tl_images, downsample)` - M3 colourfulness metric
- `extract_warmth(tl_images, downsample)` - Color temperature score
- `extract_dominant_color(tl_images, n_colors, downsample)` - Dominant colors via k-means
- `extract_color_histogram(tl_images, n_bins, downsample)` - Color histograms
- `extract_contrast(tl_images, downsample)` - Michelson contrast
- `extract_hue_mean(tl_images, downsample)` - Mean hue in HSV space
- `extract_luminance(tl_images, downsample)` - Relative luminance
- `extract_color_entropy(tl_images, downsample)` - Color distribution entropy

#### Fluency/Composition
- `extract_fluency_metrics(tl_images, downsample)` - Simplicity, symmetry, balance
- `extract_rule_of_thirds(tl_images, downsample)` - Rule of thirds adherence
- `extract_visual_complexity(tl_images, downsample)` - Edge-based complexity
- `extract_center_bias(tl_images, downsample)` - Visual weight at center

#### Detection
- `detect_faces(tl_images, min_size)` - Face detection with bounding boxes
- `detect_skin_tones(tl_images, downsample)` - Skin tone pixel proportion

#### Embeddings
- `extract_embeddings(tl_images, model, layer, downsample)` - ResNet embeddings
- `compute_embedding_similarity(embeddings1, embeddings2)` - Cosine similarity

#### LLM Vision
- `llm_describe(tl_images, model, prompt, base_url, downsample)` - Image descriptions
- `llm_classify(tl_images, categories, model, base_url, downsample)` - Category classification
- `llm_sentiment(tl_images, model, base_url, downsample)` - Mood/sentiment analysis
- `llm_recognize(tl_images, model, base_url, downsample)` - Object recognition

#### LLM Setup
- `llm_check_ollama(base_url)` - Check if Ollama is running
- `llm_list_models(base_url)` - List available models
- `llm_pull_model(model, base_url)` - Pull/download a model
- `llm_test_vision(model, test_image, base_url)` - Test vision capabilities
- `llm_get_recommended_models()` - Get recommended vision models

#### Audio
- `extract_audio_features(tl_images, video_source)` - Full audio analysis
- `extract_audio_rms(tl_images, video_source)` - Lightweight loudness only

---

## Internal Architecture

### The `map_images()` Pattern

Most extraction functions follow this internal pattern using the `map_images()` helper:

```r
extract_some_feature <- function(tl_images, downsample = 200) {
  validate_tl_images(tl_images)  # Ensure valid input
  
  results <- map_images(tl_images, function(img) {
    # Process single magick image object
    # ... computation ...
    
    list(
      feature1 = value1,
      feature2 = value2
    )
  }, downsample = downsample, msg = "Extracting features")
  
  # Unpack results into tibble columns
  tl_images$feature1 <- purrr::map_dbl(results, ~ .x$feature1 %||% NA_real_)
  tl_images$feature2 <- purrr::map_dbl(results, ~ .x$feature2 %||% NA_real_)
  
  tl_images
}
```

### The `map_images()` Helper

Located in `R/utils.R`, this handles:
1. Input validation
2. Progress bar display
3. Image reading and optional downsampling
4. Error handling per image
5. Result collection

```r
map_images <- function(tl_images, fn, downsample = NULL, msg = "Processing") {
  validate_tl_images(tl_images)
  n <- nrow(tl_images)
  results <- vector("list", n)
  
  cli::cli_progress_bar(msg, total = n)
  
  for (i in seq_len(n)) {
    path <- tl_images$local_path[i]
    tryCatch({
      img <- read_image(path, downsample = downsample)
      results[[i]] <- fn(img)
    }, error = function(e) {
      cli::cli_warn("Error processing {basename(path)}: {e$message}")
      results[[i]] <<- NULL
    })
    cli::cli_progress_update()
  }
  
  cli::cli_progress_done()
  results
}
```

### Why `for` loops instead of `purrr::map()`?

The `cli` progress bar (`cli_progress_update()`) cannot be called inside `purrr::map()` due to how evaluation frames work. Using explicit `for` loops allows proper progress reporting.

---

## Data Flow Patterns

### Typical Pipeline

```r
# Load → Extract → Analyze
images <- load_images("images/") |>
  extract_brightness() |>
  extract_color_mean() |>
  extract_fluency_metrics() |>
  detect_faces()

# Result: tibble with original columns + extracted features
```

### Video Analysis Pipeline

```r
# Extract shots → Per-shot features → Aggregate metrics
shots <- video_extract_shots("film.mp4") |>
  film_classify_scale() |>
  film_classify_angle() |>
  extract_brightness()

# Aggregate pacing metrics
asl <- film_compute_asl(shots)
rhythm <- film_compute_rhythm(shots)
scales <- film_summarize_scales(shots)
```

### LLM Pipeline

```r
# Ensure Ollama is running
llm_check_ollama()

# Visual analysis
images <- load_images("images/") |>
  llm_describe() |>
  llm_classify(categories = c("indoor", "outdoor", "portrait")) |>
  llm_sentiment()
```

---

## Key Algorithms

### Image Data Handling with magick

**Critical note:** The `magick::image_data()` function returns data in CxWxH format (channels × width × height), but `as.integer()` converts it to HxWxC (height × width × channels):

```r
# Read image
img <- magick::image_read("photo.jpg")

# Get pixel data as integer array
data <- as.integer(magick::image_data(img, channels = "rgb"))

# Indexing: data[row, column, channel]
red_channel   <- data[, , 1]
green_channel <- data[, , 2]
blue_channel  <- data[, , 3]
```

### Brightness Calculation

```r
# Convert to grayscale, compute mean intensity
gray <- magick::image_convert(img, colorspace = "gray")
data <- as.integer(magick::image_data(gray))
brightness <- mean(data) / 255.0  # Normalize to 0-1
```

### M3 Colourfulness Metric

Based on Hasler & Süsstrunk (2003):

```r
# M3 = sqrt(σ_rg² + σ_yb²) + 0.3 * sqrt(μ_rg² + μ_yb²)
rg <- r - g
yb <- 0.5 * (r + g) - b

sigma_rg <- sd(rg)
sigma_yb <- sd(yb)
mu_rg <- mean(rg)
mu_yb <- mean(yb)

M3 <- sqrt(sigma_rg^2 + sigma_yb^2) + 0.3 * sqrt(mu_rg^2 + mu_yb^2)
```

### Shannon Entropy (for rhythm analysis)

```r
# Normalize durations to probabilities
p <- durations / sum(durations)
p <- p[p > 0]  # Avoid log(0)

# Raw entropy
entropy_raw <- -sum(p * log2(p))

# Normalize to 0-1
max_entropy <- log2(n)
rhythm_entropy <- entropy_raw / max_entropy
```

### Shot Scale Classification

Uses face detection or gradient salience to estimate subject size:

```r
# Get subject coverage (0-1 proportion of frame)
if (method == "face") {
  # Use face bounding box size
  coverage <- face_area / frame_area
} else {
  # Use gradient-based salience (high gradients = subject)
  coverage <- high_gradient_area / total_area
}

# Map coverage to scale
scale <- case_when(
  coverage > 0.70 ~ "ECU",  # Extreme Close-Up
  coverage > 0.45 ~ "CU",   # Close-Up
  coverage > 0.30 ~ "MCU",  # Medium Close-Up
  coverage > 0.20 ~ "MS",   # Medium Shot
  coverage > 0.15 ~ "CS",   # Cowboy Shot
  coverage > 0.10 ~ "MFS",  # Medium Full Shot
  coverage > 0.06 ~ "FS",   # Full Shot
  coverage > 0.02 ~ "WS",   # Wide Shot
  TRUE ~ "EWS"              # Extreme Wide Shot
)
```

---

## Dependencies

### Required
- `magick` - Image processing backbone
- `tibble`, `dplyr`, `purrr` - Tidy data manipulation
- `cli` - Progress bars and messages
- `tools`, `fs` - File handling

### Optional (Suggests)
- `av` - Video processing (ffmpeg wrapper)
- `tuneR` - Audio analysis
- `torch`, `torchvision` - Neural embeddings
- `image.libfacedetection` - Face detection
- `httr2`, `base64enc`, `jsonlite` - LLM functions (Ollama API)

### Installing Optional Dependencies

```r
# Video support
install.packages("av")

# Face detection
install.packages("image.libfacedetection", 
                 repos = "https://bnosac.r-universe.dev")

# Neural embeddings
install.packages("torch")
torch::install_torch()
install.packages("torchvision")

# LLM support (packages + Ollama)
install.packages(c("httr2", "base64enc", "jsonlite"))
# Then install Ollama from https://ollama.ai
```

---

## Adding New Features

### Step-by-Step Guide

1. **Identify the function category** - Use appropriate prefix (`extract_*`, `detect_*`, etc.)

2. **Create the function skeleton**:

```r
#' Extract my new feature
#'
#' Brief description of what it does.
#'
#' @param tl_images A tl_images tibble.
#' @param downsample Maximum side length for analysis. Default 200.
#'
#' @return The input tibble with added column:
#'   - `my_feature`: Description of the column.
#'
#' @family appropriate_family
#' @export
extract_my_feature <- function(tl_images, downsample = 200) {
  validate_tl_images(tl_images)
  
  results <- map_images(tl_images, function(img) {
    # Your computation here
    list(my_feature = computed_value)
  }, downsample = downsample, msg = "Extracting my feature")
  
  tl_images$my_feature <- purrr::map_dbl(results, ~ .x$my_feature %||% NA_real_)
  
  tl_images
}
```

3. **Add to NAMESPACE**:
```
export(extract_my_feature)
```

4. **Add documentation** with roxygen2 comments:
   - Use `@family` for grouping related functions
   - Use `[function()]` syntax for cross-references
   - End sentences with periods

5. **Test thoroughly** before merging

### Documentation Style (Tidyverse)

Follow these conventions:
- Use `@noRd` for internal functions
- Use `@family` tags for grouping
- End all sentences with periods
- Use `[function()]` for cross-references in roxygen
- First line is a title (no period)
- Second paragraph is description

---

## Academic References

### Color Analysis
- Hasler, D. and Süsstrunk, S. E. (2003). Measuring colorfulness in natural images.

### Film Metrics
- Salt, B. (2009). Film Style and Technology: History and Analysis.
- Cinemetrics project: https://www.cinemetrics.lv/

### Shot Scale
- StudioBinder (industry standard): https://www.studiobinder.com/blog/ultimate-guide-to-camera-shots/
- Redfern, N. (2023). Computational Film Analysis with R: https://cfa-with-r.netlify.app/

---

*Last updated: 2025-01-21*
*Version: tinylens 0.1.0 (v1.10)*
