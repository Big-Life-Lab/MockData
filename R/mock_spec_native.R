# ==============================================================================
# MockData v0.4 Native Backend
# ==============================================================================
# Baseline native generation from mock_spec. Post-processing for missing codes,
# garbage, diagnostics, and richer rType handling lands in later milestones.
# ==============================================================================

.with_mock_seed <- function(seed, expr) {
  if (is.null(seed)) {
    return(force(expr))
  }

  if (!is.numeric(seed) || length(seed) != 1 || is.na(seed) || seed != floor(seed)) {
    stop("seed must be a single whole number.", call. = FALSE)
  }

  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) {
    old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  }

  on.exit({
    if (had_seed) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)

  set.seed(seed)
  force(expr)
}

.empty_native_data <- function(n) {
  data.frame(row.names = seq_len(n))
}

.sample_indices <- function(n_levels, n, prob = NULL) {
  if (n == 0) {
    return(integer(0))
  }
  sample.int(n_levels, size = n, replace = TRUE, prob = prob)
}

.native_formula_variables <- function(spec) {
  names(Filter(function(variable) {
    formula <- variable$formula
    !is.null(formula) &&
      !(is.character(formula) && length(formula) == 1 && (is.na(formula) || trimws(formula) == ""))
  }, spec$variables))
}

.check_native_backend_scope <- function(spec) {
  formula_variables <- .native_formula_variables(spec)
  if (length(formula_variables) > 0) {
    stop(
      "Formula evaluation is not yet implemented in the M4 native backend. ",
      "Formula variable(s): ",
      paste(formula_variables, collapse = ", "),
      ". Expected in a later formula/dependency milestone.",
      call. = FALSE
    )
  }

  invisible(TRUE)
}

.native_truncated_normal <- function(n, mean, sd, range, variable_name) {
  if (n == 0) {
    return(numeric(0))
  }

  values <- rep(NA_real_, n)
  remaining <- seq_len(n)
  attempts <- 0
  max_attempts <- 100

  while (length(remaining) > 0 && attempts < max_attempts) {
    draws <- stats::rnorm(length(remaining), mean = mean, sd = sd)
    valid <- draws >= range[[1]] & draws <= range[[2]]
    values[remaining[valid]] <- draws[valid]
    remaining <- remaining[!valid]
    attempts <- attempts + 1
  }

  if (length(remaining) > 0) {
    warning(
      "Variable '", variable_name,
      "': could not fill all truncated-normal values by rejection sampling; ",
      "using uniform draws for the remaining values.",
      call. = FALSE
    )
    values[remaining] <- stats::runif(length(remaining), range[[1]], range[[2]])
  }

  values
}

.coerce_native_continuous <- function(values, rtype, variable_name) {
  if (rtype == "integer") {
    return(as.integer(round(values)))
  }
  if (rtype %in% c("double", "numeric")) {
    return(as.numeric(values))
  }

  stop(
    "Variable '", variable_name, "' has unsupported native continuous rType '",
    rtype, "'.",
    call. = FALSE
  )
}

.coerce_native_categorical <- function(values, levels, rtype, variable_name) {
  if (rtype == "factor") {
    return(factor(values, levels = levels))
  }
  if (rtype == "character") {
    return(as.character(values))
  }
  if (rtype == "integer") {
    converted <- suppressWarnings(as.integer(values))
    if (any(is.na(converted) & !is.na(values))) {
      stop(
        "Variable '", variable_name,
        "' integer categorical generation requires integer-like levels.",
        call. = FALSE
      )
    }
    return(converted)
  }
  if (rtype %in% c("double", "numeric")) {
    converted <- suppressWarnings(as.numeric(values))
    if (any(is.na(converted) & !is.na(values))) {
      stop(
        "Variable '", variable_name,
        "' numeric categorical generation requires numeric-like levels.",
        call. = FALSE
      )
    }
    return(converted)
  }
  if (rtype == "logical") {
    if (!all(values %in% c("TRUE", "FALSE", "true", "false", "1", "0", TRUE, FALSE))) {
      stop(
        "Variable '", variable_name,
        "' logical categorical generation requires TRUE/FALSE or 1/0 levels.",
        call. = FALSE
      )
    }
    return(values %in% c("TRUE", "true", "1", TRUE))
  }

  stop(
    "Variable '", variable_name, "' has unsupported native categorical rType '",
    rtype, "'.",
    call. = FALSE
  )
}

.coerce_native_date <- function(values, rtype, variable_name) {
  if (rtype == "date") {
    return(values)
  }
  if (rtype == "character") {
    return(as.character(values))
  }

  stop(
    "Variable '", variable_name, "' has unsupported native date rType '",
    rtype, "'.",
    call. = FALSE
  )
}

.generate_native_continuous <- function(variable, n) {
  distribution <- tolower(variable$distribution %||% "uniform")

  if (distribution == "uniform") {
    values <- stats::runif(n, variable$range[[1]], variable$range[[2]])
  } else if (distribution == "normal") {
    values <- .native_truncated_normal(
      n,
      variable$mean,
      variable$sd,
      variable$range,
      variable$name
    )
  } else {
    stop(
      "Native backend does not yet support continuous distribution '",
      distribution, "' for variable '", variable$name, "'.",
      call. = FALSE
    )
  }

  .coerce_native_continuous(values, variable$rtype, variable$name)
}

.generate_native_categorical <- function(variable, n) {
  levels <- as.character(variable$levels)
  prob <- variable$proportions
  if (is.null(prob)) {
    prob <- rep(1 / length(levels), length(levels))
  }

  values <- levels[.sample_indices(length(levels), n, prob)]
  .coerce_native_categorical(values, levels, variable$rtype, variable$name)
}

.generate_native_date <- function(variable, n) {
  distribution <- tolower(variable$distribution %||% "uniform")
  if (distribution != "uniform") {
    stop(
      "Native backend does not yet support date distribution '",
      distribution, "' for variable '", variable$name, "'.",
      call. = FALSE
    )
  }

  if (n == 0) {
    values <- as.Date(character(0))
  } else {
    range_numeric <- as.integer(variable$range)
    offsets <- .sample_indices(
      range_numeric[[2]] - range_numeric[[1]] + 1,
      n
    ) - 1
    values <- as.Date(range_numeric[[1]] + offsets, origin = "1970-01-01")
  }

  .coerce_native_date(values, variable$rtype, variable$name)
}

.generate_native_variable <- function(variable, n) {
  if (variable$type == "continuous") {
    return(.generate_native_continuous(variable, n))
  }
  if (variable$type == "categorical") {
    return(.generate_native_categorical(variable, n))
  }
  if (variable$type == "date") {
    return(.generate_native_date(variable, n))
  }

  stop(
    "Native backend does not support variable type '", variable$type,
    "' for variable '", variable$name, "'.",
    call. = FALSE
  )
}

#' Generate mock data with the native backend
#'
#' `generate_mock_data_native()` consumes a validated `mock_spec` and generates
#' baseline valid values using MockData's native R backend. This milestone does
#' not yet apply missing-code injection, garbage values, diagnostics, formula
#' evaluation, or optional `simstudy` features.
#'
#' @param spec A `mock_spec` object.
#' @param n Non-negative whole number of rows to generate.
#' @param seed Optional whole-number random seed. The previous R random state is
#'   restored after generation.
#'
#' @return A data frame with one column per `mock_spec` variable and `n` rows.
#' @family mock generation APIs
#' @seealso [mock_spec()], [mock_continuous()], [mock_spec_from_recodeflow()]
#'
#' @examples
#' spec <- mock_spec(
#'   mock_spec_continuous("age", range = c(18, 85), rtype = "integer"),
#'   mock_spec_categorical(
#'     "smoking",
#'     levels = c("never", "former", "current"),
#'     proportions = c(0.5, 0.3, 0.2)
#'   )
#' )
#' data <- generate_mock_data_native(spec, n = 10, seed = 1)
#' head(data)
#'
#' @export
generate_mock_data_native <- function(spec, n, seed = NULL) {
  validate_mock_spec(spec, n = n, strict = TRUE)
  .check_native_backend_scope(spec)

  .with_mock_seed(seed, {
    if (length(spec$variables) == 0) {
      .empty_native_data(n)
    } else {
      columns <- lapply(spec$variables, .generate_native_variable, n = n)
      names(columns) <- names(spec$variables)
      as.data.frame(columns, stringsAsFactors = FALSE, check.names = FALSE)
    }
  })
}
