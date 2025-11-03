#' Scalar Variable Generation Helpers
#'
#' Helper functions for scalar variable generation (single variables at a time).
#' Used by create_cat_var(), create_con_var(), create_date_var() when called
#' with individual variable parameters (var_raw, cycle, etc.) rather than
#' configuration data frames.
#'
#' These helpers work with recodeflow-style metadata (variables.csv +
#' variable_details.csv from cchsflow/chmsflow).


#' Get variable details for raw variable and cycle
#'
#' Filters variable_details to rows matching a specific raw variable name and cycle.
#' Handles multiple naming patterns from recodeflow packages.
#'
#' @param var_raw Character. Raw variable name (e.g., "alc_11", "HGT_CM")
#' @param cycle Character. Cycle identifier (e.g., "cycle1", "cchs2001")
#' @param variable_details Data frame. Full variable_details metadata
#' @param variables Data frame. Optional variables metadata (not used currently)
#'
#' @return Data frame subset of variable_details for this variable + cycle
#'
#' @details
#' Tries three matching strategies in order:
#' 1. Database-prefixed format: "cycle::var_raw"
#' 2. Bracket format: "[var_raw]" with databaseStart filtering
#' 3. Plain format: exact match on variableStart with cycle filtering
#'
#' @keywords internal
get_variable_details_for_raw <- function(var_raw, cycle, variable_details, variables = NULL) {
  if (is.null(var_raw) || is.null(cycle) || var_raw == "" || cycle == "") {
    return(data.frame(
      variable = character(),
      variableStart = character(),
      databaseStart = character(),
      variableType = character(),
      recStart = character(),
      recEnd = character(),
      stringsAsFactors = FALSE
    ))
  }

  # Strategy 1: Find by database-prefixed format (cycle::var_raw)
  cycle_pattern <- paste0(cycle, "::", var_raw)
  matches <- variable_details[grepl(cycle_pattern, variable_details$variableStart, fixed = TRUE), ]

  # Strategy 2: Find by bracket format ([var_raw]) with databaseStart filtering
  if (nrow(matches) == 0) {
    bracket_pattern <- paste0("[", var_raw, "]")
    bracket_matches <- variable_details[grepl(bracket_pattern, variable_details$variableStart, fixed = TRUE), ]

    if (nrow(bracket_matches) > 0) {
      # Filter by databaseStart to ensure correct cycle
      bracket_matches <- bracket_matches[grepl(cycle, bracket_matches$databaseStart, fixed = TRUE), ]
      matches <- bracket_matches
    }
  }

  # Strategy 3: Find by plain format (var_raw) with strict filtering
  if (nrow(matches) == 0) {
    # Only match if variableStart is EXACTLY the var_raw
    plain_matches <- variable_details[
      variable_details$variableStart == var_raw &
        grepl(cycle, variable_details$databaseStart, fixed = TRUE),
    ]
    matches <- plain_matches
  }

  return(matches)
}


#' Extract categories from variable details
#'
#' Extracts categorical values from variable_details recStart/recEnd columns.
#' Handles range notation, special codes, and missing code patterns.
#'
#' @param var_details Data frame. Filtered variable_details rows
#' @param include_na Logical. Include NA/missing codes (default FALSE)
#'
#' @return Character vector of category values
#'
#' @details
#' Handles recodeflow notation:
#' - Simple categories: "1", "2", "3"
#' - Integer ranges: "[7,9]" → c("7", "8", "9")
#' - Continuous ranges: "[18.5,25)" (kept as single value)
#' - Special codes: "copy", "else" (EXCLUDED from v0.1 generation)
#' - Missing codes: Identified by "NA" in recEnd
#'
#' Note: "else" is excluded because it represents a harmonization rule,
#' not a predictable raw data value.
#'
#' @keywords internal
get_variable_categories <- function(var_details, include_na = FALSE) {
  if (nrow(var_details) == 0) {
    return(character(0))
  }

  # Filter based on whether we want NA codes or regular labels
  if (include_na) {
    # Get rows where recEnd contains "NA"
    rows <- var_details[grepl("NA", var_details$recEnd, fixed = TRUE), ]
  } else {
    # Get rows where recEnd does NOT contain "NA"
    rows <- var_details[!grepl("NA", var_details$recEnd, fixed = TRUE), ]
  }

  if (nrow(rows) == 0) {
    return(character(0))
  }

  # IMPORTANT: Exclude "else" rows (harmonization rules, not raw data values)
  # This matches the fix in extract_proportions() for v0.2 path
  rows <- rows[rows$recEnd != "else", ]

  if (nrow(rows) == 0) {
    return(character(0))
  }

  # Extract recStart values
  rec_start_values <- rows$recStart

  # Process each value through parse_range_notation
  all_values <- character(0)

  for (value in rec_start_values) {
    if (is.na(value) || value == "") {
      next
    }

    parsed <- parse_range_notation(value)

    if (is.null(parsed)) {
      # If parsing failed, use raw value
      all_values <- c(all_values, as.character(value))
      next
    }

    # Handle different parsed types
    if (parsed$type == "integer") {
      # For integer ranges, use the expanded values
      if (!is.null(parsed$values)) {
        all_values <- c(all_values, as.character(parsed$values))
      } else {
        # If values not expanded, just use min-max representation
        all_values <- c(all_values, as.character(value))
      }
    } else if (parsed$type == "single_value") {
      # Single numeric value
      all_values <- c(all_values, as.character(parsed$value))
    } else if (parsed$type == "continuous") {
      # For continuous ranges, keep as-is (don't expand)
      all_values <- c(all_values, as.character(value))
    } else if (parsed$type == "special") {
      # Skip special codes (copy, else, Func::, etc.)
      next
    } else if (parsed$type == "function") {
      # Skip function calls
      next
    } else {
      # Unknown type, use raw value
      all_values <- c(all_values, as.character(value))
    }
  }

  # Return unique values
  return(unique(all_values))
}
