#' Create date variable for MockData
#'
#' Creates a mock date variable based on specifications from variable_details.
#'
#' @param var_raw character. The RAW variable name (as it appears in source data)
#' @param cycle character. The database or cycle identifier (e.g., "cycle1", "HC1")
#' @param variable_details data.frame. Variable details metadata
#' @param length integer. The desired length of the mock data vector
#' @param df_mock data.frame. The current mock data (to check if variable already exists)
#' @param variables data.frame. Variables metadata (optional, for validation)
#' @param prop_NA numeric. Optional. Proportion of NA values (0 to 1). If NULL, no NAs introduced.
#' @param seed integer. Random seed for reproducibility. Default is 100.
#'
#' @return data.frame with one column (the new continuous variable), or NULL if:
#'  - Variable details not found
#'  - Variable already exists in df_mock
#'  - No valid range found
#'
#' @details
#' This function uses:
#' - `get_variable_details_for_raw()` to find variable specifications
#'
#' @examples
#' \dontrun{
#' # Create a date variable
#' mock_death_date <- create_date_var(
#'   var_raw = "death_date",
#'   cycle = "ices",
#'   variable_details = variable_details,
#'   length = 1000,
#'   df_mock = data.frame()
#' )
#'
#' # Create a date variable with NA values
#' mock_birth_date <- create_date_var(
#'   var_name = "birth_date",
#'   cycle = "ices",
#'   variable_details = variable_details,
#'   length = 1000,
#'   df_mock = existing_data,
#'   prop_na = 0.02
#' )
#' }
#'
#' @export
create_date_var <- function(
  var_raw,
  cycle,
  variable_details,
  length,
  df_mock,
  variables = NULL,
  prop_NA = NULL,
  seed = 100
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

  # TODO: Extract NA code from recEnd, if needed

  # Generate mock data
  set.seed(seed)

  # Calculate counts
  n_regular <- if (!is.null(prop_NA)) floor(length * (1 - prop_NA)) else length
  n_na <- if (!is.null(prop_NA)) (length - n_regular) else 0

  # Generate date values
  values <- sample(valid_dates, size = n_regular, replace = TRUE)
}
