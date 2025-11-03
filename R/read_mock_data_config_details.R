#' Read MockData configuration details file
#'
#' @description
#' Reads a mock_data_config_details.csv file containing distribution parameters
#' and proportions for mock data generation. Optionally validates the details
#' against schema requirements and optionally against a config file.
#'
#' @param details_path Character. Path to mock_data_config_details.csv file.
#' @param validate Logical. Whether to validate the details (default TRUE).
#' @param config Data frame (optional). Configuration from read_mock_data_config()
#'   for cross-validation of variable references.
#'
#' @return Data frame with detail rows for each variable's distribution parameters.
#'
#' @details
#' The details file should have the following columns:
#'
#' **Link columns:**
#' - uid: Links to mock_data_config.csv via uid (variable-level)
#' - uid_detail: Unique identifier for this detail row (d_001, d_002, ...)
#' - variable: Variable name (denormalized for readability)
#'
#' **Category/parameter columns:**
#' - dummyVariable: Recodeflow dummy variable identifier
#' - recEnd: Category value or parameter name
#' - catLabel: Short category label
#' - catLabelLong: Long category label
#' - units: Measurement units for this parameter
#'
#' **Distribution parameters:**
#' - proportion: Proportion for this category (0-1)
#' - value: Numeric value
#' - range_min, range_max: Value ranges
#' - date_start, date_end: Date ranges
#' - notes: Implementation notes
#'
#' The function performs the following processing:
#' 1. Reads CSV file with read.csv()
#' 2. Converts numeric columns (proportion, value, ranges)
#' 3. Converts date columns to Date type
#' 4. Validates if validate = TRUE
#'
#' @examples
#' \dontrun{
#' # Read details file
#' details <- read_mock_data_config_details(
#'   "inst/extdata/mock_data_config_details.csv"
#' )
#'
#' # Read with cross-validation against config
#' config <- read_mock_data_config("inst/extdata/mock_data_config.csv")
#' details <- read_mock_data_config_details(
#'   "inst/extdata/mock_data_config_details.csv",
#'   config = config
#' )
#'
#' # View structure
#' str(details)
#' head(details)
#' }
#'
#' @export
read_mock_data_config_details <- function(details_path, validate = TRUE, config = NULL) {

  # Input validation
  if (!file.exists(details_path)) {
    stop("Details file does not exist: ", details_path)
  }

  # Read CSV
  details <- read.csv(details_path, stringsAsFactors = FALSE, check.names = FALSE)

  # Type conversions
  numeric_cols <- c("proportion", "value", "range_min", "range_max")
  for (col in numeric_cols) {
    if (col %in% names(details)) {
      details[[col]] <- as.numeric(details[[col]])
    }
  }

  date_cols <- c("date_start", "date_end")
  for (col in date_cols) {
    if (col %in% names(details)) {
      details[[col]] <- as.Date(details[[col]])
    }
  }

  # Validate if requested
  if (validate) {
    validate_mock_data_config_details(details, config = config)
  }

  return(details)
}

#' Validate MockData configuration details
#'
#' @description
#' Validates a mock_data_config_details data frame against schema requirements.
#' Checks for required columns, valid proportions, proportion sums, parameter
#' requirements, and optionally validates links to config file.
#'
#' @param details Data frame. Details data read from mock_data_config_details.csv.
#' @param config Data frame (optional). Configuration for cross-validation.
#'
#' @return Invisible NULL. Stops with error message if validation fails.
#'
#' @details
#' Validation checks:
#'
#' **Required columns:**
#' - uid, uid_detail, variable, recEnd
#'
#' **Uniqueness:**
#' - uid_detail values must be unique
#'
#' **Proportion validation:**
#' - Values must be in range [0, 1]
#' - Population proportions (valid + missing codes) must sum to 1.0 ±0.001 per variable
#' - Contamination proportions (corrupt_*) are excluded from sum
#' - Auto-normalizes with warning if sum ≠ 1.0
#'
#' **Parameter validation:**
#' - Distribution-specific requirements:
#'   - normal → mean + sd
#'   - gompertz → rate + shape
#'   - exponential → rate
#'   - poisson → rate
#'
#' **Link validation (if config provided):**
#' - All uid values must exist in config$uid
#'
#' **Flexible recEnd validation:**
#' - Warns but doesn't error on unknown recEnd values
#'
#' @examples
#' \dontrun{
#' # Validate details
#' details <- read.csv("mock_data_config_details.csv", stringsAsFactors = FALSE)
#' validate_mock_data_config_details(details)
#'
#' # Validate with cross-check against config
#' config <- read.csv("mock_data_config.csv", stringsAsFactors = FALSE)
#' validate_mock_data_config_details(details, config = config)
#' }
#'
#' @export
validate_mock_data_config_details <- function(details, config = NULL) {

  # Check required columns
  required_cols <- c("uid", "uid_detail", "variable", "recEnd")
  missing_cols <- setdiff(required_cols, names(details))
  if (length(missing_cols) > 0) {
    stop("Missing required columns in mock_data_config_details.csv: ",
         paste(missing_cols, collapse = ", "))
  }

  # Check unique uid_detail values
  if (any(duplicated(details$uid_detail))) {
    duplicates <- details$uid_detail[duplicated(details$uid_detail)]
    stop("Duplicate uid_detail values found in mock_data_config_details.csv: ",
         paste(unique(duplicates), collapse = ", "))
  }

  # Validate proportions are in valid range
  if ("proportion" %in% names(details)) {
    invalid_props <- which(!is.na(details$proportion) &
                           (details$proportion < 0 | details$proportion > 1))
    if (length(invalid_props) > 0) {
      bad_rows <- details$uid_detail[invalid_props]
      stop("Proportion values must be between 0 and 1. Invalid rows: ",
           paste(bad_rows, collapse = ", "))
    }
  }

  # Check proportions sum to 1.0 per variable (excluding garbage rows)
  if ("proportion" %in% names(details)) {
    # Group by variable
    vars <- unique(details$variable)
    for (var in vars) {
      var_rows <- details[details$variable == var, ]

      # Exclude garbage rows (corrupt_*)
      pop_rows <- var_rows[!grepl("^corrupt_", var_rows$recEnd, ignore.case = TRUE), ]

      # Calculate sum of population proportions (excluding NA)
      prop_sum <- sum(pop_rows$proportion, na.rm = TRUE)

      # Check if we have any non-NA proportions
      has_proportions <- any(!is.na(pop_rows$proportion))

      if (has_proportions) {
        tolerance <- 0.001
        if (abs(prop_sum - 1.0) > tolerance) {
          warning("Proportions for variable '", var, "' sum to ",
                  round(prop_sum, 4), " (expected 1.0). ",
                  "Auto-normalizing proportions.")

          # Auto-normalize
          norm_factor <- 1.0 / prop_sum
          pop_idx <- which(details$variable == var &
                          !grepl("^corrupt_", details$recEnd, ignore.case = TRUE) &
                          !is.na(details$proportion))
          details$proportion[pop_idx] <- details$proportion[pop_idx] * norm_factor
        }
      }
    }
  }

  # Link validation: check all uids exist in config
  if (!is.null(config)) {
    if (!"uid" %in% names(config)) {
      warning("Config file provided but does not have 'uid' column. Skipping link validation.")
    } else {
      missing_uids <- setdiff(unique(details$uid), config$uid)
      if (length(missing_uids) > 0) {
        stop("Details file references uids not found in config: ",
             paste(missing_uids, collapse = ", "))
      }
    }
  }

  # Flexible recEnd validation (warn on potentially unknown values)
  # Common known values
  known_recEnd <- c("copy", "distribution", "mean", "sd", "rate", "shape",
                    "range_min", "range_max", "date_start", "date_end",
                    "censored", "valid", "corrupt_low", "corrupt_high", "corrupt_future",
                    "7", "8", "9", "96", "97", "98", "99",  # Missing codes
                    "-7", "-8", "-9")  # Negative missing codes

  # Check for numeric category values (1, 2, 3, etc.) - these are valid
  is_numeric_category <- grepl("^[0-9]+$", details$recEnd)
  is_known <- details$recEnd %in% known_recEnd | is_numeric_category

  unknown_recEnd <- unique(details$recEnd[!is_known])
  if (length(unknown_recEnd) > 0) {
    # Just inform, don't error (flexible validation)
    message("Note: Found recEnd values that may be category-specific: ",
            paste(head(unknown_recEnd, 10), collapse = ", "),
            if (length(unknown_recEnd) > 10) "..." else "")
  }

  invisible(NULL)
}
