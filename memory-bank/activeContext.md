# Active Context: Tinylens

## Current Work Focus

### Recently Completed (v1.14)

- **Package Validation**: Fixed R CMD check issues
  - Fixed NAMESPACE imports (stats, utils, graphics)
  - Fixed LICENSE format (DCF format)
  - Fixed vignette structure (inst/doc)
  - Updated .Rbuildignore
  - **Result: 1 NOTE (acceptable)**

- **Core Functionality Verified**: Comprehensive test passed
  - Video shot extraction: 15 shots detected
  - Color extraction: 11 functions working
  - Fluency/composition: 4 functions working
  - Film metrics: ASL, rhythm, scale distribution
  - **62 columns extracted per image**

### Active Decisions

1. **Directory Structure**: Clean separation:
   - `docs/` = Reference documentation
   - `vignettes/` = User tutorials
   - `memory-bank/tests/` = Test scripts and data
   - `logo.png` = Package branding at root

2. **Package Status**: Ready for use
   - R CMD check: 1 NOTE (optional deps not available)
   - All core functions working

## File Structure (v1.14)

```
tinylens/
├── DESCRIPTION
├── LICENSE
├── NAMESPACE
├── README.md
├── logo.png
├── .Rbuildignore
├── .github/
│   └── copilot-instructions.md
├── docs/
│   ├── code-architecture.md
│   ├── feature-glossary.md
│   ├── naming-convention.md
│   ├── output-reference.md
│   └── publishing-guide.md
├── inst/
│   └── doc/                     # Vignette outputs
├── memory-bank/
│   ├── activeContext.md
│   ├── productContext.md
│   ├── progress.md
│   ├── projectbrief.md
│   ├── systemPatterns.md
│   ├── techContext.md
│   └── tests/
│       ├── hero.mp4             # Test video
│       ├── test_run.R           # Main test script
│       └── outputs/             # CSV outputs
├── R/
│   ├── audio.R
│   ├── color.R
│   ├── detection.R
│   ├── embeddings.R
│   ├── film_metrics.R
│   ├── fluency.R
│   ├── llm.R
│   ├── llm_setup.R
│   ├── load_images.R
│   ├── tinylens-package.R       # Package-level docs + imports
│   ├── utils.R
│   └── video.R
└── vignettes/
    └── getting-started.Rmd
```

## Next Steps

1. **Testing**: Continue running test scripts to verify all functions
2. **Documentation**: Update docs if needed
3. **Publication**: Consider publishing to GitHub, CRAN, or journal

## Important Patterns and Preferences

### Function Patterns
- All extract_* functions: `function(tl_images, ...) -> tl_images with added columns`
- All video_* functions that return images: Must return tl_images class
- LLM functions: Default to qwen2.5vl, allow model override, use trimws() on output
- All roxygen docs: Periods at end of @param, @return bullet items

### User Preferences
- Prefers tidy data principles strictly enforced
- Wants single-purpose functions over multi-purpose ones
- Values ELI5 documentation style
- Local-only processing (no cloud APIs)
- Follows tidyverse style guide

## Learnings and Project Insights

1. **magick array ordering**: `as.integer(image_data())` returns HxWxC, index as `data[,,1]` for R channel

2. **Progress bars**: Cannot use `cli_progress_update()` inside `purrr::map()` - must use for loops

3. **Shot scale systems**: Industry (StudioBinder) and academic (CFA/Salt) use different conventions - both are valid

4. **ASL limitations**: ASL is affected by outliers; our asl_median addresses this

5. **R CMD check**: Use `_R_CHECK_FORCE_SUGGESTS_=false` to skip optional dependency checks
