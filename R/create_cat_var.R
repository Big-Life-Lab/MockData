#' Create categorical variable for MockData
#'
#' Generates a categorical mock variable based on specifications from metadata.
#'
#' @param var character. Variable name to generate (column name in output)
#' @param databaseStart character. Database/cycle identifier for filtering metadata
#'   (e.g., "cchs2001_p", "minimal-example"). Used to filter variables and
#'   variable_details to the specified database.
#' @param variables data.frame or character. Variable-level metadata containing:
#'   \itemize{
#'     \item \code{variable}: Variable names
#'     \item \code{database}: Database identifier (optional, for filtering)
#'     \item \code{rType}: R output type (factor/character/integer/logical)
#'     \item \code{garbage_low_prop}, \code{garbage_high_prop}: Garbage data parameters
#'   }
#'   Can also be a file path (character) to variables.csv.
#' @param variable_details data.frame or character. Detail-level metadata containing:
#'   \itemize{
#'     \item \code{variable}: Variable name (for joining)
#'     \item \code{recStart}: Category code or range
#'     \item \code{recEnd}: Classification (numeric code, "NA::a", "NA::b")
#'     \item \code{proportion}: Category proportion (0-1, must sum to 1)
#'     \item \code{catLabel}: Category label/description
#'   }
#'   Can also be a file path (character) to variable_details.csv.
#' @param df_mock data.frame. Optional. Existing mock data (to check if variable already exists).
#' @param prop_missing numeric. Proportion of missing values (0-1). Default 0 (no missing).
#'   If > 0, function looks for rows with recEnd containing "NA::" in variable_details.
#' @param n integer. Number of observations to generate.
#' @param seed integer. Optional. Random seed for reproducibility.
#'
#' @return data.frame with one column (the generated categorical variable), or NULL if:
#'   \itemize{
#'     \item Variable not found in metadata
#'     \item Variable already exists in df_mock
#'     \item No valid categories found in variable_details
#'   }
#'
#' @details
#' **v0.3.0 API**: This function now accepts full metadata data frames and filters
#' internally for the specified variable and database. This is the "recodeflow pattern"
#' where filtering is handled inside the function.
#'
#' **Generation process**:
#' \enumerate{
#'   \item Filter metadata: Extract rows for specified var + database
#'   \item Extract proportions: Read from variable_details (proportion column)
#'   \item Generate population: Sample categories based on proportions
#'   \item Apply missing codes: If prop_missing > 0 or proportions in metadata
#'   \item Apply garbage: Read garbage parameters from variables.csv
#'   \item Apply rType: Coerce to specified R type (factor/character/integer/logical)
#' }
#'
#' **Type coercion (rType)**:
#' The rType column in variables.csv controls output data type:
#' \itemize{
#'   \item \code{"factor"}: Factor with levels from category codes (default for categorical)
#'   \item \code{"character"}: Character vector
#'   \item \code{"integer"}: Integer (for numeric category codes)
#'   \item \code{"logical"}: Logical (for TRUE/FALSE categories)
#' }
#'
#' **Missing data**:
#' Missing codes are identified by \code{recEnd} containing "NA::":
#' \itemize{
#'   \item \code{NA::a}: Skip codes (not applicable)
#'   \item \code{NA::b}: Missing codes (don't know, refusal, not stated)
#' }
#' Proportions for missing codes are read from the proportion column in variable_details.
#'
#' **Garbage data**:
#' Garbage parameters are read from variables.csv:
#' \itemize{
#'   \item \code{garbage_low_prop}, \code{garbage_low_range}: Below-range invalid values
#'   \item \code{garbage_high_prop}, \code{garbage_high_range}: Above-range invalid values
#' }
#'
#' @examples
#' \dontrun{
#' # Basic usage with metadata data frames
#' smoking <- create_cat_var(
#'   var = "smoking",
#'   databaseStart = "cchs2001_p",
#'   variables = variables,
#'   variable_details = variable_details,
#'   n = 1000,
#'   seed = 123
#' )
#'
#' # Expected output: data.frame with 1000 rows, 1 column ("smoking")
#' # Values: Factor with levels from metadata (e.g., "1", "2", "3", "7")
#' # Distribution: Based on proportions in variable_details
#' # Example:
#' #   smoking
#' # 1       1
#' # 2       3
#' # 3       2
#' # 4       1
#' # 5       7
#' # ...
#'
#' # With missing data (uses proportions from metadata)
#' smoking <- create_cat_var(
#'   var = "smoking",
#'   databaseStart = "cchs2001_p",
#'   variables = variables,
#'   variable_details = variable_details,
#'   n = 1000
#' )
#' # Missing codes (recEnd = "NA::b") automatically included based on proportions
#'
#' # With file paths instead of data frames
#' result <- create_cat_var(
#'   var = "smoking",
#'   databaseStart = "cchs2001_p",
#'   variables = "path/to/variables.csv",
#'   variable_details = "path/to/variable_details.csv",
#'   n = 1000
#' )
#' }
#'
#' @family generators
#' @export
create_cat_var <- function(var,
                            databaseStart,
                            variables,
                            variable_details,
                            df_mock = NULL,
                            prop_missing = 0,
                            n,
                            seed = NULL) {

  # ========== PARAMETER VALIDATION ==========

  # Load metadata from file paths if needed
  if (is.character(variables) && length(variables) == 1) {
    variables <- read.csv(variables, stringsAsFactors = FALSE, check.names = FALSE)
  }
  if (is.character(variable_details) && length(variable_details) == 1) {
    variable_details <- read.csv(variable_details, stringsAsFactors = FALSE, check.names = FALSE)
  }

  # ========== INTERNAL FILTERING (recodeflow pattern) ==========

  # Filter variables for this var
  var_row <- variables[variables$variable == var, ]

  if (nrow(var_row) == 0) {
    warning(paste0("Variable '", var, "' not found in variables metadata"))
    return(NULL)
  }

  # Take first row if multiple matches
  if (nrow(var_row) > 1) {
    var_row <- var_row[1, ]
  }

  # Filter variable_details for this var AND database (using databaseStart)
  # databaseStart is a recodeflow core column containing comma-separated database identifiers
  if ("databaseStart" %in% names(variable_details)) {
    details_subset <- variable_details[
      variable_details$variable == var &
      (is.na(variable_details$databaseStart) |
       variable_details$databaseStart == "" |
       grepl(databaseStart, variable_details$databaseStart, fixed = TRUE)),
    ]
  } else {
    # Fallback: no databaseStart filtering (for simple configs)
    details_subset <- variable_details[variable_details$variable == var, ]
  }

  # ========== CHECK IF VARIABLE ALREADY EXISTS ==========

  if (!is.null(df_mock) && var %in% names(df_mock)) {
    return(NULL)
  }

  # ========== SET SEED ==========

  if (!is.null(seed)) set.seed(seed)

  # ========== FALLBACK MODE: Simple generation if no details ==========

  if (nrow(details_subset) == 0) {
    # Generate simple 2-category variable with uniform distribution
    values <- sample(c("1", "2"), size = n, replace = TRUE)

    col <- data.frame(
      new = values,
      stringsAsFactors = FALSE
    )
    names(col)[1] <- var
    return(col)
  }

  # ========== EXTRACT PROPORTIONS ==========

  props <- extract_proportions(details_subset, variable_name = var)

  # Check if we have valid categories
  if (length(props$categories) == 0) {
    warning(paste0("No valid categories found for ", var))
    return(NULL)
  }

  # ========== STEP 1: Generate population (valid values only) ==========

  # Calculate number of valid observations (excluding missing)
  n_valid <- floor(n * props$valid)

  # Generate category assignments based on category-specific proportions
  valid_assignments <- sample_with_proportions(
    categories = props$categories,
    proportions = props$category_proportions,
    n = n_valid,
    seed = NULL  # Already set globally if needed
  )

  # ========== STEP 2: Apply missing codes ==========

  # Calculate number of each missing type
  n_missing <- n - n_valid

  if (n_missing > 0 && length(props$missing) > 0) {
    # Generate missing assignments
    missing_assignments <- sample(
      names(props$missing),
      size = n_missing,
      replace = TRUE,
      prob = unlist(props$missing)
    )

    # Combine valid and missing assignments
    all_assignments <- c(valid_assignments, missing_assignments)

    # Create map of missing categories to their codes
    missing_map <- list()
    for (miss_cat in names(props$missing)) {
      miss_row <- details_subset[details_subset$recStart == miss_cat, ]
      if (nrow(miss_row) > 0) {
        # Use recStart itself if value is NA or not present
        code_value <- if ("value" %in% names(miss_row) && !is.na(miss_row$value[1])) {
          miss_row$value[1]
        } else {
          miss_cat  # Use recStart (e.g., "7" or "[7,9]") as the value
        }
        missing_map[[miss_cat]] <- code_value
      }
    }

    # Apply missing codes (replaces missing category names with actual codes)
    values <- apply_missing_codes(
      values = all_assignments,
      category_assignments = all_assignments,
      missing_code_map = missing_map
    )
  } else {
    # No missing codes needed
    values <- valid_assignments
  }

  # ========== STEP 3: Apply garbage data if specified in variables.csv ==========

  # Extract missing codes from missing_map (metadata-based)
  missing_codes_vec <- NULL
  if (exists("missing_map") && length(missing_map) > 0) {
    # Flatten missing_map to get all numeric codes
    missing_codes_vec <- unique(unlist(missing_map))
  }

  values <- apply_garbage(
    values = values,
    var_row = var_row,
    variable_type = "categorical",
    missing_codes = missing_codes_vec,  # Pass metadata-based missing codes
    seed = NULL  # Already set globally if needed
  )

  # ========== STEP 4: Apply rType coercion if specified ==========

  # Read rType from var_row (variables.csv)
  if ("rType" %in% names(var_row)) {
    r_type <- var_row$rType
    if (!is.null(r_type) && !is.na(r_type) && r_type != "") {
      values <- switch(r_type,
        "factor" = {
          # Extract category levels from details_subset
          categories <- unique(details_subset$recStart[!is.na(details_subset$recStart)])

          # If garbage was applied, include garbage values in factor levels
          # This ensures garbage codes don't get converted to NA
          all_values <- unique(values[!is.na(values)])
          if (any(!all_values %in% categories)) {
            # Garbage values present - use all observed values as levels
            # Sort to put valid codes first, then garbage codes
            valid_levels <- categories[categories %in% all_values]
            garbage_levels <- all_values[!all_values %in% categories]
            combined_levels <- c(valid_levels, sort(garbage_levels))
            factor(values, levels = combined_levels)
          } else {
            # No garbage - use only metadata-defined levels
            factor(values, levels = categories)
          }
        },
        "character" = as.character(values),
        "integer" = as.integer(values),
        "logical" = as.logical(values),
        values  # No coercion for other types
      )
    }
  }

  # ========== RETURN AS DATA FRAME ==========

  col <- data.frame(
    new = values,
    stringsAsFactors = FALSE
  )
  names(col)[1] <- var

  return(col)
}
