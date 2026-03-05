# tidylens: An R Package for Tidy Computational Film and Image Analysis

**Authors:** Nabeel Siddiqui  
**Affiliation:** Department of Communications, Susquehanna University  
**Corresponding author:** siddiqui@susqu.edu  
**GitHub:** https://github.com/nabsiddiqui/tidylens  
**License:** MIT  

---

## Code Metadata

| Nr. | Code metadata description | Please fill in this column |
|-----|--------------------------|---------------------------|
| C1 | Current code version | v0.1.0 |
| C2 | Permanent link to code/repository | https://github.com/nabsiddiqui/tidylens |
| C3 | Permanent link to reproducible capsule | (pending) |
| C4 | Legal Code License | MIT |
| C5 | Code versioning system used | git |
| C6 | Software code languages, tools, and services used | R (≥ 4.1.0) |
| C7 | Compilation requirements, operating environments & dependencies | magick, tibble, dplyr, purrr, cli, fs, rlang, tools, stats, utils; optional: av, tuneR, image.libfacedetection, torch, torchvision, ollamar |
| C8 | If available Link to developer documentation/manual | https://github.com/nabsiddiqui/tidylens/tree/main/vignettes |
| C9 | Support email for questions | siddiqui@susqu.edu |

---

## Highlights

- Unified pipeable interface for computational film analysis in R
- GPU-free shot scale classification achieving 76% three-class accuracy across directors
- Returns tidyverse-compatible tibbles for immediate analysis
- Implements 11 color metrics, 4 composition measures, 7 audio features
- Enables corpus-scale research on consumer hardware without infrastructure barriers

---

## Abstract

Computational analysis of film corpora at scale presents a methodological dilemma: convolutional neural network (CNN) approaches deliver semantic precision but require GPU infrastructure that most researchers cannot access, creating a reproducibility barrier that limits who can participate in corpus-scale film studies. tidylens is an R package that provides a unified, pipeable interface for computational film and image analysis that runs entirely on consumer hardware without GPU requirements. The package combines a lightweight CNN-based shot scale classifier—a frozen ResNet-18 backbone with a 17-kilobyte linear head, validated against the CineScale benchmark at 76% three-class accuracy across eight films from six directors—with histogram-based shot detection, eleven perceptual color metrics, four composition measures, and seven audio features, all returning tidyverse-compatible tibbles. Validation on 4,394 annotated frames from films by Scorsese, Bergman, Fellini, Godard, Tarr, and Antonioni confirms that the classifier generalizes across directorial styles, with 89% of predictions falling within one scale category of ground truth. By prioritizing inspectability, reproducibility, and composability, tidylens fills a gap in the research software ecosystem where film analysis has lacked unified tools operating within established analytical paradigms.

---

## Keywords

R package; computational film analysis; image analysis; shot scale classification; shot boundary detection; color analysis; tidyverse; reproducibility

---

## 1. Motivation

### 1.1 The Scale Problem

Computational analysis of film corpora at scale—hundreds of films, hundreds of thousands of frames—has become tractable with convolutional neural networks (CNNs), but at a substantial reproducibility cost. CNN-based methods require GPU infrastructure that most researchers cannot access, creating a barrier to replication that limits who can participate in corpus-scale film studies [1,2]. Arnold and Tilton's distant viewing framework demonstrates the scholarly potential of analyzing large visual corpora but explicitly acknowledges that their pipeline requires substantial computational resources including GPU acceleration for practical processing times. This infrastructure requirement excludes researchers at institutions without high-performance computing clusters, independent scholars, and those working in resource-constrained environments—effectively stratifying the field by access to hardware rather than by research question quality or methodological rigor.

### 1.2 The Ecosystem Gap

Statistical film analysis has operated for decades without unified software infrastructure. The tidyverse ecosystem provides unified paradigms for text analysis, network analysis, and spatial data—film analysis has no comparable package [3]. Researchers working with visual media must either maintain complex cross-language pipelines or write custom functions that duplicate existing implementations without community maintenance. This infrastructure asymmetry inhibits cumulative research: findings from one project resist replication in another because data structures vary, metadata must be manually aligned, and analytical pipelines become difficult to debug or extend. A unified package operating within a coherent data analysis grammar would enable researchers to move from raw video to publication-ready visualizations within a single computational environment.

### 1.3 Three Core Values

tidylens addresses this gap by combining lightweight neural network inference with classical algorithms, all returning tidyverse-native tibbles, and prioritizing three values. First, inspectability: color, composition, and audio metrics use formulas documented in peer-reviewed literature rather than learned representations [4]. Formula-based metrics produce identical outputs given identical inputs regardless of computing environment. Where the package employs a CNN—for shot scale classification—the architecture is minimal (a frozen ImageNet backbone with a small linear head) and its outputs are directly interpretable as cinematographic categories.

Second, reproducibility: all measurements run on consumer hardware without requiring GPU acceleration, enabling researchers at teaching-focused institutions and international contexts to conduct corpus-scale analysis. The CNN component uses CPU inference through the torch package, requiring no CUDA installation or cloud computing access.

Third, composability: outputs integrate directly with dplyr verbs, ggplot2, and tidymodels without requiring transformation. Each function returns a tibble subclass that carries metadata forward through pipelines, enabling readable, debuggable workflows.

### 1.4 The Trade-Off

These values involve a deliberate trade-off. tidylens does not attempt the full semantic scene understanding that GPU-accelerated CNNs provide. It cannot label objects, recognize actions, or parse complex spatial relationships. The scholarly value lies in combining a targeted CNN classifier for shot scale—a specific, well-defined cinematographic property—with systematic measurements of color, composition, and pacing that can be aggregated, compared, and replicated across studies.

### 1.5 Theoretical Foundation

This approach extends a methodological tradition established by Salt [5], who demonstrated that quantitative methods reveal patterns invisible to textual analysis; Tsivian [6], whose cinemetrics project showed systematic variation in shot-length distributions across periods and cinemas; O'Brien [7], who applied such methods to comparative editing; Cutting, DeLong, and Nothelfer [8], who analyzed 150 Hollywood films to reveal evolution toward 1/f temporal structure; and Baxter, Khitrova, and Tsivian [9], who established that classical algorithms distinguish directorial styles through editing patterns alone. Flueckiger and Halter [4] demonstrate that formula-based metrics reveal historical patterns in chromatic practice that resist intuitive observation but emerge through computational aggregation. These findings establish that computationally efficient techniques produce significant scholarly insights when applied systematically across corpora.

---

## 2. Software Description

### 2.1 Core Data Structure

All tidylens functions operate on and return objects of class `tl_images`, a subclass of the standard tibble [3]. Each row represents one image or video frame; each column represents either metadata inherited at load time or feature values added by subsequent extraction functions. The metadata columns include file path, source video (when applicable), frame number, timestamp, pixel dimensions, and aspect ratio. This one-row-per-image structure integrates immediately with dplyr verbs for filtering, grouping, and summarizing, and with ggplot2 for visualization without requiring reshaping or pivoting operations.

The `tl_images` class maintains attributes that enable downstream functions to validate inputs and provide informative error messages. When a function expects image data but receives an ordinary tibble, the package raises a clear error indicating the expected class. When a function is applied to `tl_images` that lacks required columns—for instance, attempting to extract color features before frames have been loaded—the error message identifies the missing prerequisite step. This validation infrastructure prevents silent failures that would produce incorrect results without warning.

### 2.2 Video Processing and Shot Scale Classification

The `video_*` family handles the transition from raw video to analyzable frame data through a pipeline designed to minimize memory usage while maintaining analytical flexibility. `video_get_info()` retrieves metadata including duration, frame rate, codec information, and resolution without extracting frames, enabling researchers to make informed decisions about sampling rates before committing computational resources to full extraction.

`video_extract_frames()` uses FFmpeg bindings through the av package to extract frames at user-specified rates. The function supports absolute frame counts (extract exactly N evenly spaced frames) or temporal rates (extract M frames per second), enabling researchers to balance granularity against processing time based on their analytical needs. Extracted frames are stored as in-memory magick-image objects that preserve full color information while enabling rapid processing.

`video_extract_shots()` integrates frame extraction and shot boundary detection in a single operation: it extracts frames at the specified rate, computes normalized RGB color histograms for consecutive frame pairs, calculates chi-squared distance between histograms [10], and marks boundaries where distance exceeds a configurable threshold [2]. This histogram-based approach detects cuts, fades, and dissolves through chromatic discontinuity rather than semantic content, producing shot-level segmentation without requiring scene understanding.

`film_classify_scale()` assigns shot scale labels using a CNN classifier that runs on CPU. The classifier passes each frame through a frozen ResNet-18 backbone pretrained on ImageNet to extract a 512-dimensional feature vector, then applies a trained linear head (a 7×512 weight matrix and bias vector, totaling 17 kilobytes) to predict seven cinematographic scale categories: extreme close-up, close-up, medium close-up, medium shot, medium long shot, long shot, and extreme long shot. These categories follow the CineScale taxonomy established by Savardi et al. [13,14]. The ResNet-18 weights (approximately 45 megabytes) are downloaded once on first use; subsequent runs load from a local cache. The entire inference pipeline runs on CPU through the torch and torchvision R packages without requiring CUDA, GPU drivers, or cloud computing infrastructure. A heuristic fallback based on face detection (via image.libfacedetection) and figure-ground ratio is available when torch is not installed, though at reduced accuracy.

### 2.3 Color and Composition Analysis

The `extract_*` family covers eleven color metrics and four composition metrics, all designed to be pipe-compatible and computationally efficient. Color functions address perceptual properties through established formulas from the computer vision and media studies literature.

`extract_brightness()` computes mean or median intensity in either grayscale or perceptually uniform color spaces. The function supports multiple color space options (sRGB, Lab, HSV) recognizing that "brightness" has different mathematical definitions depending on whether the research question concerns physical luminance or perceptual lightness.

`extract_colourfulness()` applies the Hasler-Süsstrunk M3 formula, which measures chromatic variation through opponent color space distances [11]: M = σ_rgyb + 0.3μ_rgyb, where σ and μ denote standard deviation and mean of the red-green and yellow-blue opponent color axes. This metric correlates with human judgments of image colorfulness and has been applied extensively in film color analysis research. Values range from near zero for grayscale images to higher values for highly saturated multicolor scenes.

`extract_warmth()` measures the warm-cool axis through opponent color space calculations, returning a continuous value where higher numbers indicate warmer (red-yellow) coloration and lower numbers indicate cooler (blue-green) coloration. This metric captures a dimension of color experience that matters for genre conventions, historical periodization, and affective analysis.

`extract_dominant_color()` uses K-means clustering to identify the most prevalent hue in each image, returning results as hex codes that integrate directly with ggplot2 color scales. The function allows specification of cluster count, enabling researchers to distinguish between single-dominant-color images and those with balanced dual-color schemes.

`extract_color_variance()` computes statistical dispersion measures including standard deviation and entropy across color channels, capturing the degree of chromatic heterogeneity within frames. High variance indicates polychromatic scenes; low variance indicates restricted palettes.

Composition functions address spatial organization and aesthetic principles. `extract_fluency_metrics()` computes symmetry (mirror correspondence across vertical and horizontal axes), balance (visual weight distribution), and simplicity (feature count reduction) following experimental aesthetics research. `extract_rule_of_thirds()` identifies the degree to which salient content aligns with intersection points of the classical compositional grid. `extract_center_bias()` measures the tendency for visual attention to concentrate at the image center, relevant to studying framing conventions across periods and genres. `extract_visual_complexity()` quantifies the amount of visual information through edge detection and texture analysis, distinguishing simple from cluttered compositions.

### 2.4 Film Metrics and Audio Features

The `film_*` functions aggregate shot-level data into film-level measures suitable for corpus comparison. `film_compute_asl()` computes average shot length, median shot length, standard deviation, and shots per minute—the standard quantitative vocabulary of film pacing research established by Cutting, DeLong, and Nothelfer [8]. These metrics have demonstrated historical validity in showing systematic evolution of Hollywood editing rhythms over decades.

`film_compute_rhythm()` extends pacing analysis to temporal structure, returning shot-duration entropy (measuring unpredictability in shot lengths), regularity (degree of periodic patterning), and acceleration (trend toward shorter or longer shots across a film's duration). These metrics capture aspects of temporal experience that simple averages obscure.

Audio feature extraction aligns seven features to shot boundaries for audio-visual correspondence analysis [12]. RMS loudness measures perceived volume; peak amplitude captures transient events; zero-crossing rate distinguishes tonal from noisy sounds; silence ratio identifies passages of diegetic quiet; spectral centroid indicates brightness as the frequency-weighted spectral magnitude, rolloff identifies the frequency below which a specified percentage of spectral energy resides, and flux measures the rate of spectral change between consecutive frames. By aligning these features to shot timing, researchers can analyze how sound design correlates with visual rhythm—whether cuts coincide with sonic events, whether loudness varies systematically across shot types, or whether spectral characteristics predict transition patterns.

---

## 3. Illustrative Example

The following code illustrates a representative workflow from raw video to exportable dataset:

```r
library(tidylens)
library(dplyr)
library(ggplot2)

# Extract shots with scale classification and color metrics
shots <- video_extract_shots("film.mp4", fps = 2, threshold = 0.5) |>
  film_classify_scale() |>
  extract_brightness() |>
  extract_colourfulness() |>
  extract_warmth() |>
  extract_audio_features("film.mp4")

# Visualize color distribution across shots
shots |>
  ggplot(aes(x = timestamp, y = colourful, color = warmth)) +
  geom_point(alpha = 0.5) +
  scale_color_gradient(low = "blue", high = "red") +
  labs(title = "Chromatic Variation Across Film Duration")

# Compute pacing metrics
pacing <- shots |>
  summarise(
    asl           = mean(duration),
    shot_count    = n(),
    shots_per_min = n() / (sum(duration) / 60),
    avg_loudness  = mean(audio_rms, na.rm = TRUE),
    mean_colour   = mean(colourfulness, na.rm = TRUE)
  )

# Export for corpus aggregation
write.csv(shots, "shot_data.csv", row.names = FALSE)
```

The output of each step is a standard tibble: `shots` has one row per shot with timing, scale, color, and audio data; `pacing` is a one-row summary. Each integrates directly with ggplot2 or modeling functions without transformation. The pipe syntax chains operations in the order researchers conceptualize their workflow: extract shots, then classify scale, then measure color properties, then aggregate, then export.

---

## 4. Impact

### 4.1 Empirical Validation

tidylens enables corpus-scale analysis on consumer hardware. Empirical validation against the CineScale benchmark dataset—792,000 ground-truth annotations across 124 films from six directors [13]—quantifies the accuracy of the shot scale classifier and confirms that meaningful analysis can proceed without GPU infrastructure.

The validation tested 4,394 annotated frames across eight films from six directors: Scorsese (Taxi Driver), Bergman (Persona), Fellini (8½), Godard (Breathless, La Chinoise), Tarr (Macbeth, Panelkapcsolat), and Antonioni (Blow-Up). Three films served as training data for the linear head; five were held out entirely—never seen during training. On the full seven-class CineScale taxonomy, the classifier achieved 56% exact accuracy. Collapsing to three perceptual groups (close, medium, long), accuracy reached 76% overall: 84% on training films and 71% on held-out films. Adjacent accuracy—the proportion of predictions within one scale category of ground truth—reached 89% overall and 85% on held-out films, indicating that misclassifications rarely cross major perceptual boundaries (Figure 1, Figure 2).

Per-director results reveal how the classifier generalizes across stylistic variation (Figure 3). Directors represented in the training set—Scorsese (86% three-class), Bergman (83%), Fellini (82%)—show accuracy consistent with familiarity. Among held-out directors, Godard (76%) and Antonioni (73%) maintained accuracy above 70%, while Tarr (65%) presented the greatest challenge. Tarr's distinctive long-take, deep-staging visual style departs substantially from the close-up and medium-shot distributions that dominate the training films, and the lower accuracy for his work suggests that expanding the training corpus to include a broader range of directorial styles would improve generalization. Per-class analysis shows that extreme scales (extreme close-up at 94% group accuracy, long shot at 93%) are classified more reliably than middle scales (medium shot at 77%, medium long shot at 62%), consistent with the greater visual ambiguity of intermediate framings (Figure 4).

These results compare directly against the CineScale benchmark literature. Savardi et al. [14] reported 94–97% seven-class accuracy using VGG-16 and DenseNet architectures on GPU hardware, establishing an upper bound defined by deep networks with full GPU training. The tidylens classifier operates in a different regime: a frozen backbone with a small trained head, running on CPU at approximately 41 frames per second on an Apple M-series processor. Classical approaches—face detection combined with figure-ground heuristics, following Canini et al. [15]—achieved 75% three-class accuracy in our testing but at 12 frames per second, roughly 3.4 times slower than the CNN approach and with lower accuracy at every granularity. The lightweight CNN thus occupies a practical middle ground: sufficient accuracy for corpus-level patterns, no GPU requirement, and throughput adequate for processing feature-length films in minutes rather than hours.

A complementary validation on a 15-film corpus—eight CC-licensed Blender Open Movies and seven public-domain silents—processed in under two hours on a 2021 MacBook Pro with no GPU acceleration. Measuring colourfulness [11] yielded distinct chromatic categories: silent films scored near zero (consistent with grayscale transfers), Blender films registered median 29.7 (reflecting contemporary digital color design), and a print of The General (1926) recorded 12.1—revealing sepia print provenance that no metadata flagged. That a single corpus-level measurement surfaced material variation demonstrates the scholarly utility of inspectable, replicable methods.

### 4.2 Scholarly Utility

The package addresses researchers who require transparent, citable metrics. Formula-based extractors—over thirty in the current release—produce single numbers per image with documented mathematical provenance [4] and run in seconds on consumer laptops. This transparency matters for cumulative research: subsequent studies can apply identical metrics to different corpora and compare results with confidence that measurement differences reflect historical variation rather than methodological divergence. For shot scale classification, the CNN component introduces a learned representation, but the output categories—the seven CineScale classes—remain interpretable and comparable across studies. Unlike full-pipeline CNN approaches where retraining produces different feature spaces, the frozen backbone and fixed linear head ensure that the same model produces identical classifications on identical inputs.

### 4.3 Pedagogical Applications

Beyond research applications, tidylens supports pedagogical goals in film studies and digital humanities curricula. The inspectable formulas enable students to understand precisely how computational analysis transforms visual material into quantitative data, tracing the mathematical path from pixel values to color metrics rather than treating computation as a black box. Students who work through these steps develop a critical capacity to assess what computational methods measure and what they elide—a form of methodological literacy that digital humanities pedagogy increasingly prioritizes [16]. The package bridges the gap between conceptual instruction and practical implementation: students move from understanding a formula to applying it across a film corpus without writing boilerplate code.

### 4.4 Limitations and Future Directions

tidylens does not address research questions requiring full semantic understanding: it cannot distinguish between a close-up of a face and a close-up of a flower, nor can it identify emotional expression or narrative events. The shot scale classifier, while adequate for corpus-level analysis, does not match the accuracy of GPU-trained deep networks; researchers requiring per-frame precision should use dedicated CNN tools such as the CineScale models [14] or dvt [1], accepting the infrastructure requirements that accompany them. The 71% held-out three-class accuracy indicates room for improvement—particularly for directors whose visual styles diverge sharply from the training distribution—and future versions may expand the training set or explore domain adaptation techniques.

The package extends a methodological tradition begun by Salt [5] and Tsivian [6] into an era when computational film analysis risks becoming synonymous with opaque neural network outputs. tidylens ensures that statistical film analysis remains accessible regardless of institutional resources—and that the insights it produces can be verified, compared, and built upon by subsequent scholarship.

---

## Declaration of generative AI and AI-assisted technologies in the manuscript preparation process

During the preparation of this work the author used AI-assisted tools for literature synthesis, citation verification, and prose revision. After using these tools, the author reviewed and edited the content as needed and takes full responsibility for the content of the published article.

---

## CRediT authorship contribution statement

**Nabeel Siddiqui:** Conceptualization, Software, Methodology, Writing – original draft, Writing – review & editing.

---

## References

[1] Arnold T, Tilton L. Distant Viewing: Analyzing Large Visual Corpora. Digit Scholarsh Humanit 2019;34(Supplement_1):i3-16. https://doi.org/10.1093/llc/fqz013.

[2] Pustu-Iren K, Sittel J, Mauer R, Bulgakowa O, Ewerth R. Automated Visual Content Analysis for Film Studies: Current Status and Challenges. Digit Humanit Q 2020;14(4).

[3] Wickham H. Tidy Data. J Stat Softw 2014;59:1-23. https://doi.org/10.18637/jss.v059.i10.

[4] Flueckiger B, Halter G. Methods and Advanced Tools for the Analysis of Film Colors in Digital Humanities. Digit Humanit Q 2020;14(4).

[5] Salt B. Statistical Style Analysis of Motion Pictures. Film Q 1974;28(1):13-22. https://doi.org/10.2307/1211438.

[6] Tsivian Y. Cinemetrics, Part of the Humanities' Cyberinfrastructure. In: Ross M, Grauer M, Freisleben B, editors. Digital Tools in Media Studies: Analysis and Research. An Overview. New Brunswick, NJ: Transcript-Verlag; 2009. p. 93-100.

[7] O'Brien C. Sous les toits de Paris and Transnational Film Style: An Analysis of Film Editing Statistics. Stud Fr Cinema 2009;9(2):111-25. https://doi.org/10.1386/sfc.9.2.111_1.

[8] Cutting JE, DeLong JE, Nothelfer CE. Attention and the Evolution of Hollywood Film. Psychol Sci 2010;21(3):432-9. https://doi.org/10.1177/0956797610361679.

[9] Baxter M, Khitrova D, Tsivian Y. Exploring Cutting Structure in Film, with Applications to the Films of D. W. Griffith, Mack Sennett, and Charlie Chaplin. Digit Scholarsh Humanit 2017;32(1):1-16. https://doi.org/10.1093/llc/fqv035.

[10] Boreczky JS, Rowe LA. Comparison of Video Shot Boundary Detection Techniques. J Electron Imaging 1996;5(2):122-8. https://doi.org/10.1117/12.240304.

[11] Hasler D, Süsstrunk SE. Measuring Colorfulness in Natural Images. Proc SPIE 2003;5007:87-95.

[12] Cella C-E. An Introduction to Audio Features; 2015. https://www.carminecella.com/teaching/Audio_features.pdf.

[13] Savardi M, Kovács AB, Signoroni A, Benini S. CineScale: A dataset of cinematic shot scale in movies. Data Brief 2021;36:107002. https://doi.org/10.1016/j.dib.2021.107002.

[14] Savardi M, Signoroni A, Migliorati P, Benini S. Shot scale analysis in movies by convolutional neural networks. In: 2018 25th IEEE International Conference on Image Processing (ICIP); 2018. p. 2620-4. https://doi.org/10.1109/ICIP.2018.8451474.

[15] Canini L, Benini S, Leonardi R. Classifying cinematographic shot types. Multimed Tools Appl 2011;62(1):51-73. https://doi.org/10.1007/s11042-011-0916-9.

[16] Burghardt M, Heftberger A, Pause J, Walkowski N-O, Zeppelzauer M. Film and Video Analysis in the Digital Humanities — An Interdisciplinary Dialog. Digit Humanit Q 2020;14(4).
