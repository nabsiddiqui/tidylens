# Tinylens Naming Convention

## Core Principle: Verb-Object with Category Prefix

Following tidyverse conventions, all exported functions use:
- **snake_case**
- **Verbs first** (action-oriented)
- **Category prefix** for grouping related functions

---

## Naming Patterns

### 1. Image Feature Extraction: `extract_*`
Functions that add columns to a tl_images tibble use `extract_`:

```r
# Color
extract_brightness()
extract_saturation()
extract_warmth()
extract_dominant_color()
extract_color_variance()
extract_color_mean()       # was: extract_average_colour_mean
extract_color_median()     # was: extract_average_colour_median
extract_color_mode()       # was: extract_average_colour_mode
extract_color_moments()
extract_colourfulness()    # was: compute_colourfulness_M3
extract_hue_histogram()

# Fluency/Composition
extract_fluency_metrics()
extract_rule_of_thirds()
extract_visual_complexity()
extract_center_bias()      # was: analyze_center_bias

# Embeddings
extract_embeddings()       # was: compute_image_embeddings
extract_color_histogram()  # was: compute_color_histogram
```

### 2. Detection Functions: `detect_*`
Functions that detect objects/features:

```r
detect_faces()
detect_skin_tones()
detect_shot_changes()
```

### 3. Video Functions: `video_*`
Functions that operate on video files:

```r
video_extract_frames()     # was: extract_frames
video_extract_shots()      # was: extract_shots  
video_get_info()           # was: get_video_info
video_sample_frames()      # was: sample_frames
video_extract_shot_frames() # was: extract_shot_frames
```

### 4. Film Metrics: `film_*`
Functions for film/editing analysis:

```r
film_compute_asl()         # was: compute_asl
film_compute_rhythm()      # was: compute_shot_rhythm
film_summarize_scales()    # was: summarize_shot_scales
film_classify_scale()      # was: get_shot_style
```

### 5. LLM Functions: `llm_*`
All LLM-related functions (already consistent):

```r
llm_describe()
llm_classify()
llm_sentiment()
llm_recognize()

# Setup helpers
llm_check_ollama()         # was: check_ollama
llm_list_models()          # was: list_vision_models
llm_pull_model()           # was: pull_vision_model
llm_check_dependencies()   # was: check_llm_dependencies
llm_setup_instructions()
```

### 6. Core I/O: `load_*` / `is_*`
```r
load_images()
is_tl_images()
```

---

## Summary of Changes

| Old Name | New Name | Reason |
|----------|----------|--------|
| `extract_average_colour_mean` | `extract_color_mean` | Shorter, American spelling |
| `extract_average_colour_median` | `extract_color_median` | Shorter, American spelling |
| `extract_average_colour_mode` | `extract_color_mode` | Shorter, American spelling |
| `compute_colourfulness_M3` | `extract_colourfulness` | extract_ prefix, simpler |
| `analyze_center_bias` | `extract_center_bias` | extract_ prefix consistency |
| `compute_image_embeddings` | `extract_embeddings` | extract_ prefix |
| `compute_color_histogram` | `extract_color_histogram` | extract_ prefix |
| `extract_frames` | `video_extract_frames` | video_ prefix |
| `extract_shots` | `video_extract_shots` | video_ prefix |
| `get_video_info` | `video_get_info` | video_ prefix |
| `sample_frames` | `video_sample_frames` | video_ prefix |
| `extract_shot_frames` | `video_extract_shot_frames` | video_ prefix |
| `compute_asl` | `film_compute_asl` | film_ prefix |
| `compute_shot_rhythm` | `film_compute_rhythm` | film_ prefix |
| `summarize_shot_scales` | `film_summarize_scales` | film_ prefix |
| `get_shot_style` | `film_classify_scale` | film_ prefix, verb |
| `check_ollama` | `llm_check_ollama` | llm_ prefix |
| `list_vision_models` | `llm_list_models` | llm_ prefix |
| `pull_vision_model` | `llm_pull_model` | llm_ prefix |
| `check_llm_dependencies` | `llm_check_dependencies` | llm_ prefix |

---

## Backward Compatibility

For v1.x releases, deprecated functions will be kept as aliases:

```r
# Deprecated alias (kept for compatibility)
compute_colourfulness_M3 <- function(...) {

  .Deprecated("extract_colourfulness")
  extract_colourfulness(...)
}
```

These will be removed in v2.0.
