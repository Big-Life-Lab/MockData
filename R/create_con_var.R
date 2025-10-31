#' Create continuous variable for MockData
#'
#' Creates a continuous mock variable based on specifications from variable_details.
#'
#' @param var_raw character. The RAW variable name (as it appears in source data)
#' @param cycle character. The cycle identifier (e.g., "cycle1", "HC1")
#' @param variable_details data.frame. Variable details metadata
#' @param variables data.frame. Variables metadata (optional, for validation)
#' @param length integer. The desired length of the mock data vector
#' @param df_mock data.frame. The current mock data (to check if variable already exists)
#' @param prop_NA numeric. Optional. Proportion of NA values (0 to 1). If NULL, no NAs introduced.
#' @param prop_invalid numeric. Optional. Proportion of invalid out-of-range values (0 to 1). If NULL, no invalid values generated.
#' @param seed integer. Random seed for reproducibility. Default is 100.
#' @param distribution character. Distribution type: "uniform" (default) or "normal"
#'
#' @return data.frame with one column (the new continuous variable), or NULL if:
#'   - Variable details not found
#'   - Variable already exists in df_mock
#'   - No valid range found
#'
#' @details
#' This function uses:
#' - `get_variable_details_for_raw()` to find variable specifications
#'
#' The function handles continuous ranges:
#' - Closed intervals: "[18.5,25]" → 18.5 ≤ x ≤ 25
#' - Half-open intervals: "[18.5,25)" → 18.5 ≤ x < 25
#' - Open intervals: "(18.5,25)" → 18.5 < x < 25
#' - Infinity ranges: "[30,inf)" → x ≥ 30
#' - Invalid values: When prop_invalid specified, generates out-of-range values below min or above max
#'
#' For variables with multiple ranges (e.g., age categories), uses the overall min/max.
#'
#' @examples
#' \dontrun{
#' # Create a continuous variable with uniform distribution
#' mock_drinks_week <- create_con_var(
#'   var_raw = "alcdwky",
#'   cycle = "cycle1",
#'   variable_details = variable_details,
#'   length = 1000,
#'   df_mock = data.frame()
#' )
#'
#' # Create with normal distribution and NA values
#' mock_drinks_norm <- create_con_var(
#'   var_raw = "alcdwky",
#'   cycle = "cycle1",
#'   variable_details = variable_details,
#'   length = 1000,
#'   df_mock = existing_data,
#'   prop_NA = 0.02,
#'   distribution = "normal"
#' )
#'
#' # Create with invalid out-of-range values to test data validation
#' mock_drinks_dirty <- create_con_var(
#'   var_raw = "alcdwky",
#'   cycle = "cycle1",
#'   variable_details = variable_details,
#'   length = 1000,
#'   df_mock = existing_data,
#'   prop_invalid = 0.03
#' )
#' }
#'
#' @family generators
#' @export
create_con_var <- function(var_raw, cycle, variable_details, variables = NULL,
                            length, df_mock, prop_NA = NULL, prop_invalid = NULL,
                            seed = 100, distribution = "uniform") {

  # Level 1: Get variable details for this raw variable + cycle
  var_details <- get_variable_details_for_raw(var_raw, cycle, variable_details, variables)

  if (nrow(var_details) == 0) {
    # No variable details found for this raw variable in this cycle
    return(NULL)
  }

  # Check if variable already exists in mock data
  if (var_raw %in% names(df_mock)) {
    # Variable already created, skip
    return(NULL)
  }

  # Level 2: Extract continuous ranges from recStart
  # For continuous variables, we need to find the overall min/max from all ranges
  rec_start_values <- var_details$recStart[!grepl("NA", var_details$recEnd, fixed = TRUE)]

  if (length(rec_start_values) == 0) {
    # No valid ranges found
    return(NULL)
  }

  # Parse all ranges to find overall min/max
  all_mins <- c()
  all_maxs <- c()
  has_else <- FALSE

  for (value in rec_start_values) {
    if (is.na(value) || value == "") next

    parsed <- parse_range_notation(value)

    if (is.null(parsed)) next

    if (parsed$type %in% c("integer", "continuous", "single_value")) {
      all_mins <- c(all_mins, parsed$min)
      all_maxs <- c(all_maxs, parsed$max)
    } else if (parsed$type == "special" && parsed$value == "else") {
      # "else" means pass-through - we need to generate default values
      has_else <- TRUE
    }
  }

  if (length(all_mins) == 0 || length(all_maxs) == 0) {
    if (has_else) {
      # For "else" (pass-through) variables with no explicit range,
      # use reasonable defaults based on common continuous variable ranges
      warning(paste0(
        "Variable '", var_raw, "' has recStart='else' with no explicit range. ",
        "Using default range [0, 100]."
      ))
      all_mins <- c(0)
      all_maxs <- c(100)
    } else {
      # No valid numeric ranges found and no "else"
      return(NULL)
    }
  }

  # Get overall range
  overall_min <- min(all_mins, na.rm = TRUE)
  overall_max <- max(all_maxs, na.rm = TRUE)

  # Handle infinity
  if (is.infinite(overall_min)) overall_min <- 0
  if (is.infinite(overall_max)) overall_max <- overall_min + 100  # Arbitrary upper bound

  # Level 2: Extract NA codes (if prop_NA specified)
  na_labels <- NULL
  if (!is.null(prop_NA) && prop_NA > 0) {
    na_labels <- get_variable_categories(var_details, include_na = TRUE)

    if (length(na_labels) == 0) {
      # No NA codes found, use actual NA
      na_labels <- NA
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

  # Generate regular continuous values
  if (distribution == "normal") {
    # Normal distribution centered at midpoint
    midpoint <- (overall_min + overall_max) / 2
    spread <- (overall_max - overall_min) / 4  # Use 1/4 of range as SD

    values <- rnorm(n_regular, mean = midpoint, sd = spread)

    # Clip to range
    values <- pmax(overall_min, pmin(overall_max, values))

  } else {
    # Uniform distribution (default)
    values <- runif(n_regular, min = overall_min, max = overall_max)
  }

  # Generate invalid out-of-range values
  invalid_values <- numeric(0)
  if (n_invalid > 0) {
    # Split invalid values between below-min and above-max
    n_below <- floor(n_invalid / 2)
    n_above <- n_invalid - n_below

    # Values below minimum (if min is not -Inf)
    if (n_below > 0 && !is.infinite(overall_min)) {
      # Generate values in range [min - 100, min - 1]
      range_width <- min(100, abs(overall_min))  # Avoid excessive negative values
      invalid_below <- runif(n_below,
                            min = overall_min - range_width,
                            max = overall_min - 0.001)
      invalid_values <- c(invalid_values, invalid_below)
    }

    # Values above maximum (if max is not Inf)
    if (n_above > 0 && !is.infinite(overall_max)) {
      # Generate values in range [max + 1, max + 100]
      range_width <- max(100, abs(overall_max))  # Scale with magnitude
      invalid_above <- runif(n_above,
                            min = overall_max + 0.001,
                            max = overall_max + range_width)
      invalid_values <- c(invalid_values, invalid_above)
    }

    # If we couldn't generate enough invalid values (due to infinite bounds),
    # pad with values far outside typical range
    if (length(invalid_values) < n_invalid) {
      n_missing <- n_invalid - length(invalid_values)
      padding <- runif(n_missing, min = 1e6, max = 1e7)
      invalid_values <- c(invalid_values, padding)
    }
  }

  # Generate NA values
  na_values <- numeric(0)
  if (n_na > 0) {
    if (length(na_labels) > 0 && !is.na(na_labels[1])) {
      # Use NA codes from variable_details
      na_values <- sample(na_labels, n_na, replace = TRUE)
    } else {
      # Use actual NA
      na_values <- rep(NA, n_na)
    }
  }

  # Combine all values and shuffle
  all_values <- c(values, invalid_values, na_values)
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
