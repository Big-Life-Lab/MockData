#' Read study configuration from CSV file
#'
#' Loads a study configuration file and returns a named list with typed parameters.
#' Configuration files specify study design, time windows, event parameters, and
#' data quality settings for generating mock survival data.
#'
#' @param config_path character. Path to configuration CSV file
#'
#' @return Named list with configuration parameters, properly typed according to
#'   the 'type' column in the config file
#'
#' @details
#' The configuration CSV must have columns: parameter, value, type, description
#'
#' Supported types:
#' - character: Text values
#' - date: Dates (YYYY-MM-DD format)
#' - integer: Whole numbers
#' - numeric: Decimal numbers
#' - logical: TRUE/FALSE values
#'
#' @examples
#' \dontrun{
#' # Load example configuration
#' config <- read_study_config(
#'   system.file("extdata/study_config_example.csv", package = "MockData")
#' )
#'
#' # Access parameters
#' config$study_design
#' config$accrual_start
#' config$sample_size
#' }
#'
#' @family configuration
#' @export
read_study_config <- function(config_path) {
  # Read configuration file
  if (!file.exists(config_path)) {
    stop("Configuration file not found: ", config_path)
  }

  config_df <- read.csv(
    config_path,
    header = TRUE,
    stringsAsFactors = FALSE,
    strip.white = TRUE
  )

  # Validate required columns
  required_cols <- c("parameter", "value", "type", "description")
  missing_cols <- setdiff(required_cols, names(config_df))
  if (length(missing_cols) > 0) {
    stop("Configuration file missing required columns: ",
         paste(missing_cols, collapse = ", "))
  }

  # Convert to named list with proper types
  config_list <- list()

  for (i in seq_len(nrow(config_df))) {
    param_name <- config_df$parameter[i]
    param_value <- config_df$value[i]
    param_type <- config_df$type[i]

    # Skip empty parameters
    if (is.na(param_name) || param_name == "") {
      next
    }

    # Type conversion
    typed_value <- tryCatch({
      switch(param_type,
        "character" = as.character(param_value),
        "date" = as.Date(param_value),
        "integer" = as.integer(param_value),
        "numeric" = as.numeric(param_value),
        "logical" = as.logical(param_value),
        stop("Unsupported type: ", param_type)
      )
    }, error = function(e) {
      stop("Error converting parameter '", param_name, "' to type '",
           param_type, "': ", e$message)
    })

    config_list[[param_name]] <- typed_value
  }

  # Validate study design
  if (!is.null(config_list$study_design)) {
    valid_designs <- c("open_cohort", "fixed_followup")
    if (!(config_list$study_design %in% valid_designs)) {
      stop("Invalid study_design: ", config_list$study_design,
           ". Must be one of: ", paste(valid_designs, collapse = ", "))
    }
  }

  return(config_list)
}


#' Validate study configuration
#'
#' Checks that a study configuration has all required parameters and valid values
#' for the specified study design.
#'
#' @param config list. Configuration from read_study_config()
#'
#' @return logical. TRUE if valid, otherwise stops with error message
#'
#' @details
#' Validation checks:
#' - Required parameters present
#' - Date ranges valid (start < end)
#' - Proportions in valid range (0-1)
#' - Design-specific parameters present
#'
#' @examples
#' \dontrun{
#' config <- read_study_config("study_config.csv")
#' validate_study_config(config)
#' }
#'
#' @family configuration
#' @export
validate_study_config <- function(config) {
  # Check required parameters
  required_params <- c("study_design", "accrual_start", "accrual_end",
                       "sample_size", "seed")

  missing_params <- setdiff(required_params, names(config))
  if (length(missing_params) > 0) {
    stop("Missing required parameters: ", paste(missing_params, collapse = ", "))
  }

  # Validate date ranges
  if (config$accrual_start >= config$accrual_end) {
    stop("accrual_start must be before accrual_end")
  }

  # Design-specific validation
  if (config$study_design == "open_cohort") {
    if (is.null(config$max_followup_date)) {
      stop("open_cohort design requires max_followup_date parameter")
    }
    if (config$max_followup_date <= config$accrual_end) {
      stop("max_followup_date must be after accrual_end")
    }
  } else if (config$study_design == "fixed_followup") {
    required_followup <- c("followup_min", "followup_max")
    missing_followup <- setdiff(required_followup, names(config))
    if (length(missing_followup) > 0) {
      stop("fixed_followup design requires: ",
           paste(missing_followup, collapse = ", "))
    }
    if (config$followup_min >= config$followup_max) {
      stop("followup_min must be less than followup_max")
    }
  }

  # Validate proportions
  prop_params <- c("prop_censored", "prop_NA", "prop_invalid")
  for (param in prop_params) {
    if (!is.null(config[[param]])) {
      if (config[[param]] < 0 || config[[param]] > 1) {
        stop(param, " must be between 0 and 1")
      }
    }
  }

  # Validate sample size
  if (config$sample_size < 1) {
    stop("sample_size must be at least 1")
  }

  return(TRUE)
}
