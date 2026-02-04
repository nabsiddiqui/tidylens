# Tinylens Feature Glossary

This guide explains every metric in tinylens in plain English. No jargon, just clarity.

---

## Quick Reference Chart

| Category | Function | What It Measures | ELI5 Explanation |
|----------|----------|------------------|------------------|
| **Film/Video** | `film_compute_asl()` | Pacing metrics | How fast/slow the editing feels |
| **Film/Video** | `film_compute_rhythm()` | Editing rhythm | Is the editing pattern regular or chaotic? |
| **Film/Video** | `film_classify_scale()` | Shot scale | How close/far is the camera to subjects? |
| **Film/Video** | `film_classify_angle()` | Camera angle | Is the camera looking up, down, or level? |
| **Color** | `extract_brightness()` | Light levels | Is the image dark or bright? |
| **Color** | `extract_colourfulness()` | Color intensity | Are the colors vivid or muted? |
| **Color** | `extract_warmth()` | Color temperature | Does it feel warm (orange) or cool (blue)? |
| **Color** | `extract_color_moments()` | Color statistics | Mathematical fingerprint of color distribution |
| **Fluency** | `extract_fluency_metrics()` | Visual simplicity | How easy is the image to "process" mentally? |
| **Fluency** | `extract_rule_of_thirds()` | Composition | Does it follow classic photo composition? |
| **Audio** | `extract_audio_features()` | Sound analysis | Loudness, silence, frequency balance |

---

## Detailed Explanations

### 📽️ Pacing Metrics (Film Analysis)

**What is pacing?**
Pacing describes how fast a film "feels." A fast-paced action movie has many short shots (cuts happen frequently). A slow art film has long shots that linger.

**`compute_asl()` returns:**

| Column | Meaning | Example |
|--------|---------|---------|
| `asl` | Average Shot Length (in seconds) | 4.2 = cuts happen every 4.2 seconds on average |
| `asl_median` | Median shot length | Less affected by one very long shot |
| `asl_std` | Standard deviation | High = mix of short and long shots |
| `shot_count` | Total number of shots | How many times the editor "cut" |
| `shots_per_minute` | Cutting rate | 15 = 15 cuts per minute (fast!) |

**Real-world benchmarks:**
- Modern action film: ASL ~2-3 seconds
- Classic Hollywood: ASL ~6-8 seconds
- Art/documentary: ASL ~12+ seconds
- Michael Bay: ASL ~2 seconds
- Hitchcock: ASL ~8-10 seconds

---

### 🎬 Editing Rhythm

**What is editing rhythm?**
Beyond just "how fast," rhythm describes the *pattern* of editing. Is it steady like a metronome, or unpredictable like jazz?

**`compute_shot_rhythm()` returns:**

| Column | Meaning | ELI5 |
|--------|---------|------|
| `rhythm_entropy` | Pattern randomness (0-1) | Low = predictable pattern, High = chaotic cuts |
| `rhythm_regularity` | How consistent shot lengths are | 1 = all shots same length, 0 = wildly varying |
| `rhythm_acceleration` | Is cutting speeding up or slowing down? | Positive = getting faster toward end |

**Example:**
- Music video with beat-synced cuts → High regularity, low entropy
- Action sequence building tension → Positive acceleration (cuts get faster)
- Avant-garde film → High entropy (unpredictable)

---

### 🎨 Color Moments

**`extract_color_moments()` returns 9 columns:**

| Moment | What It Means |
|--------|---------------|
| Mean | Average color value per channel |
| Std (Standard Deviation) | How much color varies |
| Skewness | Is the color distribution lopsided? |

Applied to RGB channels, you get:
- `color_moment_r_mean`, `color_moment_r_std`, `color_moment_r_skew`
- `color_moment_g_mean`, `color_moment_g_std`, `color_moment_g_skew`  
- `color_moment_b_mean`, `color_moment_b_std`, `color_moment_b_skew`

**Film use cases:**
- Fingerprint a film's color palette
- Detect color grading changes
- Compare visual style between directors

---

## Visual Summary: What Each Category Tells You

```
┌─────────────────────────────────────────────────────────────────┐
│                    IMAGE ANALYSIS                                │
├─────────────────────────────────────────────────────────────────┤
│  COLOR                   │  TEXTURE                             │
│  • How bright?           │  • How sharp?                        │
│  • How colorful?         │  • How complex?                      │
│  • Warm or cool?         │  • What kind of surface?             │
│  • Color distribution    │  • Shape fingerprints                │
├─────────────────────────────────────────────────────────────────┤
│  COMPOSITION             │  DETECTION                           │
│  • Rule of thirds?       │  • Faces?                            │
│  • Symmetrical?          │  • Key regions?                      │
│  • Center-focused?       │  • Skin tones?                       │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    VIDEO/FILM ANALYSIS                           │
├─────────────────────────────────────────────────────────────────┤
│  PACING                  │  RHYTHM                              │
│  • How fast are cuts?    │  • Regular or chaotic?               │
│  • ASL in seconds        │  • Speeding up or slowing?           │
│  • Cuts per minute       │  • Pattern entropy                   │
├─────────────────────────────────────────────────────────────────┤
│  SHOT STYLE              │                                      │
│  • Close-up? Wide?       │                                      │
│  • ECU/CU/MCU/MS/LS/ELS  │                                      │
└─────────────────────────────────────────────────────────────────┘
```

---

## Academic References

| Concept | Original Paper |
|---------|----------------|
| ASL (Average Shot Length) | Salt, B. (2009). *Film Style and Technology* |
| Tamura Texture | Tamura, H. et al. (1978). "Textural Features Corresponding to Visual Perception" |
| Hu Moments | Hu, M.K. (1962). "Visual Pattern Recognition by Moment Invariants" |
| Color Moments | Stricker, M. & Orengo, M. (1995). "Similarity of Color Images" |
| Colourfulness M3 | Hasler, D. & Süsstrunk, S. (2003). "Measuring Colorfulness in Natural Images" |
| Harris Corners | Harris, C. & Stephens, M. (1988). "A Combined Corner and Edge Detector" |

---

*This glossary is part of the Tinylens R package for image-first analysis in digital humanities and film studies.*
