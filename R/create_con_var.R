#' Create continuous variable for MockData
#'
#' Generates a continuous mock variable based on specifications from metadata.
#'
#' @param var character. Variable name to generate (column name in output)
#' @param databaseStart character. Database/cycle identifier for filtering metadata
#'   (e.g., "cchs2001_p", "minimal-example"). Used to filter variables and
#'   variable_details to the specified database.
#' @param variables data.frame or character. Variable-level metadata containing:
#'   \itemize{
#'     \item \code{variable}: Variable names
#'     \item \code{database}: Database identifier (optional, for filtering)
#'     \item \code{rType}: R output type (integer/double)
#'     \item \code{distribution}: Distribution type (uniform/normal/exponential)
#'     \item \code{mean}, \code{sd}: Normal distribution parameters
#'     \item \code{rate}, \code{shape}: Exponential/Gompertz parameters
#'     \item \code{garbage_low_prop}, \code{garbage_high_prop}: Garbage data parameters
#'   }
#'   Can also be a file path (character) to variables.csv.
#' @param variable_details data.frame or character. Detail-level metadata containing:
#'   \itemize{
#'     \item \code{variable}: Variable name (for joining)
#'     \item \code{recStart}: Valid range in interval notation (e.g., [18,100])
#'     \item \code{recEnd}: Classification (copy, NA::a, NA::b)
#'     \item \code{proportion}: Category proportion for missing codes
#'   }
#'   Can also be a file path (character) to variable_details.csv.
#' @param df_mock data.frame. Optional. Existing mock data (to check if variable already exists).
#' @param prop_missing numeric. Proportion of missing values (0-1). Default 0 (no missing).
#' @param n integer. Number of observations to generate.
#' @param seed integer. Optional. Random seed for reproducibility.
#'
#' @return data.frame with one column (the generated continuous variable), or NULL if:
#'   \itemize{
#'     \item Variable not found in metadata
#'     \item Variable already exists in df_mock
#'     \item No valid range found in variable_details
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
#'   \item Extract distribution parameters: Read from variables.csv
#'   \item Extract valid range: Parse from variable_details recStart column
#'   \item Generate population: Based on distribution type (uniform/normal/exponential)
#'   \item Apply missing codes: If proportions specified in metadata
#'   \item Apply garbage: Read garbage parameters from variables.csv
#'   \item Apply rType: Coerce to specified R type (integer/double)
#' }
#'
#' **Type coercion (rType)**:
#' The rType column in variables.csv controls output data type:
#' \itemize{
#'   \item \code{\"integer\"}: Rounds and converts to integer (for age, counts)
#'   \item \code{\"double\"}: Double precision (default for continuous)
#' }
#'
#' **Distribution types**:
#' \itemize{
#'   \item \code{\"uniform\"}: Uniform distribution over [min, max] from recStart
#'   \item \code{\"normal\"}: Normal distribution (requires mean, sd in variables.csv)
#'   \item \code{\"exponential\"}: Exponential distribution (requires rate in variables.csv)
#' }
#'
#' **Missing data**:
#' Missing codes are identified by recEnd containing "NA::":
#' \itemize{
#'   \item \code{NA::a}: Skip codes (not applicable)
#'   \item \code{NA::b}: Missing codes (don't know, refusal, not stated)
#' }
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
#' age <- create_con_var(
#'   var = "age",
#'   databaseStart = "cchs2001_p",
#'   variables = variables,
#'   variable_details = variable_details,
#'   n = 1000,
#'   seed = 123
#' )
#'
#' # Expected output: data.frame with 1000 rows, 1 column ("age")
#' # Values: Numeric based on distribution in metadata
#' # Example for age with normal(50, 15):
#' #   age
#' # 1  45
#' # 2  52
#' # 3  48
#' # 4  61
#' # 5  39
#' # ...
#' # Distribution: Normal(mean=50, sd=15), clipped to [18,100]
#' # Type: Integer (if rType="integer" in metadata)
#'
#' # With file paths instead of data frames
#' result <- create_con_var(
#'   var = "BMI",
#'   databaseStart = "minimal-example",
#'   variables = "path/to/variables.csv",
#'   variable_details = "path/to/variable_details.csv",
#'   n = 1000
#' )
#' }
#'
#' @family generators
#' @export
create_con_var <- function(var,
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

  # ========== FALLBACK MODE: Uniform [0, 100] if no details ==========

  if (nrow(details_subset) == 0) {
    values <- runif(n, min = 0, max = 100)

    col <- data.frame(
      new = values,
      stringsAsFactors = FALSE
    )
    names(col)[1] <- var
    return(col)
  }

  # ========== EXTRACT DISTRIBUTION PARAMETERS ==========

  # Extract distribution parameters from var_row (v0.3.0 schema)
  distribution_type <- if ("distribution" %in% names(var_row) && !is.na(var_row$distribution)) {
    var_row$distribution
  } else {
    "uniform"  # default
  }

  mean_val <- if ("mean" %in% names(var_row)) as.numeric(var_row$mean) else NULL
  sd_val <- if ("sd" %in% names(var_row)) as.numeric(var_row$sd) else NULL
  rate_val <- if ("rate" %in% names(var_row)) as.numeric(var_row$rate) else NULL
  shape_val <- if ("shape" %in% names(var_row)) as.numeric(var_row$shape) else NULL

  # Extract range from details_subset recStart (interval notation like [18,100])
  range_min <- NULL
  range_max <- NULL
  if (nrow(details_subset) > 0 && "recStart" %in% names(details_subset)) {
    # Parse first recStart that looks like interval notation
    for (i in seq_len(nrow(details_subset))) {
      rec_val <- details_subset$recStart[i]
      if (!is.na(rec_val) && grepl("^\\[.*,.*\\]$", rec_val)) {
        parsed <- parse_range_notation(rec_val)
        if (!is.null(parsed) && !is.null(parsed$min) && !is.null(parsed$max)) {
          range_min <- parsed$min
          range_max <- parsed$max
          break
        }
      }
    }
  }

  # ========== STEP 1: Generate population (valid values only) ==========

  # Extract proportions to determine valid vs missing
  props <- extract_proportions(details_subset, variable_name = var)
  n_valid <- floor(n * props$valid)

  # Generate based on distribution type
  if (distribution_type == "normal" && !is.na(mean_val) && !is.na(sd_val)) {
    # Normal distribution
    values <- rnorm(n_valid, mean = mean_val, sd = sd_val)

    # Clip to range if specified
    if (!is.null(range_min) && !is.null(range_max)) {
      values <- pmax(range_min, pmin(range_max, values))
    }

  } else if (distribution_type == "exponential" && !is.na(rate_val)) {
    # Exponential distribution
    values <- rexp(n_valid, rate = rate_val)

    # Clip to range if specified
    if (!is.null(range_max)) {
      values <- pmin(range_max, values)
    }

  } else {
    # Uniform distribution (default)
    if (is.null(range_min)) range_min <- 0
    if (is.null(range_max)) range_max <- 100

    values <- runif(n_valid, min = range_min, max = range_max)
  }

  # ========== STEP 2: Apply missing codes ==========

  n_missing <- n - n_valid

  if (n_missing > 0 && length(props$missing) > 0) {
    # Generate missing assignments
    missing_assignments <- sample(
      names(props$missing),
      size = n_missing,
      replace = TRUE,
      prob = unlist(props$missing)
    )

    # Create placeholder values for missing (will be replaced)
    missing_values <- rep(NA, n_missing)

    # Combine valid and missing
    all_values <- c(values, missing_values)
    all_assignments <- c(rep("valid", n_valid), missing_assignments)

    # Create map of missing categories to their codes
    missing_map <- list()
    for (miss_cat in names(props$missing)) {
      miss_row <- details_subset[details_subset$recStart == miss_cat, ]
      if (nrow(miss_row) > 0) {
        # For continuous variables, missing codes should be numeric
        # Check if 'value' column exists or use recStart
        code_value <- if ("value" %in% names(miss_row) && !is.na(miss_row$value[1])) {
          miss_row$value[1]
        } else {
          NA
        }

        if (is.na(code_value) || length(code_value) == 0) {
          # Parse recStart to extract numeric codes
          # For ranges like "[997,999]", sample from 997, 998, 999
          # For single values like "996", use as-is
          parsed <- parse_range_notation(miss_cat)

          if (!is.null(parsed) && parsed$type == "integer" && !is.null(parsed$values)) {
            # Integer range - use expanded values (e.g., [997,999] → c(997, 998, 999))
            code_value <- parsed$values
          } else if (!is.null(parsed) && parsed$type == "single_value") {
            # Single numeric value
            code_value <- parsed$value
          } else {
            # Fallback: try to convert to numeric
            code_value <- suppressWarnings(as.numeric(miss_cat))
            if (is.na(code_value)) {
              # If all else fails, use the string
              code_value <- miss_cat
            }
          }
        }

        missing_map[[miss_cat]] <- code_value
      }
    }

    # Apply missing codes
    values <- apply_missing_codes(
      values = all_values,
      category_assignments = all_assignments,
      missing_code_map = missing_map
    )
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
    variable_type = "continuous",
    missing_codes = missing_codes_vec,  # Pass metadata-based missing codes
    seed = NULL  # Already set globally if needed
  )

  # ========== STEP 4: Apply rType coercion if specified ==========

  # Read rType from var_row (variables.csv)
  if ("rType" %in% names(var_row)) {
    r_type <- var_row$rType
    if (!is.null(r_type) && !is.na(r_type) && r_type != "") {
      values <- switch(r_type,
        "integer" = as.integer(round(values)),
        "double" = as.double(values),
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
