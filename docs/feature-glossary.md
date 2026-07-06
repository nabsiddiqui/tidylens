# Feature Glossary

Tidylens computes classical visual features from extracted film frames.

| Family | Functions | Interpretation |
|--------|-----------|----------------|
| Brightness | `frame_extract_brightness()` | Overall lightness/darkness |
| Color | `frame_extract_colourfulness()`, `frame_extract_warmth()`, `frame_extract_hue_histogram()` | Palette intensity, warm/cool balance, hue distribution |
| Dominant color | `frame_extract_dominant_color()` | Most common RGB color in the frame |
| Composition | `frame_extract_fluency_metrics()`, `frame_extract_rule_of_thirds()`, `frame_extract_center_bias()` | Symmetry, balance, thirds alignment, centeredness |
| Faces | `frame_detect_faces()` | Face count and face-area coverage |
| Shot scale | `frame_classify_scale()` | Classical RF classification into `Close`, `Medium`, `Long` |
| Camera angle | `frame_classify_angle()` | Heuristic high/low/eye-level/dutch angle estimate |
| Vector representation | `frame_extract_color_histogram()` | Normalized RGB histogram for similarity or clustering |

This glossary reflects v3.x: classical visual features only, with no CNN-based features.
