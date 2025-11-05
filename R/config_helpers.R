#' Get variables by role
#'
#' @description
#' Filters a MockData configuration to return only variables matching one or more roles.
#' The role column can contain comma-separated values (e.g., "predictor, outcome"),
#' so this function uses pattern matching to find all matching variables.
#'
#' @param config Data frame. Configuration from read_mock_data_config().
#' @param roles Character vector. Role(s) to filter for (e.g., c("enabled", "predictor")).
#'
#' @return Data frame with subset of config rows matching any of the specified roles.
#'
#' @details
#' This function handles comma-separated role values by using grepl() pattern matching.
#' A variable matches if its role column contains any of the specified role values.
#'
#' Common role values:
#' - enabled: Variables to generate in mock data
#' - predictor: Predictor variables for analysis
#' - outcome: Outcome variables
#' - confounder: Confounding variables
#' - exposure: Exposure variables
#' - intermediate: Intermediate/derived variables
#' - table1_master, table1_sub: Table 1 display variables
#' - metadata: Study metadata (dates, identifiers)
#'
#' @examples
#' \dontrun{
#' # Load configuration
#' config <- read_mock_data_config("inst/extdata/mock_data_config.csv")
#'
#' # Get all predictor variables
#' predictors <- get_variables_by_role(config, "predictor")
#'
#' # Get variables with multiple roles
#' outcomes <- get_variables_by_role(config, c("outcome", "exposure"))
#'
#' # Get Table 1 variables
#' table1_vars <- get_variables_by_role(config, c("table1_master", "table1_sub"))
#' }
#'
#' @family configuration
#' @export
get_variables_by_role <- function(config, roles) {

  # Input validation
  if (!is.data.frame(config)) {
    stop("config must be a data frame")
  }

  if (!"role" %in% names(config)) {
    stop("config must have a 'role' column")
  }

  if (!is.character(roles) || length(roles) == 0) {
    stop("roles must be a non-empty character vector")
  }

  # Build pattern to match any of the specified roles
  # Use word boundaries to avoid partial matches (e.g., "table1" shouldn't match "table1_master")
  pattern <- paste0("\\b(", paste(roles, collapse = "|"), ")\\b")

  # Filter using grepl (handles comma-separated role values)
  matches <- grepl(pattern, config$role, ignore.case = FALSE)

  result <- config[matches, ]

  # Return empty data frame with same structure if no matches
  if (nrow(result) == 0) {
    warning("No variables found with role(s): ", paste(roles, collapse = ", "))
  }

  return(result)
}


#' Get enabled variables
#'
#' @description
#' Convenience function to get all variables marked with role "enabled",
#' excluding derived variables by default. Derived variables should be
#' calculated after generating raw mock data, not generated directly.
#'
#' @param config Data frame. Configuration from read_mock_data_config().
#' @param exclude_derived Logical. If TRUE (default), exclude variables with
#'   role "derived". Derived variables are calculated from raw variables and
#'   should not be generated as mock data.
#'
#' @return Data frame with subset of config rows where role contains "enabled"
#'   but not "derived" (unless exclude_derived = FALSE).
#'
#' @details
#' The "enabled" role indicates variables that should be included when generating
#' mock data. However, variables with role "derived" are calculated from other
#' variables and should NOT be generated directly.
#'
#' **Derived variables**: Variables calculated from raw data (e.g., BMI from
#' height and weight, pack-years from smoking variables). These have
#' `role = "derived,enabled"` in metadata and `variableStart` starting with
#' "DerivedVar::".
#'
#' **Default behavior**: Excludes derived variables to prevent generating
#' variables that should be calculated from raw data.
#'
#' @examples
#' \dontrun{
#' # Load configuration
#' config <- read_mock_data_config("inst/extdata/mock_data_config.csv")
#'
#' # Get only enabled RAW variables (excludes derived, default)
#' enabled_vars <- get_enabled_variables(config)
#'
#' # Include derived variables (not recommended)
#' all_enabled <- get_enabled_variables(config, exclude_derived = FALSE)
#'
#' # View enabled variable names
#' enabled_vars$variable
#' }
#'
#' @family configuration
#' @export
get_enabled_variables <- function(config, exclude_derived = TRUE) {
  # Get all enabled variables
  enabled_vars <- get_variables_by_role(config, "enabled")

  # Exclude derived variables if requested (default)
  if (exclude_derived) {
    # Check if role column contains "derived"
    is_derived <- grepl("\\bderived\\b", enabled_vars$role, ignore.case = FALSE)

    # Filter out derived variables
    enabled_vars <- enabled_vars[!is_derived, ]

    # Return empty data frame with same structure if no matches
    if (nrow(enabled_vars) == 0) {
      warning("No enabled non-derived variables found. ",
              "All enabled variables are derived variables.")
    }
  }

  return(enabled_vars)
}
