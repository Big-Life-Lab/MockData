#' Create continuous variable for MockData
#'
#' Creates a continuous mock variable based on specifications from variable_details.
#'
#' **Configuration v0.2 format (NEW):**
#' @param var_row data.frame. Single row from mock_data_config (contains variable metadata)
#' @param details_subset data.frame. Rows from mock_data_config_details for this variable
#' @param n integer. Number of observations to generate
#' @param seed integer. Random seed for reproducibility. If NULL, uses global seed.
#' @param df_mock data.frame. The current mock data (to check if variable already exists)
#'
#' **Configuration v0.1 format (LEGACY):**
#' @param var_raw character. The RAW variable name (as it appears in source data)
#' @param cycle character. The cycle identifier (e.g., "cycle1", "HC1")
#' @param variable_details data.frame. Variable details metadata
#' @param variables data.frame. Variables metadata (optional, for validation)
#' @param length integer. The desired length of the mock data vector
#' @param prop_NA numeric. Optional. Proportion of NA values (0 to 1). If NULL, no NAs introduced.
#' @param prop_invalid numeric. Optional. Proportion of invalid out-of-range values (0 to 1). If NULL, no invalid values generated.
#' @param distribution character. Distribution type: "uniform" (default) or "normal"
#'
#' @return data.frame with one column (the new continuous variable), or NULL if:
#'   - Variable details not found (v0.1 only)
#'   - Variable already exists in df_mock
#'   - No valid range found
#'
#' @details
#' **v0.2 format (NEW):**
#' - Uses `extract_distribution_params()` to get distribution parameters from details_subset
#' - Generates population based on specified distribution (uniform, normal, exponential)
#' - Applies missing codes with `apply_missing_codes()`
#' - Adds garbage using `make_garbage()` if garbage rows present
#' - Supports fallback mode: uniform [0, 100] when details_subset is NULL
#'
#' **v0.1 format (LEGACY):**
#' - Uses `get_variable_details_for_raw()` to find variable specifications
#' - Parses ranges from recStart using `parse_range_notation()`
#' - Supports "uniform" or "normal" distribution via parameter
#' - Handles prop_NA and prop_invalid parameters
#'
#' The function auto-detects which format based on parameter names.
#'
#' **Type coercion (rType):**
#' If the metadata contains an `rType` column, values will be coerced to the specified R type:
#' - `"integer"`: Rounds and converts to integer (e.g., for age, counts, years)
#' - `"double"`: Converts to double (default for continuous variables)
#' - Other types are passed through without coercion
#'
#' This allows age variables to return integers (45L) instead of doubles (45.0),
#' matching real survey data. If `rType` is not specified, defaults to double.
#'
#' @examples
#' \dontrun{
#' # v0.2 format - called by create_mock_data()
#' config <- read_mock_data_config("mock_data_config.csv")
#' details <- read_mock_data_config_details("mock_data_config_details.csv")
#' var_row <- config[config$variable == "ALW_2A1", ]
#' details_subset <- get_variable_details(details, variable_name = "ALW_2A1")
#' mock_var <- create_con_var(var_row, details_subset, n = 1000, seed = 123)
#'
#' # v0.1 format (legacy)
#' mock_drinks <- create_con_var(
#'   var_raw = "alcdwky",
#'   cycle = "cycle1",
#'   variable_details = variable_details,
#'   length = 1000,
#'   df_mock = existing_data,
#'   prop_NA = 0.02,
#'   distribution = "normal"
#' )
#' }
#'
#' @family generators
#' @export
create_con_var <- function(var_row = NULL, details_subset = NULL, n = NULL,
                            seed = NULL, df_mock = NULL,
                            # v0.1 legacy parameters
                            var_raw = NULL, cycle = NULL, variable_details = NULL,
                            variables = NULL, length = NULL,
                            prop_NA = NULL, prop_invalid = NULL, distribution = "uniform") {

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

    # FALLBACK MODE: Uniform distribution [0, 100] if details_subset is NULL
    if (is.null(details_subset) || nrow(details_subset) == 0) {
      values <- runif(n, min = 0, max = 100)

      col <- data.frame(
        new = values,
        stringsAsFactors = FALSE
      )
      names(col)[1] <- var_name
      return(col)
    }

    # Extract distribution parameters from details_subset
    params <- extract_distribution_params(details_subset, distribution_type = NULL)

    # STEP 1: Generate population (valid values only)
    # Extract proportions to determine valid vs missing
    props <- extract_proportions(details_subset, variable_name = var_name)
    n_valid <- floor(n * props$valid)

    # Generate based on distribution type
    if (!is.null(params$distribution) && params$distribution == "normal") {
      # Normal distribution
      values <- rnorm(n_valid, mean = params$mean, sd = params$sd)

      # Clip to range if specified
      if (!is.null(params$range_min) && !is.null(params$range_max)) {
        values <- pmax(params$range_min, pmin(params$range_max, values))
      }

    } else if (!is.null(params$distribution) && params$distribution == "exponential") {
      # Exponential distribution
      values <- rexp(n_valid, rate = params$rate)

      # Clip to range if specified
      if (!is.null(params$range_max)) {
        values <- pmin(params$range_max, values)
      }

    } else {
      # Uniform distribution (default)
      range_min <- if (!is.null(params$range_min)) params$range_min else 0
      range_max <- if (!is.null(params$range_max)) params$range_max else 100

      values <- runif(n_valid, min = range_min, max = range_max)
    }

    # STEP 2: Apply missing codes
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
        miss_row <- details_subset[details_subset$recEnd == miss_cat, ]
        if (nrow(miss_row) > 0) {
          # For continuous variables, missing codes should be numeric
          # Check if 'value' column exists (v0.1 format) or use recEnd (v0.2 format)
          code_value <- if ("value" %in% names(miss_row) && !is.na(miss_row$value[1])) {
            miss_row$value[1]
          } else {
            NA
          }

          if (is.na(code_value) || length(code_value) == 0) {
            # Parse recEnd to extract numeric codes
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

    # STEP 3: Apply garbage if specified
    if (has_garbage(details_subset)) {
      values <- make_garbage(
        values = values,
        details_subset = details_subset,
        variable_type = "Continuous",
        seed = NULL  # Already set globally if needed
      )
    }

    # STEP 4: Apply rType coercion if specified
    if ("rType" %in% names(details_subset)) {
      r_type <- details_subset$rType[1]
      if (!is.null(r_type) && !is.na(r_type)) {
        values <- switch(r_type,
          "integer" = as.integer(round(values)),
          "double" = as.double(values),
          values  # No coercion for other types
        )
      }
    }

    # Return as data frame
    col <- data.frame(
      new = values,
      stringsAsFactors = FALSE
    )
    names(col)[1] <- var_name
    return(col)

  } else {
    # ========== v0.1 LEGACY IMPLEMENTATION ==========

    # Level 1: Get variable details for this raw variable + cycle
    var_details <- get_variable_details_for_raw(var_raw, cycle, variable_details, variables)

    if (nrow(var_details) == 0) {
      # No variable details found for this raw variable in this cycle
      return(NULL)
    }

    # Check if variable already exists in mock data
    if (!is.null(df_mock) && var_raw %in% names(df_mock)) {
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
        # Use NA codes from variable_details (convert to numeric)
        na_values <- as.numeric(sample(na_labels, n_na, replace = TRUE))
      } else {
        # Use actual NA
        na_values <- rep(NA_real_, n_na)
      }
    }

    # Combine all values and shuffle
    all_values <- c(values, invalid_values, na_values)
    all_values <- sample(all_values)

    # Ensure exact length
    all_values <- all_values[1:n_obs]

    # Apply rType coercion if specified
    if ("rType" %in% names(var_details)) {
      r_type <- var_details$rType[1]
      if (!is.null(r_type) && !is.na(r_type)) {
        all_values <- switch(r_type,
          "integer" = as.integer(round(all_values)),
          "double" = as.double(all_values),
          all_values  # No coercion for other types
        )
      }
    }

    col <- data.frame(
      new = all_values,
      stringsAsFactors = FALSE
    )

    # Set column name to raw variable name
    names(col)[1] <- var_raw

    return(col)
  }
}
