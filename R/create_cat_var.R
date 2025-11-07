#' Create categorical variable for MockData
#'
#' Creates a categorical mock variable based on specifications from variable_details.
#'
#' @param var_raw character. The RAW variable name (as it appears in source data)
#' @param cycle character. The cycle identifier (e.g., "cycle1", "HC1")
#' @param variable_details data.frame. Variable details metadata
#' @param variables data.frame. Variables metadata (optional, for validation)
#' @param length integer. The desired length of the mock data vector
#' @param df_mock data.frame. Existing mock data (to check if variable already exists)
#' @param proportions Proportions for category generation. Can be:
#'   \itemize{
#'     \item \strong{NULL} (default): Uses uniform distribution across all categories
#'     \item \strong{Named list}: Maps category codes to proportions (e.g., \code{list("1" = 0.25, "2" = 0.75)})
#'     \item \strong{Numeric vector}: Proportions in same order as categories appear in variable_details
#'   }
#'   If provided, overrides any proportion column in variable_details.
#'   Proportions will be normalized to sum to 1.
#' @param seed integer. Random seed for reproducibility. If NULL, uses global seed.
#' @param prop_NA numeric. Optional. Proportion of NA values (0 to 1). If NULL, no NAs introduced.
#' @param prop_invalid numeric. Optional. Proportion of invalid out-of-range category codes (0 to 1). If NULL, no invalid values generated.
#' @param var_row data.frame. Single row from mock_data_config (for batch generation)
#' @param details_subset data.frame. Rows from mock_data_config_details (for batch generation)
#' @param n integer. Number of observations (for batch generation)
#'
#' @return data.frame with one column (the new categorical variable), or NULL if:
#'   - Variable details not found
#'   - Variable already exists in df_mock
#'   - No categories found
#'
#' @details
#' The function determines proportions in this priority order:
#' \enumerate{
#'   \item Explicit `proportions` parameter (if provided)
#'   \item `proportion` column in variable_details (if present)
#'   \item Uniform distribution (default fallback)
#' }
#'
#' Uses `determine_proportions()` helper to handle proportion logic cleanly.
#' Generates values using vectorized `sample()` for efficiency.
#'
#' **Type coercion (rType):**
#' If the metadata contains an `rType` column, values will be coerced to the specified R type:
#' - `"factor"`: Converts to factor with levels from category codes (default for categorical)
#' - `"character"`: Converts to character vector
#' - `"integer"`: Converts to integer (for numeric category codes)
#' - `"logical"`: Converts to logical (for TRUE/FALSE categories)
#' - Other types are passed through without coercion
#'
#' This allows categorical variables to be returned as factors with proper levels,
#' or as other types appropriate to the data. If `rType` is not specified, defaults to character.
#'
#' @examples
#' \dontrun{
#' # Uniform distribution (no proportions specified)
#' result <- create_cat_var(
#'   var_raw = "smoking",
#'   cycle = "cycle1",
#'   variable_details = variable_details,
#'   length = 1000
#' )
#'
#' # Custom proportions with named list (recommended)
#' result <- create_cat_var(
#'   var_raw = "smoking",
#'   cycle = "cycle1",
#'   variable_details = variable_details,
#'   proportions = list(
#'     "1" = 0.25,   # Daily smoker
#'     "2" = 0.50,   # Occasional smoker
#'     "3" = 0.20,   # Never smoked
#'     "996" = 0.05  # Missing
#'   ),
#'   length = 1000,
#'   seed = 123
#' )
#'
#' # Custom proportions with numeric vector
#' result <- create_cat_var(
#'   var_raw = "smoking",
#'   cycle = "cycle1",
#'   variable_details = variable_details,
#'   proportions = c(0.25, 0.50, 0.20, 0.05),
#'   length = 1000,
#'   seed = 123
#' )
#'
#' # With data quality issues
#' result <- create_cat_var(
#'   var_raw = "smoking",
#'   cycle = "cycle1",
#'   variable_details = variable_details,
#'   proportions = list("1" = 0.3, "2" = 0.6, "3" = 0.1),
#'   length = 1000,
#'   prop_NA = 0.05,
#'   prop_invalid = 0.02,
#'   seed = 123
#' )
#' }
#'
#' @family generators
#' @export
create_cat_var <- function(var_row = NULL, details_subset = NULL, n = NULL,
                            seed = NULL, df_mock = NULL,
                            # Scalar variable generation parameters
                            var_raw = NULL, cycle = NULL, variable_details = NULL,
                            variables = NULL, length = NULL,
                            proportions = NULL, prop_NA = NULL, prop_invalid = NULL) {

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

    # FALLBACK MODE: Uniform distribution if details_subset is NULL
    if (is.null(details_subset) || nrow(details_subset) == 0) {
      # Generate simple 2-category variable with uniform distribution
      values <- sample(c("1", "2"), size = n, replace = TRUE)

      col <- data.frame(
        new = values,
        stringsAsFactors = FALSE
      )
      names(col)[1] <- var_name
      return(col)
    }

    # Extract proportions from details_subset
    props <- extract_proportions(details_subset, variable_name = var_name)

    # Check if we have valid categories
    if (length(props$categories) == 0) {
      warning(paste0("No valid categories found for ", var_name))
      return(NULL)
    }

    # STEP 1: Generate population (valid values only)
    # Calculate number of valid observations (excluding missing)
    n_valid <- floor(n * props$valid)

    # Generate category assignments based on category-specific proportions
    valid_assignments <- sample_with_proportions(
      categories = props$categories,
      proportions = props$category_proportions,
      n = n_valid,
      seed = NULL  # Already set globally if needed
    )

    # STEP 2: Apply missing codes
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
        miss_row <- details_subset[details_subset$recEnd == miss_cat, ]
        if (nrow(miss_row) > 0) {
          # Use recEnd itself if value is NA
          code_value <- miss_row$value[1]
          if (is.na(code_value)) {
            code_value <- miss_cat  # Use recEnd (e.g., "[7,9]") as the value
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

    # STEP 3: Apply garbage if specified
    if (has_garbage(details_subset)) {
      values <- make_garbage(
        values = values,
        details_subset = details_subset,
        variable_type = "Categorical",
        seed = NULL  # Already set globally if needed
      )
    }

    # STEP 4: Apply rType coercion if specified
    if ("rType" %in% names(details_subset)) {
      r_type <- details_subset$rType[1]
      if (!is.null(r_type) && !is.na(r_type)) {
        values <- switch(r_type,
          "factor" = {
            # Extract category levels from details_subset
            categories <- unique(details_subset$recEnd[!is.na(details_subset$recEnd)])
            factor(values, levels = categories)
          },
          "character" = as.character(values),
          "integer" = as.integer(values),
          "logical" = as.logical(values),
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
    # ========== SCALAR VARIABLE GENERATION ==========

    # Get variable details for this raw variable + cycle
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

    # Extract categories (non-NA values) - do this once
    labels <- get_variable_categories(var_details, include_na = FALSE)

    if (length(labels) == 0) {
      # No valid categories found
      return(NULL)
    }

    # Determine proportions using helper function
    probs <- determine_proportions(labels, proportions, var_details)

    # Extract NA codes (if prop_NA specified)
    na_labels <- NULL
    if (!is.null(prop_NA) && prop_NA > 0) {
      na_labels <- get_variable_categories(var_details, include_na = TRUE)

      if (length(na_labels) == 0) {
        # No NA codes found, but prop_NA requested
        na_labels <- NULL
        prop_NA <- NULL
        warning(paste0(
          "prop_NA requested for ", var_raw, " but no NA codes found in variable_details. ",
          "Proceeding without NAs."
        ))
      }
    }

    # Generate invalid codes (if prop_invalid specified)
    invalid_labels <- NULL
    if (!is.null(prop_invalid) && prop_invalid > 0) {
      # Common invalid codes that are likely not in valid categories
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

    # Set seed and generate mock data
    if (!is.null(seed)) set.seed(seed)
    n_obs <- length

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
    n_na <- floor(n_obs * prop_na_actual)
    n_invalid <- floor(n_obs * prop_invalid_actual)
    n_regular <- n_obs - n_na - n_invalid

    # Generate regular values using determined proportions (vectorized)
    vec_regular <- if (n_regular > 0) {
      sample(labels, n_regular, replace = TRUE, prob = probs)
    } else {
      character(0)
    }

    # Generate NA codes
    vec_na <- if (n_na > 0) {
      sample(na_labels, n_na, replace = TRUE)
    } else {
      character(0)
    }

    # Generate invalid codes
    vec_invalid <- if (n_invalid > 0) {
      sample(invalid_labels, n_invalid, replace = TRUE)
    } else {
      character(0)
    }

    # Combine and shuffle all values
    vec_all <- c(vec_regular, vec_na, vec_invalid)
    vec_shuffled <- sample(vec_all)

    # Ensure exact length
    vec_shuffled <- vec_shuffled[1:n_obs]

    # Apply rType coercion if specified
    if ("rType" %in% names(var_details)) {
      r_type <- var_details$rType[1]
      if (!is.null(r_type) && !is.na(r_type)) {
        vec_shuffled <- switch(r_type,
          "factor" = {
            # Use labels as factor levels
            factor(vec_shuffled, levels = labels)
          },
          "character" = as.character(vec_shuffled),
          "integer" = as.integer(vec_shuffled),
          "logical" = as.logical(vec_shuffled),
          vec_shuffled  # No coercion for other types
        )
      }
    }

    # Return as data frame with one column
    col <- data.frame(
      new = vec_shuffled,
      stringsAsFactors = FALSE
    )
    names(col)[1] <- var_raw

    return(col)
  }
}
