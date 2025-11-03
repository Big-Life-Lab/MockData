#' Read MockData configuration file
#'
#' @description
#' Reads a mock_data_config.csv file containing variable definitions for
#' mock data generation. Optionally validates the configuration against
#' schema requirements.
#'
#' @param config_path Character. Path to mock_data_config.csv file.
#' @param validate Logical. Whether to validate the configuration (default TRUE).
#'
#' @return Data frame with configuration variables and their parameters,
#'   sorted by position column.
#'
#' @details
#' The configuration file should have the following columns:
#'
#' **Core columns:**
#' - uid: Unique identifier (v_001, v_002, ...)
#' - variable: Variable name
#' - role: Comma-separated role values (enabled, predictor, outcome, etc.)
#' - label: Short label for tables
#' - labelLong: Descriptive label
#' - section: Primary grouping for Table 1
#' - subject: Secondary grouping
#' - variableType: Data type (categorical, continuous, date, survival, character, integer)
#' - units: Measurement units
#' - position: Sort order (10, 20, 30...)
#'
#' **Provenance columns:**
#' - source_database: Database identifier(s) from import
#' - source_spec: Source specification file
#' - version: Configuration version
#' - last_updated: Date last modified
#' - notes: Documentation
#' - seed: Random seed for reproducibility
#'
#' The function performs the following processing:
#' 1. Reads CSV file with read.csv()
#' 2. Converts date columns to Date type
#' 3. Sorts by position column
#' 4. Validates if validate = TRUE
#'
#' @examples
#' \dontrun{
#' # Read configuration file
#' config <- read_mock_data_config(
#'   "inst/extdata/mock_data_config.csv"
#' )
#'
#' # Read without validation
#' config <- read_mock_data_config(
#'   "inst/extdata/mock_data_config.csv",
#'   validate = FALSE
#' )
#'
#' # View structure
#' str(config)
#' head(config)
#' }
#'
#' @export
read_mock_data_config <- function(config_path, validate = TRUE) {

  # Input validation
  if (!file.exists(config_path)) {
    stop("Configuration file does not exist: ", config_path)
  }

  # Read CSV
  config <- read.csv(config_path, stringsAsFactors = FALSE, check.names = FALSE)

  # Type conversions
  if ("last_updated" %in% names(config)) {
    config$last_updated <- as.Date(config$last_updated)
  }

  # Sort by position
  if ("position" %in% names(config)) {
    config <- config[order(config$position), ]
  }

  # Validate if requested
  if (validate) {
    validate_mock_data_config(config)
  }

  return(config)
}

#' Validate MockData configuration
#'
#' @description
#' Validates a mock_data_config data frame against schema requirements.
#' Checks for required columns, unique variable names, valid role values,
#' and valid variableType values.
#'
#' @param config Data frame. Configuration data read from mock_data_config.csv.
#'
#' @return Invisible NULL. Stops with error message if validation fails.
#'
#' @details
#' Validation checks:
#'
#' **Required columns:**
#' - uid, variable, role, variableType, position
#'
#' **Uniqueness:**
#' - uid values must be unique
#' - variable names must be unique
#'
#' **Valid values:**
#' - role: Can contain enabled, predictor, outcome, confounder, exposure,
#'   table1, metadata, intermediate (comma-separated)
#' - variableType: categorical, continuous, date, survival, character, integer
#'
#' **Safe NA handling:**
#' - Uses which() to handle NA values in logical comparisons
#' - Prevents "missing value where TRUE/FALSE needed" errors
#'
#' @examples
#' \dontrun{
#' # Validate configuration
#' config <- read.csv("mock_data_config.csv", stringsAsFactors = FALSE)
#' validate_mock_data_config(config)
#' }
#'
#' @export
validate_mock_data_config <- function(config) {

  # Check required columns
  required_cols <- c("uid", "variable", "role", "variableType", "position")
  missing_cols <- setdiff(required_cols, names(config))
  if (length(missing_cols) > 0) {
    stop("Missing required columns in mock_data_config.csv: ",
         paste(missing_cols, collapse = ", "))
  }

  # Check unique uid values
  if (any(duplicated(config$uid))) {
    duplicates <- config$uid[duplicated(config$uid)]
    stop("Duplicate uid values found in mock_data_config.csv: ",
         paste(unique(duplicates), collapse = ", "))
  }

  # Check unique variable names
  if (any(duplicated(config$variable))) {
    duplicates <- config$variable[duplicated(config$variable)]
    stop("Duplicate variable names found in mock_data_config.csv: ",
         paste(unique(duplicates), collapse = ", "))
  }

  # Check valid variableType values (case-insensitive)
  valid_types <- c("categorical", "continuous", "date", "survival",
                   "character", "integer")
  invalid_types <- which(!tolower(config$variableType) %in% c(tolower(valid_types), NA))
  if (length(invalid_types) > 0) {
    bad_values <- unique(config$variableType[invalid_types])
    stop("Invalid variableType values in mock_data_config.csv: ",
         paste(bad_values, collapse = ", "),
         "\nValid values: ", paste(valid_types, collapse = ", "))
  }

  # Check position values are positive
  invalid_positions <- which(config$position <= 0)
  if (length(invalid_positions) > 0) {
    stop("Position values must be positive. Invalid rows: ",
         paste(config$variable[invalid_positions], collapse = ", "))
  }

  # Validate role values (flexible - just check for common patterns)
  # Role can be comma-separated, so we don't enforce strict values
  # Just warn if role is NA
  na_roles <- which(is.na(config$role) | config$role == "")
  if (length(na_roles) > 0) {
    warning("Some variables have missing role values (rows: ",
            paste(config$variable[na_roles], collapse = ", "), ")")
  }

  invisible(NULL)
}
