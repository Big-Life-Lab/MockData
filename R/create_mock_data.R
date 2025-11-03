#' Create mock data from configuration files
#'
#' @description
#' Main orchestrator function that generates complete mock datasets from
#' v0.2 configuration files. Reads config and details files, filters for
#' enabled variables, dispatches to type-specific create_* functions, and
#' assembles results into a complete data frame.
#'
#' @param config_path Character. Path to mock_data_config.csv file.
#' @param details_path Character. Optional path to mock_data_config_details.csv.
#'   If NULL, uses uniform distributions (fallback mode).
#' @param n Integer. Number of observations to generate (default 1000).
#' @param seed Integer. Optional random seed for reproducibility.
#' @param source_format Character. Format to simulate post-import data from different sources.
#'   Options: "analysis" (default, R Date objects), "csv" (character strings),
#'   "sas" (numeric days since 1960-01-01). Only affects date variables.
#' @param validate Logical. Whether to validate configuration files (default TRUE).
#' @param verbose Logical. Whether to print progress messages (default FALSE).
#'
#' @return Data frame with n rows and one column per enabled variable.
#'
#' @details
#' The function performs the following steps:
#' 1. Read and validate config file
#' 2. Read and validate details file (if provided)
#' 3. Filter for enabled variables
#' 4. Set global seed (if provided)
#' 5. Loop through variables in position order:
#'    - Extract var_row and details_subset
#'    - Dispatch to create_cat_var, create_con_var, create_date_var, or create_survival_dates
#'    - Merge result into data frame
#' 6. Return complete dataset
#'
#' **Fallback mode**: If details_path = NULL, uses uniform distributions for all
#' enabled variables.
#'
#' **Variable types supported**:
#' - categorical: create_cat_var()
#' - continuous: create_con_var()
#' - date: create_date_var()
#' - survival: create_survival_dates()
#' - character: create_char_var() (if implemented)
#' - integer: create_int_var() (if implemented)
#'
#' @examples
#' \dontrun{
#' # Generate mock data with details
#' mock_data <- create_mock_data(
#'   config_path = "inst/extdata/mock_data_config.csv",
#'   details_path = "inst/extdata/mock_data_config_details.csv",
#'   n = 1000,
#'   seed = 123
#' )
#'
#' # Fallback mode (uniform distributions)
#' mock_data <- create_mock_data(
#'   config_path = "inst/extdata/mock_data_config.csv",
#'   details_path = NULL,
#'   n = 500
#' )
#'
#' # View structure
#' str(mock_data)
#' head(mock_data)
#' }
#'
#' @family data-generation
#' @export
create_mock_data <- function(config_path,
                             details_path = NULL,
                             n = 1000,
                             seed = NULL,
                             source_format = "analysis",
                             validate = TRUE,
                             verbose = FALSE) {

  # Input validation
  if (!file.exists(config_path)) {
    stop("Configuration file does not exist: ", config_path)
  }

  if (!is.null(details_path) && !file.exists(details_path)) {
    stop("Details file does not exist: ", details_path)
  }

  if (n < 1) {
    stop("n must be at least 1")
  }

  # Validate source_format parameter
  valid_formats <- c("analysis", "csv", "sas")
  if (!source_format %in% valid_formats) {
    stop("source_format must be one of: ",
         paste(valid_formats, collapse = ", "),
         "\n  Got: ", source_format)
  }

  # Read configuration
  if (verbose) message("Reading configuration file...")
  config <- read_mock_data_config(config_path, validate = validate)

  # Read details (if provided)
  details <- NULL
  if (!is.null(details_path)) {
    if (verbose) message("Reading details file...")
    details <- read_mock_data_config_details(details_path, validate = validate)
  } else {
    if (verbose) message("No details file provided - using fallback mode (uniform distributions)")
  }

  # Filter for enabled variables
  if (verbose) message("Filtering for enabled variables...")
  enabled_vars <- get_enabled_variables(config)

  if (nrow(enabled_vars) == 0) {
    stop("No enabled variables found in configuration. ",
         "Add role='enabled' to variables you want to generate.")
  }

  if (verbose) {
    message("Found ", nrow(enabled_vars), " enabled variable(s): ",
            paste(enabled_vars$variable, collapse = ", "))
  }

  # Set global seed if provided
  if (!is.null(seed)) {
    if (verbose) message("Setting random seed: ", seed)
    set.seed(seed)
  }

  # Initialize empty data frame
  df_mock <- data.frame(row.names = seq_len(n))

  # Generate variables in position order
  if (verbose) message("Generating ", n, " observations...")

  for (i in seq_len(nrow(enabled_vars))) {
    var_row <- enabled_vars[i, ]
    var_name <- var_row$variable
    var_type <- tolower(var_row$variableType)

    # Detect date variables by role column (v2.1.0 hack: dates are "Continuous" with date-related roles)
    var_role <- if ("role" %in% names(var_row) && !is.na(var_row$role)) {
      var_row$role
    } else {
      ""
    }
    # Check if role contains "date" (e.g., "index-date", "outcome-date", "date")
    is_date_var <- grepl("date", var_role, ignore.case = TRUE)

    if (verbose) {
      display_type <- if (is_date_var) paste0(var_type, "/date") else var_type
      message("  [", i, "/", nrow(enabled_vars), "] Generating ",
              var_name, " (", display_type, ")")
    }

    # Get details for this variable
    details_subset <- get_variable_details(details, variable_name = var_name)

    # Dispatch to type-specific generator
    var_data <- tryCatch({
      # Override type dispatch for date variables
      if (is_date_var) {
        create_date_var(
          var_row = var_row,
          details_subset = details_subset,
          n = n,
          seed = NULL,
          source_format = source_format,
          df_mock = df_mock
        )
      } else {
        switch(var_type,
          "categorical" = create_cat_var(
            var_row = var_row,
            details_subset = details_subset,
            n = n,
            seed = NULL,  # Global seed already set
            df_mock = df_mock
          ),
          "continuous" = create_con_var(
            var_row = var_row,
            details_subset = details_subset,
            n = n,
            seed = NULL,
            df_mock = df_mock
          ),
          "date" = create_date_var(
            var_row = var_row,
            details_subset = details_subset,
            n = n,
            seed = NULL,
            source_format = source_format,
            df_mock = df_mock
          ),
          "survival" = create_survival_dates(
            var_row = var_row,
            details_subset = details_subset,
            n = n,
            seed = NULL
          ),
          "character" = {
            warning("Character variable type not yet implemented: ", var_name)
            NULL
          },
          "integer" = {
            warning("Integer variable type not yet implemented: ", var_name)
            NULL
          },
          {
            warning("Unknown variable type '", var_type, "' for variable: ", var_name)
            NULL
          }
        )
      }
    }, error = function(e) {
      warning("Error generating variable ", var_name, ": ", e$message)
      NULL
    })

    # Merge into dataset if generation succeeded
    if (!is.null(var_data) && is.data.frame(var_data)) {
      # Add columns from var_data to df_mock
      for (col_name in names(var_data)) {
        df_mock[[col_name]] <- var_data[[col_name]]
      }
    }
  }

  if (verbose) {
    message("Mock data generation complete!")
    message("  Rows: ", nrow(df_mock))
    message("  Variables: ", ncol(df_mock))
  }

  return(df_mock)
}
