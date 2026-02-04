# Product Context: Tinylens

## Why This Project Exists

### The Problem
Film studies and digital humanities researchers need quantitative tools for visual analysis, but:
1. Most tools are Python-based (barrier for R users)
2. Existing R packages are scattered and don't integrate well
3. Cloud vision APIs have privacy/cost concerns for research data
4. Many tools don't follow tidy data principles, making analysis awkward

### The Solution
Tinylens provides a unified, R-native toolkit for visual analysis that:
- Works entirely locally (no cloud dependencies)
- Returns tidy data structures compatible with tidyverse workflows
- Covers the full analysis pipeline from loading to feature extraction
- Uses local LLMs (Ollama) for vision descriptions

## How It Should Work

### User Experience Goals

1. **Load Once, Analyze Many**
   ```r
   images <- load_images("frames/")
   images |>
     extract_brightness() |>
     extract_colourfulness() |>
     extract_dominant_color()
   ```

2. **Tidy Data Throughout**
   - Every function takes a tl_images tibble as input
   - Every function returns the same tibble with added columns
   - One row = one image, always

3. **Progressive Enhancement**
   - Core functions work with just magick/tibble
   - Advanced features (embeddings, audio, faces) require optional packages
   - Clear errors when optional dependencies are missing

4. **Film Studies Workflow**
   ```r
   video_extract_shots("film.mp4") |>      # Returns tl_images with shot columns
     extract_brightness() |>
     extract_audio_features() |>           # Add audio analysis
     film_classify_scale() |>              # Add shot scale classification
     film_classify_angle() |>              # Add camera angle detection
     group_by(shot_scale) |>
     summarise(avg_brightness = mean(brightness))
   ```

## User Personas

### Primary: Film Studies Researcher
- Analyzing visual style across filmographies
- Needs: Shot detection, pacing metrics, color analysis
- Comfort: R/tidyverse, not Python
- Example use: Comparing visual complexity across director's works

### Secondary: Digital Humanities Scholar
- Analyzing historical photograph collections
- Needs: Batch processing, reproducible workflows
- Comfort: Basic R, prefers simple APIs
- Example use: Color palette evolution in 20th century magazines

### Tertiary: Media Analyst
- Quick visual analysis of social media content
- Needs: LLM descriptions, sentiment analysis
- Comfort: Data science workflows
- Example use: Brand image consistency analysis

## Design Principles

1. **Tidy First**: Every output is a tibble, every column is scalar
2. **Local Only**: No cloud dependencies for core or LLM features
3. **Progressive Disclosure**: Simple things simple, complex things possible
4. **Composability**: Functions chain naturally with pipes
5. **Documentation**: ELI5 explanations for all metrics
