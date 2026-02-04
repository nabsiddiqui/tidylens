# Tinylens 📷

**Tinylens** is an R package for image-first analysis targeting digital humanities and film studies. It provides a tidy, pipeable API for analyzing visual content.

## Installation

```r
# Install from local source
devtools::install_local("tinylens")

# Or source files directly
source("R/load_images.R")
source("R/color.R")
# ... etc
```

## Quick Start

```r
library(tinylens)

# Load images
images <- load_images("my_photos/")

# Extract features
results <- images |>
  extract_brightness() |>
  extract_average_colour_mean() |>
  extract_saturation() |>
  compute_colourfulness_M3()

# View results
print(results)
```

## Core Functions

### Image Loading

| Function | Description |
|----------|-------------|
| `load_images()` | Load images into a tl_images tibble with metadata |
| `extract_frames()` | Extract frames from video at specified FPS |
| `extract_shots()` | Detect shots in video with timing information |

### Color Analysis

| Function | Description | Formula/Method |
|----------|-------------|----------------|
| `extract_brightness()` | Mean/median brightness | Mean of grayscale pixel values (0-1 scale) |
| `extract_average_colour_mean()` | Mean RGB color | Per-channel mean: μ_R, μ_G, μ_B |
| `extract_average_colour_median()` | Median RGB color | Per-channel median |
| `extract_average_colour_mode()` | Most frequent color | Histogram binning + mode finding |
| `extract_hue_histogram()` | Hue distribution | HSV conversion + hue binning |
| `extract_saturation()` | Color saturation | S = (max - min) / max in HSV |
| `compute_colourfulness_M3()` | Colourfulness metric | Hasler & Süsstrunk M3 formula |
| `extract_warmth()` | Warm/cool tone | (R - B) / intensity |
| `extract_dominant_color()` | Most prominent color | K-means clustering on RGB |
| `extract_color_variance()` | Color spread | Variance of RGB channels |

### Texture & Edge Analysis

| Function | Description | Formula/Method |
|----------|-------------|----------------|
| `extract_edge_density()` | Edge proportion | Sobel gradient + threshold |
| `extract_contrast()` | Image contrast | Michelson & RMS contrast |
| `extract_entropy()` | Texture complexity | Shannon entropy of histogram |
| `extract_sharpness()` | Focus/blur detection | Laplacian variance |
| `extract_canny_edges()` | Canny edge detection | Gaussian + gradient + hysteresis |
| `extract_contours()` | Contour detection | Edge-following algorithm |
| `extract_line_segments()` | Line detection | LSD algorithm |
| `extract_corners()` | Corner features | Harris corner detector |

### Composition & Fluency

| Function | Description | Formula/Method |
|----------|-------------|----------------|
| `extract_fluency_metrics()` | Processing fluency | Simplicity, symmetry, balance |
| `extract_rule_of_thirds()` | Composition adherence | Gradient at power points |
| `extract_visual_complexity()` | Overall complexity | Entropy + edges + variance |
| `analyze_center_bias()` | Central focus | Center vs peripheral salience |

### Video Analysis

| Function | Description |
|----------|-------------|
| `get_video_info()` | Video metadata (fps, duration, size) |
| `detect_shot_changes()` | Detect scene cuts |
| `extract_shots()` | Extract shots with timing |
| `get_shot_style()` | Classify shot scale (ECU, CU, MS, etc.) |

### LLM Vision (Optional)

| Function | Description | Provider |
|----------|-------------|----------|
| `llm_describe()` | Natural language description | Ollama/OpenAI |
| `llm_classify()` | Category classification | Ollama/OpenAI |
| `llm_sentiment()` | Mood/sentiment analysis | Ollama/OpenAI |
| `llm_recognize()` | Object recognition | Ollama/OpenAI |

---

## Formula Details & References

### Colourfulness (M3 Metric)

The Hasler & Süsstrunk M3 colourfulness metric measures how colorful an image appears:

```
rg = R - G
yb = 0.5 * (R + G) - B
M3 = sqrt(σ_rg² + σ_yb²) + 0.3 * sqrt(μ_rg² + μ_yb²)
```

**ELI5**: This formula looks at how spread out and different the colors are. Images with lots of bright, varied colors score higher.

**Reference**: Hasler, D. and Süsstrunk, S. E. (2003). "Measuring colorfulness in natural images." *Proc. SPIE 5007, Human Vision and Electronic Imaging VIII*.
- Paper: https://www.researchgate.net/publication/243135534_Measuring_Colourfulness_in_Natural_Images
- Implementation: https://gist.github.com/zabela/8539116

---

### Michelson Contrast

Measures the range of luminance divided by the sum:

```
Michelson = (L_max - L_min) / (L_max + L_min)
```

**ELI5**: How much difference is there between the brightest and darkest parts? High contrast = big difference.

**Reference**: Michelson, A. A. (1927). *Studies in Optics*. University of Chicago Press.
- Wikipedia: https://en.wikipedia.org/wiki/Contrast_(vision)

---

### RMS Contrast

Root mean square of pixel intensity deviations:

```
RMS = sqrt(mean((I - μ)²)) = standard deviation of intensity
```

**ELI5**: This measures how much the brightness "jumps around" across the image. Higher = more variation.

**Reference**: Peli, E. (1990). "Contrast in complex images." *Journal of the Optical Society of America A*.
- Wikipedia: https://en.wikipedia.org/wiki/Contrast_(vision)#RMS_contrast

---

### Shannon Entropy

Measures randomness/complexity of pixel intensity distribution:

```
H = -Σ p(x) * log₂(p(x))
```

Where p(x) is the probability of intensity value x.

**ELI5**: How surprising is each pixel? If all pixels are the same, entropy is 0. If pixels are completely random, entropy is maximum.

**Reference**: Shannon, C. E. (1948). "A Mathematical Theory of Communication." *Bell System Technical Journal*.
- Wikipedia: https://en.wikipedia.org/wiki/Entropy_(information_theory)

---

### Laplacian Variance (Sharpness)

Uses the variance of the Laplacian (second derivative) to measure focus:

```
Laplacian(x,y) = 4*I(x,y) - I(x-1,y) - I(x+1,y) - I(x,y-1) - I(x,y+1)
Sharpness = Var(Laplacian)
```

**ELI5**: Sharp images have clear edges (big second derivatives). Blurry images have smooth transitions (small derivatives).

**Reference**: Pech-Pacheco, J. L. et al. (2000). "Diatom autofocusing in brightfield microscopy." *Pattern Recognition*.
- OpenCV tutorial: https://www.researchgate.net/publication/315919131_Blur_image_detection_using_Laplacian_operator_and_Open-CV

---

### Saturation (HSV)

Saturation in HSV color space:

```
S = (max(R,G,B) - min(R,G,B)) / max(R,G,B)
```

**ELI5**: How "pure" is the color? Grays have 0 saturation, vivid colors have high saturation.

**Reference**: https://en.wikipedia.org/wiki/HSL_and_HSV

---

### Hue Entropy

Shannon entropy applied to the hue histogram:

```
H_hue = -Σ p(h) * log₂(p(h))
```

**ELI5**: How many different colors are in the image? Monochromatic images have low hue entropy.

---

### Rule of Thirds

Measures how much visual interest (gradient magnitude) concentrates at "power points":

```
Power points: (1/3, 1/3), (1/3, 2/3), (2/3, 1/3), (2/3, 2/3)
Score = mean gradient at power points / overall mean gradient
```

**ELI5**: Good compositions often place important elements where the thirds-lines intersect.

**Reference**: https://en.wikipedia.org/wiki/Rule_of_thirds

---

### Center Bias

Ratio of center region salience to peripheral region salience:

```
Center bias = mean_gradient(center) / mean_gradient(periphery)
```

**ELI5**: Is the interesting stuff in the middle? A center bias > 1 means more action in the center.

---

### Shot Detection (Chi-squared Histogram Distance)

Detects scene cuts by measuring histogram differences:

```
χ² = Σ (H1(i) - H2(i))² / (H1(i) + H2(i))
```

**ELI5**: When colors suddenly change a lot between frames, that's probably a scene cut.

**Reference**: Lienhart, R. (2001). "Reliable Transition Detection in Videos." *ACM Multimedia*.
- DOI: https://doi.org/10.1145/500141.500149

---

### Shot Scale Classification

Based on subject coverage in frame:

| Scale | Subject Coverage | Description |
|-------|-----------------|-------------|
| ECU (Extreme Close-Up) | > 60% | Eyes/mouth only |
| CU (Close-Up) | 40-60% | Face fills frame |
| MCU (Medium Close-Up) | 25-40% | Head and shoulders |
| MS (Medium Shot) | 15-25% | Waist up |
| MLS (Medium Long Shot) | 8-15% | Knees up |
| LS (Long Shot) | 3-8% | Full body |
| ELS (Extreme Long Shot) | < 3% | Wide landscape |

**Reference**: Bordwell, D. & Thompson, K. (2010). *Film Art: An Introduction*. McGraw-Hill.

---

## Optional Dependencies

For full functionality, install these optional packages:

```r
# Video processing
install.packages("av")

# Edge detection
install.packages("image.CannyEdges")
install.packages("image.ContourDetector")
install.packages("image.LineSegmentDetector")
install.packages("image.CornerDetectionHarris")

# Texture analysis
install.packages("glcm")

# Face detection
install.packages("image.libfacedetection")

# Neural embeddings
install.packages("torch")
install.packages("torchvision")

# LLM Vision
install.packages("httr2")
install.packages("base64enc")
```

---

## License

MIT License. See LICENSE file.

## Citation

If you use Tinylens in academic research, please cite:

```
Tinylens: An R package for image-first analysis in digital humanities
https://github.com/your-repo/tinylens
```
