# Output Reference

Tidylens functions return tibbles. The main object is a `tl_frames` tibble: one row per extracted frame or representative shot frame.

## Core Columns

| Column | Type | Meaning |
|--------|------|---------|
| `id` | character | Frame identifier |
| `source` | character | Frame file path as originally recorded |
| `local_path` | character | Normalized local path to the frame image |
| `width`, `height` | integer | Frame dimensions |
| `format` | character | Image format |
| `video_source` | character | Source video path, when extracted from video |

## Shot Columns

`frame_extract_shots()` and `detect_shot_changes()` add timing data:

| Column | Type | Meaning |
|--------|------|---------|
| `shot_id` | integer | Shot sequence number |
| `start_time`, `end_time` | numeric | Shot start/end in seconds |
| `duration` | numeric | Shot duration in seconds |
| `shot_scale` | character | `Close`, `Medium`, or `Long` |
| `shot_scale_confidence` | numeric | Random Forest confidence |

## Color And Composition Columns

Examples include `brightness`, `brightness_std`, `colourfulness`, `warmth`, `tint`, `dominant_color_hex`, `hue_entropy`, `simplicity`, `symmetry_horizontal`, `symmetry_vertical`, `balance`, `rule_of_thirds`, `visual_complexity`, and `center_bias`.

## Detection And Classification Columns

| Function | Added columns |
|----------|---------------|
| `frame_detect_faces()` | `n_faces`, `faces`, `face_area_prop` |
| `frame_classify_scale()` | `shot_scale`, `shot_scale_confidence` |
| `frame_classify_angle()` | `camera_angle`, `horizon_position`, `tilt_angle` |

## Vector Representations

`frame_extract_color_histogram()` adds `color_hist`, a list-column of normalized RGB histograms with length `bins * 3`.
