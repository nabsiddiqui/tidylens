#' Neural Network Embeddings
#'
#' Functions for computing image embeddings using neural networks.
#'
#' @name embeddings
#' @keywords internal
NULL

#' Extract image embeddings
#'
#' Extract dense embeddings from images using pretrained neural networks.
#' These embeddings can be used downstream for similarity search, clustering,
#' or as input features for other models.
#'
#' Requires the torch and torchvision packages.
#'
#' @param tl_images A tl_images tibble.
#' @param model Model to use: `"resnet18"`, `"resnet50"`, or `"vgg16"`.
#'   Default `"resnet18"`.
#' @param layer Which layer to extract from. Default `"avgpool"`.
#' @param batch_size Number of images to process at once. Default 8.
#' @param device `"cpu"` or `"cuda"`. Default `"cpu"`.
#'
#' @return The input tibble with added column:
#'   - `embedding`: List column containing numeric embedding vectors.
#'
#' @family embeddings
#' @export
extract_embeddings <- function(tl_images,
                               model = "resnet18",
                               layer = "avgpool",
                               batch_size = 8,
                               device = "cpu") {
  validate_tl_images(tl_images)
  
  if (!requireNamespace("torch", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg torch} is required. Install with: install.packages('torch')")
  }
  
  if (!requireNamespace("torchvision", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg torchvision} is required. Install with: install.packages('torchvision')")
  }
  
  # Ensure torch is installed
  if (!torch::torch_is_installed()) {
    cli::cli_abort("Torch backend not installed. Run: torch::install_torch()")
  }
  
  # Load pretrained model
  cli::cli_alert_info("Loading {model} model...")
  
  net <- switch(model,
    "resnet18" = torchvision::model_resnet18(pretrained = TRUE),
    "resnet50" = torchvision::model_resnet50(pretrained = TRUE),
    "vgg16" = torchvision::model_vgg16(pretrained = TRUE),
    cli::cli_abort("Unknown model: {model}. Use 'resnet18', 'resnet50', or 'vgg16'.")
  )
  
  net$eval()
  net$to(device = device)
  
  # Create feature extractor by removing final classification layer
  if (model %in% c("resnet18", "resnet50")) {
    # Remove the fc layer - use as feature extractor
    modules <- net$children
    feature_extractor <- torch::nn_sequential(!!!head(modules, -1))
  } else {
    # VGG - use features + avgpool
    feature_extractor <- net$features
  }
  
  feature_extractor$eval()
  
  # Image preprocessing
  normalize <- torchvision::transform_normalize(
    mean = c(0.485, 0.456, 0.406),
    std = c(0.229, 0.224, 0.225)
  )
  
  preprocess <- function(img_path) {
    img <- magick::image_read(img_path)
    img <- magick::image_resize(img, "224x224!")
    
    # Convert to tensor
    data <- as.integer(magick::image_data(img, channels = "rgb"))
    tensor <- torch::torch_tensor(data, dtype = torch::torch_float())
    tensor <- tensor$permute(c(3, 1, 2))  # HWC to CHW
    tensor <- tensor / 255.0
    tensor <- normalize(tensor)
    tensor$unsqueeze(1)  # Add batch dimension
  }
  
  n <- nrow(tl_images)
  embeddings <- vector("list", n)
  
  cli::cli_progress_bar("Computing embeddings", total = n)
  
  torch::with_no_grad({
    for (i in seq_len(n)) {
      tryCatch({
        input <- preprocess(tl_images$local_path[i])
        input <- input$to(device = device)
        
        features <- feature_extractor(input)
        
        # Flatten to 1D vector
        emb <- features$squeeze()$flatten()$cpu()$numpy()
        embeddings[[i]] <- as.numeric(emb)
        
      }, error = function(e) {
        cli::cli_warn("Failed to compute embedding for {tl_images$id[i]}: {e$message}")
        embeddings[[i]] <<- NA
      })
      
      cli::cli_progress_update()
    }
  })
  
  cli::cli_progress_done()
  
  tl_images$embedding <- embeddings
  
  tl_images
}

#' Extract color histogram embedding
#'
#' A lightweight alternative to neural embeddings using color histograms.
#' Color histograms capture the distribution of colors in an image and can
#' be used for simple similarity comparisons or as features for clustering.
#'
#' @param tl_images A tl_images tibble.
#' @param bins Number of bins per channel. Default 16.
#' @param downsample Maximum side length for analysis. Default 100.
#'
#' @return The input tibble with added column:
#'   - `color_hist`: List column with color histogram vectors (length = bins * 3).
#'
#' @family embeddings
#' @export
extract_color_histogram <- function(tl_images, bins = 16, downsample = 100) {
  validate_tl_images(tl_images)
  
  results <- map_images(tl_images, function(img) {
    data <- as.integer(magick::image_data(img, channels = "rgb"))
    # data is HxWxC after as.integer
    r <- data[, , 1]
    g <- data[, , 2]
    b <- data[, , 3]
    
    # Quantize to bins
    r_bin <- floor(r / (256 / bins))
    g_bin <- floor(g / (256 / bins))
    b_bin <- floor(b / (256 / bins))
    
    # Create histograms
    r_hist <- tabulate(r_bin + 1, nbins = bins)
    g_hist <- tabulate(g_bin + 1, nbins = bins)
    b_hist <- tabulate(b_bin + 1, nbins = bins)
    
    # Normalize
    total <- length(r)
    hist_vec <- c(r_hist, g_hist, b_hist) / total
    
    list(color_hist = hist_vec)
  }, downsample = downsample, msg = "Computing color histograms")
  
  tl_images$color_hist <- purrr::map(results, ~ .x$color_hist)
  
  tl_images
}
