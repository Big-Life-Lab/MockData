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
#'
#' @examples
#' \dontrun{
#' # Create a categorical variable
#' mock_gender <- create_cat_var(
#'   var_raw = "DHH_SEX",
#'   cycle = "cycle1",
#'   variable_details = variable_details,
#'   length = 1000
#' )
#'
#' # Create with NA values
#' mock_age_cat <- create_cat_var(
#'   var_raw = "clc_age",
#'   cycle = "cycle1",
#'   variable_details = variable_details,
#'   length = 1000,
#'   df_mock = existing_mock_data,
#'   prop_NA = 0.05
#' )
#' }
#'
#' @export
create_cat_var <- function(var_raw, cycle, variable_details, variables = NULL,
                            length, df_mock, prop_NA = NULL, seed = 100) {

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

  # Generate mock data
  if (is.null(prop_NA) || is.null(na_labels)) {
    # Simple case: no NA values
    set.seed(seed)
    col <- data.frame(
      new = sample(labels, length, replace = TRUE),
      stringsAsFactors = FALSE
    )

  } else {
    # Case with NA values using NA codes
    set.seed(seed)

    # Calculate counts
    n_regular <- floor(length * (1 - prop_NA))
    n_na <- length - n_regular

    # Sample regular values
    vec_regular <- sample(labels, n_regular, replace = TRUE)

    # Sample NA codes
    vec_na <- sample(na_labels, n_na, replace = TRUE)

    # Combine and shuffle
    vec_combined <- c(vec_regular, vec_na)
    vec_shuffled <- sample(vec_combined)

    # Ensure exact length
    col <- data.frame(
      new = vec_shuffled[1:length],
      stringsAsFactors = FALSE
    )
  }

  # Set column name to raw variable name
  names(col)[1] <- var_raw

  return(col)
}
