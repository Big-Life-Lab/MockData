#' Identify derived variables using recodeflow patterns
#'
#' @description
#' Identifies derived variables using recodeflow metadata patterns in
#' variable_details. Derived variables are calculated from raw variables
#' (e.g., BMI from height/weight) and should NOT be generated as mock data.
#'
#' This function uses the recodeflow approach: derived variables are identified
#' by metadata patterns in variable_details, NOT by role column flags.
#'
#' @param variables data.frame. Variable-level metadata with column: variable
#' @param variable_details data.frame. Required. Detail-level metadata with
#'   columns: variable, recStart, recEnd. Contains DerivedVar:: and Func::
#'   patterns that identify derived variables.
#'
#' @return Character vector of derived variable names (may be empty if none found)
#'
#' @details
#' **Detection methods** (recodeflow patterns only):
#'
#' 1. **DerivedVar:: pattern**: Variables with `DerivedVar::` in recStart column
#'    - Example: `recStart = "DerivedVar::[HWTGHTM, HWTGWTK]"`
#'    - Indicates variable is derived from listed raw variables
#'
#' 2. **Func:: pattern**: Variables with `Func::` in recEnd column
#'    - Example: `recEnd = "Func::bmi_fun"`
#'    - Indicates transformation function applied to derive variable
#'
#' **Why variable_details is required:**
#'
#' The recodeflow approach stores derivation logic in variable_details, not in
#' variables. The role column (if present) is NOT used for derived variable
#' detection. This ensures:
#' - Derivation logic is explicit (what variables, what function)
#' - Metadata is self-documenting
#' - Compatible with cchsflow and other recodeflow tools
#'
#' **Note:** This function does NOT check role = "derived" even if present.
#' Derived status is determined solely by DerivedVar:: and Func:: patterns.
#'
#' @examples
#' \dontrun{
#' # BMI derived from height and weight
#' variables <- data.frame(
#'   variable = c("height", "weight", "BMI_derived"),
#'   variableType = c("Continuous", "Continuous", "Continuous"),
#'   role = c("enabled", "enabled", "enabled"),  # NO "derived" flag needed
#'   stringsAsFactors = FALSE
#' )
#'
#' variable_details <- data.frame(
#'   variable = c("height", "weight", "BMI_derived"),
#'   recStart = c("[1.4,2.1]", "[45,150]", "DerivedVar::[height, weight]"),
#'   recEnd = c("copy", "copy", "Func::bmi_fun"),
#'   stringsAsFactors = FALSE
#' )
#'
#' identify_derived_vars(variables, variable_details)
#' # Returns: "BMI_derived"
#'
#' # ADL derived from 5 ADL items
#' variable_details_adl <- data.frame(
#'   variable = c("ADL_01", "ADL_02", "ADL_03", "ADL_04", "ADL_05", "ADL_der"),
#'   recStart = c(rep("1", 5), "DerivedVar::[ADL_01, ADL_02, ADL_03, ADL_04, ADL_05]"),
#'   recEnd = c(rep("1", 5), "Func::adl_fun"),
#'   stringsAsFactors = FALSE
#' )
#'
#' identify_derived_vars(variables, variable_details_adl)
#' # Returns: "ADL_der"
#' }
#'
#' @family helpers
#' @export
identify_derived_vars <- function(variables, variable_details) {

  # ========== VALIDATION ==========

  if (!is.data.frame(variables)) {
    stop("variables must be a data frame")
  }

  if (!"variable" %in% names(variables)) {
    stop("variables must have a 'variable' column")
  }

  if (missing(variable_details) || is.null(variable_details)) {
    stop("variable_details is required to identify derived variables. ",
         "Derived variables are identified by DerivedVar:: and Func:: patterns ",
         "in variable_details, not by role column.")
  }

  if (!is.data.frame(variable_details)) {
    stop("variable_details must be a data frame")
  }

  if (!"variable" %in% names(variable_details)) {
    stop("variable_details must have a 'variable' column")
  }

  # ========== PATTERN-BASED DETECTION (RECODEFLOW ONLY) ==========

  derived_vars <- character(0)

  # Method 1: Check for DerivedVar:: in recStart
  if ("recStart" %in% names(variable_details)) {
    vars_with_derivedvar <- unique(
      variable_details$variable[
        grepl("DerivedVar::", variable_details$recStart, fixed = TRUE)
      ]
    )
    derived_vars <- c(derived_vars, vars_with_derivedvar)
  }

  # Method 2: Check for Func:: in recEnd (transformation functions)
  if ("recEnd" %in% names(variable_details)) {
    vars_with_func <- unique(
      variable_details$variable[
        grepl("Func::", variable_details$recEnd, fixed = TRUE)
      ]
    )
    derived_vars <- c(derived_vars, vars_with_func)
  }

  # Remove duplicates
  derived_vars <- unique(derived_vars)

  # Filter to only variables that exist in variables data frame
  derived_vars <- derived_vars[derived_vars %in% variables$variable]

  return(derived_vars)
}


#' Extract raw variable dependencies from derived variable metadata
#'
#' @description
#' For a given derived variable, extract the list of raw variables it depends on
#' by parsing the DerivedVar::[...] pattern in variable_details.
#'
#' @param derived_var character. Name of the derived variable
#' @param variable_details data.frame. Detail-level metadata with columns:
#'   variable, recStart
#'
#' @return Character vector of raw variable names that the derived variable
#'   depends on. Returns character(0) if no dependencies found.
#'
#' @details
#' Parses patterns like:
#' - `DerivedVar::[HWTGHTM, HWTGWTK]` → c("HWTGHTM", "HWTGWTK")
#' - `DerivedVar::[ADL_01, ADL_02, ADL_03, ADL_04, ADL_05]` → c("ADL_01", ...)
#'
#' @examples
#' \dontrun{
#' variable_details <- data.frame(
#'   variable = c("HWTGBMI_der"),
#'   recStart = c("DerivedVar::[HWTGHTM, HWTGWTK]"),
#'   stringsAsFactors = FALSE
#' )
#'
#' get_raw_var_dependencies("HWTGBMI_der", variable_details)
#' # Returns: c("HWTGHTM", "HWTGWTK")
#' }
#'
#' @family helpers
#' @export
get_raw_var_dependencies <- function(derived_var, variable_details) {

  # Validate inputs
  if (!is.character(derived_var) || length(derived_var) != 1) {
    stop("derived_var must be a single character string")
  }

  if (!is.data.frame(variable_details)) {
    stop("variable_details must be a data frame")
  }

  if (!"variable" %in% names(variable_details) || !"recStart" %in% names(variable_details)) {
    stop("variable_details must have 'variable' and 'recStart' columns")
  }

  # Find rows for this derived variable with DerivedVar:: pattern
  pattern_rows <- variable_details[
    variable_details$variable == derived_var &
      grepl("DerivedVar::", variable_details$recStart, fixed = TRUE),
  ]

  if (nrow(pattern_rows) == 0) {
    return(character(0))
  }

  # Extract first match (should only be one DerivedVar:: row per variable)
  pattern <- pattern_rows$recStart[1]

  # Extract content between [ and ]
  # Pattern: DerivedVar::[VAR1, VAR2, VAR3]
  raw_vars_str <- gsub(".*DerivedVar::\\[(.*)\\].*", "\\1", pattern)

  # Split by comma and trim whitespace
  raw_vars <- strsplit(raw_vars_str, ",\\s*")[[1]]
  raw_vars <- trimws(raw_vars)

  return(raw_vars)
}
