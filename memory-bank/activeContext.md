# Active Context: Tidylens Development

## Current State (Last Updated: Session 27)

### Package Status
- **Name:** tidylens (renamed from tinylens)
- **Version:** 0.1.0
- **Repository:** https://github.com/nabsiddiqui/tidylens
- **R CMD check:** PASS with 1 NOTE (suggested packages)
- **Test Results:** 15 shots detected, 62 columns extracted from hero.mp4

### Recent Changes
1. **Renamed package** from tinylens → tidylens (all files updated)
2. **Consolidated folder structure** - single folder with:
   - Package files at root (GitHub repo)
   - memory-bank/ for dev notes and tests
   - docs/ for internal documentation
3. **README** - comprehensive documentation merged from vignette
4. **GitHub** - live at nabsiddiqui/tidylens

### Folder Structure
```
tidylens/
├── .git/                 ← GitHub repository
├── R/                    ← 11 source files
├── man/                  ← Function documentation
├── vignettes/            ← getting-started.Rmd
├── docs/                 ← Internal docs
│   ├── code-architecture.md
│   ├── feature-glossary.md
│   ├── naming-convention.md
│   ├── output-reference.md
│   └── publishing-guide.md
├── memory-bank/          ← This folder
│   ├── tests/            ← Test scripts and outputs
│   └── *.md              ← Context files
├── DESCRIPTION
├── NAMESPACE
├── README.md
├── logo.png
└── LICENSE
```

### What's Working
- All 38+ functions operational
- Shot detection with 9-scale classification
- Color analysis (11 functions)
- Composition metrics (4 functions)
- Audio analysis per shot
- LLM vision via Ollama (4 functions)
- Tidy outputs (one row per image)

### SoftwareX Submission
- Target journal: SoftwareX (no 6-month history requirement)
- Separate memory-bank created at: `/Dropbox/Spring 2026/Tidylens Software X Submission/`
- Next step: Draft manuscript following SoftwareX guidelines

---

## Quick Reference

### Install from GitHub
```r
devtools::install_github("nabsiddiqui/tidylens")
```

### Basic Usage
```r
library(tidylens)

# Video analysis
shots <- video_extract_shots("movie.mp4") |>
  extract_audio_features("movie.mp4")

# Image analysis  
images <- load_images("folder/") |>
  extract_brightness() |>
  extract_colourfulness()
```

### Run Tests
```r
source("memory-bank/tests/run_full_test.R")
```

---

## Session History

| Session | Date | Actions |
|---------|------|---------|
| 1-14 | Earlier | Fixed R CMD check, cleanup, initial GitHub push |
| 15-16 | Today | Merged vignette into README |
| 17 | Today | Removed inst/doc, Related Projects |
| 18 | Today | Removed References, created Bluesky post |
| 19-20 | Today | Renamed tinylens → tidylens, pushed to new repo |
| 21-23 | Today | Verified Ollama integration |
| 24 | Today | Created SoftwareX submission folder |
| 25-26 | Today | Consolidated folder structure |
| 27 | Today | Updated memory bank |
