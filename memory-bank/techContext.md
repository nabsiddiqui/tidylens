# Tech Context: Tinylens

## Technologies Used

### Core R Packages (Required)
| Package | Purpose | Version |
|---------|---------|---------|
| magick | Image I/O, resize, crop, manipulation | 2.7+ |
| tibble | Tidy data structures | 3.0+ |
| dplyr | Data manipulation | 1.0+ |
| purrr | Functional programming, iteration | 0.3+ |
| cli | Progress bars, user messages | 3.0+ |

### Optional R Packages
| Package | Purpose | Required For |
|---------|---------|--------------|
| av | Video processing | video_* functions |
| tuneR | Audio analysis | extract_audio_* functions |
| torch | Neural networks | extract_embeddings() |
| torchvision | Pre-trained models | extract_embeddings() |
| image.libfacedetection | Face detection | detect_faces() |
| httr2 | HTTP requests | llm_* functions |
| base64enc | Base64 encoding | llm_* functions |
| jsonlite | JSON parsing | llm_* functions |

### External Dependencies
| Tool | Purpose | Installation |
|------|---------|--------------|
| Ollama | Local LLM runtime | `brew install ollama` (macOS) |

## Development Setup

### Minimum Requirements
```r
install.packages(c("magick", "tibble", "dplyr", "purrr", "cli"))
```

### Full Installation
```r
# Core
install.packages(c("magick", "tibble", "dplyr", "purrr", "cli"))

# Video & Audio
install.packages(c("av", "tuneR"))

# Detection
install.packages("image.libfacedetection")

# Embeddings
install.packages(c("torch", "torchvision"))

# LLM
install.packages(c("httr2", "base64enc", "jsonlite"))
```

### Ollama Setup
```bash
# macOS
brew install ollama
ollama serve  # Start server

# Pull recommended model
ollama pull qwen2.5vl:7b
```

## Technical Constraints

### Memory
- Large videos can consume significant memory during frame extraction
- Embeddings require GPU memory (or slow CPU fallback)
- Recommend processing in batches for 1000+ images

### Performance
- Image reading is I/O bound
- Feature extraction is CPU bound
- LLM calls are network/GPU bound
- Use `future` for parallel processing if needed

### Compatibility
- Tested on macOS (Apple Silicon and Intel)
- Should work on Linux and Windows
- av package may need ffmpeg on some systems

## Dependencies

### Package DESCRIPTION Imports
```
Imports:
    magick,
    tibble,
    dplyr,
    purrr,
    cli,
    stats,
    grDevices
```

### Package DESCRIPTION Suggests
```
Suggests:
    av,
    torch,
    torchvision,
    glcm,
    image.libfacedetection,
    image.CannyEdges,
    image.ContourDetector,
    image.LineSegmentDetector,
    image.CornerDetectionHarris,
    httr2,
    base64enc,
    jsonlite,
    testthat
```

## Tool Usage Patterns

### magick
```r
# Read image
img <- magick::image_read(path)
info <- magick::image_info(img)

# Get pixel data (returns CxWxH raw array)
data <- magick::image_data(img, channels = "rgb")

# Convert to integer matrix (becomes HxWxC!)
mat <- as.integer(data)  # mat[,,1] = R, mat[,,2] = G, mat[,,3] = B
```

### av
```r
# Get video info (returns tibble!)
av::av_video_info(path)

# Extract frames
av::av_video_images(path, destdir = dir, fps = 1)
```

### Ollama API
```r
# POST to /api/generate
httr2::request("http://localhost:11434/api/generate") |>
  httr2::req_body_json(list(
    model = "qwen2.5vl:7b",
    prompt = prompt,
    images = list(base64_image),
    stream = FALSE
  )) |>
  httr2::req_perform()
```

## File Structure
```
tinylens/
├── DESCRIPTION          # Package metadata
├── NAMESPACE            # Exports
├── LICENSE              # MIT
├── README.md            # Package overview
├── R/
│   ├── load_images.R    # Core I/O (load_images, is_tl_images)
│   ├── video.R          # video_* functions
│   ├── film.R           # film_* functions (film_classify_scale)
│   ├── color.R          # Color extraction (11 functions)
│   ├── texture.R        # Texture extraction (11 functions)
│   ├── detection.R      # Detection functions (3 functions)
│   ├── embeddings.R     # Neural embeddings (2 functions)
│   ├── fluency.R        # Composition metrics (4 functions)
│   ├── llm.R            # LLM vision functions (4 functions)
│   ├── llm_setup.R      # LLM helpers (5 functions)
│   └── utils.R          # Helper functions
├── docs/
│   ├── feature-glossary.md
│   └── naming-convention.md
├── vignettes/
│   └── getting-started.Rmd
├── tests/
│   ├── run_full_test.R
│   └── csvs/            # Test outputs
├── memory-bank/         # Project documentation
└── .github/
    └── copilot-instructions.md
```
