# Tinylens Publishing Guide

This document covers two paths:
1. **Making a "real" R package** - Releasing on GitHub and optionally CRAN
2. **Submitting to JOSS** - Publishing a software paper in the Journal of Open Source Software

---

## Part 1: Making a "Real" R Package

### Current State ✅

Your package already has the core structure:
- `DESCRIPTION` - Package metadata
- `NAMESPACE` - Exported functions
- `R/` - Source code
- `vignettes/` - Documentation
- `LICENSE` - MIT license

### Step 1: Final Checks

#### 1.1 Run R CMD check

```r
# From R console
devtools::check()

# Or from terminal
R CMD build . && R CMD check tinylens_*.tar.gz
```

Fix any ERRORs, WARNINGs, and most NOTEs before proceeding.

#### 1.2 Check package dependencies

Make sure DESCRIPTION lists all packages:
```
Imports:     # Required packages
Suggests:    # Optional packages (av, tuneR, torch, etc.)
```

#### 1.3 Check documentation

```r
devtools::document()  # Regenerate NAMESPACE and .Rd files
devtools::build_vignettes()
```

### Step 2: GitHub Release

#### 2.1 Ensure you have a GitHub repository

```bash
# If not already on GitHub
git init
git add .
git commit -m "Initial commit for tinylens v0.1.0"
git remote add origin https://github.com/yourusername/tinylens.git
git push -u origin main
```

#### 2.2 Create a release

1. Go to your GitHub repo
2. Click "Releases" → "Create a new release"
3. Tag version: `v0.1.0`
4. Title: `tinylens 0.1.0`
5. Describe major features
6. Publish release

#### 2.3 Make installable via GitHub

Users can now install with:
```r
# install.packages("devtools")
devtools::install_github("yourusername/tinylens")
```

### Step 3: (Optional) CRAN Submission

CRAN has strict requirements. Only do this if you want maximum reach.

#### 3.1 CRAN requirements

- No errors or warnings in `R CMD check`
- All examples must run without errors
- Tests shouldn't take too long
- No non-standard file types
- Proper licensing

#### 3.2 Pre-submission check

```r
# Run the full CRAN check
devtools::check(cran = TRUE)

# Check on multiple platforms via GitHub Actions
usethis::use_github_action_check_standard()
```

#### 3.3 Submit to CRAN

```r
devtools::release()
```

This guides you through the submission process.

### Step 4: Add GitHub Actions (CI/CD)

Create `.github/workflows/R-CMD-check.yaml`:

```yaml
name: R-CMD-check

on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]

jobs:
  R-CMD-check:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [macos-latest, ubuntu-latest, windows-latest]
        r: ['release']
    
    steps:
      - uses: actions/checkout@v4
      - uses: r-lib/actions/setup-r@v2
        with:
          r-version: ${{ matrix.r }}
      - uses: r-lib/actions/setup-r-dependencies@v2
        with:
          extra-packages: rcmdcheck
      - uses: r-lib/actions/check-r-package@v2
```

### Step 5: Add a pkgdown Site (Optional)

Create a professional documentation website:

```r
# Setup
usethis::use_pkgdown()

# Build site
pkgdown::build_site()
```

Then enable GitHub Pages to host it.

---

## Part 2: Submitting to JOSS

The Journal of Open Source Software publishes short papers (1-2 pages) about research software.

### JOSS Requirements

#### Software Requirements
- ✅ Open source license (MIT)
- ✅ Version controlled (Git)
- ✅ Documentation (vignettes, README)
- ✅ Automated tests
- ✅ Community guidelines (CONTRIBUTING.md - you should add this)

#### Paper Requirements
- Summary statement
- Statement of need
- Installation instructions
- Example usage
- Scholarly references

### Step 1: Pre-submission Checklist

#### 1.1 Code Quality
- [ ] `R CMD check` passes with no errors
- [ ] Examples in documentation work
- [ ] Tests pass

#### 1.2 Documentation
- [ ] README with installation and quick start
- [ ] Vignette with detailed examples
- [ ] All exported functions have roxygen documentation

#### 1.3 Community
Create `CONTRIBUTING.md`:

```markdown
# Contributing to Tinylens

We welcome contributions! Here's how to help:

## Reporting Issues
- Use GitHub Issues
- Include a minimal reproducible example

## Pull Requests
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run `devtools::check()` to ensure no new issues
5. Submit a pull request

## Code Style
We follow the tidyverse style guide.
```

Create `CODE_OF_CONDUCT.md`:
```r
usethis::use_code_of_conduct()
```

### Step 2: Write the JOSS Paper

Create `paper.md` in your repository root:

```markdown
---
title: 'Tinylens: A Tidy R Package for Image-First Analysis in Film Studies and Digital Humanities'
tags:
  - R
  - film studies
  - digital humanities
  - image analysis
  - computational methods
authors:
  - name: Nabeel Siddiqui
    orcid: 0000-0000-0000-0000
    affiliation: 1
affiliations:
  - name: Your Institution
    index: 1
date: DD Month YYYY
bibliography: paper.bib
---

# Summary

Tinylens is an R package providing a tidy, pipeable API for analyzing visual 
content, targeting film studies and digital humanities researchers. Unlike 
existing image analysis tools that require Python or complex setup, Tinylens 
offers an R-native approach that integrates seamlessly with the tidyverse 
ecosystem.

# Statement of Need

Film scholars and digital humanities researchers increasingly use computational 
methods to analyze visual media at scale. However, existing tools often require:
- Python expertise (OpenCV, scikit-image)
- Complex dependencies (deep learning frameworks)
- Manual data transformation to work with statistical analysis tools

Tinylens addresses these barriers by providing:
- Pure R implementation for core features
- Tidy data output (one row per image)
- Pipeable functions that chain naturally
- Optional integrations (face detection, neural embeddings, local LLMs)

# Key Features

- **Color analysis**: 11 functions for brightness, saturation, warmth, dominant colors
- **Composition**: Symmetry, balance, rule of thirds, visual complexity
- **Video processing**: Frame extraction, shot detection, ASL computation
- **Film metrics**: Shot scale classification (ECU to EWS), camera angle detection
- **Audio analysis**: RMS loudness, spectral features aligned to video
- **LLM integration**: Local vision models via Ollama for descriptions and classification

# Example Usage

```r
library(tinylens)

# Analyze a film
shots <- video_extract_shots("film.mp4") |>
  extract_brightness() |>
  extract_warmth() |>
  film_classify_scale()

# Compute pacing metrics
pacing <- film_compute_asl(shots)
```

# Acknowledgements

We thank the developers of the magick, av, and cli packages for their 
foundational work.

# References
```

### Step 3: Create paper.bib

```bibtex
@book{salt2009film,
  title={Film Style and Technology: History and Analysis},
  author={Salt, Barry},
  year={2009},
  publisher={Starword}
}

@article{hasler2003measuring,
  title={Measuring colorfulness in natural images},
  author={Hasler, David and S{\"u}sstrunk, Sabine E},
  journal={Human Vision and Electronic Imaging VIII},
  volume={5007},
  pages={87--95},
  year={2003},
  publisher={SPIE}
}

@software{R-magick,
  title={magick: Advanced Graphics and Image-Processing in R},
  author={Ooms, Jeroen},
  year={2024},
  url={https://CRAN.R-project.org/package=magick}
}

@article{tidyverse2019,
  title={Welcome to the {tidyverse}},
  author={Wickham, Hadley and others},
  journal={Journal of Open Source Software},
  volume={4},
  number={43},
  pages={1686},
  year={2019}
}
```

### Step 4: Submit to JOSS

1. **Go to**: https://joss.theoj.org/papers/new
2. **Log in** with GitHub
3. **Fill in repository URL**: https://github.com/yourusername/tinylens
4. **Submit**

### Step 5: The Review Process

1. **Pre-review**: Editor checks basic requirements (~1 week)
2. **Review**: 2 reviewers check:
   - Functionality
   - Documentation
   - Tests
   - Paper content
3. **Revisions**: Address reviewer feedback
4. **Acceptance**: Paper published with DOI

### JOSS AI Policy Note

JOSS is developing formal AI guidelines. Their current stance:
- **AI-assisted code is allowed**
- **Wholly AI-generated code may be out of scope**
- **You must understand and be able to explain your code**
- **Be honest about AI use if asked during review**

Your package shows clear scholarly contribution through:
- Domain expertise (film studies, digital humanities)
- Thoughtful design (tidy principles, modular functions)
- Academic grounding (Salt, Hasler & Süsstrunk references)
- Original integration (local LLMs for film analysis)

---

## Quick Reference

### Timeline

| Task | Time Estimate |
|------|---------------|
| Final R CMD check fixes | 1-2 hours |
| GitHub release | 30 minutes |
| Write JOSS paper | 2-4 hours |
| JOSS submission | 15 minutes |
| JOSS review process | 4-8 weeks |

### Files to Create

```
tinylens/
├── paper.md          # JOSS paper
├── paper.bib         # References
├── CONTRIBUTING.md   # Contribution guidelines
├── CODE_OF_CONDUCT.md
├── .github/
│   └── workflows/
│       └── R-CMD-check.yaml
└── (existing files)
```

### Useful Commands

```r
# Check package
devtools::check()

# Build documentation
devtools::document()

# Build vignettes
devtools::build_vignettes()

# Install locally
devtools::install()

# Simulate CRAN submission
devtools::check(cran = TRUE)
```

---

*Good luck with your submission!*
