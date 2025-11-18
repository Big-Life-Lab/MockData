# ==============================================================================
# MockData Helper Functions
# ==============================================================================
# DRY utilities for create_* functions
#
# These helpers centralize common operations across all variable generators:
# - Proportion extraction and validation
# - Missing code application
# - Garbage data model (make_garbage!)
# - Distribution parameter extraction
# - Variable details filtering
#
# Note: Leverages parse_range_notation() from mockdata-parsers.R
# ==============================================================================


# 1. VARIABLE DETAILS OPERATIONS ====

#' Get variable details for specific variable
#'
#' Filters details data frame to return only rows for a specific variable.
#' Handles NULL details (fallback mode) and provides consistent sorting.
#'
#' @param details Data frame. Full details data (or NULL for fallback mode).
#' @param variable_name Character. Variable name to filter (e.g., "ADL_01").
#' @param uid Character. Alternative - filter by uid (e.g., "v_001").
#'
#' @return Subset of details rows for this variable, sorted by uid_detail.
#'   Returns NULL if details is NULL (signals fallback mode).
#'   Returns empty data frame with warning if no matching rows.
#'
#' @examples
#' \dontrun{
#' details <- read_mock_data_config_details("details.csv")
#' var_details <- get_variable_details(details, variable_name = "ADL_01")
#'
#' # Fallback mode
#' var_details <- get_variable_details(NULL, variable_name = "ADL_01")
#' # Returns: NULL
#' }
#'
#' @family mockdata-helpers
#' @export
get_variable_details <- function(details, variable_name = NULL, uid = NULL) {
  # Handle NULL details (fallback mode)
  if (is.null(details)) {
    return(NULL)
  }

  # Validate inputs
  if (is.null(variable_name) && is.null(uid)) {
    stop("Must provide either variable_name or uid")
  }

  # Filter by variable_name or uid
  if (!is.null(variable_name)) {
    subset <- details[details$variable == variable_name, ]
  } else {
    subset <- details[details$uid == uid, ]
  }

  # Warn if no matches
  if (nrow(subset) == 0) {
    search_term <- if (!is.null(variable_name)) variable_name else uid
    warning("No details found for variable: ", search_term)
    return(subset)  # Empty data frame with same structure
  }

  # Sort by uid_detail for consistent ordering
  if ("uid_detail" %in% names(subset)) {
    subset <- subset[order(subset$uid_detail), ]
  }

  return(subset)
}


# 2. PROPORTION OPERATIONS ====

#' Extract proportions from details subset
#'
#' Parses proportion column and organizes by type (valid, missing, garbage).
#' Validates that valid + missing proportions sum to 1.0 (±0.001 tolerance).
#' Auto-normalizes with warning if sum != 1.0.
#'
#' @param details_subset Data frame. Rows from details for one variable.
#' @param variable_name Character. Variable name for error messages.
#'
#' @return Named list with:
#'   - valid: Numeric. Proportion for valid values (sum of all non-missing, non-garbage)
#'   - missing: Named list. Proportion for each missing code (e.g., "7" = 0.03)
#'   - garbage: Named list. Proportion for each garbage type (e.g., corrupt_low = 0.02)
#'   - categories: Character vector. All non-garbage recStart values
#'   - category_proportions: Numeric vector. Proportions for sampling (aligned with categories)
#'
#' @details
#' Population proportions (valid + missing) must sum to 1.0. Garbage proportions
#' are separate and applied to valid values only.
#'
#' If proportions are NA or missing, returns uniform probabilities.
#'
#' @examples
#' \dontrun{
#' details <- read_mock_data_config_details("details.csv")
#' details_subset <- details[details$variable == "ADL_01", ]
#' props <- extract_proportions(details_subset, "ADL_01")
#' # Returns: list(valid = 0.92, missing = list("7" = 0.03, "9" = 0.05), ...)
#' }
#'
#' @family mockdata-helpers
#' @export
extract_proportions <- function(details_subset, variable_name = "variable") {
  # Handle NULL or empty details
  if (is.null(details_subset) || nrow(details_subset) == 0) {
    return(list(
      valid = 1.0,
      missing = list(),
      garbage = list(),
      categories = character(0),
      category_proportions = numeric(0)
    ))
  }

  # Identify garbage rows (exclude from population sum)
  is_garbage_row <- grepl("^garbage_", details_subset$recStart, ignore.case = TRUE)

  # Identify "else" rows - harmonization logic that recodes to NA::b
  # "else" acts as a garbage collector, ensuring garbage data → NA::b
  # Must exclude from population: it's not a valid missing code category,
  # but rather a catch-all for harmonization (exception to "recodes to NA::b = missing code" rule)
  is_else <- details_subset$recStart == "else"

  # Split into population (valid + missing) and garbage
  # Exclude both garbage AND "else" from population
  pop_rows <- details_subset[!is_garbage_row & !is_else, ]
  garbage_rows <- details_subset[is_garbage_row, ]

  # Extract population proportions
  pop_proportions <- pop_rows$proportion
  has_proportions <- !all(is.na(pop_proportions))

  if (!has_proportions) {
    # Uniform distribution if no proportions specified
    n_categories <- nrow(pop_rows)
    pop_proportions <- rep(1.0 / n_categories, n_categories)
  } else {
    # Validate and auto-normalize
    prop_sum <- sum(pop_proportions, na.rm = TRUE)
    tolerance <- 0.001

    if (abs(prop_sum - 1.0) > tolerance) {
      warning("Proportions for variable '", variable_name, "' sum to ",
              round(prop_sum, 4), " (expected 1.0). Auto-normalizing.")
      norm_factor <- 1.0 / prop_sum
      pop_proportions <- pop_proportions * norm_factor
    }
  }

  # Separate missing codes from valid
  # Common missing code patterns: numeric codes 7,8,9,96,97,98,99,996,997,998,999
  # Check catLabelLong if it exists, otherwise check recStart pattern
  #
  # IMPORTANT: v0.2.1 uses interval notation [min,max] for ranges, which should NOT be treated as missing
  # Only treat as missing if:
  #   1. catLabelLong explicitly says "missing", OR
  #   2. recStart is a single-digit or double-digit code ending in 7,8,9 (not part of a larger range)
  has_label_long <- "catLabelLong" %in% names(pop_rows)

  # Detect interval notation (ranges for continuous variables): [min,max]
  is_interval_notation <- grepl("^\\[.*,.*\\]$", pop_rows$recStart)

  # Missing codes: explicit label OR numeric codes ending in 7,8,9 (but not interval notation)
  # Check catLabelLong column if it exists
  if (has_label_long) {
    is_missing <- !is_interval_notation & (
      pop_rows$catLabelLong == "missing" |
      (grepl("^[0-9]+$", pop_rows$recStart) & grepl("[789]$", pop_rows$recStart))
    )
  } else {
    # Only check numeric codes ending in 7,8,9
    is_missing <- !is_interval_notation &
      grepl("^[0-9]+$", pop_rows$recStart) &
      grepl("[789]$", pop_rows$recStart)
  }

  # Build results
  # Categories should ONLY include valid (non-missing) rows
  valid_rows <- pop_rows[!is_missing, ]
  missing_rows <- pop_rows[is_missing, ]

  result <- list(
    valid = sum(pop_proportions[!is_missing], na.rm = TRUE),
    missing = list(),
    garbage = list(),
    categories = valid_rows$recStart,
    category_proportions = pop_proportions[!is_missing]
  )

  # Normalize category proportions to sum to 1.0
  if (length(result$category_proportions) > 0 && result$valid > 0) {
    result$category_proportions <- result$category_proportions / result$valid
  }

  # Add missing codes
  if (nrow(missing_rows) > 0) {
    result$missing <- as.list(setNames(pop_proportions[is_missing], missing_rows$recStart))
  }

  # Extract garbage proportions
  if (nrow(garbage_rows) > 0) {
    garbage_props <- garbage_rows$proportion
    garbage_names <- garbage_rows$recStart
    result$garbage <- as.list(setNames(garbage_props, garbage_names))
  }

  return(result)
}


#' Sample with proportions
#'
#' Generates category assignments with specified proportions.
#' Handles NA proportions (uniform fallback) and validates inputs.
#'
#' @param categories Character or numeric vector. Category values.
#' @param proportions Numeric vector. Proportions (same length, sum to 1.0).
#' @param n Integer. Number of samples.
#' @param seed Integer. Optional random seed.
#'
#' @return Vector of length n with category assignments.
#'
#' @examples
#' \dontrun{
#' categories <- c("1", "2", "7", "9")
#' proportions <- c(0.4, 0.52, 0.03, 0.05)
#' assignments <- sample_with_proportions(categories, proportions, n = 1000)
#' }
#'
#' @family mockdata-helpers
#' @export
sample_with_proportions <- function(categories, proportions, n, seed = NULL) {
  # Set seed if provided
  if (!is.null(seed)) {
    set.seed(seed)
  }

  # Validate inputs
  if (length(categories) != length(proportions)) {
    stop("categories and proportions must have same length")
  }

  # Handle NA proportions - use uniform
  if (all(is.na(proportions))) {
    proportions <- rep(1.0 / length(categories), length(categories))
  }

  # Normalize if sum != 1.0
  prop_sum <- sum(proportions, na.rm = TRUE)
  if (abs(prop_sum - 1.0) > 0.001) {
    proportions <- proportions / prop_sum
  }

  # Sample
  sample(categories, size = n, replace = TRUE, prob = proportions)
}


# 3. DISTRIBUTION PARAMETERS ====

#' Extract distribution parameters from details
#'
#' Extracts distribution-specific parameters (mean, sd, rate, shape, range) from
#' details subset. Auto-detects distribution type if not specified.
#'
#' @param details_subset Data frame. Rows from details for one variable.
#' @param distribution_type Character. Optional ("normal", "uniform", "gompertz",
#'   "exponential", "poisson"). If NULL, attempts auto-detection.
#'
#' @return Named list with distribution type and parameters:
#'   - distribution: Character. Distribution type.
#'   - mean, sd: Numeric. For normal distribution.
#'   - rate, shape: Numeric. For Gompertz/exponential.
#'   - range_min, range_max: Numeric. For uniform or truncation.
#'
#' @examples
#' \dontrun{
#' params <- extract_distribution_params(details_subset, "normal")
#' # Returns: list(distribution = "normal", mean = 25, sd = 5, range_min = 18.5, range_max = 40)
#' }
#'
#' @family mockdata-helpers
#' @export
extract_distribution_params <- function(details_subset, distribution_type = NULL) {
  # Handle NULL or empty details
  if (is.null(details_subset) || nrow(details_subset) == 0) {
    return(list(distribution = "uniform", range_min = 0, range_max = 100))
  }

  # Auto-detect distribution type if not specified
  if (is.null(distribution_type)) {
    has_mean <- "mean" %in% details_subset$recEnd
    has_sd <- "sd" %in% details_subset$recEnd
    has_rate <- "rate" %in% details_subset$recEnd
    has_shape <- "shape" %in% details_subset$recEnd

    if (has_mean && has_sd) {
      distribution_type <- "normal"
    } else if (has_rate && has_shape) {
      distribution_type <- "gompertz"
    } else if (has_rate) {
      distribution_type <- "exponential"
    } else {
      distribution_type <- "uniform"
    }
  }

  # Extract parameters based on distribution type
  result <- list(distribution = distribution_type)

  # Extract mean and sd (for normal)
  if ("mean" %in% details_subset$recEnd) {
    mean_row <- details_subset[details_subset$recEnd == "mean", ]
    result$mean <- as.numeric(mean_row$value[1])
  }

  if ("sd" %in% details_subset$recEnd) {
    sd_row <- details_subset[details_subset$recEnd == "sd", ]
    result$sd <- as.numeric(sd_row$value[1])
  }

  # Extract rate and shape (for Gompertz/exponential)
  if ("rate" %in% details_subset$recEnd) {
    rate_row <- details_subset[details_subset$recEnd == "rate", ]
    result$rate <- as.numeric(rate_row$value[1])
  }

  if ("shape" %in% details_subset$recEnd) {
    shape_row <- details_subset[details_subset$recEnd == "shape", ]
    result$shape <- as.numeric(shape_row$value[1])
  }

  # Extract range (for uniform or truncation)
  # Parse from recStart using interval notation
  if ("recStart" %in% names(details_subset)) {
    # Look for rows with recEnd = "valid" which specify the valid range
    valid_rows <- details_subset[details_subset$recEnd == "valid", ]

    if (nrow(valid_rows) > 0 && !is.na(valid_rows$recStart[1]) && valid_rows$recStart[1] != "") {
      # Parse the valid range from recStart interval notation
      parsed <- parse_range_notation(valid_rows$recStart[1])

      if (!is.null(parsed) && parsed$type %in% c("integer", "continuous", "single_value")) {
        result$range_min <- parsed$min
        result$range_max <- parsed$max
      }
    }
  }

  # Validate required parameters
  if (distribution_type == "normal") {
    if (is.null(result$mean) || is.null(result$sd)) {
      stop("Normal distribution requires mean and sd parameters")
    }
  }

  return(result)
}


# 4. MISSING CODE APPLICATION ====

#' Apply missing codes to values
#'
#' Replaces category assignments with actual missing code values (7, 8, 9, etc.).
#' Handles different data types (numeric, Date, character).
#'
#' @param values Vector. Generated values (numeric, date, or categorical).
#' @param category_assignments Vector. Category assignments ("valid", "7", "8", "9", etc.).
#' @param missing_code_map Named list. Maps category names to codes (e.g., list("7" = 7, "9" = 9)).
#'
#' @return Vector with missing codes applied.
#'
#' @examples
#' \dontrun{
#' values <- c(23.5, 45.2, 18.9, 30.1, 25.6)
#' assignments <- c("valid", "valid", "7", "valid", "9")
#' missing_map <- list("7" = 7, "9" = 9)
#' result <- apply_missing_codes(values, assignments, missing_map)
#' # Returns: c(23.5, 45.2, 7, 30.1, 9)
#' }
#'
#' @family mockdata-helpers
#' @export
apply_missing_codes <- function(values, category_assignments, missing_code_map) {
  # Handle NULL or empty inputs
  if (is.null(values) || length(values) == 0) {
    return(values)
  }

  if (is.null(missing_code_map) || length(missing_code_map) == 0) {
    return(values)
  }

  # Apply missing codes
  for (code_name in names(missing_code_map)) {
    code_value <- missing_code_map[[code_name]]
    missing_idx <- which(category_assignments == code_name)

    if (length(missing_idx) > 0) {
      # Handle type coercion if needed
      if (inherits(values, "Date") && is.numeric(code_value)) {
        # Convert Date to numeric for missing codes
        values <- as.numeric(values)
      }

      # If code_value is a vector (e.g., c(997, 998, 999)), sample from it
      if (length(code_value) > 1) {
        values[missing_idx] <- sample(code_value, length(missing_idx), replace = TRUE)
      } else {
        values[missing_idx] <- code_value
      }
    }
  }

  return(values)
}


# 5. GARBAGE (MAKE GARBAGE!) ====

#' Check if garbage is specified
#'
#' Quick check for presence of garbage rows (recEnd starts with "garbage_").
#'
#' @param details_subset Data frame. Rows from details for one variable.
#'
#' @return Logical. TRUE if garbage rows exist, FALSE otherwise.
#'
#' @examples
#' \dontrun{
#' if (has_garbage(details_subset)) {
#'   values <- make_garbage(values, details_subset, "continuous")
#' }
#' }
#'
#' @family mockdata-helpers
#' @export
has_garbage <- function(details_subset) {
  if (is.null(details_subset) || nrow(details_subset) == 0) {
    return(FALSE)
  }

  any(grepl("^garbage_", details_subset$recEnd, ignore.case = TRUE))
}


#' Make garbage
#'
#' Applies garbage model to introduce realistic data quality issues.
#' Replaces some valid values with implausible values (garbage_low, garbage_high,
#' garbage_future, etc.).
#'
#' @param values Vector. Generated values (already has valid + missing).
#' @param details_subset Data frame. Rows from details (contains garbage_* rows).
#' @param variable_type Character. "categorical", "continuous", "date", "survival".
#' @param seed Integer. Optional random seed.
#'
#' @return Vector with garbage applied.
#'
#' @details
#' Two-step garbage model:
#' 1. Identify valid value indices (not missing codes)
#' 2. Sample from valid indices based on garbage proportions
#' 3. Replace with garbage values
#' 4. Ensure no overlap (use setdiff for sequential garbage application)
#'
#' Garbage types:
#' - garbage_low: Values below valid range (continuous, integer)
#' - garbage_high: Values above valid range (continuous, integer)
#' - garbage_future: Future dates (date, survival)
#'
#' @examples
#' \dontrun{
#' values <- c(23.5, 45.2, 7, 30.1, 9, 18.9, 25.6)
#' result <- make_garbage(values, details_subset, "continuous", seed = 123)
#' # Some valid values replaced with implausible values
#' }
#'
#' @family mockdata-helpers
#' @export
make_garbage <- function(values, details_subset, variable_type, seed = NULL) {
  # Set seed if provided
  if (!is.null(seed)) {
    set.seed(seed)
  }

  # Check if garbage specified
  if (!has_garbage(details_subset)) {
    return(values)
  }

  # Extract garbage rows
  garbage_rows <- details_subset[grepl("^garbage_", details_subset$recEnd, ignore.case = TRUE), ]

  if (nrow(garbage_rows) == 0) {
    return(values)
  }

  # Identify valid indices (exclude missing codes like 7, 8, 9, 996, 997, etc.)
  # Assume missing codes are numeric values in specific ranges
  is_missing <- values %in% c(7, 8, 9, 96, 97, 98, 99, 996, 997, 998, 999)
  valid_idx <- which(!is_missing & !is.na(values))

  if (length(valid_idx) == 0) {
    return(values)  # No valid values to make garbage
  }

  # Apply each garbage type sequentially
  remaining_idx <- valid_idx

  for (i in seq_len(nrow(garbage_rows))) {
    garbage_row <- garbage_rows[i, ]
    garbage_type <- garbage_row$recEnd
    garbage_prop <- garbage_row$proportion

    # Skip if proportion is NA or 0
    if (is.na(garbage_prop) || garbage_prop == 0) {
      next
    }

    # Calculate number to make garbage
    n_valid <- length(valid_idx)
    n_garbage <- round(n_valid * garbage_prop)

    if (n_garbage == 0 || length(remaining_idx) == 0) {
      next
    }

    # Sample indices to make garbage (without replacement)
    n_garbage <- min(n_garbage, length(remaining_idx))
    garbage_idx <- sample(remaining_idx, n_garbage)

    # Generate garbage values
    garbage_values <- generate_garbage_values(garbage_type, garbage_row, variable_type, n_garbage)

    # Apply garbage
    values[garbage_idx] <- garbage_values

    # Remove garbage indices from remaining pool (no overlap)
    remaining_idx <- setdiff(remaining_idx, garbage_idx)
  }

  return(values)
}


#' Generate garbage values
#'
#' Generates implausible values for garbage based on type.
#' Helper function for make_garbage().
#'
#' @param garbage_type Character. "garbage_low", "garbage_high", "garbage_future", etc.
#' @param garbage_row Data frame row. Contains recStart with interval notation for garbage range.
#' @param variable_type Character. "continuous", "date", etc.
#' @param n Integer. Number of values to generate.
#'
#' @return Vector of garbage values.
#'
#' @family mockdata-helpers
#' @export
generate_garbage_values <- function(garbage_type, garbage_row, variable_type, n) {
  # Extract garbage range from recStart using interval notation
  range_min <- NA
  range_max <- NA

  if ("recStart" %in% names(garbage_row)) {
    rec_start <- garbage_row$recStart
    if (!is.na(rec_start) && rec_start != "") {
      parsed <- parse_range_notation(rec_start)
      if (!is.null(parsed) && parsed$type %in% c("integer", "continuous", "single_value")) {
        range_min <- parsed$min
        range_max <- parsed$max
      }
    }
  }

  if (grepl("garbage_low", garbage_type, ignore.case = TRUE)) {
    # Generate values below valid range
    if (!is.na(range_min) && !is.na(range_max)) {
      # Use specified range
      values <- runif(n, range_min, range_max)
    } else {
      # Default: very low values
      values <- runif(n, -100, -1)
    }

  } else if (grepl("garbage_high", garbage_type, ignore.case = TRUE)) {
    # Generate values above valid range
    if (!is.na(range_min) && !is.na(range_max)) {
      values <- runif(n, range_min, range_max)
    } else {
      # Default: very high values
      values <- runif(n, 200, 1000)
    }

  } else if (grepl("garbage_future", garbage_type, ignore.case = TRUE)) {
    # Generate future dates
    if (variable_type %in% c("date", "survival")) {
      today <- Sys.Date()
      future_start <- today + 365
      future_end <- today + 365 * 100
      values <- sample(seq(future_start, future_end, by = "day"), n, replace = TRUE)
    } else {
      values <- rep(NA, n)
    }

  } else if (grepl("garbage_past", garbage_type, ignore.case = TRUE)) {
    # Generate past dates (less common)
    if (variable_type %in% c("date", "survival")) {
      past_end <- Sys.Date() - 365 * 100
      past_start <- Sys.Date() - 365 * 200
      values <- sample(seq(past_start, past_end, by = "day"), n, replace = TRUE)
    } else {
      values <- rep(NA, n)
    }

  } else {
    # Unknown garbage type - return NA
    warning("Unknown garbage type: ", garbage_type)
    values <- rep(NA, n)
  }

  return(values)
}


#' Apply garbage data from variables.csv
#'
#' Applies garbage data using parameters from variables.csv extension columns.
#' Garbage data is specified at the variable level.
#'
#' @param values Vector. Generated values (already has valid + missing).
#' @param var_row Data frame. Single row from variables.csv (contains garbage data parameters).
#' @param variable_type Character. "categorical", "continuous", "integer", "date".
#' @param missing_codes Numeric vector. Optional. Missing codes extracted from metadata
#'   (rows where recEnd contains "NA::"). Used to exclude missing codes from valid range
#'   calculations. If NULL, uses hardcoded fallback for backward compatibility.
#' @param seed Integer. Optional random seed.
#'
#' @return Vector with garbage data applied.
#'
#' @details
#' **Garbage data fields (in variables.csv):**
#'
#' **Garbage parameters:**
#' - garbage_low_prop: Proportion for low garbage values (0-1)
#' - garbage_low_range: Range for low values (interval notation "[min,max]")
#' - garbage_high_prop: Proportion for high garbage values (0-1)
#' - garbage_high_range: Range for high values (interval notation "[min,max]")
#'
#' **Application order:**
#' 1. Apply garbage_low (if specified)
#' 2. Apply garbage_high (if specified)
#' 3. No overlap - indices removed after each application
#'
#' **Config-driven generation:**
#' If var_row is NULL or missing garbage fields, no garbage data applied.
#'
#' @examples
#' \dontrun{
#' var_row <- data.frame(
#'   variable = "BMI",
#'   garbage_low_prop = 0.02,
#'   garbage_low_range = "[-10,0]",
#'   garbage_high_prop = 0.01,
#'   garbage_high_range = "[60,150]"
#' )
#' values <- c(23.5, 45.2, 30.1, 18.9, 25.6)
#' result <- apply_garbage(values, var_row, "continuous", seed = 123)
#' }
#'
#' @family mockdata-helpers
#' @export
apply_garbage <- function(values, var_row, variable_type, missing_codes = NULL, seed = NULL) {
  # Set seed if provided
  if (!is.null(seed)) {
    set.seed(seed)
  }

  # Check if var_row has garbage data fields
  if (is.null(var_row) || !is.data.frame(var_row) || nrow(var_row) == 0) {
    return(values)
  }

  # Check for garbage data fields
  has_low <- "garbage_low_prop" %in% names(var_row) && "garbage_low_range" %in% names(var_row)
  has_high <- "garbage_high_prop" %in% names(var_row) && "garbage_high_range" %in% names(var_row)

  # Check if any garbage is specified
  has_garbage_low <- has_low && !is.na(var_row$garbage_low_prop) && var_row$garbage_low_prop > 0
  has_garbage_high <- has_high && !is.na(var_row$garbage_high_prop) && var_row$garbage_high_prop > 0

  if (!has_garbage_low && !has_garbage_high) {
    return(values)  # No garbage data specified
  }

  # Identify valid indices (exclude missing codes and NA)
  if (is.null(missing_codes) || length(missing_codes) == 0) {
    # No missing codes defined - only exclude NA values
    # This is safer than assuming hardcoded values that may not apply to this dataset
    valid_idx <- which(!is.na(values))
  } else {
    # Use metadata-based missing codes (from recEnd = "NA::a" or "NA::b")
    is_missing <- values %in% missing_codes
    valid_idx <- which(!is_missing & !is.na(values))
  }

  if (length(valid_idx) == 0) {
    return(values)  # No valid values to set to garbage
  }

  # ==========================================================================
  # Apply garbage sequentially (low, then high)
  # ==========================================================================
  remaining_idx <- valid_idx

    # GARBAGE_LOW
    if (has_low) {
    garbage_low_prop <- var_row$garbage_low_prop
    garbage_low_range <- var_row$garbage_low_range

    if (!is.na(garbage_low_prop) && !is.na(garbage_low_range) &&
        garbage_low_prop > 0 && garbage_low_range != "") {

      # Calculate number to set to garbage
      n_valid <- length(valid_idx)
      n_garbage <- round(n_valid * garbage_low_prop)

      if (n_garbage > 0 && length(remaining_idx) > 0) {
        # Sample indices
        n_garbage <- min(n_garbage, length(remaining_idx))
        garbage_idx <- sample(remaining_idx, n_garbage)

        # Parse range
        parsed <- parse_range_notation(garbage_low_range)

        if (!is.null(parsed)) {
          # Generate garbage values
          if (parsed$type == "date") {
            # Date garbage
            garbage_dates_obj <- sample(
              seq(parsed$min, parsed$max, by = "day"),
              n_garbage,
              replace = TRUE
            )
            # Convert to character to avoid numeric coercion when assigning to char vector
            garbage_values <- as.character(garbage_dates_obj)
          } else {
            # Numeric garbage (integer or continuous)
            garbage_values <- runif(n_garbage, parsed$min, parsed$max)

            # Round if integer type
            if (variable_type %in% c("integer", "categorical")) {
              garbage_values <- round(garbage_values)
            }
          }

          # Apply garbage
          values[garbage_idx] <- garbage_values

          # Remove from remaining pool
          remaining_idx <- setdiff(remaining_idx, garbage_idx)
        }
      }
    }
  }

  # GARBAGE_HIGH
  if (has_high) {
    garbage_high_prop <- var_row$garbage_high_prop
    garbage_high_range <- var_row$garbage_high_range

    if (!is.na(garbage_high_prop) && !is.na(garbage_high_range) &&
        garbage_high_prop > 0 && garbage_high_range != "") {

      # Calculate number to set to garbage
      n_valid <- length(valid_idx)
      n_garbage <- round(n_valid * garbage_high_prop)

      if (n_garbage > 0 && length(remaining_idx) > 0) {
        # Sample indices
        n_garbage <- min(n_garbage, length(remaining_idx))
        garbage_idx <- sample(remaining_idx, n_garbage)

        # Parse range
        parsed <- parse_range_notation(garbage_high_range)

        if (!is.null(parsed)) {
          # Generate garbage values
          if (parsed$type == "date") {
            # Date garbage
            garbage_dates_obj <- sample(
              seq(parsed$min, parsed$max, by = "day"),
              n_garbage,
              replace = TRUE
            )
            # Convert to character to avoid numeric coercion when assigning to char vector
            garbage_values <- as.character(garbage_dates_obj)
          } else {
            # Numeric garbage (integer or continuous)
            garbage_values <- runif(n_garbage, parsed$min, parsed$max)

            # Round if integer type
            if (variable_type %in% c("integer", "categorical")) {
              garbage_values <- round(garbage_values)
            }
          }

          # Apply garbage
          values[garbage_idx] <- garbage_values

          # Remove from remaining pool
          remaining_idx <- setdiff(remaining_idx, garbage_idx)
        }
      }
    }
  }

  return(values)
}


# 7. R TYPE COERCION ====

#' Apply rType defaults to variable details
#'
#' Adds rType column with smart defaults if missing. This enables
#' language-specific type coercion (R types like integer, double, factor).
#'
#' @param details Data frame. Variable details metadata.
#'
#' @return Data frame with rType column added (if missing) or validated (if present).
#'
#' @details
#' ## Default rType values
#'
#' If rType column is missing, defaults are applied based on variable type:
#' - `continuous`/`cont` → `"double"`
#' - `categorical`/`cat` → `"factor"`
#' - `date` → `"Date"`
#' - `logical` → `"logical"`
#' - Unknown → `"character"`
#'
#' ## Valid rType values
#'
#' - `"integer"`: Whole numbers (age, counts, years)
#' - `"double"`: Decimal numbers (BMI, income, percentages)
#' - `"factor"`: Categorical with levels
#' - `"character"`: Text codes
#' - `"logical"`: TRUE/FALSE values
#' - `"Date"`: Date objects
#' - `"POSIXct"`: Datetime objects
#'
#' @examples
#' \dontrun{
#' # Missing rType - defaults applied
#' details <- data.frame(
#'   variable = "age",
#'   typeEnd = "cont",
#'   recStart = "[18, 100]"
#' )
#' details <- apply_rtype_defaults(details)
#' # details$rType is now "double"
#'
#' # Existing rType - preserved
#' details <- data.frame(
#'   variable = "age",
#'   typeEnd = "cont",
#'   rType = "integer"
#' )
#' details <- apply_rtype_defaults(details)
#' # details$rType remains "integer"
#' }
#'
#' @family mockdata-helpers
#' @export
apply_rtype_defaults <- function(details) {

  # If rType already exists, validate and return
  if ("rType" %in% names(details)) {
    # Validate rType values
    valid_rtypes <- c("integer", "double", "factor", "character",
                      "logical", "Date", "POSIXct")
    invalid <- setdiff(unique(details$rType[!is.na(details$rType)]), valid_rtypes)
    if (length(invalid) > 0) {
      warning("Invalid rType values found: ", paste(invalid, collapse = ", "),
              ". Valid values: ", paste(valid_rtypes, collapse = ", "),
              call. = FALSE)
    }
    return(details)
  }

  # Add rType column with defaults
  details$rType <- NA_character_

  # Determine type column (could be typeEnd or variableType)
  type_col <- if ("typeEnd" %in% names(details)) {
    "typeEnd"
  } else if ("variableType" %in% names(details)) {
    "variableType"
  } else {
    NULL
  }

  if (!is.null(type_col)) {
    # Apply defaults based on type
    type_lower <- tolower(details[[type_col]])

    details$rType <- dplyr::case_when(
      type_lower %in% c("cont", "continuous") ~ "double",    # Continuous → double (default)
      type_lower %in% c("cat", "categorical") ~ "factor",    # Categorical → factor (default)
      type_lower == "date" ~ "Date",                         # Date → Date (default)
      type_lower == "logical" ~ "logical",                   # Logical → logical
      TRUE ~ "character"                                     # Fallback
    )
  } else {
    # No type column found - default to character
    details$rType <- "character"
  }

  return(details)
}


# 8. CYCLE AND VARIABLE QUERIES ====

#' Get list of variables used in a specific database/cycle
#'
#' Returns a data frame containing all variables that are available in a
#' specified database/cycle, with their metadata and extracted raw variable names.
#'
#' @param cycle Character string specifying the database/cycle (e.g., "cycle1",
#'   "cycle1_meds" for CHMS; "cchs2001", "cchs2017_p" for CCHS).
#' @param variables Data frame from variables.csv containing variable metadata.
#' @param variable_details Data frame from variable_details.csv containing detailed recoding specifications.
#' @param include_derived Logical. Should derived variables be included? Default is TRUE.
#'
#' @return Data frame with columns:
#' \itemize{
#'   \item variable - Harmonized variable name
#'   \item variable_raw - Raw source variable name (extracted from variableStart)
#'   \item label - Human-readable label
#'   \item variableType - "Categorical" or "Continuous"
#'   \item databaseStart - Which databases/cycles the variable appears in
#'   \item variableStart - Original variableStart string (for reference)
#' }
#'
#' Returns empty data frame if no variables found for the database/cycle.
#'
#' @details
#' The function filters variables.csv by checking if the database/cycle appears
#' in the `databaseStart` field (exact match), then uses \code{\link{parse_variable_start}}
#' to extract the raw variable name from the `variableStart` field.
#'
#' **Important**: Uses exact matching to avoid false positives (e.g., "cycle1"
#' should not match "cycle1_meds").
#'
#' Derived variables (those with "DerivedVar::" in variableStart) return NA for
#' variable_raw since they require custom derivation logic.
#'
#' @examples
#' \dontrun{
#' # Load metadata
#' variables <- read.csv("inst/extdata/variables.csv")
#' variable_details <- read.csv("inst/extdata/variable-details.csv")
#'
#' # CHMS example
#' cycle1_vars <- get_cycle_variables("cycle1", variables, variable_details)
#'
#' # CCHS example
#' cchs2001_vars <- get_cycle_variables("cchs2001", variables, variable_details)
#'
#' # Exclude derived variables
#' cycle1_original <- get_cycle_variables("cycle1", variables, variable_details,
#'                                         include_derived = FALSE)
#' }
#'
#' @seealso \code{\link{parse_variable_start}}
#'
#' @family mockdata-helpers
#' @export
get_cycle_variables <- function(cycle, variables, variable_details,
                                 include_derived = TRUE) {
  # Basic validation
  if (is.null(cycle) || cycle == "") {
    return(data.frame(
      variable = character(),
      variable_raw = character(),
      label = character(),
      variableType = character(),
      databaseStart = character(),
      variableStart = character(),
      stringsAsFactors = FALSE
    ))
  }

  # Filter variables by cycle using EXACT match
  # Split databaseStart by comma and check for exact cycle match
  # This prevents "cycle1" from matching "cycle1_meds"
  cycle_vars <- variables[sapply(variables$databaseStart, function(db_start) {
    cycles <- strsplit(db_start, ",")[[1]]
    cycles <- trimws(cycles)
    cycle %in% cycles
  }), ]

  # If no variables found, return empty data frame
  if (nrow(cycle_vars) == 0) {
    return(data.frame(
      variable = character(),
      variable_raw = character(),
      label = character(),
      variableType = character(),
      databaseStart = character(),
      variableStart = character(),
      stringsAsFactors = FALSE
    ))
  }

  # Extract raw variable names using parse_variable_start
  cycle_vars$variable_raw <- sapply(cycle_vars$variableStart, function(vs) {
    raw_name <- parse_variable_start(vs, cycle)
    if (is.null(raw_name)) return(NA_character_)
    return(raw_name)
  })

  # Filter out derived variables if requested
  if (!include_derived) {
    cycle_vars <- cycle_vars[!grepl("DerivedVar::", cycle_vars$variableStart, fixed = TRUE), ]
  }

  # Select and return relevant columns
  result <- data.frame(
    variable = cycle_vars$variable,
    variable_raw = cycle_vars$variable_raw,
    label = cycle_vars$label,
    variableType = cycle_vars$variableType,
    databaseStart = cycle_vars$databaseStart,
    variableStart = cycle_vars$variableStart,
    stringsAsFactors = FALSE
  )

  return(result)
}


#' Get list of unique raw variables for a database/cycle
#'
#' Returns a data frame of unique raw (source) variables that should be generated
#' for a specific database/cycle. This is the correct approach for generating mock
#' data, as we want to create the raw source data, not the harmonized variables.
#'
#' @param cycle Character string specifying the database/cycle (e.g., "cycle1",
#'   "cycle1_meds" for CHMS; "cchs2001" for CCHS).
#' @param variables Data frame from variables.csv containing variable metadata.
#' @param variable_details Data frame from variable_details.csv containing detailed specifications.
#' @param include_derived Logical. Should derived variables be included? Default is FALSE
#'   (since derived variables are computed from other variables, not in raw data).
#'
#' @return Data frame with columns:
#' \itemize{
#'   \item variable_raw - Raw source variable name (unique)
#'   \item variableType - "Categorical" or "Continuous"
#'   \item harmonized_vars - Comma-separated list of harmonized variables that use this raw variable
#'   \item n_harmonized - Count of how many harmonized variables use this raw variable
#' }
#'
#' @details
#' This function:
#' \enumerate{
#'   \item Gets all variables available in the database/cycle using \code{\link{get_cycle_variables}}
#'   \item Extracts unique raw variable names
#'   \item Groups harmonized variables by their raw source
#'   \item Returns one row per unique raw variable
#' }
#'
#' This is the correct approach because:
#' \itemize{
#'   \item Mock data should represent raw source data (before harmonization)
#'   \item Each raw variable should appear exactly once
#'   \item Multiple harmonized variables can derive from the same raw variable
#' }
#'
#' @examples
#' \dontrun{
#' # Load metadata
#' variables <- read.csv("inst/extdata/variables.csv")
#' variable_details <- read.csv("inst/extdata/variable-details.csv")
#'
#' # CHMS example
#' raw_vars <- get_raw_variables("cycle1", variables, variable_details)
#'
#' # CCHS example
#' raw_vars_cchs <- get_raw_variables("cchs2001", variables, variable_details)
#'
#' # Generate mock data from raw variables
#' for (i in 1:nrow(raw_vars)) {
#'   var_raw <- raw_vars$variable_raw[i]
#'   var_type <- raw_vars$variableType[i]
#'   # Generate the raw variable...
#' }
#' }
#'
#' @seealso \code{\link{get_cycle_variables}}, \code{\link{parse_variable_start}}
#'
#' @family mockdata-helpers
#' @export
get_raw_variables <- function(cycle, variables, variable_details,
                               include_derived = FALSE) {
  # Get all cycle variables (harmonized)
  cycle_vars <- get_cycle_variables(cycle, variables, variable_details,
                                     include_derived = include_derived)

  # Remove rows with NA raw variable names (e.g., DerivedVar that couldn't be parsed)
  cycle_vars <- cycle_vars[!is.na(cycle_vars$variable_raw), ]

  # If no variables, return empty data frame
  if (nrow(cycle_vars) == 0) {
    return(data.frame(
      variable_raw = character(),
      variableType = character(),
      harmonized_vars = character(),
      n_harmonized = integer(),
      stringsAsFactors = FALSE
    ))
  }

  # Group by raw variable name
  # For each unique raw variable, collect the harmonized variables that use it
  raw_var_list <- unique(cycle_vars$variable_raw)

  result <- lapply(raw_var_list, function(raw_var) {
    # Find all harmonized variables that map to this raw variable
    matching_rows <- cycle_vars[cycle_vars$variable_raw == raw_var, ]

    # Get variable type (should be same for all harmonized vars using this raw var)
    var_type <- matching_rows$variableType[1]

    # Get list of harmonized variable names
    harmonized_list <- matching_rows$variable

    data.frame(
      variable_raw = raw_var,
      variableType = var_type,
      harmonized_vars = paste(harmonized_list, collapse = ", "),
      n_harmonized = length(harmonized_list),
      stringsAsFactors = FALSE
    )
  })

  # Combine into single data frame
  result_df <- do.call(rbind, result)

  # Sort by variable name for consistency
  result_df <- result_df[order(result_df$variable_raw), ]
  rownames(result_df) <- NULL

  return(result_df)
}
