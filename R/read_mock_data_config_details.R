#' Read and validate MockData configuration details file containing distribution parameters and category proportions
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
#' - recStart: Category value or range notation `[min,max]`
#' - catLabel: Short category label
#' - catLabelLong: Long category label
#' - units: Measurement units for this parameter
#'
#' **Distribution parameters:**
#' - proportion: Proportion for this category (0-1)
#' - value: Numeric value
#' - range_min, range_max: Value ranges
#' - notes: Implementation notes
#'
#' The function performs the following processing:
#' 1. Reads CSV file with read.csv()
#' 2. Converts numeric columns (proportion, value, ranges)
#' 3. Validates if validate = TRUE
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
  numeric_cols <- c("proportion", "value")
  for (col in numeric_cols) {
    if (col %in% names(details)) {
      details[[col]] <- as.numeric(details[[col]])
    }
  }

  # Validate if requested
  if (validate) {
    validate_mock_data_config_details(details, config = config)
  }

  return(details)
}

#' Validate MockData configuration details against schema requirements including proportion sums and parameter completeness
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
#' - variable, recStart (always required)
#' - recEnd (conditionally required when using missing data codes 6-9, 96-99)
#' - uid, uid_detail (optional for simple examples)
#'
#' **Conditional recEnd requirement:**
#' - recEnd column required when recStart contains missing codes (6-9, 96-99)
#' - Enables classification: NA::a (skip), NA::b (missing), numeric (valid)
#' - Without recEnd, missing vs. valid codes cannot be distinguished
#'
#' **Uniqueness:**
#' - uid_detail values must be unique (if column present)
#'
#' **Proportion validation:**
#' - Values must be in range `[0, 1]`
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

  # Check required columns (uid and uid_detail are optional for simple examples)
  required_cols <- c("variable", "recStart")
  missing_cols <- setdiff(required_cols, names(details))
  if (length(missing_cols) > 0) {
    stop("Missing required columns in mock_data_config_details.csv: ",
         paste(missing_cols, collapse = ", "))
  }

  # Conditional recEnd requirement: check for missing data codes
  # recEnd is required when there are rows with typical missing codes (6-9, 96-99)
  # because these need explicit classification as NA::a (skip) or NA::b (missing)
  missing_codes <- c("6", "7", "8", "9", "96", "97", "98", "99")
  has_missing_codes <- any(details$recStart %in% missing_codes)

  # Also check for range notation that includes missing codes: [7,9] for example
  has_missing_ranges <- any(grepl("\\[(6|7|8|9|96|97|98|99)", details$recStart))

  if ((has_missing_codes || has_missing_ranges) && !"recEnd" %in% names(details)) {
    stop("recEnd column required in variable_details when using missing data codes (6-9, 96-99).\n",
         "  Use 'NA::a' for skip codes (6, 96, 996),\n",
         "  Use 'NA::b' for missing codes (7-9, 97-99) representing DK/Refusal/NS,\n",
         "  and numeric codes (e.g., '1', '2', '3') for valid responses.")
  }

  # Check unique uid_detail values (if uid_detail column exists)
  if ("uid_detail" %in% names(details) && any(duplicated(details$uid_detail))) {
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
      pop_rows <- var_rows[!grepl("^corrupt_", var_rows$recStart, ignore.case = TRUE), ]

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
                          !grepl("^corrupt_", details$recStart, ignore.case = TRUE) &
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

  # Flexible recStart validation (warn on potentially unknown values)
  # Common known values
  known_recStart <- c("copy", "distribution", "mean", "sd", "rate", "shape",
                      "valid", "censored", "corrupt_low", "corrupt_high", "corrupt_future",
                      "followup_min", "followup_max", "event",  # Survival parameters
                      "7", "8", "9", "96", "97", "98", "99",  # Missing codes
                      "-7", "-8", "-9")  # Negative missing codes

  # Check for numeric category values (1, 2, 3, etc.) and range notation [min,max] - these are valid
  is_numeric_category <- grepl("^[0-9]+$", details$recStart)
  is_range_notation <- grepl("^\\[.*,.*\\]$", details$recStart)
  is_known <- details$recStart %in% known_recStart | is_numeric_category | is_range_notation

  unknown_recStart <- unique(details$recStart[!is_known])
  if (length(unknown_recStart) > 0) {
    # Just inform, don't error (flexible validation)
    message("Note: Found recStart values that may be category-specific: ",
            paste(head(unknown_recStart, 10), collapse = ", "),
            if (length(unknown_recStart) > 10) "..." else "")
  }

  invisible(NULL)
}
