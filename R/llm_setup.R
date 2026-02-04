#' LLM Setup Helpers
#'
#' Functions to help users set up LLM dependencies for tinylens.
#'
#' @name llm_setup
#' @keywords internal
NULL

#' Check if Ollama is installed and running
#'
#' Verifies that Ollama is properly installed and the server is responding.
#'
#' @param base_url Base URL for Ollama server. Default `"http://localhost:11434"`.
#' @param verbose Print status messages. Default TRUE.
#'
#' @return Logical indicating if Ollama is available.
#'
#' @details
#' ## Installation Instructions
#'
#' ### macOS
#' 1. Download from https://ollama.com/download/Ollama-darwin.zip
#' 2. Unzip and drag to Applications folder
#' 3. Open Ollama.app - it runs in the menu bar
#'
#' ### Windows
#' 1. Download from https://ollama.com/download/OllamaSetup.exe
#' 2. Run the installer
#' 3. Ollama runs in the system tray
#'
#' ### Linux
#' Run in terminal: `curl -fsSL https://ollama.com/install.sh | sh`
#'
#' @examples
#' \dontrun{
#' llm_check_ollama()
#' }
#'
#' @family llm
#' @export
llm_check_ollama <- function(base_url = "http://localhost:11434", verbose = TRUE) {
  tryCatch({
    response <- httr2::request(base_url) |>
      httr2::req_url_path("/api/version") |>
      httr2::req_timeout(5) |>
      httr2::req_perform()

    if (httr2::resp_status(response) == 200) {
      if (verbose) {
        version_data <- httr2::resp_body_json(response)
        cli::cli_alert_success("Ollama is running (version: {version_data$version})")
      }
      return(invisible(TRUE))
    }
  }, error = function(e) {
    if (verbose) {
      cli::cli_alert_danger("Ollama is not running at {base_url}")
      cli::cli_alert_info("Start Ollama or see {.code ?check_ollama} for installation instructions")
    }
    return(invisible(FALSE))
  })

  invisible(FALSE)
}

#' List available vision models from Ollama
#'
#' Lists vision-capable models that can be used with tinylens LLM functions.
#'
#' @param base_url Base URL for Ollama server. Default `"http://localhost:11434"`.
#' @param only_installed If TRUE, only show installed models. Default FALSE.
#'
#' @return A tibble with model information, or NULL if Ollama is not running.
#'
#' @details
#' ## Recommended Vision Models
#'
#' | Model | Size | Description |
#' |-------|------|-------------|
#' | qwen2.5vl | 3-72B | Best overall vision model for captioning |
#' | qwen3-vl | 2-235B | Latest Qwen vision model |
#' | llama3.2-vision | 11-90B | Meta's vision model |
#' | llava | 7-34B | Classic vision-language model |
#' | minicpm-v | 8B | Efficient multimodal model |
#' | moondream | 1.8B | Small, fast, edge-optimized |
#' | gemma3 | 1-27B | Google's vision model |
#'
#' For film/humanities research, we recommend:
#' - **qwen2.5vl:7b** - Best balance of quality and speed.
#' - **moondream** - Fast processing for large batches.
#' - **llama3.2-vision** - Good general-purpose alternative.
#'
#' @examples
#' \dontrun{
#' llm_list_models()
#' llm_list_models(only_installed = TRUE)
#' }
#'
#' @family llm
#' @export
llm_list_models <- function(base_url = "http://localhost:11434",
                            only_installed = FALSE) {

  # Define recommended vision models
  recommended <- tibble::tibble(
    model = c("qwen2.5vl", "qwen3-vl", "llama3.2-vision", "llava",
              "minicpm-v", "moondream", "gemma3", "bakllava", "llava-llama3"),
    sizes = c("3b, 7b, 32b, 72b", "2b-235b", "11b, 90b", "7b, 13b, 34b",
              "8b", "1.8b", "1-27b", "7b", "8b"),
    description = c(
      "Best overall - excellent for detailed captions",
      "Latest Qwen vision model",
      "Meta's multimodal model",
      "Classic vision-language model",
      "Efficient multimodal model",
      "Small, fast, edge-optimized",
      "Google's vision model",
      "Mistral-based multimodal",
      "LLaVA on Llama 3"
    ),
    recommended = c(TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE)
  )

  # Check installed models
  if (only_installed || llm_check_ollama(base_url, verbose = FALSE)) {
    tryCatch({
      response <- httr2::request(base_url) |>
        httr2::req_url_path("/api/tags") |>
        httr2::req_timeout(10) |>
        httr2::req_perform()

      if (httr2::resp_status(response) == 200) {
        data <- httr2::resp_body_json(response)
        if (length(data$models) > 0) {
          installed <- sapply(data$models, function(m) m$name)
          # Extract base model name (before :)
          installed_base <- gsub(":.*", "", installed)

          recommended$installed <- sapply(recommended$model, function(m) {
            any(grepl(paste0("^", m), installed_base, ignore.case = TRUE))
          })

          if (only_installed) {
            recommended <- recommended[recommended$installed, ]
          }
        } else {
          recommended$installed <- FALSE
          if (only_installed) {
            cli::cli_alert_warning("No vision models installed. Use {.code llm_pull_model()} to install.")
            return(NULL)
          }
        }
      }
    }, error = function(e) {
      recommended$installed <- NA
    })
  } else {
    recommended$installed <- NA
  }

  recommended
}

#' Pull (download) a vision model from Ollama
#'
#' Downloads a vision-capable model for use with tinylens LLM functions.
#'
#' @param model Model name to download. Default `"qwen2.5vl:7b"`.
#' @param base_url Base URL for Ollama server. Default `"http://localhost:11434"`.
#'
#' @return TRUE if successful, FALSE otherwise.
#'
#' @details
#' ## Model Size Guide
#'
#' | Model | Size (RAM needed) | Speed | Quality |
#' |-------|-------------------|-------|---------|
#' | moondream | ~2GB | Very Fast | Good |
#' | qwen2.5vl:3b | ~3GB | Fast | Good |
#' | qwen2.5vl:7b | ~5GB | Medium | Excellent |
#' | llava:7b | ~5GB | Medium | Very Good |
#' | qwen2.5vl:32b | ~20GB | Slow | Superior |
#'
#' ## Recommendations by Hardware
#' - **8GB RAM**: moondream, qwen2.5vl:3b.
#' - **16GB RAM**: qwen2.5vl:7b, llava:7b.
#' - **32GB+ RAM**: qwen2.5vl:32b, llama3.2-vision:11b.
#'
#' @examples
#' \dontrun{
#' llm_pull_model("moondream")
#' llm_pull_model("qwen2.5vl:7b")
#' llm_pull_model("llama3.2-vision")
#' }
#'
#' @family llm
#' @export
llm_pull_model <- function(model = "qwen2.5vl:7b",
                           base_url = "http://localhost:11434") {

  if (!llm_check_ollama(base_url, verbose = FALSE)) {
    cli::cli_abort("Ollama is not running. Start Ollama first.")
  }

  cli::cli_alert_info("Downloading {model}... This may take several minutes.")
  cli::cli_alert_info("Model will be saved locally and only needs to be downloaded once.")

  tryCatch({
    response <- httr2::request(base_url) |>
      httr2::req_url_path("/api/pull") |>
      httr2::req_body_json(list(name = model, stream = FALSE)) |>
      httr2::req_timeout(3600) |>  # 1 hour timeout for large models
      httr2::req_perform()

    if (httr2::resp_status(response) == 200) {
      cli::cli_alert_success("Successfully downloaded {model}")
      return(invisible(TRUE))
    }
  }, error = function(e) {
    cli::cli_alert_danger("Failed to download {model}: {conditionMessage(e)}")
    cli::cli_alert_info("Try running in terminal: ollama pull {model}")
    return(invisible(FALSE))
  })

  invisible(FALSE)
}

#' Check LLM dependencies for tinylens
#'
#' Verifies all required packages and services for LLM functions.
#'
#' @param provider Which provider to check: `"ollama"`, `"openai"`, or `"all"`.
#' @param verbose Print detailed status. Default TRUE.
#'
#' @return A list with status of each dependency.
#'
#' @details
#' ## Required R Packages
#' - httr2: HTTP requests to LLM APIs.
#' - base64enc: Encoding images for API calls.
#' - jsonlite: Parsing API responses.
#'
#' ## For Ollama (Local LLM)
#' 1. Install Ollama (see [llm_check_ollama()]).
#' 2. Start Ollama.
#' 3. Pull a vision model: `llm_pull_model("qwen2.5vl:7b")`.
#'
#' ## For OpenAI (Cloud LLM)
#' 1. Get API key from https://platform.openai.com
#' 2. Set environment variable: `Sys.setenv(OPENAI_API_KEY = "your-key")`.
#'
#' @examples
#' \dontrun{
#' llm_check_dependencies("ollama")
#' llm_check_dependencies("all")
#' }
#'
#' @family llm
#' @export
llm_check_dependencies <- function(provider = "all", verbose = TRUE) {

  status <- list(
    r_packages = list(),
    ollama = NULL,
    openai = NULL
  )

  # Check R packages
  required_packages <- c("httr2", "base64enc", "jsonlite")
  for (pkg in required_packages) {
    installed <- requireNamespace(pkg, quietly = TRUE)
    status$r_packages[[pkg]] <- installed
    if (verbose) {
      if (installed) {
        cli::cli_alert_success("{.pkg {pkg}} is installed")
      } else {
        cli::cli_alert_danger("{.pkg {pkg}} is NOT installed - run: install.packages(\"{pkg}\")")
      }
    }
  }

  # Check Ollama
  if (provider %in% c("ollama", "all")) {
    status$ollama$running <- llm_check_ollama(verbose = verbose)

    if (status$ollama$running) {
      models <- llm_list_models(only_installed = TRUE)
      if (!is.null(models) && nrow(models) > 0) {
        status$ollama$models <- models$model
        if (verbose) {
          cli::cli_alert_success("Vision models installed: {paste(models$model, collapse = ', ')}")
        }
      } else {
        status$ollama$models <- character(0)
        if (verbose) {
          cli::cli_alert_warning("No vision models installed. Run: llm_pull_model(\"qwen2.5vl:7b\")")
        }
      }
    }
  }

  # Check OpenAI
  if (provider %in% c("openai", "all")) {
    api_key <- Sys.getenv("OPENAI_API_KEY")
    status$openai$key_set <- nchar(api_key) > 0

    if (verbose) {
      if (status$openai$key_set) {
        cli::cli_alert_success("OPENAI_API_KEY is set")
      } else {
        cli::cli_alert_info("OPENAI_API_KEY not set (optional for cloud LLM)")
      }
    }
  }

  invisible(status)
}

#' Print setup instructions for LLM functions
#'
#' Displays comprehensive setup instructions for all supported platforms.
#'
#' @param platform Operating system: `"auto"`, `"macos"`, `"windows"`, or `"linux"`.
#'
#' @return NULL (prints instructions).
#'
#' @family llm
#' @export
llm_setup_instructions <- function(platform = "auto") {

  if (platform == "auto") {
    platform <- tolower(Sys.info()["sysname"])
    platform <- switch(platform,
                       "darwin" = "macos",
                       "windows" = "windows",
                       "linux")
  }

  cli::cli_h1("tinylens LLM Setup Instructions")

  cli::cli_h2("Step 1: Install Required R Packages")
  cli::cli_code("install.packages(c('httr2', 'base64enc', 'jsonlite'))")

  cli::cli_h2("Step 2: Install Ollama (for local LLM)")

  if (platform == "macos") {
    cli::cli_h3("macOS Installation")
    cli::cli_bullets(c(
      " " = "Option A: Download from https://ollama.com/download",
      " " = "Option B: Use Homebrew: brew install ollama"
    ))
    cli::cli_text("After installation, Ollama runs in the menu bar.")

  } else if (platform == "windows") {
    cli::cli_h3("Windows Installation")
    cli::cli_bullets(c(
      " " = "Download from: https://ollama.com/download/OllamaSetup.exe",
      " " = "Run the installer and follow prompts"
    ))
    cli::cli_text("After installation, Ollama runs in the system tray.")

  } else {
    cli::cli_h3("Linux Installation")
    cli::cli_code("curl -fsSL https://ollama.com/install.sh | sh")
    cli::cli_text("After installation, start with: ollama serve")
  }

  cli::cli_h2("Step 3: Download a Vision Model")
  cli::cli_text("In terminal (or R with llm_pull_model()):")
  cli::cli_code("ollama pull qwen2.5vl:7b")

  cli::cli_h3("Recommended Models by RAM")
  cli::cli_bullets(c(
    " " = "8GB RAM: ollama pull moondream",
    " " = "16GB RAM: ollama pull qwen2.5vl:7b (recommended)",
    " " = "32GB+ RAM: ollama pull llama3.2-vision"
  ))

  cli::cli_h2("Step 4: Verify Setup")
  cli::cli_code('
library(tinylens)
llm_check_ollama()       # Should show Ollama is running
llm_list_models()        # List available models
  ')

  cli::cli_h2("Step 5: Use LLM Functions")
  cli::cli_code('
images <- load_images("my_images/")
images |>
  llm_describe(provider = "ollama", model = "qwen2.5vl:7b") |>
  llm_classify(categories = c("action", "dialogue", "landscape"))
  ')

  cli::cli_h2("Alternative: OpenAI (Cloud)")
  cli::cli_text("For cloud-based processing (requires API key):")
  cli::cli_code('
Sys.setenv(OPENAI_API_KEY = "your-key-from-platform.openai.com")
images |> llm_describe(provider = "openai", model = "gpt-4o")
  ')

  invisible(NULL)
}
