# ==============================================================================
# Metadata-driven survival dates (#40) — spec-side helpers.
# Generation lives in generate_survival_dates() (same file, added in Task 3).
# ADR: development/adr/v05-survival-dates.md
# ==============================================================================

.survival_distributions <- c("uniform", "exponential", "gompertz")

#' @noRd
.is_survival_variable <- function(variable) {
  identical(variable$type, "survival")
}

#' @noRd
.is_derived_variable <- function(variable) {
  # Derived types are computed after baseline generation from already-generated
  # columns, so both backends skip them (ADR v05-survival-dates D1, D7).
  .is_formula_variable(variable) || .is_survival_variable(variable)
}

#' @noRd
.survival_dependencies <- function(variable) {
  if (!.is_survival_variable(variable)) {
    return(character(0))
  }
  deps <- as.character(c(variable$anchor, variable$censored_by))
  unique(deps[!is.na(deps) & nzchar(trimws(deps))])
}

#' @noRd
.validate_survival_variable <- function(variable) {
  errors <- character(0)
  label <- paste0("Survival variable '", variable$name, "'")
  is_number <- function(x) {
    is.numeric(x) && length(x) == 1 && !is.na(x) && is.finite(x)
  }

  if (.is_blank(variable$anchor)) {
    errors <- c(errors, paste0(
      label, " requires an anchor (the name of its entry-date variable)."
    ))
  }

  followup_min <- variable$followup_min
  followup_max <- variable$followup_max
  if (!is_number(followup_min) || !is_number(followup_max)) {
    errors <- c(errors, paste0(
      label, " requires finite numeric followup_min and followup_max (days)."
    ))
  } else {
    if (followup_min < 0) {
      errors <- c(errors, paste0(label, " followup_min must be >= 0."))
    }
    if (followup_min > followup_max) {
      errors <- c(errors, paste0(label, " followup_min must be <= followup_max."))
    }
  }

  event_prop <- variable$event_prop
  if (!is_number(event_prop) || event_prop < 0 || event_prop > 1) {
    errors <- c(errors, paste0(label, " event_prop must be a number in [0, 1]."))
  }

  distribution <- variable$distribution %||% "uniform"
  if (!distribution %in% .survival_distributions) {
    errors <- c(errors, paste0(
      label, " distribution must be one of: ",
      paste(.survival_distributions, collapse = ", "), "."
    ))
  }

  for (param in c("shape", "rate")) {
    value <- variable[[param]]
    supplied <- !is.null(value) && !(length(value) == 1 && is.na(value))
    if (supplied && !(is_number(value) && value > 0)) {
      errors <- c(errors, paste0(
        label, " ", param, " must be a positive number when supplied."
      ))
    }
  }

  if (!identical(variable$rtype, "date")) {
    errors <- c(errors, paste0(label, " must have rType 'date'."))
  }
  if (!identical(variable$source_format %||% "analysis", "analysis")) {
    errors <- c(errors, paste0(
      label, " supports sourceFormat 'analysis' only in this version."
    ))
  }

  errors
}

#' @noRd
.validate_survival_referents <- function(spec) {
  errors <- character(0)
  for (variable in spec$variables) {
    if (!.is_survival_variable(variable)) next
    label <- paste0("Survival variable '", variable$name, "'")

    anchor <- variable$anchor
    if (!.is_blank(anchor)) {
      anchor_variable <- spec$variables[[anchor]]
      if (is.null(anchor_variable)) {
        errors <- c(errors, paste0(
          label, " has anchor '", anchor, "', which is not a variable in the ",
          "spec. Enable the entry-date variable or correct the anchor."
        ))
      } else if (!identical(anchor_variable$type, "date")) {
        errors <- c(errors, paste0(
          label, " has anchor '", anchor, "' of type '", anchor_variable$type,
          "'; an anchor must be a date variable."
        ))
      }
    }

    censor <- variable$censored_by
    if (.is_blank(censor)) next
    censor_variable <- spec$variables[[censor]]
    if (identical(censor, variable$name)) {
      errors <- c(errors, paste0(label, " cannot be censored by itself."))
    } else if (is.null(censor_variable)) {
      errors <- c(errors, paste0(
        label, " has censored_by '", censor,
        "', which is not a variable in the spec."
      ))
    } else if (!.is_survival_variable(censor_variable)) {
      errors <- c(errors, paste0(
        label, " has censored_by '", censor, "'; censored_by '", censor,
        "' must be a survival variable."
      ))
    } else if (!identical(censor_variable$anchor, anchor)) {
      errors <- c(errors, paste0(
        label, " has censored_by '", censor,
        "', which must share its anchor ('", anchor, "')."
      ))
    } else if (!.is_blank(censor_variable$censored_by)) {
      # ADR D7: with a chain (A by B, B by C) the sequential rules report A as
      # observed after observation ended, so chains are rejected in v0.5.
      errors <- c(errors, paste0(
        label, " has censored_by '", censor, "', which is itself censored by '",
        censor_variable$censored_by, "'. Chained censoring is not supported in ",
        "this version; censor '", variable$name, "' by the earliest date ",
        "directly, or derive observed outcomes after generation."
      ))
    }
  }
  errors
}

#' @noRd
.order_survival_variables <- function(spec) {
  survival_names <- names(spec$variables)[
    vapply(spec$variables, .is_survival_variable, logical(1))
  ]
  dependencies <- lapply(spec$variables[survival_names], .survival_dependencies)
  .order_dependent_variables(survival_names, dependencies, "Survival")
}
