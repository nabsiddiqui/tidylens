# Project Brief: Tidylens

## What is Tidylens?

An R package for **image-first visual analysis** targeting digital humanities and film studies. Provides a tidy, pipeable API for extracting quantitative features from images and video.

## Core Value Proposition

1. **R-native:** No Python dependencies for core functionality
2. **Tidy outputs:** All functions return tibbles with one row per image
3. **Film-specific:** Metrics designed for humanities research questions
4. **Local LLM:** Ollama integration for privacy-conscious research

## Feature Categories

### Video Processing
- `video_get_info()` - Video metadata
- `video_extract_frames()` - Extract at FPS
- `video_sample_frames()` - Sample N frames
- `video_extract_shots()` - Shot boundary detection
- `video_extract_shot_frames()` - Representative frame per shot

### Color Analysis (11 functions)
- Brightness, saturation, colourfulness
- Mean/median/mode RGB
- Dominant color (k-means)
- Warmth/tint
- Color moments, variance
- Hue histogram

### Composition (4 functions)
- Fluency metrics (symmetry, balance)
- Rule of thirds
- Visual complexity
- Center bias

### Film Metrics
- Shot scale classification (9 StudioBinder types: ECU, CU, MCU, MS, CS, MFS, FS, WS, EWS)
- ASL computed via dplyr summarise

### Detection
- Face detection (requires image.libfacedetection)
- Skin tone proportion

### Audio
- Full features: RMS, peak, ZCR, silence ratio, freq energy, spectral centroid
- Lightweight: RMS only

### LLM Vision (Ollama)
- `llm_describe()` - Natural language descriptions
- `llm_classify()` - Category classification
- `llm_sentiment()` - Mood/valence/intensity
- `llm_recognize()` - Object detection

## Target Audience

1. Film scholars analyzing editing patterns, color palettes
2. Digital humanities researchers with visual archives
3. Cultural analytics practitioners
4. R users preferring tidyverse workflows

## Repository

- **GitHub:** https://github.com/nabsiddiqui/tidylens
- **License:** MIT
- **Author:** Nabeel Siddiqui

## Publication Plan

- **Target:** SoftwareX (no 6-month public history requirement)
- **Submission folder:** `/Dropbox/Spring 2026/Tidylens Software X Submission/`
