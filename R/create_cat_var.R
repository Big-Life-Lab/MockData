#' Create categorical variable for MockData
#'
#' Creates a categorical mock variable based on specifications from variable_details.
#'
#' @param var_raw character. The RAW variable name (as it appears in source data)
#' @param cycle character. The cycle identifier (e.g., "cycle1", "HC1")
#' @param variable_details data.frame. Variable details metadata
#' @param variables data.frame. Variables metadata (optional, for validation)
#' @param length integer. The desired length of the mock data vector
#' @param df_mock data.frame. The current mock data (to check if variable already exists)
#' @param prop_NA numeric. Optional. Proportion of NA values (0 to 1). If NULL, no NAs introduced.
#' @param prop_invalid numeric. Optional. Proportion of invalid out-of-range category codes (0 to 1). If NULL, no invalid values generated.
#' @param seed integer. Random seed for reproducibility. Default is 100.
#'
#' @return data.frame with one column (the new categorical variable), or NULL if:
#'   - Variable details not found
#'   - Variable already exists in df_mock
#'   - No categories found
#'
#' @details
#' This function uses:
#' - `get_variable_details_for_raw()` to find variable specifications
#' - `get_variable_categories()` to extract category values
#'
#' The function handles:
#' - Simple categories: "1", "2", "3"
#' - Range notation: "[7,9]" → expands to c("7","8","9")
#' - NA codes: Categories where recEnd contains "NA"
#' - Special codes: "copy", "else", "NA::a"
#' - Invalid codes: When prop_invalid specified, generates out-of-range category codes not in metadata
#'
#' @examples
#' \dontrun{
#' # Create a categorical variable
#' mock_alcohol_past_year <- create_cat_var(
#'   var_raw = "alc_11",
#'   cycle = "cycle1",
#'   variable_details = variable_details,
#'   length = 1000
#' )
#'
#' # Create with NA values
#' mock_alcohol <- create_cat_var(
#'   var_raw = "alc_11",
#'   cycle = "cycle1",
#'   variable_details = variable_details,
#'   length = 1000,
#'   df_mock = existing_mock_data,
#'   prop_NA = 0.05
#' )
#'
#' # Create with invalid out-of-range codes to test data validation
#' mock_alcohol_dirty <- create_cat_var(
#'   var_raw = "alc_11",
#'   cycle = "cycle1",
#'   variable_details = variable_details,
#'   length = 1000,
#'   df_mock = existing_mock_data,
#'   prop_invalid = 0.02
#' )
#' }
#'
#' @family generators
#' @export
create_cat_var <- function(var_raw, cycle, variable_details, variables = NULL,
                            length, df_mock, prop_NA = NULL, prop_invalid = NULL, seed = 100) {

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

  # Level 2: Extract categories (non-NA values)
  labels <- get_variable_categories(var_details, include_na = FALSE)

  if (length(labels) == 0) {
    # No valid categories found
    return(NULL)
  }

  # Level 2: Extract NA codes (if prop_NA specified)
  na_labels <- NULL
  if (!is.null(prop_NA) && prop_NA > 0) {
    na_labels <- get_variable_categories(var_details, include_na = TRUE)

    if (length(na_labels) == 0) {
      # No NA codes found, but prop_NA requested
      # Use regular labels with NA values instead
      na_labels <- NULL
      prop_NA <- NULL
      warning(paste0(
        "prop_NA requested for ", var_raw, " but no NA codes found in variable_details. ",
        "Proceeding without NAs."
      ))
    }
  }

  # Level 3: Generate invalid codes (if prop_invalid specified)
  invalid_labels <- NULL
  if (!is.null(prop_invalid) && prop_invalid > 0) {
    # Common invalid codes that are likely not in valid categories
    # These represent typical data quality issues
    all_invalid_candidates <- c("99", "999", "9999", "88", "888", "-1", "-9", "-99", "96", "97", "98")

    # Exclude any that are actually valid or NA codes
    all_categories <- get_variable_categories(var_details, include_na = TRUE)
    invalid_labels <- setdiff(all_invalid_candidates, all_categories)

    if (length(invalid_labels) == 0) {
      # All common invalid codes are in metadata (unlikely)
      # Generate synthetic invalid codes
      max_code <- suppressWarnings(max(as.numeric(all_categories), na.rm = TRUE))
      if (!is.infinite(max_code) && !is.na(max_code)) {
        invalid_labels <- as.character((max_code + 1):(max_code + 5))
      } else {
        # Fallback: use clearly invalid text codes
        invalid_labels <- c("INVALID", "ERROR", "XXX")
      }
    }
  }

  # Generate mock data
  set.seed(seed)

  # Calculate counts for each value type
  prop_na_actual <- if (!is.null(prop_NA) && !is.null(na_labels)) prop_NA else 0
  prop_invalid_actual <- if (!is.null(prop_invalid) && !is.null(invalid_labels)) prop_invalid else 0

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

  # Generate vectors
  vec_all <- character(0)

  # Regular values
  if (n_regular > 0) {
    vec_regular <- sample(labels, n_regular, replace = TRUE)
    vec_all <- c(vec_all, vec_regular)
  }

  # NA codes
  if (n_na > 0) {
    vec_na <- sample(na_labels, n_na, replace = TRUE)
    vec_all <- c(vec_all, vec_na)
  }

  # Invalid codes
  if (n_invalid > 0) {
    vec_invalid <- sample(invalid_labels, n_invalid, replace = TRUE)
    vec_all <- c(vec_all, vec_invalid)
  }

  # Shuffle to mix value types
  vec_shuffled <- sample(vec_all)

  # Ensure exact length (handle rounding)
  col <- data.frame(
    new = vec_shuffled[1:length],
    stringsAsFactors = FALSE
  )

  # Set column name to raw variable name
  names(col)[1] <- var_raw

  return(col)
}
