# ==============================================================================
# MockData v0.4 Specification Layer
# ==============================================================================
# Normalized internal representation for direct APIs, recodeflow adapters, and
# optional generation backends.
# ==============================================================================

.mock_spec_version <- "0.4.0"

.mock_spec_model_hints <- c(
  "auto",
  "native",
  "simstudy",
  "native-postprocess",
  "simstudy-or-native",
  "simstudy-advanced",
  "diagnostic-required"
)

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

.normalize_provenance <- function(provenance, source = NULL) {
  if (is.null(provenance)) {
    provenance <- list(adapter = "direct", source = source %||% "direct")
  } else if (!is.list(provenance)) {
    provenance <- list(adapter = as.character(provenance), source = source %||% as.character(provenance))
  }

  if (is.null(provenance$adapter) || is.na(provenance$adapter) || provenance$adapter == "") {
    provenance$adapter <- "unknown"
  }
  if (is.null(provenance$source) || is.na(provenance$source) || provenance$source == "") {
    provenance$source <- provenance$adapter
  }

  provenance
}

.validate_model_hint <- function(model_hint) {
  if (length(model_hint) != 1 || is.na(model_hint) || !model_hint %in% .mock_spec_model_hints) {
    stop(
      "model_hint must be one of: ",
      paste(.mock_spec_model_hints, collapse = ", "),
      call. = FALSE
    )
  }

  invisible(TRUE)
}

.new_mock_spec_variable <- function(name,
                                    type,
                                    rtype,
                                    distribution = NULL,
                                    range = NULL,
                                    levels = NULL,
                                    proportions = NULL,
                                    formula = NULL,
                                    missing_codes = character(0),
                                    missing_proportions = numeric(0),
                                    garbage_rules = list(),
                                    source_format = NULL,
                                    depends_on = character(0),
                                    provenance = NULL,
                                    model_hint = "auto",
                                    ...) {
  if (!is.character(name) || length(name) != 1 || is.na(name) || trimws(name) == "") {
    stop("mock_spec variable name must be a non-empty string.", call. = FALSE)
  }
  if (!is.character(type) || length(type) != 1 || is.na(type) || trimws(type) == "") {
    stop("mock_spec variable type must be a non-empty string.", call. = FALSE)
  }

  .validate_model_hint(model_hint)

  structure(
    c(
      list(
        name = name,
        type = tolower(type),
        rtype = tolower(rtype),
        distribution = distribution,
        range = range,
        levels = levels,
        proportions = proportions,
        formula = formula,
        missing_codes = missing_codes,
        missing_proportions = missing_proportions,
        garbage_rules = garbage_rules,
        source_format = source_format,
        depends_on = depends_on,
        provenance = .normalize_provenance(provenance),
        model_hint = model_hint
      ),
      list(...)
    ),
    class = c("mock_spec_variable", "list")
  )
}

.as_mock_spec_variable_list <- function(...) {
  variables <- list(...)

  if (length(variables) == 1 && is.null(variables[[1]])) {
    return(list())
  }

  if (length(variables) == 1 && is.list(variables[[1]]) && !inherits(variables[[1]], "mock_spec_variable")) {
    variables <- variables[[1]]
  }

  if (length(variables) == 0) {
    return(list())
  }

  if (!all(vapply(variables, inherits, logical(1), what = "mock_spec_variable"))) {
    stop("mock_spec() inputs must be mock_spec_variable objects.", call. = FALSE)
  }

  names(variables) <- vapply(variables, `[[`, character(1), "name")
  variables
}

#' Create a MockData specification
#'
#' `mock_spec()` creates the normalized v0.4 specification object used by the
#' new architecture. Direct APIs and recodeflow adapters should both normalize
#' into this shape before validation and generation.
#'
#' @param ... `mock_spec_variable` objects, or a single list of them. `NULL`
#'   creates an empty specification.
#' @param spec_version Character version of the specification shape.
#' @param provenance List or character describing where the spec came from.
#' @param model_hint Character backend hint. One of the supported MockData model
#'   hints.
#'
#' @return S3 object of class `mock_spec`.
#' @export
mock_spec <- function(...,
                      spec_version = .mock_spec_version,
                      provenance = list(adapter = "direct", source = "direct"),
                      model_hint = "auto") {
  .validate_model_hint(model_hint)

  structure(
    list(
      spec_version = spec_version,
      provenance = .normalize_provenance(provenance),
      model_hint = model_hint,
      variables = .as_mock_spec_variable_list(...)
    ),
    class = c("mock_spec", "list")
  )
}

#' Create a continuous variable specification
#'
#' @param name Variable name.
#' @param range Numeric vector of length two giving the inclusive valid range.
#' @param distribution Distribution name. Defaults to `"uniform"`.
#' @param mean,sd Optional distribution parameters.
#' @param rtype R output type. Defaults to `"double"`.
#' @param missing_codes Explicit missing-code values.
#' @param missing_proportions Missing-code probabilities aligned to
#'   `missing_codes`.
#' @param garbage_rules List of intentional invalid-value rules.
#' @param provenance Provenance metadata.
#' @param model_hint Backend hint.
#'
#' @return A `mock_spec_variable` object.
#' @export
mock_spec_continuous <- function(name,
                                 range,
                                 distribution = "uniform",
                                 mean = NA_real_,
                                 sd = NA_real_,
                                 rtype = "double",
                                 missing_codes = numeric(0),
                                 missing_proportions = numeric(0),
                                 garbage_rules = list(),
                                 provenance = "direct",
                                 model_hint = "auto") {
  .new_mock_spec_variable(
    name = name,
    type = "continuous",
    rtype = rtype,
    distribution = distribution,
    range = range,
    mean = mean,
    sd = sd,
    missing_codes = missing_codes,
    missing_proportions = missing_proportions,
    garbage_rules = garbage_rules,
    provenance = provenance,
    model_hint = model_hint
  )
}

#' Create a categorical variable specification
#'
#' @param name Variable name.
#' @param levels Character vector of valid levels or codes.
#' @param proportions Optional probabilities aligned to `levels`.
#' @param rtype R output type. Defaults to `"factor"`.
#' @param missing_codes Explicit missing-code values.
#' @param missing_proportions Missing-code probabilities aligned to
#'   `missing_codes`.
#' @param garbage_rules List of intentional invalid-value rules.
#' @param provenance Provenance metadata.
#' @param model_hint Backend hint.
#'
#' @return A `mock_spec_variable` object.
#' @export
mock_spec_categorical <- function(name,
                                  levels,
                                  proportions = NULL,
                                  rtype = "factor",
                                  missing_codes = character(0),
                                  missing_proportions = numeric(0),
                                  garbage_rules = list(),
                                  provenance = "direct",
                                  model_hint = "auto") {
  .new_mock_spec_variable(
    name = name,
    type = "categorical",
    rtype = rtype,
    distribution = "categorical",
    levels = levels,
    proportions = proportions,
    missing_codes = missing_codes,
    missing_proportions = missing_proportions,
    garbage_rules = garbage_rules,
    provenance = provenance,
    model_hint = model_hint
  )
}

#' Create a date variable specification
#'
#' @param name Variable name.
#' @param range Date vector of length two giving the inclusive valid date range.
#' @param rtype R output type. Defaults to `"date"`.
#' @param source_format Source-format hint. Defaults to `"analysis"`.
#' @param missing_codes Explicit missing-code values.
#' @param missing_proportions Missing-code probabilities aligned to
#'   `missing_codes`.
#' @param garbage_rules List of intentional invalid-value rules.
#' @param provenance Provenance metadata.
#' @param model_hint Backend hint.
#'
#' @return A `mock_spec_variable` object.
#' @export
mock_spec_date <- function(name,
                           range,
                           rtype = "date",
                           source_format = "analysis",
                           missing_codes = character(0),
                           missing_proportions = numeric(0),
                           garbage_rules = list(),
                           provenance = "direct",
                           model_hint = "native-postprocess") {
  .new_mock_spec_variable(
    name = name,
    type = "date",
    rtype = rtype,
    distribution = "uniform",
    range = range,
    source_format = source_format,
    missing_codes = missing_codes,
    missing_proportions = missing_proportions,
    garbage_rules = garbage_rules,
    provenance = provenance,
    model_hint = model_hint
  )
}

#' Check whether an object is a MockData specification
#'
#' @param x Object to check.
#'
#' @return Logical scalar.
#' @export
is_mock_spec <- function(x) {
  inherits(x, "mock_spec")
}

.new_mock_spec_validation_result <- function(valid = TRUE,
                                             errors = character(0),
                                             warnings = character(0),
                                             info = character(0)) {
  structure(
    list(
      valid = valid,
      errors = errors,
      warnings = warnings,
      info = info
    ),
    class = c("mock_spec_validation_result", "list")
  )
}

.validate_probability_vector <- function(values, label, allow_null = FALSE) {
  errors <- character(0)

  if (is.null(values)) {
    if (allow_null) {
      return(errors)
    }
    return(paste0(label, " must not be NULL."))
  }

  if (!is.numeric(values)) {
    errors <- c(errors, paste0(label, " must be numeric."))
  } else {
    if (any(is.na(values))) {
      errors <- c(errors, paste0(label, " must not contain NA values."))
    }
    if (any(values < 0 | values > 1, na.rm = TRUE)) {
      errors <- c(errors, paste0(label, " must be between 0 and 1."))
    }
  }

  errors
}

.validate_missing_spec <- function(variable) {
  errors <- character(0)

  if (length(variable$missing_codes) == 0 && length(variable$missing_proportions) == 0) {
    return(errors)
  }

  if (length(variable$missing_codes) != length(variable$missing_proportions)) {
    errors <- c(errors, paste0(
      "Variable '", variable$name,
      "' must have one missing proportion per missing code."
    ))
  }

  errors <- c(errors, .validate_probability_vector(
    variable$missing_proportions,
    paste0("Variable '", variable$name, "' missing_proportions"),
    allow_null = FALSE
  ))

  missing_sum <- sum(variable$missing_proportions, na.rm = TRUE)
  if (missing_sum > 1) {
    errors <- c(errors, paste0(
      "Variable '", variable$name,
      "' missing proportions must sum to <= 1."
    ))
  }

  errors
}

.validate_range <- function(range, variable_name, expected_class = "numeric") {
  errors <- character(0)

  if (is.null(range) || length(range) != 2) {
    return(paste0("Variable '", variable_name, "' range must have length 2."))
  }

  if (expected_class == "Date") {
    if (!inherits(range, "Date")) {
      errors <- c(errors, paste0("Variable '", variable_name, "' range must be Date."))
    }
  } else if (!is.numeric(range)) {
    errors <- c(errors, paste0("Variable '", variable_name, "' range must be numeric."))
  }

  if (any(is.na(range))) {
    errors <- c(errors, paste0("Variable '", variable_name, "' range must not contain NA values."))
  } else if (range[[1]] > range[[2]]) {
    errors <- c(errors, paste0("Variable '", variable_name, "' range lower bound must be <= upper bound."))
  }

  errors
}

.validate_mock_spec_variable <- function(variable) {
  errors <- character(0)

  if (!inherits(variable, "mock_spec_variable")) {
    return("All mock_spec variables must inherit from mock_spec_variable.")
  }

  errors <- c(errors, .validate_missing_spec(variable))

  if (variable$type == "continuous") {
    errors <- c(errors, .validate_range(variable$range, variable$name, "numeric"))
    if (identical(variable$distribution, "normal")) {
      if (is.null(variable$mean) || length(variable$mean) != 1 || is.na(variable$mean)) {
        errors <- c(errors, paste0("Variable '", variable$name, "' normal distribution requires mean."))
      }
      if (is.null(variable$sd) || length(variable$sd) != 1 || is.na(variable$sd) || variable$sd <= 0) {
        errors <- c(errors, paste0("Variable '", variable$name, "' normal distribution requires sd > 0."))
      }
    }
  } else if (variable$type == "categorical") {
    if (is.null(variable$levels) || length(variable$levels) == 0) {
      errors <- c(errors, paste0("Variable '", variable$name, "' must have at least one level."))
    }
    if (!is.null(variable$proportions)) {
      if (length(variable$levels) != length(variable$proportions)) {
        errors <- c(errors, paste0("Variable '", variable$name, "' must have one proportion per level."))
      }
      errors <- c(errors, .validate_probability_vector(
        variable$proportions,
        paste0("Variable '", variable$name, "' proportions"),
        allow_null = FALSE
      ))
      prop_sum <- sum(variable$proportions, na.rm = TRUE)
      if (abs(prop_sum - 1) > 0.001) {
        errors <- c(errors, paste0("Variable '", variable$name, "' proportions must sum to 1."))
      }
    }
  } else if (variable$type == "date") {
    errors <- c(errors, .validate_range(variable$range, variable$name, "Date"))
  } else {
    errors <- c(errors, paste0("Variable '", variable$name, "' has unsupported type '", variable$type, "'."))
  }

  errors
}

#' Validate a MockData specification
#'
#' @param spec A `mock_spec` object.
#' @param n Optional number of rows expected for generation. If supplied, must
#'   be a non-negative whole number.
#' @param strict Logical. If `TRUE`, invalid specs throw an error. If `FALSE`,
#'   a validation result object is returned.
#'
#' @return A `mock_spec_validation_result` object when valid or `strict = FALSE`.
#' @export
validate_mock_spec <- function(spec, n = NULL, strict = TRUE) {
  errors <- character(0)
  warnings <- character(0)
  info <- character(0)

  if (!is_mock_spec(spec)) {
    errors <- c(errors, "spec must be a mock_spec object.")
  } else {
    if (is.null(spec$spec_version) || length(spec$spec_version) != 1 || is.na(spec$spec_version)) {
      errors <- c(errors, "mock_spec must have a scalar spec_version.")
    }
    if (is.null(spec$variables) || !is.list(spec$variables)) {
      errors <- c(errors, "mock_spec variables must be a list.")
    } else {
      variable_names <- names(spec$variables)
      if (length(variable_names) != length(unique(variable_names))) {
        errors <- c(errors, "mock_spec variable names must be unique.")
      }
      for (variable in spec$variables) {
        errors <- c(errors, .validate_mock_spec_variable(variable))
      }
    }
  }

  if (!is.null(n)) {
    if (!is.numeric(n) || length(n) != 1 || is.na(n) || n < 0 || n != floor(n)) {
      errors <- c(errors, "n must be a non-negative whole number.")
    }
  }

  valid <- length(errors) == 0
  result <- .new_mock_spec_validation_result(valid, errors, warnings, info)

  if (!valid && isTRUE(strict)) {
    stop(paste(errors, collapse = "\n"), call. = FALSE)
  }

  result
}
