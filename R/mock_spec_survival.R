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

#' @noRd
.survival_param <- function(value, default) {
  if (is.null(value) || length(value) != 1 || is.na(value)) default else value
}

#' @noRd
.survival_event_days <- function(variable, n_events) {
  # Exact port of the legacy follow-up-time draws (R/create_date_var.R:305-340,
  # ADR v05-survival-dates D4), including behaviour filed as #54 (Gompertz
  # clamp) and #56 (exponential rate derived from the window, not `rate`).
  followup_min <- variable$followup_min
  followup_max <- variable$followup_max
  distribution <- tolower(variable$distribution %||% "uniform")

  if (distribution == "gompertz") {
    shape <- .survival_param(variable$shape, 0.1)
    rate <- .survival_param(variable$rate, 0.0001)
    u <- stats::runif(n_events)
    days <- (1 / shape) * log(1 - (shape / rate) * log(1 - u))
    return(pmax(followup_min, pmin(followup_max, days)))
  }
  if (distribution == "exponential") {
    rate_exp <- 1 / ((followup_max - followup_min) / 3)
    days <- stats::rexp(n_events, rate = rate_exp) + followup_min
    return(pmin(days, followup_max))
  }
  stats::runif(n_events, min = followup_min, max = followup_max)
}

#' @noRd
.draw_survival_dates <- function(variable, anchor_dates) {
  n <- length(anchor_dates)
  values <- rep(as.Date(NA), n)
  if (n == 0) {
    return(values)
  }
  # Legacy event assignment: a fixed count, shuffled (R/create_date_var.R:295).
  n_events <- floor(n * variable$event_prop)
  is_event <- c(rep(TRUE, n_events), rep(FALSE, n - n_events))
  is_event <- is_event[sample(n)]
  if (n_events > 0) {
    # floor(): legacy output is whole days because create_date_var() converts
    # dates to character and back (R/create_date_var.R:479).
    values[is_event] <- anchor_dates[is_event] +
      floor(.survival_event_days(variable, n_events))
  }
  values
}

#' Generate survival dates from their anchor dates
#'
#' Computes each `type = "survival"` variable in `spec` from its anchor column
#' in `data`: `floor(n * event_prop)` rows receive a date a follow-up time
#' after the anchor (whole days, within `[followup_min, followup_max]`), and
#' the rest are `NA`. Variables are processed in dependency order; each is
#' drawn and then has its rules applied: a date earlier than its anchor
#' becomes `NA`, and, if `censored_by` is set, a date later than the censoring
#' date becomes `NA`. Draws use the isolated `survival` sub-stream of the seed
#' contract.
#'
#' Survival dates describe true values. [postprocess_mock_data()] applies
#' missing codes and garbage afterwards, independently for each column.
#'
#' @param data Data frame of generated baseline values (from
#'   [generate_mock_data_native()] or [generate_mock_data_simstudy()]),
#'   containing each anchor column as class `Date`.
#' @param spec A `mock_spec`. Strict-validated at entry.
#' @param seed Optional whole-number seed. The caller's RNG state and kind are
#'   restored on exit.
#'
#' @return `data` with one appended `Date` column per survival variable.
#'   Returns `data` unchanged if the spec has no survival variables.
#' @family mock generation APIs
#' @seealso [mock_spec_survival()], [evaluate_mock_formulas()],
#'   [postprocess_mock_data()]
#'
#' @examples
#' spec <- mock_spec(
#'   mock_spec_date("entry", range = as.Date(c("2001-01-01", "2005-12-31"))),
#'   mock_spec_survival("death", anchor = "entry",
#'     followup_min = 365, followup_max = 7300, event_prop = 0.2)
#' )
#' baseline <- generate_mock_data_native(spec, n = 10, seed = 1)
#' generate_survival_dates(baseline, spec, seed = 1)
#'
#' @export
generate_survival_dates <- function(data, spec, seed = NULL) {
  if (!is.data.frame(data)) {
    stop("data must be a data frame.", call. = FALSE)
  }
  validate_mock_spec(spec, n = nrow(data), strict = TRUE)

  ordered <- .order_survival_variables(spec)
  if (length(ordered) == 0) {
    return(data)
  }

  anchors <- unique(vapply(spec$variables[ordered], function(variable) {
    variable$anchor
  }, character(1)))
  missing_anchors <- setdiff(anchors, names(data))
  if (length(missing_anchors) > 0) {
    stop(
      "data is missing anchor column(s) required by survival variables: ",
      paste(missing_anchors, collapse = ", "),
      call. = FALSE
    )
  }
  for (anchor in anchors) {
    if (!inherits(data[[anchor]], "Date")) {
      stop(
        "Anchor column '", anchor, "' must be of class Date; got ",
        class(data[[anchor]])[1], ". Convert it with as.Date() first.",
        call. = FALSE
      )
    }
  }

  .with_mock_seed(seed, stage = "survival", {
    for (name in ordered) {
      variable <- spec$variables[[name]]
      anchor_dates <- data[[variable$anchor]]
      values <- .draw_survival_dates(variable, anchor_dates)
      # Legacy rules (R/create_wide_survival_data.R:347,363), applied per
      # variable in dependency order so a censoring date is already final.
      values[!is.na(values) & !is.na(anchor_dates) & values < anchor_dates] <-
        as.Date(NA)
      if (!.is_blank(variable$censored_by)) {
        censor <- data[[variable$censored_by]]
        values[!is.na(values) & !is.na(censor) & censor < values] <- as.Date(NA)
      }
      data[[name]] <- values
    }
    data
  })
}
