#' Create date variable for MockData
#'
#' Creates a mock date variable based on specifications from variable_details.
#'
#' @param var_raw character. The RAW variable name (as it appears in source data)
#' @param cycle character. The database or cycle identifier (e.g., "cycle1", "HC1")
#' @param variable_details data.frame. Variable details metadata
#' @param variables data.frame. Variables metadata (optional, for validation)
#' @param length integer. The desired length of the mock data vector
#' @param df_mock data.frame. The current mock data (to check if variable already exists)
#' @param prop_NA numeric. Optional. Proportion of NA values (0 to 1). If NULL, no NAs introduced.
#' @param prop_invalid numeric. Optional. Proportion of invalid out-of-period dates (0 to 1). If NULL, no invalid dates generated.
#' @param seed integer. Random seed for reproducibility. Default is 100.
#' @param distribution character. Distribution type: "uniform" (default), "gompertz", or "exponential"
#'
#' @return data.frame with one column (the new date variable), or NULL if:
#'  - Variable details not found
#'  - Variable already exists in df_mock
#'  - No valid date range found
#'
#' @details
#' This function uses:
#' - `get_variable_details_for_raw()` to find variable specifications
#'
#' The function handles date ranges in SAS format:
#' - recStart: "[01JAN2001, 31MAR2017]" (SAS date format)
#' - Generates R Date objects between start and end dates
#'
#' Distribution options:
#' - "uniform": Equal probability across all dates in range
#' - "gompertz": Gompertz survival distribution (useful for event times)
#' - "exponential": Exponential distribution (useful for time-to-event)
#' - Invalid dates: When prop_invalid specified, generates dates outside the valid range
#'
#' @examples
#' \dontrun{
#' # Create a date variable with uniform distribution
#' mock_death_date <- create_date_var(
#'   var_raw = "death_date",
#'   cycle = "ices",
#'   variable_details = variable_details,
#'   length = 1000,
#'   df_mock = data.frame()
#' )
#'
#' # Create a date variable with NA values and Gompertz distribution
#' mock_birth_date <- create_date_var(
#'   var_raw = "birth_date",
#'   cycle = "ices",
#'   variable_details = variable_details,
#'   length = 1000,
#'   df_mock = existing_data,
#'   prop_NA = 0.02,
#'   distribution = "gompertz"
#' )
#'
#' # Create with invalid out-of-period dates to test data validation
#' mock_death_date_dirty <- create_date_var(
#'   var_raw = "death_date",
#'   cycle = "ices",
#'   variable_details = variable_details,
#'   length = 1000,
#'   df_mock = existing_data,
#'   prop_invalid = 0.015
#' )
#' }
#'
#' @family generators
#' @export
create_date_var <- function(
  var_raw,
  cycle,
  variable_details,
  variables = NULL,
  length,
  df_mock,
  prop_NA = NULL,
  prop_invalid = NULL,
  seed = 100,
  distribution = "uniform"
) {
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

  if (var_raw %in% names(df_mock)) {
    # Variable already exists in mock data
    return(NULL)
  }

  # Extract date range from recStart
  rec_start_values <- var_details$recStart[
    !grepl("NA", var_details$recEnd, fixed = TRUE)
  ]

  pattern <- "^\\[\\d{2}[A-Z]{3}\\d{4},\\s*\\d{2}[A-Z]{3}\\d{4}\\]$"

  if (!stringr::str_detect(rec_start_values, pattern)) {
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
  set.seed(seed)

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
  n_na <- floor(length * prop_na_actual)
  n_invalid <- floor(length * prop_invalid_actual)
  n_regular <- length - n_na - n_invalid

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
  col <- data.frame(
    new = all_values[1:length],
    stringsAsFactors = FALSE
  )

  # Set column name to raw variable name
  names(col)[1] <- var_raw

  return(col)
}
