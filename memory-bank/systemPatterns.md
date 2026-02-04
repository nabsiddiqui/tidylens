# System Patterns: Tinylens

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         User Interface                          │
│                    (R Console / Scripts)                        │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Core Data Structure                        │
│                         tl_images tibble                         │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ id | source | local_path | width | height | format | ...   ││
│  │ One row per image, scalar columns only                      ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        ▼                       ▼                       ▼
┌──────────────┐       ┌──────────────┐       ┌──────────────┐
│   I/O Layer  │       │  Processing  │       │  LLM Layer   │
│ load_images()│       │  extract_*   │       │   llm_*      │
│ video_*      │       │  detect_*    │       │ (Ollama)     │
│              │       │  film_*      │       │              │
└──────────────┘       └──────────────┘       └──────────────┘
        │                       │                       │
        ▼                       ▼                       ▼
┌──────────────┐       ┌──────────────┐       ┌──────────────┐
│    magick    │       │ R base/stats │       │    httr2     │
│      av      │       │    glcm      │       │  base64enc   │
│              │       │ image.* pkgs │       │   jsonlite   │
└──────────────┘       └──────────────┘       └──────────────┘
```

## Key Technical Decisions

### 1. Tidy Data Structure
- **Decision**: All functions operate on and return tibbles with one row per image
- **Rationale**: Integrates seamlessly with tidyverse, enables piping
- **Trade-off**: No nested structures (lists-of-lists), may need multiple columns for related data

### 2. Class-Based Validation
- **Decision**: tl_images has its own class for validation
- **Implementation**: `is_tl_images()` checks class and required columns
- **Trade-off**: Extra validation step, but prevents errors downstream

### 3. Optional Dependencies
- **Decision**: Core works with minimal deps; advanced features require optional packages
- **Implementation**: Check with `requireNamespace()`, fail with helpful message
- **Trade-off**: User must install extra packages, but core stays lightweight

### 4. Local LLM Only
- **Decision**: No cloud API support, Ollama only
- **Rationale**: Privacy, no API keys, works offline
- **Trade-off**: User must install Ollama, but full control over data

## Design Patterns in Use

### 1. Pipeline Pattern
Every function takes tl_images first, returns modified tl_images:
```r
images |>
  extract_brightness() |>
  extract_colourfulness() |>
  extract_dominant_color()
```

### 2. Progressive Enhancement
Core → Optional → Advanced:
```r
# Core (magick only)
extract_brightness()

# Optional (requires av + tuneR)
extract_audio_features()

# Advanced (requires torch)
extract_embeddings()
```

### 3. Internal Helpers
Pattern: Public function wraps internal per-image function:
```r
# Public
extract_brightness <- function(tl_images) {
  results <- map_images(tl_images, extract_brightness_single)
  bind_cols(tl_images, results)
}

# Internal
extract_brightness_single <- function(path) {
  # ... actual computation
}
```

### 4. Consistent Naming
- `extract_*`: Feature extraction (adds columns)
- `detect_*`: Detection functions (adds columns)
- `video_*`: Video operations (may return images)
- `film_*`: Film-specific metrics (adds columns)
- `llm_*`: LLM operations (adds columns)

## Component Relationships

```
load_images() ─────────────────────────────────────────────────┐
       │                                                        │
       ▼                                                        │
 ┌─────────────┐                                               │
 │ tl_images   │◄──────────────────────────────────────────────┤
 │   tibble    │                                               │
 └─────────────┘                                               │
       │                                                        │
       ├──► extract_brightness() ──► tl_images + brightness    │
       ├──► extract_colourfulness() ──► tl_images + colourfulness
       ├──► detect_faces() ──► tl_images + face_count          │
       ├──► llm_describe() ──► tl_images + description         │
       └──► ... (all functions return augmented tl_images)     │
                                                                │
video_extract_shots() ──► tl_images (with shot columns) ───────┘
```

## Critical Implementation Paths

### Image Loading
1. `load_images(source)` - Source can be path, glob, or URL vector
2. Read with magick, extract metadata
3. Return tibble with class "tl_images"

### Feature Extraction
1. Validate input is tl_images
2. Use `map_images()` to iterate with progress bar
3. Each per-image function reads file, computes feature
4. Bind results to original tibble

### Video Processing
1. `video_extract_frames()` - Extract all/sample frames to temp dir
2. Frames are regular images, pipe to load_images()
3. `video_extract_shots()` - Detect shots, return tl_images with shot metadata

### LLM Integration
1. Check Ollama running with `llm_check_ollama()`
2. Encode image as base64
3. POST to Ollama API
4. Parse response, add as column
