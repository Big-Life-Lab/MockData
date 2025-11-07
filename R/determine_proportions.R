#' Determine proportions for categorical variable generation
#'
#' @description
#' Helper function to determine proportions for categorical variables based on
#' priority: explicit parameter > metadata column > uniform distribution
#'
#' @param categories character vector. Category codes/values
#' @param proportions_param Proportions specification. Can be:
#'   - NULL: Use uniform distribution
#'   - Named list: Maps category codes to proportions
#'   - Numeric vector: Proportions in same order as categories
#' @param var_details data.frame. Variable details metadata (may contain proportion column)
#'
#' @return Numeric vector of proportions (normalized to sum to 1), same length as categories
#'
#' @details
#' Priority order:
#' 1. proportions_param if provided (explicit user specification)
#' 2. proportion column in var_details if present
#' 3. Uniform distribution (fallback)
#'
#' @keywords internal
determine_proportions <- function(categories, proportions_param, var_details) {

  # Priority 1: Explicit proportions parameter
  if (!is.null(proportions_param)) {

    if (is.list(proportions_param) && !is.null(names(proportions_param))) {
      # Named list: validate and reorder to match categories
      missing_cats <- setdiff(categories, names(proportions_param))
      if (length(missing_cats) > 0) {
        stop("proportions list missing categories: ",
             paste(missing_cats, collapse = ", "),
             call. = FALSE)
      }

      # Extract proportions in category order
      probs <- unlist(proportions_param[categories])

    } else if (is.numeric(proportions_param)) {
      # Numeric vector: must match length
      if (length(proportions_param) != length(categories)) {
        stop("proportions length (", length(proportions_param),
             ") must match number of categories (", length(categories), ")",
             call. = FALSE)
      }
      probs <- proportions_param

    } else {
      stop("proportions must be a named list or numeric vector",
           call. = FALSE)
    }

    # Normalize to sum to 1
    probs <- probs / sum(probs)
    return(probs)
  }

  # Priority 2: proportion column in metadata
  if ("proportion" %in% names(var_details) &&
      any(!is.na(var_details$proportion))) {

    # Extract non-NA proportions
    props_from_metadata <- var_details$proportion[!is.na(var_details$proportion)]

    # Only use if length matches categories
    if (length(props_from_metadata) == length(categories)) {
      probs <- props_from_metadata / sum(props_from_metadata)
      return(probs)
    }
  }

  # Priority 3: Uniform distribution (fallback)
  probs <- rep(1 / length(categories), length(categories))
  return(probs)
}
