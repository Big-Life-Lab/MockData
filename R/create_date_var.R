#' Create date variable for MockData
#'
#' Creates a mock date variable based on specifications from variable_details.
#'
#' **Configuration v0.2 format (NEW):**
#' @param var_row data.frame. Single row from mock_data_config (contains variable metadata)
#' @param details_subset data.frame. Rows from mock_data_config_details for this variable
#' @param n integer. Number of observations to generate
#' @param seed integer. Random seed for reproducibility. If NULL, uses global seed.
#' @param source_format character. Format to simulate post-import data: "analysis" (R Date objects),
#'   "csv" (character ISO strings), "sas" (numeric days since 1960-01-01). Default: "analysis".
#' @param df_mock data.frame. The current mock data (to check if variable already exists)
#'
#' **Configuration v0.1 format (LEGACY):**
#' @param var_raw character. The RAW variable name (as it appears in source data)
#' @param cycle character. The database or cycle identifier (e.g., "cycle1", "HC1")
#' @param variable_details data.frame. Variable details metadata
#' @param variables data.frame. Variables metadata (optional, for validation)
#' @param length integer. The desired length of the mock data vector
#' @param prop_NA numeric. Optional. Proportion of NA values (0 to 1). If NULL, no NAs introduced.
#' @param prop_invalid numeric. Optional. Proportion of invalid out-of-period dates (0 to 1). If NULL, no invalid dates generated.
#' @param distribution character. Distribution type: "uniform" (default), "gompertz", or "exponential"
#'
#' @return data.frame with one column (the new date variable), or NULL if:
#'  - Variable details not found (v0.1 only)
#'  - Variable already exists in df_mock
#'  - No valid date range found
#'
#' @details
#' **v0.2 format (NEW):**
#' - Extracts date_start and date_end from details_subset
#' - Generates dates uniformly distributed between start and end
#' - Applies missing codes with `apply_missing_codes()`
#' - Adds garbage using `make_garbage()` if garbage rows present
#' - Supports fallback mode: uniform distribution [2000-01-01, 2025-12-31] when details_subset is NULL
#'
#' **v0.1 format (LEGACY):**
#' - Uses `get_variable_details_for_raw()` to find variable specifications
#' - Parses SAS date format from recStart: "[01JAN2001, 31MAR2017]"
#' - Supports "uniform", "gompertz", or "exponential" distribution
#' - Handles prop_NA and prop_invalid parameters
#'
#' The function auto-detects which format based on parameter names.
#'
#' @examples
#' \dontrun{
#' # v0.2 format - called by create_mock_data()
#' config <- read_mock_data_config("mock_data_config.csv")
#' details <- read_mock_data_config_details("mock_data_config_details.csv")
#' var_row <- config[config$variable == "index_date", ]
#' details_subset <- get_variable_details(details, variable_name = "index_date")
#' mock_var <- create_date_var(var_row, details_subset, n = 1000, seed = 123)
#'
#' # v0.1 format (legacy)
#' mock_death_date <- create_date_var(
#'   var_raw = "death_date",
#'   cycle = "ices",
#'   variable_details = variable_details,
#'   length = 1000,
#'   df_mock = existing_data,
#'   prop_NA = 0.02,
#'   distribution = "gompertz"
#' )
#' }
#'
#' @family generators
#' @export
create_date_var <- function(var_row = NULL, details_subset = NULL, n = NULL,
                             seed = NULL, source_format = "analysis", df_mock = NULL,
                             # v0.1 legacy parameters
                             var_raw = NULL, cycle = NULL, variable_details = NULL,
                             variables = NULL, length = NULL,
                             prop_NA = NULL, prop_invalid = NULL, distribution = "uniform") {

  # Helper function to convert dates to specified source format
  convert_date_format <- function(date_vector, format) {
    if (format == "csv") {
      # CSV format: character ISO strings (e.g., "2001-01-15")
      return(as.character(date_vector))
    } else if (format == "sas") {
      # SAS format: numeric days since 1960-01-01
      sas_epoch <- as.Date("1960-01-01")
      return(as.numeric(date_vector - sas_epoch))
    } else {
      # "analysis" or default: keep as R Date objects
      return(date_vector)
    }
  }

  # Auto-detect format based on parameters
  use_v02 <- !is.null(var_row) && is.data.frame(var_row) && nrow(var_row) == 1

  if (use_v02) {
    # ========== v0.2 IMPLEMENTATION ==========
    var_name <- var_row$variable

    # Check if variable already exists in mock data
    if (!is.null(df_mock) && var_name %in% names(df_mock)) {
      return(NULL)
    }

    # Set seed if provided
    if (!is.null(seed)) set.seed(seed)

    # FALLBACK MODE: Default date range if details_subset is NULL
    if (is.null(details_subset) || nrow(details_subset) == 0) {
      # Default range: 2000-01-01 to 2025-12-31
      date_start <- as.Date("2000-01-01")
      date_end <- as.Date("2025-12-31")

      values <- sample(seq(date_start, date_end, by = "day"), size = n, replace = TRUE)

      # Apply source format conversion
      values <- convert_date_format(values, source_format)

      col <- data.frame(
        new = values,
        stringsAsFactors = FALSE
      )
      names(col)[1] <- var_name
      return(col)
    }

    # Extract date_start and date_end from details_subset
    # Look for rows with recEnd = "date_start" and recEnd = "date_end"
    date_start_row <- details_subset[details_subset$recEnd == "date_start", ]
    date_end_row <- details_subset[details_subset$recEnd == "date_end", ]

    if (nrow(date_start_row) == 0 || nrow(date_end_row) == 0) {
      warning(paste0("Missing date_start or date_end for ", var_name, ". Using defaults."))
      date_start <- as.Date("2000-01-01")
      date_end <- as.Date("2025-12-31")
    } else {
      # Parse dates from date_start and date_end columns
      date_start <- as.Date(date_start_row$date_start[1])
      date_end <- as.Date(date_end_row$date_end[1])

      if (is.na(date_start) || is.na(date_end)) {
        warning(paste0("Invalid date_start or date_end for ", var_name, ". Using defaults."))
        date_start <- as.Date("2000-01-01")
        date_end <- as.Date("2025-12-31")
      }
    }

    # STEP 1: Generate population (all valid dates)
    # For date variables, we don't use proportions - just generate uniform distribution
    # Date variables typically don't have missing codes in v0.2 format

    # Generate valid dates uniformly distributed
    valid_dates <- seq(date_start, date_end, by = "day")
    values <- sample(valid_dates, size = n, replace = TRUE)

    # STEP 3: Apply garbage if specified
    if (has_garbage(details_subset)) {
      values <- make_garbage(
        values = values,
        details_subset = details_subset,
        variable_type = "date",
        seed = NULL  # Already set globally if needed
      )
    }

    # STEP 4: Apply source format conversion
    values <- convert_date_format(values, source_format)

    # Return as data frame
    col <- data.frame(
      new = values,
      stringsAsFactors = FALSE
    )
    names(col)[1] <- var_name
    return(col)

  } else {
    # ========== v0.1 LEGACY IMPLEMENTATION ==========

    # Get variable details for this raw variable and cycle
    var_details <- get_variable_details_for_raw(
      var_raw,
      cycle,
      variable_details,
      variables
    )

    if (nrow(var_details) == 0) {
      # No variable details found for this raw variable in this cycle
      return(NULL)
    }

    if (!is.null(df_mock) && var_raw %in% names(df_mock)) {
      # Variable already exists in mock data
      return(NULL)
    }

    # Extract date range from recStart
    rec_start_values <- var_details$recStart[
      !grepl("NA", var_details$recEnd, fixed = TRUE)
    ]

    pattern <- "^\\[\\d{2}[A-Z]{3}\\d{4},\\s*\\d{2}[A-Z]{3}\\d{4}\\]$"

    # Check if any value matches the pattern (handle vector input)
    if (!any(stringr::str_detect(rec_start_values, pattern))) {
      # recStart value does not match the expected pattern of [startdate, enddate]
      return(NULL)
    }

    dates <- stringr::str_extract_all(rec_start_values, "\\d{2}[A-Z]{3}\\d{4}")[[
      1
    ]]

    parsed <- lubridate::parse_date_time(dates, orders = "db Y", locale = "en_CA")

    if (any(is.na(parsed))) {
      # Extracted dates do not conform to ddmmmyyyy format
      return(NULL)
    }

    # Generate a sequence of valid dates from start to end (inclusive)
    valid_dates <- seq(parsed[1], parsed[2], by = "day")
    n_days <- as.numeric(difftime(parsed[2], parsed[1], units = "days"))

    # Extract NA codes if prop_NA specified
    # For dates, we typically use actual NA rather than numeric codes
    # But check metadata for explicit NA codes just in case
    na_values <- NULL
    if (!is.null(prop_NA) && prop_NA > 0) {
      # Check for NA codes in metadata
      na_rows <- var_details[grepl("NA", var_details$recEnd, fixed = TRUE), ]

      if (nrow(na_rows) > 0) {
        # Use actual NA for dates (not numeric codes)
        na_values <- NA
        warning(paste0(
          "Variable '", var_raw, "' has NA codes in metadata, but date variables use R NA. ",
          "Using NA for missing dates."
        ))
      } else {
        na_values <- NA
      }
    }

    # Generate mock data
    if (!is.null(seed)) set.seed(seed)

    # Use 'length' parameter for v0.1
    n_obs <- length

    # Calculate counts for each value type
    prop_na_actual <- if (!is.null(prop_NA)) prop_NA else 0
    prop_invalid_actual <- if (!is.null(prop_invalid)) prop_invalid else 0

    # Ensure proportions don't exceed 1
    total_prop <- prop_na_actual + prop_invalid_actual
    if (total_prop > 1) {
      stop(paste0(
        "prop_NA (", prop_NA, ") + prop_invalid (", prop_invalid, ") = ",
        total_prop, " exceeds 1.0"
      ))
    }

    # Calculate counts
    n_na <- floor(n_obs * prop_na_actual)
    n_invalid <- floor(n_obs * prop_invalid_actual)
    n_regular <- n_obs - n_na - n_invalid

    # Generate date values based on distribution
    if (distribution == "uniform") {
      # Uniform distribution: equal probability for all dates
      date_values <- sample(valid_dates, size = n_regular, replace = TRUE)

    } else if (distribution == "gompertz") {
      # Gompertz distribution: useful for survival/event times
      # Shape parameter (eta) and rate parameter (b)
      # Higher events near end of range (typical survival pattern)
      eta <- 0.1  # Shape parameter
      b <- 0.01   # Rate parameter

      # Generate Gompertz-distributed proportions [0,1]
      u <- runif(n_regular)
      t <- (1/b) * log(1 - (b/eta) * log(1 - u))
      t <- pmin(pmax(t, 0), 1)  # Clip to [0, 1]

      # Map to date range (index into valid_dates vector)
      date_indices <- pmax(1, pmin(round(t * length(valid_dates)), length(valid_dates)))
      date_values <- valid_dates[date_indices]

    } else if (distribution == "exponential") {
      # Exponential distribution: useful for time-to-event
      # More events near start of range
      rate <- 1 / (n_days / 3)  # Mean at 1/3 of range

      # Generate exponential-distributed days from start
      days_from_start <- rexp(n_regular, rate = rate)
      days_from_start <- pmin(days_from_start, n_days)  # Clip to range

      # Map to dates (index into valid_dates vector)
      date_indices <- pmax(1, pmin(round(days_from_start) + 1, length(valid_dates)))
      date_values <- valid_dates[date_indices]

    } else {
      stop(paste0(
        "Unknown distribution '", distribution, "'. ",
        "Must be one of: 'uniform', 'gompertz', 'exponential'"
      ))
    }

    # Convert to Date objects
    date_values <- as.Date(date_values, origin = "1970-01-01")

    # Generate invalid out-of-period dates
    invalid_dates <- as.Date(character(0))
    if (n_invalid > 0) {
      # Split invalid dates between before-start and after-end
      n_before <- floor(n_invalid / 2)
      n_after <- n_invalid - n_before

      # Dates before start (1-5 years earlier)
      if (n_before > 0) {
        days_before <- sample(365:(5*365), n_before, replace = TRUE)
        invalid_before <- parsed[1] - days_before
        invalid_dates <- c(invalid_dates, as.Date(invalid_before, origin = "1970-01-01"))
      }

      # Dates after end (1-5 years later)
      if (n_after > 0) {
        days_after <- sample(365:(5*365), n_after, replace = TRUE)
        invalid_after <- parsed[2] + days_after
        invalid_dates <- c(invalid_dates, as.Date(invalid_after, origin = "1970-01-01"))
      }
    }

    # Generate NA values
    na_dates <- if (n_na > 0) rep(as.Date(NA), n_na) else as.Date(character(0))

    # Combine all values and shuffle
    all_values <- c(date_values, invalid_dates, na_dates)
    all_values <- sample(all_values)

    # Ensure exact length
    all_values <- all_values[1:n_obs]

    # Apply source format conversion
    all_values <- convert_date_format(all_values, source_format)

    col <- data.frame(
      new = all_values,
      stringsAsFactors = FALSE
    )

    # Set column name to raw variable name
    names(col)[1] <- var_raw

    return(col)
  }
}
