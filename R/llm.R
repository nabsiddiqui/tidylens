#' LLM Vision Functions
#'
#' Functions for analyzing images using Large Language Models via Ollama (local only).
#' These functions require Ollama to be installed and running locally.
#'
#' @name llm
#' @keywords internal
NULL

#' Describe images using LLM vision
#'
#' Generate natural language descriptions of images using vision-capable LLMs.
#'
#' ## How it works (ELI5)
#' Think of this like showing a picture to a really smart friend who can describe
#' what they see in words. The LLM "looks" at the image and tells you what's in it,
#' including objects, people, colors, mood, and actions happening in the scene.
#'
#' @param tl_images A tl_images tibble.
#' @param model Model name. Default `"qwen2.5vl"` (recommended).
#'   Other options: `"llava"`, `"moondream"`.
#' @param prompt Custom prompt for description. Default asks for detailed scene
#'   description.
#' @param base_url Base URL for Ollama. Default `"http://localhost:11434"`.
#' @param downsample Max image dimension to send. Default 512 (reduces processing time).
#'
#' @return The input tibble with added column:
#'   - `llm_description`: Natural language description of the image.
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
#' [llm_check_ollama()] to verify Ollama is running.
#' [llm_list_models()] to see available models.
#'
#' @family llm
#' @export
llm_describe <- function(tl_images,
                         model = "qwen2.5vl",
                         prompt = "Describe this image in detail. Include: main subjects, setting, colors, mood, and any notable actions or elements.",
                         base_url = "http://localhost:11434",
                         downsample = 512) {
  validate_tl_images(tl_images)
  check_llm_packages()
  
  n <- nrow(tl_images)
  descriptions <- character(n)
  
  cli::cli_progress_bar("Describing images with LLM", total = n)
  
  for (i in seq_len(n)) {
    tryCatch({
      # Read and resize image
      img <- magick::image_read(tl_images$local_path[i])
      img <- magick::image_resize(img, paste0(downsample, "x"))
      
      # Convert to base64
      img_data <- magick::image_write(img, format = "jpeg")
      img_base64 <- base64enc::base64encode(img_data)
      
      descriptions[i] <- trimws(llm_ollama_vision(img_base64, prompt, model, base_url))
    }, error = function(e) {
      descriptions[i] <<- paste("Error:", conditionMessage(e))
    })
    
    cli::cli_progress_update()
  }
  
  cli::cli_progress_done()
  
  tl_images$llm_description <- descriptions
  tl_images
}

#' Classify images using LLM
#'
#' Classify images into categories using LLM vision.
#'
#' ## How it works (ELI5)
#' Like asking someone to sort photos into piles (action, landscape, portrait, etc.)
#' The LLM looks at each image and picks which category fits best.
#'
#' @param tl_images A tl_images tibble.
#' @param categories Character vector of category names to classify into.
#' @param model Model name. Default `"qwen2.5vl"`.
#' @param base_url Base URL for Ollama. Default `"http://localhost:11434"`.
#' @param downsample Max image dimension. Default 512.
#'
#' @return The input tibble with added column:
#'   - `llm_category`: Predicted category.
#'
#' @family llm
#' @export
llm_classify <- function(tl_images,
                         categories = c("portrait", "landscape", "action", "still life", "abstract"),
                         model = "qwen2.5vl",
                         base_url = "http://localhost:11434",
                         downsample = 512) {
  validate_tl_images(tl_images)
  check_llm_packages()
  
  # Build classification prompt
  cats_str <- paste(categories, collapse = ", ")
  prompt <- paste0(
    "Classify this image into exactly ONE of these categories: ", cats_str, ". ",
    "Respond with ONLY the category name, nothing else."
  )
  
  n <- nrow(tl_images)
  llm_categories <- character(n)
  
  cli::cli_progress_bar("Classifying images", total = n)
  
  for (i in seq_len(n)) {
    tryCatch({
      img <- magick::image_read(tl_images$local_path[i])
      img <- magick::image_resize(img, paste0(downsample, "x"))
      img_data <- magick::image_write(img, format = "jpeg")
      img_base64 <- base64enc::base64encode(img_data)
      
      response <- llm_ollama_vision(img_base64, prompt, model, base_url)
      
      # Clean and match to categories
      response_clean <- tolower(trimws(response))
      matched <- categories[which.min(adist(response_clean, tolower(categories)))]
      llm_categories[i] <- matched
      
    }, error = function(e) {
      llm_categories[i] <<- NA_character_
    })
    
    cli::cli_progress_update()
  }
  
  cli::cli_progress_done()
  
  tl_images$llm_category <- llm_categories
  tl_images
}

#' Analyze sentiment/mood of images using LLM
#'
#' Detect the emotional mood or sentiment of images.
#'
#' ## How it works (ELI5)
#' The LLM acts like an art critic, looking at the colors, composition, and content
#' to determine if an image feels happy, sad, tense, peaceful, etc.
#'
#' @param tl_images A tl_images tibble.
#' @param model Model name. Default `"qwen2.5vl"`.
#' @param base_url Base URL for Ollama. Default `"http://localhost:11434"`.
#' @param downsample Max image dimension. Default 512.
#'
#' @return The input tibble with added columns:
#'   - `llm_mood`: Primary mood/sentiment.
#'   - `llm_mood_valence`: Positive/negative/neutral.
#'   - `llm_mood_intensity`: Intensity level (low/medium/high).
#'
#' @family llm
#' @export
llm_sentiment <- function(tl_images,
                          model = "qwen2.5vl",
                          base_url = "http://localhost:11434",
                          downsample = 512) {
  validate_tl_images(tl_images)
  check_llm_packages()
  
  prompt <- paste0(
    "Analyze the mood/sentiment of this image. Respond in exactly this format:\n",
    "MOOD: [one-word mood like peaceful, tense, joyful, melancholic, dramatic, etc]\n",
    "VALENCE: [positive/negative/neutral]\n",
    "INTENSITY: [low/medium/high]"
  )
  
  n <- nrow(tl_images)
  moods <- character(n)
  valences <- character(n)
  intensities <- character(n)
  
  cli::cli_progress_bar("Analyzing mood", total = n)
  
  for (i in seq_len(n)) {
    tryCatch({
      img <- magick::image_read(tl_images$local_path[i])
      img <- magick::image_resize(img, paste0(downsample, "x"))
      img_data <- magick::image_write(img, format = "jpeg")
      img_base64 <- base64enc::base64encode(img_data)
      
      response <- llm_ollama_vision(img_base64, prompt, model, base_url)
      
      # Parse response
      lines <- strsplit(response, "\n")[[1]]
      mood_line <- grep("MOOD:", lines, value = TRUE, ignore.case = TRUE)
      valence_line <- grep("VALENCE:", lines, value = TRUE, ignore.case = TRUE)
      intensity_line <- grep("INTENSITY:", lines, value = TRUE, ignore.case = TRUE)
      
      moods[i] <- if (length(mood_line) > 0) {
        trimws(gsub("MOOD:", "", mood_line[1], ignore.case = TRUE))
      } else NA_character_
      
      valences[i] <- if (length(valence_line) > 0) {
        trimws(gsub("VALENCE:", "", valence_line[1], ignore.case = TRUE))
      } else NA_character_
      
      intensities[i] <- if (length(intensity_line) > 0) {
        trimws(gsub("INTENSITY:", "", intensity_line[1], ignore.case = TRUE))
      } else NA_character_
      
    }, error = function(e) {
      moods[i] <<- NA_character_
      valences[i] <<- NA_character_
      intensities[i] <<- NA_character_
    })
    
    cli::cli_progress_update()
  }
  
  cli::cli_progress_done()
  
  tl_images$llm_mood <- moods
  tl_images$llm_mood_valence <- valences
  tl_images$llm_mood_intensity <- intensities
  
  tl_images
}

#' Recognize objects in images using LLM
#'
#' Identify and list objects, people, and elements in images.
#'
#' ## How it works (ELI5)
#' Like playing "I Spy" - the LLM looks at the image and lists everything it sees:
#' people, objects, animals, text, buildings, etc.
#'
#' @param tl_images A tl_images tibble.
#' @param model Model name. Default `"qwen2.5vl"`.
#' @param base_url Base URL for Ollama. Default `"http://localhost:11434"`.
#' @param downsample Max image dimension. Default 512.
#'
#' @return The input tibble with added columns:
#'   - `llm_objects`: Comma-separated list of detected objects.
#'   - `llm_people_count`: Estimated number of people (0, 1, 2, "few", "many").
#'   - `llm_text_detected`: Any visible text in the image.
#'
#' @family llm
#' @export
llm_recognize <- function(tl_images,
                          model = "qwen2.5vl",
                          base_url = "http://localhost:11434",
                          downsample = 512) {
  validate_tl_images(tl_images)
  check_llm_packages()
  
  prompt <- paste0(
    "Analyze this image and respond in exactly this format:\n",
    "OBJECTS: [comma-separated list of main objects/elements]\n",
    "PEOPLE: [number or 'none', 'few', 'many']\n",
    "TEXT: [any visible text, or 'none']"
  )
  
  n <- nrow(tl_images)
  objects <- character(n)
  people <- character(n)
  texts <- character(n)
  
  cli::cli_progress_bar("Recognizing objects", total = n)
  
  for (i in seq_len(n)) {
    tryCatch({
      img <- magick::image_read(tl_images$local_path[i])
      img <- magick::image_resize(img, paste0(downsample, "x"))
      img_data <- magick::image_write(img, format = "jpeg")
      img_base64 <- base64enc::base64encode(img_data)
      
      response <- llm_ollama_vision(img_base64, prompt, model, base_url)
      
      # Parse response
      lines <- strsplit(response, "\n")[[1]]
      obj_line <- grep("OBJECTS:", lines, value = TRUE, ignore.case = TRUE)
      ppl_line <- grep("PEOPLE:", lines, value = TRUE, ignore.case = TRUE)
      txt_line <- grep("TEXT:", lines, value = TRUE, ignore.case = TRUE)
      
      objects[i] <- if (length(obj_line) > 0) {
        trimws(gsub("OBJECTS:", "", obj_line[1], ignore.case = TRUE))
      } else NA_character_
      
      people[i] <- if (length(ppl_line) > 0) {
        trimws(gsub("PEOPLE:", "", ppl_line[1], ignore.case = TRUE))
      } else NA_character_
      
      texts[i] <- if (length(txt_line) > 0) {
        trimws(gsub("TEXT:", "", txt_line[1], ignore.case = TRUE))
      } else NA_character_
      
    }, error = function(e) {
      objects[i] <<- NA_character_
      people[i] <<- NA_character_
      texts[i] <<- NA_character_
    })
    
    cli::cli_progress_update()
  }
  
  cli::cli_progress_done()
  
  tl_images$llm_objects <- objects
  tl_images$llm_people_count <- people
  tl_images$llm_text_detected <- texts
  
  tl_images
}

# ============= Internal helper functions =============

#' Check required packages for LLM functions
#' @noRd
check_llm_packages <- function() {
  if (!requireNamespace("httr2", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg httr2} is required for LLM functions. Install with: install.packages('httr2')")
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
llm_ollama_vision <- function(image_base64, prompt, model, base_url) {
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

# Null-coalescing operator
if (!exists("%||%")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}
