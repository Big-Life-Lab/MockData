#' Add garbage specifications to variables data frame
#'
#' @description
#' Helper function to add garbage data specifications to a variables data frame.
#' This provides a convenient way to specify invalid/garbage values for quality
#' assurance testing. Works consistently across all variable types (categorical,
#' continuous, date).
#'
#' @param variables Data frame with variable metadata (typically read from
#'   variables.csv)
#' @param var Character. Variable name to add garbage specifications to. Must
#'   exist in `variables$variable`.
#' @param garbage_low_prop Numeric. Proportion of observations to generate as
#'   low-range garbage (0-1). If NULL, no low-range garbage is added.
#' @param garbage_low_range Character. Interval notation specifying the range for
#'   low-range garbage values (e.g., "[-2, 0]" for categorical, "[0, 1.4)" for
#'   continuous, "[1900-01-01, 1950-12-31]" for dates). If NULL, no low-range
#'   garbage is added.
#' @param garbage_high_prop Numeric. Proportion of observations to generate as
#'   high-range garbage (0-1). If NULL, no high-range garbage is added.
#' @param garbage_high_range Character. Interval notation specifying the range for
#'   high-range garbage values (e.g., "[10, 15]" for categorical, "[60, 150]"
#'   for continuous, "[2025-01-01, 2099-12-31]" for dates). If NULL, no
#'   high-range garbage is added.
#'
#' @return Modified variables data frame with garbage specifications added.
#'   If the garbage columns don't exist, they are created and initialized with
#'   NA for all other variables.
#'
#' @details
#' ## Unified garbage API
#'
#' All variable types use the same garbage specification pattern:
#' - `garbage_low_prop` + `garbage_low_range` for values below valid range
#' - `garbage_high_prop` + `garbage_high_range` for values above valid range
#'
#' ## Variable type examples
#'
#' **Categorical (ordinal treatment):**
#' ```r
#' # Valid codes: 1, 2, 3, 7
#' # Generate codes -2, -1, 0 below valid range
#' vars <- add_garbage(vars, "smoking",
#'   garbage_low_prop = 0.02, garbage_low_range = "[-2, 0]")
#' ```
#'
#' **Continuous:**
#' ```r
#' # Valid range: [18, 100]
#' # Generate extreme ages above valid range
#' vars <- add_garbage(vars, "age",
#'   garbage_high_prop = 0.03, garbage_high_range = "[150, 200]")
#' ```
#'
#' **Date:**
#' ```r
#' # Valid range: [2000-01-01, 2020-12-31]
#' # Generate future dates for QA testing
#' vars <- add_garbage(vars, "death_date",
#'   garbage_high_prop = 0.03, garbage_high_range = "[2025-01-01, 2099-12-31]")
#' ```
#'
#' ## Pipe-friendly usage
#'
#' This function returns the modified variables data frame, making it
#' pipe-friendly:
#'
#' ```r
#' vars_with_garbage <- variables %>%
#'   add_garbage("age", garbage_high_prop = 0.03, garbage_high_range = "[150, 200]") %>%
#'   add_garbage("smoking", garbage_low_prop = 0.02, garbage_low_range = "[-2, 0]") %>%
#'   add_garbage("death_date", garbage_high_prop = 0.03,
#'     garbage_high_range = "[2025-01-01, 2099-12-31]")
#' ```
#'
#' @seealso
#' - [create_cat_var()] for categorical variable generation
#' - [create_con_var()] for continuous variable generation
#' - [create_date_var()] for date variable generation
#' - [create_mock_data()] for batch generation of all variables
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Load metadata
#' variables <- read.csv(
#'   system.file("extdata/minimal-example/variables.csv",
#'     package = "MockData"),
#'   stringsAsFactors = FALSE, check.names = FALSE
#' )
#'
#' # Add garbage to age (high-range only)
#' vars <- add_garbage(variables, "age",
#'   garbage_high_prop = 0.03, garbage_high_range = "[150, 200]")
#'
#' # Add garbage to smoking (low-range only)
#' vars <- add_garbage(vars, "smoking",
#'   garbage_low_prop = 0.02, garbage_low_range = "[-2, 0]")
#'
#' # Add garbage to BMI (two-sided contamination)
#' vars <- add_garbage(vars, "BMI",
#'   garbage_low_prop = 0.02, garbage_low_range = "[-10, 15)",
#'   garbage_high_prop = 0.01, garbage_high_range = "[60, 150]")
#'
#' # Generate data with garbage
#' mock_data <- create_mock_data(
#'   databaseStart = "minimal-example",
#'   variables = vars,
#'   variable_details = variable_details,
#'   n = 1000,
#'   seed = 123
#' )
#' }
add_garbage <- function(variables, var,
                        garbage_low_prop = NULL, garbage_low_range = NULL,
                        garbage_high_prop = NULL, garbage_high_range = NULL) {
  # Validate inputs
  if (!is.data.frame(variables)) {
    stop("'variables' must be a data frame")
  }

  if (!("variable" %in% names(variables))) {
    stop("'variables' data frame must contain a 'variable' column")
  }

  if (!is.character(var) || length(var) != 1) {
    stop("'var' must be a single character string")
  }

  # Find the variable
  idx <- variables$variable == var

  if (!any(idx)) {
    stop("Variable '", var, "' not found in variables data frame")
  }

  # Validate proportions
  if (!is.null(garbage_low_prop)) {
    if (!is.numeric(garbage_low_prop) || length(garbage_low_prop) != 1 ||
        garbage_low_prop < 0 || garbage_low_prop > 1) {
      stop("'garbage_low_prop' must be a single numeric value between 0 and 1")
    }
  }

  if (!is.null(garbage_high_prop)) {
    if (!is.numeric(garbage_high_prop) || length(garbage_high_prop) != 1 ||
        garbage_high_prop < 0 || garbage_high_prop > 1) {
      stop("'garbage_high_prop' must be a single numeric value between 0 and 1")
    }
  }

  # Validate ranges
  if (!is.null(garbage_low_range)) {
    if (!is.character(garbage_low_range) || length(garbage_low_range) != 1) {
      stop("'garbage_low_range' must be a single character string in interval notation")
    }
  }

  if (!is.null(garbage_high_range)) {
    if (!is.character(garbage_high_range) || length(garbage_high_range) != 1) {
      stop("'garbage_high_range' must be a single character string in interval notation")
    }
  }

  # Add garbage_low_prop if specified
  if (!is.null(garbage_low_prop)) {
    if (!("garbage_low_prop" %in% names(variables))) {
      variables$garbage_low_prop <- NA_real_
    }
    variables$garbage_low_prop[idx] <- garbage_low_prop
  }

  # Add garbage_low_range if specified
  if (!is.null(garbage_low_range)) {
    if (!("garbage_low_range" %in% names(variables))) {
      variables$garbage_low_range <- NA_character_
    }
    variables$garbage_low_range[idx] <- garbage_low_range
  }

  # Add garbage_high_prop if specified
  if (!is.null(garbage_high_prop)) {
    if (!("garbage_high_prop" %in% names(variables))) {
      variables$garbage_high_prop <- NA_real_
    }
    variables$garbage_high_prop[idx] <- garbage_high_prop
  }

  # Add garbage_high_range if specified
  if (!is.null(garbage_high_range)) {
    if (!("garbage_high_range" %in% names(variables))) {
      variables$garbage_high_range <- NA_character_
    }
    variables$garbage_high_range[idx] <- garbage_high_range
  }

  variables
}
