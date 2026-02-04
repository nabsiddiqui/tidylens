# Project Brief: Tinylens

## Project Name
**Tinylens** - An R Package for Image-First Analysis

## Core Purpose
An R package targeting digital humanities and film studies researchers who need quantitative visual analysis tools. Provides a tidy, pipeable API for analyzing visual content without requiring Python dependencies.

## Core Requirements

### Functional Requirements
1. Load images from files/URLs into a tidy data structure (one row per image)
2. Extract 70+ scalar features across color, texture, composition, and detection
3. Process video files (frame extraction, shot detection, pacing analysis)
4. Integrate with local LLMs (Ollama) for vision descriptions
5. All functions return tibbles that chain with dplyr/tidyverse pipes

### Technical Requirements
- **R-first**: No Python dependencies for core functionality
- **Tidy outputs**: All functions return tibbles with one row per image
- **Scalar columns**: Feature extraction produces scalar columns (not nested lists)
- **Composability**: Small focused functions that chain with pipes
- **Local-only LLM**: All LLM functions use Ollama (no cloud providers)

## Target Users
- Digital humanities researchers
- Film studies scholars
- Media analysts
- Anyone needing quantitative visual analysis in R

## Success Criteria
1. ✅ 70 columns extracted from images
2. ✅ All 38+ core functions tested and working
3. ✅ Video processing pipeline complete
4. ✅ Audio feature extraction (7 columns)
5. ✅ Film classification (shot scale + camera angle)
6. ✅ LLM integration with Ollama verified
7. ✅ Tidy data principles enforced throughout
8. ✅ Tidyverse style guide compliance

## Project Scope

### In Scope
- Image feature extraction (color, fluency, composition)
- Video frame/shot extraction with timing
- Audio feature extraction (RMS, ZCR, spectral analysis)
- Per-image film metrics (shot scale, camera angle classification)
- Local LLM vision integration (Ollama)
- Documentation with ELI5 explanations

### Out of Scope
- Cloud LLM providers (OpenAI, Google Vision, etc.)
- Spatio-temporal slices (low priority)
- Python interop

## Key Constraints
- Must work on macOS, Linux, Windows
- Core functions should not require heavy dependencies (torch, av are optional)
- All outputs must follow tidy data principles
