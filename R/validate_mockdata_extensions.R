#' Validate MockData Extension Fields
#'
#' @param variables_path Path to variables.csv file
#' @param variable_details_path Path to variable_details.csv file
#' @param mode Validation mode: "basic" or "strict" (default: "basic")
#' @return Validation result object with errors, warnings, and info
#' @export
validate_mockdata_metadata <- function(variables_path, variable_details_path, mode = "basic") {
  result <- list(
    files = list(
      variables = basename(variables_path),
      variable_details = basename(variable_details_path)
    ),
    mode = mode,
    timestamp = Sys.time(),

    # Validation components
    uid_validation = list(),
    proportion_validation = list(),
    garbage_validation = list(),
    rType_validation = list(),
    versioning_validation = list(),
    foreign_key_validation = list(),

    # Issues
    errors = character(0),
    warnings = character(0),
    info = character(0),

    # Summary
    valid = TRUE,
    issues_count = 0
  )

  # Check files exist
  if (!file.exists(variables_path)) {
    result$errors <- c(result$errors, paste("Variables file not found:", variables_path))
    result$valid <- FALSE
    return(result)
  }

  if (!file.exists(variable_details_path)) {
    result$errors <- c(result$errors, paste("Variable details file not found:", variable_details_path))
    result$valid <- FALSE
    return(result)
  }

  # Load data
  variables <- read.csv(variables_path, stringsAsFactors = FALSE, check.names = FALSE)
  variable_details <- read.csv(variable_details_path, stringsAsFactors = FALSE, check.names = FALSE)

  # 1. UID validation (numeric-only pattern)
  result$uid_validation <- validate_uids(variables, variable_details)

  # 2. rType validation (enum values)
  result$rType_validation <- validate_rtype(variables)

  # 3. Foreign key validation (uid linkage)
  result$foreign_key_validation <- validate_foreign_keys(variables, variable_details)

  # 4. Proportion validation (sum to 1.0 per variable)
  result$proportion_validation <- validate_proportions(variable_details, mode)

  # 5. Garbage data validation (interval notation, 0-1 range)
  result$garbage_validation <- validate_garbage(variables)

  # 6. Versioning validation (semantic versioning pattern)
  result$versioning_validation <- validate_versioning(variables)

  # Collect all issues
  all_validations <- list(
    result$uid_validation,
    result$rType_validation,
    result$foreign_key_validation,
    result$proportion_validation,
    result$garbage_validation,
    result$versioning_validation
  )

  for (validation in all_validations) {
    if (!is.null(validation)) {
      result$errors <- c(result$errors, validation$errors)
      result$warnings <- c(result$warnings, validation$warnings)
      result$info <- c(result$info, validation$info)
    }
  }

  # Summary
  result$issues_count <- length(result$errors) + length(result$warnings)
  result$valid <- length(result$errors) == 0

  class(result) <- "mockdata_validation_result"
  return(result)
}

#' Validate UID Patterns
#' @keywords internal
validate_uids <- function(variables, variable_details) {
  result <- list(errors = character(0), warnings = character(0), info = character(0))

  # Pattern for variable-level UIDs: ^v_[0-9]+$
  uid_pattern <- "^v_[0-9]+$"

  # Pattern for detail-level UIDs: ^d_[0-9]+$
  uid_detail_pattern <- "^d_[0-9]+$"

  # Check variables.csv uid column
  if ("uid" %in% names(variables)) {
    non_empty_uids <- variables$uid[!is.na(variables$uid) & variables$uid != ""]

    if (length(non_empty_uids) > 0) {
      invalid_uids <- non_empty_uids[!grepl(uid_pattern, non_empty_uids)]

      if (length(invalid_uids) > 0) {
        result$errors <- c(result$errors,
          paste("Invalid uid format in variables.csv (expected ^v_[0-9]+$):",
                paste(invalid_uids, collapse = ", ")))
      }

      # Check uniqueness
      duplicates <- sum(duplicated(non_empty_uids))
      if (duplicates > 0) {
        result$errors <- c(result$errors,
          paste("Duplicate uid values in variables.csv:", duplicates, "duplicates found"))
      }
    }
  } else {
    result$warnings <- c(result$warnings, "No uid column found in variables.csv")
  }

  # Check variable_details.csv uid and uid_detail columns
  if ("uid" %in% names(variable_details)) {
    non_empty_uids <- variable_details$uid[!is.na(variable_details$uid) & variable_details$uid != ""]

    if (length(non_empty_uids) > 0) {
      invalid_uids <- non_empty_uids[!grepl(uid_pattern, non_empty_uids)]

      if (length(invalid_uids) > 0) {
        result$errors <- c(result$errors,
          paste("Invalid uid format in variable_details.csv (expected ^v_[0-9]+$):",
                paste(unique(invalid_uids), collapse = ", ")))
      }
    }
  } else {
    result$warnings <- c(result$warnings, "No uid column found in variable_details.csv")
  }

  if ("uid_detail" %in% names(variable_details)) {
    non_empty_uid_details <- variable_details$uid_detail[!is.na(variable_details$uid_detail) &
                                                            variable_details$uid_detail != ""]

    if (length(non_empty_uid_details) > 0) {
      invalid_uid_details <- non_empty_uid_details[!grepl(uid_detail_pattern, non_empty_uid_details)]

      if (length(invalid_uid_details) > 0) {
        result$errors <- c(result$errors,
          paste("Invalid uid_detail format (expected ^d_[0-9]+$):",
                paste(invalid_uid_details, collapse = ", ")))
      }

      # Check uniqueness
      duplicates <- sum(duplicated(non_empty_uid_details))
      if (duplicates > 0) {
        result$errors <- c(result$errors,
          paste("Duplicate uid_detail values:", duplicates, "duplicates found"))
      }
    }
  } else {
    result$warnings <- c(result$warnings, "No uid_detail column found in variable_details.csv")
  }

  return(result)
}

#' Validate rType Values
#' @keywords internal
validate_rtype <- function(variables) {
  result <- list(errors = character(0), warnings = character(0), info = character(0))

  valid_rtypes <- c("integer", "double", "factor", "logical", "character", "date")

  if ("rType" %in% names(variables)) {
    non_empty_rtypes <- variables$rType[!is.na(variables$rType) & variables$rType != ""]

    if (length(non_empty_rtypes) > 0) {
      invalid_rtypes <- setdiff(unique(non_empty_rtypes), valid_rtypes)

      if (length(invalid_rtypes) > 0) {
        result$errors <- c(result$errors,
          paste("Invalid rType values:", paste(invalid_rtypes, collapse = ", ")))
        result$info <- c(result$info,
          paste("Valid rType values:", paste(valid_rtypes, collapse = ", ")))
      }
    }
  } else {
    result$info <- c(result$info, "No rType column found in variables.csv (optional)")
  }

  return(result)
}

#' Validate Foreign Key Relationships
#' @keywords internal
validate_foreign_keys <- function(variables, variable_details) {
  result <- list(errors = character(0), warnings = character(0), info = character(0))

  if ("uid" %in% names(variables) && "uid" %in% names(variable_details)) {
    var_uids <- variables$uid[!is.na(variables$uid) & variables$uid != ""]
    detail_uids <- variable_details$uid[!is.na(variable_details$uid) & variable_details$uid != ""]

    # Check for UIDs in variable_details that don't exist in variables
    orphan_uids <- setdiff(unique(detail_uids), var_uids)

    if (length(orphan_uids) > 0) {
      result$errors <- c(result$errors,
        paste("UIDs in variable_details.csv not found in variables.csv:",
              paste(orphan_uids, collapse = ", ")))
    }

    # Info: variables without details
    unused_uids <- setdiff(var_uids, detail_uids)
    if (length(unused_uids) > 0) {
      result$info <- c(result$info,
        paste("Variables without detail rows:", paste(unused_uids, collapse = ", ")))
    }
  }

  return(result)
}

#' Validate Proportion Sums
#' @keywords internal
validate_proportions <- function(variable_details, mode) {
  result <- list(errors = character(0), warnings = character(0), info = character(0))

  tolerance <- 0.001  # +/-0.001 as specified in schema

  if ("proportion" %in% names(variable_details) && "uid" %in% names(variable_details)) {
    # Filter to rows with proportions
    prop_rows <- variable_details[!is.na(variable_details$proportion) &
                                     variable_details$proportion != "" &
                                     !is.na(variable_details$uid) &
                                     variable_details$uid != "", ]

    if (nrow(prop_rows) > 0) {
      # Convert proportion to numeric if needed
      prop_rows$proportion <- as.numeric(prop_rows$proportion)

      # Check each variable's proportions sum
      for (uid in unique(prop_rows$uid)) {
        uid_props <- prop_rows$proportion[prop_rows$uid == uid]
        prop_sum <- sum(uid_props, na.rm = TRUE)

        # Check if sum is close to 1.0
        if (abs(prop_sum - 1.0) > tolerance) {
          if (mode == "strict") {
            result$errors <- c(result$errors,
              sprintf("Proportions for %s sum to %.4f (expected 1.0 +/-%.3f)",
                      uid, prop_sum, tolerance))
          } else {
            result$warnings <- c(result$warnings,
              sprintf("Proportions for %s sum to %.4f (will be auto-normalized to 1.0)",
                      uid, prop_sum))
          }
        }

        # Check individual proportion ranges
        invalid_props <- uid_props[uid_props < 0 | uid_props > 1]
        if (length(invalid_props) > 0) {
          result$errors <- c(result$errors,
            sprintf("Proportions for %s contain invalid values (must be 0-1): %s",
                    uid, paste(invalid_props, collapse = ", ")))
        }
      }
    }
  } else {
    result$info <- c(result$info, "No proportion column found (optional)")
  }

  return(result)
}

#' Validate Garbage Data Parameters
#' @keywords internal
validate_garbage <- function(variables) {
  result <- list(errors = character(0), warnings = character(0), info = character(0))

  interval_pattern <- "^\\[.+;.+\\]$"

  # Check garbage_low_prop
  if ("garbage_low_prop" %in% names(variables)) {
    non_empty <- variables$garbage_low_prop[!is.na(variables$garbage_low_prop) &
                                               variables$garbage_low_prop != ""]
    if (length(non_empty) > 0) {
      garbage_low <- as.numeric(non_empty)
      invalid <- garbage_low[garbage_low < 0 | garbage_low > 1]

      if (length(invalid) > 0) {
        result$errors <- c(result$errors,
          paste("garbage_low_prop values must be 0-1:", paste(invalid, collapse = ", ")))
      }
    }
  }

  # Check garbage_low_range
  if ("garbage_low_range" %in% names(variables)) {
    non_empty <- variables$garbage_low_range[!is.na(variables$garbage_low_range) &
                                                variables$garbage_low_range != "" &
                                                variables$garbage_low_range != "[;]"]  # Allow empty intervals
    if (length(non_empty) > 0) {
      invalid <- non_empty[!grepl(interval_pattern, non_empty)]

      if (length(invalid) > 0) {
        result$errors <- c(result$errors,
          paste("garbage_low_range must use interval notation [min;max]:",
                paste(invalid, collapse = ", ")))
      }
    }
  }

  # Check garbage_high_prop
  if ("garbage_high_prop" %in% names(variables)) {
    non_empty <- variables$garbage_high_prop[!is.na(variables$garbage_high_prop) &
                                                variables$garbage_high_prop != ""]
    if (length(non_empty) > 0) {
      garbage_high <- as.numeric(non_empty)
      invalid <- garbage_high[garbage_high < 0 | garbage_high > 1]

      if (length(invalid) > 0) {
        result$errors <- c(result$errors,
          paste("garbage_high_prop values must be 0-1:", paste(invalid, collapse = ", ")))
      }
    }
  }

  # Check garbage_high_range
  if ("garbage_high_range" %in% names(variables)) {
    non_empty <- variables$garbage_high_range[!is.na(variables$garbage_high_range) &
                                                 variables$garbage_high_range != "" &
                                                 variables$garbage_high_range != "[;]"]  # Allow empty intervals
    if (length(non_empty) > 0) {
      invalid <- non_empty[!grepl(interval_pattern, non_empty)]

      if (length(invalid) > 0) {
        result$errors <- c(result$errors,
          paste("garbage_high_range must use interval notation [min;max]:",
                paste(invalid, collapse = ", ")))
      }
    }
  }

  return(result)
}

#' Validate MockData Versioning Fields
#' @keywords internal
validate_versioning <- function(variables) {
  result <- list(errors = character(0), warnings = character(0), info = character(0))

  semver_pattern <- "^[0-9]+\\.[0-9]+\\.[0-9]+$"
  date_pattern <- "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"

  # Check mockDataVersion
  if ("mockDataVersion" %in% names(variables)) {
    non_empty <- variables$mockDataVersion[!is.na(variables$mockDataVersion) &
                                              variables$mockDataVersion != ""]
    if (length(non_empty) > 0) {
      invalid <- non_empty[!grepl(semver_pattern, non_empty)]

      if (length(invalid) > 0) {
        result$warnings <- c(result$warnings,
          paste("mockDataVersion should use semantic versioning (e.g., 1.0.0):",
                paste(invalid, collapse = ", ")))
      }
    }
  }

  # Check mockDataLastUpdated
  if ("mockDataLastUpdated" %in% names(variables)) {
    non_empty <- variables$mockDataLastUpdated[!is.na(variables$mockDataLastUpdated) &
                                                  variables$mockDataLastUpdated != ""]
    if (length(non_empty) > 0) {
      invalid <- non_empty[!grepl(date_pattern, non_empty)]

      if (length(invalid) > 0) {
        result$warnings <- c(result$warnings,
          paste("mockDataLastUpdated should use YYYY-MM-DD format:",
                paste(invalid, collapse = ", ")))
      }
    }
  }

  return(result)
}

#' Print MockData Validation Results
#'
#' @param x mockdata_validation_result object
#' @param ... Additional arguments (unused)
#' @export
print.mockdata_validation_result <- function(x, ...) {
  cat("MockData Extension Validation Report\n")
  cat("=====================================\n")
  cat("Files:\n")
  cat("  Variables:", x$files$variables, "\n")
  cat("  Details:", x$files$variable_details, "\n")
  cat("Mode:", x$mode, "\n")
  cat("Timestamp:", format(x$timestamp), "\n\n")

  cat("Validation Summary:\n")
  cat("- Valid:", ifelse(x$valid, "YES", "NO"), "\n")
  cat("- Errors:", length(x$errors), "\n")
  cat("- Warnings:", length(x$warnings), "\n")
  cat("- Info:", length(x$info), "\n\n")

  if (length(x$errors) > 0) {
    cat("ERRORS:\n")
    for (i in seq_along(x$errors)) {
      cat(sprintf("%d. %s\n", i, x$errors[i]))
    }
    cat("\n")
  }

  if (length(x$warnings) > 0) {
    cat("WARNINGS:\n")
    for (i in seq_along(x$warnings)) {
      cat(sprintf("%d. %s\n", i, x$warnings[i]))
    }
    cat("\n")
  }

  if (length(x$info) > 0) {
    cat("INFO:\n")
    for (i in seq_along(x$warnings)) {
      cat(sprintf("%d. %s\n", i, x$info[i]))
    }
    cat("\n")
  }

  invisible(x)
}
