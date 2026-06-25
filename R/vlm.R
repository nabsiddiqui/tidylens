#' VLM Vision Functions
#'
#' Functions for analyzing images using Vision-Language Models via Ollama
#' (local only). These functions require Ollama to be installed and running
#' locally with a vision-capable model (e.g. qwen2.5vl, llava, moondream).
#'
#' @name vlm
#' @keywords internal
NULL

#' Describe images using VLM vision
#'
#' Generate natural language descriptions of images using vision-capable
#' vision-language models.
#'
#' ## How it works (ELI5)
#' Think of this like showing a picture to a really smart friend who can
#' describe what they see in words. The VLM "looks" at the image and tells
#' you what's in it, including objects, people, colors, mood, and actions
#' happening in the scene.
#'
#' @param tl_images A tl_images tibble.
#' @param model Model name. Default `"qwen2.5vl"` (recommended).
#'   Other options: `"llava"`, `"moondream"`.
#' @param prompt Custom prompt for description. Default asks for detailed
#'   scene description.
#' @param base_url Base URL for Ollama. Default `"http://localhost:11434"`.
#' @param downsample Max image dimension to send. Default 512 (reduces
#'   processing time).
#'
#' @return The input tibble with added column:
#'   - `vlm_description`: Natural language description of the image.
#'
#' @details
#' Requires Ollama to be installed and running (https://ollama.ai).
#' Pull a vision model first with: `ollama pull qwen2.5vl`
#'
#' Recommended models by quality/speed:
#' - `moondream` - Fastest, ~2GB RAM, good for quick previews.
#' - `qwen2.5vl` - Best balance (recommended default), ~5GB RAM.
#' - `llava` - Good general purpose, ~5GB RAM.
#'
#' @seealso
#' [vlm_check_ollama()] to verify Ollama is running.
#' [vlm_list_models()] to see available models.
#'
#' @family vlm
#' @export
vlm_describe <- function(tl_images,
                         model = "qwen2.5vl",
                         prompt = "Describe this image in detail. Include: main subjects, setting, colors, mood, and any notable actions or elements.",
                         base_url = "http://localhost:11434",
                         downsample = 512) {
  validate_tl_images(tl_images)
  check_vlm_packages()

  results <- vlm_map(tl_images, prompt, function(resp) {
    list(vlm_description = trimws(resp))
  }, model, base_url, downsample, "Describing images with VLM")

  bind_results(tl_images, results)
}

#' Classify images using VLM
#'
#' Classify images into categories using VLM vision.
#'
#' ## How it works (ELI5)
#' Like asking someone to sort photos into piles (action, landscape, portrait,
#' etc.) The VLM looks at each image and picks which category fits best.
#'
#' @param tl_images A tl_images tibble.
#' @param categories Character vector of category names to classify into.
#' @param model Model name. Default `"qwen2.5vl"`.
#' @param base_url Base URL for Ollama. Default `"http://localhost:11434"`.
#' @param downsample Max image dimension. Default 512.
#'
#' @return The input tibble with added column:
#'   - `vlm_category`: Predicted category.
#'
#' @family vlm
#' @export
vlm_classify <- function(tl_images,
                         categories = c("portrait", "landscape", "action", "still life", "abstract"),
                         model = "qwen2.5vl",
                         base_url = "http://localhost:11434",
                         downsample = 512) {
  validate_tl_images(tl_images)
  check_vlm_packages()

  cats_str <- paste(categories, collapse = ", ")
  prompt <- paste0(
    "Classify this image into exactly ONE of these categories: ", cats_str, ". ",
    "Respond with ONLY the category name, nothing else."
  )

  results <- vlm_map(tl_images, prompt, function(resp) {
    response_clean <- tolower(trimws(resp))
    matched <- categories[which.min(adist(response_clean, tolower(categories)))]
    list(vlm_category = matched)
  }, model, base_url, downsample, "Classifying images")

  bind_results(tl_images, results)
}

#' Analyze sentiment/mood of images using VLM
#'
#' Detect the emotional mood or sentiment of images.
#'
#' ## How it works (ELI5)
#' The VLM acts like an art critic, looking at the colors, composition, and
#' content to determine if an image feels happy, sad, tense, peaceful, etc.
#'
#' @param tl_images A tl_images tibble.
#' @param model Model name. Default `"qwen2.5vl"`.
#' @param base_url Base URL for Ollama. Default `"http://localhost:11434"`.
#' @param downsample Max image dimension. Default 512.
#'
#' @return The input tibble with added columns:
#'   - `vlm_mood`: Primary mood/sentiment.
#'   - `vlm_mood_valence`: Positive/negative/neutral.
#'   - `vlm_mood_intensity`: Intensity level (low/medium/high).
#'
#' @family vlm
#' @export
vlm_sentiment <- function(tl_images,
                           model = "qwen2.5vl",
                           base_url = "http://localhost:11434",
                           downsample = 512) {
  validate_tl_images(tl_images)
  check_vlm_packages()

  prompt <- paste0(
    "Analyze the mood/sentiment of this image. Respond in exactly this format:\n",
    "MOOD: [one-word mood like peaceful, tense, joyful, melancholic, dramatic, etc]\n",
    "VALENCE: [positive/negative/neutral]\n",
    "INTENSITY: [low/medium/high]"
  )

  results <- vlm_map(tl_images, prompt, function(resp) {
    lines <- strsplit(resp, "\n")[[1]]
    mood_line <- grep("MOOD:", lines, value = TRUE, ignore.case = TRUE)
    valence_line <- grep("VALENCE:", lines, value = TRUE, ignore.case = TRUE)
    intensity_line <- grep("INTENSITY:", lines, value = TRUE, ignore.case = TRUE)

    list(
      vlm_mood = if (length(mood_line) > 0) trimws(gsub("MOOD:", "", mood_line[1], ignore.case = TRUE)) else NA_character_,
      vlm_mood_valence = if (length(valence_line) > 0) trimws(gsub("VALENCE:", "", valence_line[1], ignore.case = TRUE)) else NA_character_,
      vlm_mood_intensity = if (length(intensity_line) > 0) trimws(gsub("INTENSITY:", "", intensity_line[1], ignore.case = TRUE)) else NA_character_
    )
  }, model, base_url, downsample, "Analyzing mood")

  bind_results(tl_images, results)
}

#' Recognize objects in images using VLM
#'
#' Identify and list objects, people, and elements in images.
#'
#' ## How it works (ELI5)
#' Like playing "I Spy" - the VLM looks at the image and lists everything it
#' sees: people, objects, animals, text, buildings, etc.
#'
#' @param tl_images A tl_images tibble.
#' @param model Model name. Default `"qwen2.5vl"`.
#' @param base_url Base URL for Ollama. Default `"http://localhost:11434"`.
#' @param downsample Max image dimension. Default 512.
#'
#' @return The input tibble with added columns:
#'   - `vlm_objects`: Comma-separated list of detected objects.
#'   - `vlm_people_count`: Estimated number of people (0, 1, 2, "few", "many").
#'   - `vlm_text_detected`: Any visible text in the image.
#'
#' @family vlm
#' @export
vlm_recognize <- function(tl_images,
                          model = "qwen2.5vl",
                          base_url = "http://localhost:11434",
                          downsample = 512) {
  validate_tl_images(tl_images)
  check_vlm_packages()

  prompt <- paste0(
    "Analyze this image and respond in exactly this format:\n",
    "OBJECTS: [comma-separated list of main objects/elements]\n",
    "PEOPLE: [number or 'none', 'few', 'many']\n",
    "TEXT: [any visible text, or 'none']"
  )

  results <- vlm_map(tl_images, prompt, function(resp) {
    lines <- strsplit(resp, "\n")[[1]]
    obj_line <- grep("OBJECTS:", lines, value = TRUE, ignore.case = TRUE)
    ppl_line <- grep("PEOPLE:", lines, value = TRUE, ignore.case = TRUE)
    txt_line <- grep("TEXT:", lines, value = TRUE, ignore.case = TRUE)

    list(
      vlm_objects = if (length(obj_line) > 0) trimws(gsub("OBJECTS:", "", obj_line[1], ignore.case = TRUE)) else NA_character_,
      vlm_people_count = if (length(ppl_line) > 0) trimws(gsub("PEOPLE:", "", ppl_line[1], ignore.case = TRUE)) else NA_character_,
      vlm_text_detected = if (length(txt_line) > 0) trimws(gsub("TEXT:", "", txt_line[1], ignore.case = TRUE)) else NA_character_
    )
  }, model, base_url, downsample, "Recognizing objects")

  bind_results(tl_images, results)
}

#' Classify shot scale using VLM
#'
#' Assign each image a cinematographic shot scale label (Close, Medium, or
#' Long) using a vision-language model via Ollama. This is the optional
#' high-accuracy path; the default [film_classify_scale()] uses a classical
#' Random Forest on engineered features and requires no VLM.
#'
#' ## How it works (ELI5)
#' Show the frame to a VLM and ask it whether the shot is close, medium, or
#' long. The VLM uses its understanding of framing, figure-ground relations,
#' and cinematographic conventions to pick the best-fitting category.
#'
#' ## Shot Scale Categories
#'
#' | Group | What's in Frame |
#' |-------|-----------------|
#' | Close | Face or detail fills the frame (ECU, CU, MCU) |
#' | Medium | Waist to knees (MS, MLS) |
#' | Long | Full body or landscape (LS, ELS) |
#'
#' @param tl_images A tl_images tibble.
#' @param model Model name. Default `"qwen2.5vl"` (recommended).
#' @param base_url Base URL for Ollama. Default `"http://localhost:11434"`.
#' @param downsample Max image dimension to send. Default 512.
#'
#' @return The input tibble with added columns:
#'   - `shot_scale`: Close, Medium, or Long.
#'   - `shot_scale_confidence`: 1.0 if the VLM's response matched a known
#'     category, otherwise 0.0.
#'
#' @details
#' Requires Ollama to be installed and running with a vision-capable model.
#' The classical Random Forest in [film_classify_scale()] is the default and
#' runs without any VLM dependency; use this function when you want the
#' higher accuracy of a VLM and have Ollama set up.
#'
#' @seealso [film_classify_scale()] for the classical default path.
#'
#' @family vlm
#' @export
vlm_scale <- function(tl_images,
                      model = "qwen2.5vl",
                      base_url = "http://localhost:11434",
                      downsample = 512) {
  validate_tl_images(tl_images)
  check_vlm_packages()

  prompt <- paste0(
    "Classify this film frame's shot scale into exactly one of: ",
    "Close (face or detail fills the frame), ",
    "Medium (waist to knees visible), ",
    "Long (full body or landscape). ",
    "Respond with ONLY the category name, nothing else."
  )

  valid <- c("close", "medium", "long")

  results <- vlm_map(tl_images, prompt, function(resp) {
    response_clean <- tolower(trimws(resp))
    matched <- valid[which.min(adist(response_clean, valid))]
    list(
      shot_scale = tools::toTitleCase(matched),
      shot_scale_confidence = if (any(adist(response_clean, valid) <= 2)) 1.0 else 0.0
    )
  }, model, base_url, downsample, "Classifying shot scales (VLM)")

  bind_results(tl_images, results)
}

# ============= Internal helper functions =============

#' Check required packages for VLM functions
#' @noRd
check_vlm_packages <- function() {
  if (!requireNamespace("httr2", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg httr2} is required for VLM functions. Install with: install.packages('httr2')")
  }
  if (!requireNamespace("base64enc", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg base64enc} is required. Install with: install.packages('base64enc')")
  }
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg jsonlite} is required. Install with: install.packages('jsonlite')")
  }
}

#' Call Ollama vision API
#' @noRd
vlm_ollama_vision <- function(image_base64, prompt, model, base_url) {
  body <- list(
    model = model,
    prompt = prompt,
    images = list(image_base64),
    stream = FALSE
  )

  resp <- httr2::request(paste0(base_url, "/api/generate")) |>
    httr2::req_body_json(body) |>
    httr2::req_timeout(120) |>
    httr2::req_perform()

  result <- httr2::resp_body_json(resp)
  result$response
}

#' Apply a prompt + parse function over images via Ollama VLM
#'
#' Shared body for vlm_describe/classify/sentiment/recognize/scale:
#' read -> resize -> base64 -> vlm_ollama_vision -> parse_fn.
#'
#' @param tl_images A tl_images tibble.
#' @param prompt Prompt string.
#' @param parse_fn function(response_str) -> named list of columns.
#' @param model Model name.
#' @param base_url Ollama base URL.
#' @param downsample Max image dimension.
#' @param msg Progress bar message.
#' @return List of parsed results (one per image).
#' @noRd
vlm_map <- function(tl_images, prompt, parse_fn, model, base_url, downsample, msg) {
  n <- nrow(tl_images)
  results <- vector("list", n)

  cli::cli_progress_bar(msg, total = n)

  for (i in seq_len(n)) {
    results[[i]] <- tryCatch({
      img <- magick::image_read(tl_images$local_path[i])
      img <- magick::image_resize(img, paste0(downsample, "x"))
      img_data <- magick::image_write(img, format = "jpeg")
      img_base64 <- base64enc::base64encode(img_data)
      response <- vlm_ollama_vision(img_base64, prompt, model, base_url)
      parse_fn(response)
    }, error = function(e) NULL)
    cli::cli_progress_update()
  }

  cli::cli_progress_done()
  results
}