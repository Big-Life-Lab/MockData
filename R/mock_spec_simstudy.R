# ==============================================================================
# MockData v0.4 Optional simstudy Backend
# ==============================================================================
# Baseline generation from mock_spec using simstudy when the optional package is
# installed. MockData still owns post-processing and diagnostics.
# ==============================================================================

.require_simstudy <- function() {
  if (!requireNamespace("simstudy", quietly = TRUE)) {
    stop(
      "The optional simstudy backend requires the 'simstudy' package. ",
      "Install simstudy or use generate_mock_data_native().",
      call. = FALSE
    )
  }
  if (utils::packageVersion("simstudy") < "0.8.1") {
    stop(
      "The optional simstudy backend requires simstudy >= 0.8.1. ",
      "Install a newer simstudy version or use generate_mock_data_native().",
      call. = FALSE
    )
  }

  invisible(TRUE)
}

.check_simstudy_variable <- function(variable) {
  if (identical(variable$name, "id")) {
    stop(
      "Variable name 'id' conflicts with simstudy's generated row identifier. ",
      "Rename the variable or use generate_mock_data_native().",
      call. = FALSE
    )
  }

  if (variable$type == "categorical" && any(grepl(";", as.character(variable$levels), fixed = TRUE))) {
    stop(
      "Variable '", variable$name,
      "' has categorical level(s) containing ';', which simstudy uses as a delimiter.",
      call. = FALSE
    )
  }

  invisible(TRUE)
}

.simstudy_definition <- function(def, variable) {
  .check_simstudy_variable(variable)

  if (variable$type == "continuous") {
    distribution <- tolower(variable$distribution %||% "uniform")
    if (distribution == "uniform") {
      return(simstudy::defData(
        dtDefs = def,
        varname = variable$name,
        formula = paste(variable$range, collapse = ";"),
        dist = "uniform"
      ))
    }
  }

  if (variable$type == "categorical") {
    probabilities <- variable$proportions
    if (is.null(probabilities)) {
      probabilities <- rep(1 / length(variable$levels), length(variable$levels))
    }

    return(simstudy::defData(
      dtDefs = def,
      varname = variable$name,
      formula = paste(probabilities, collapse = ";"),
      variance = paste(variable$levels, collapse = ";"),
      dist = "categorical"
    ))
  }

  stop(
    "simstudy backend does not yet support variable '", variable$name,
    "' of type '", variable$type, "'.",
    call. = FALSE
  )
}

.normalize_simstudy_categorical <- function(values, variable) {
  value_chr <- as.character(values)
  levels <- as.character(variable$levels)
  if (all(value_chr %in% levels)) {
    return(value_chr)
  }

  index <- suppressWarnings(as.integer(value_chr))
  if (!any(is.na(index)) && all(index >= 1 & index <= length(levels))) {
    return(levels[index])
  }

  stop(
    "simstudy returned categorical values for variable '", variable$name,
    "' that do not match the mock_spec levels. ",
    "This may indicate a simstudy version or delimiter mismatch.",
    call. = FALSE
  )
}

.simstudy_can_generate <- function(variable) {
  if (variable$type == "categorical") {
    return(TRUE)
  }

  variable$type == "continuous" &&
    identical(tolower(variable$distribution %||% "uniform"), "uniform")
}

.simstudy_variables <- function(spec) {
  Filter(.simstudy_can_generate, spec$variables)
}

.native_only_variables <- function(spec) {
  Filter(function(variable) !.simstudy_can_generate(variable), spec$variables)
}

.generate_simstudy_baseline <- function(variables, n) {
  if (length(variables) == 0) {
    return(.empty_native_data(n))
  }

  def <- NULL
  for (variable in variables) {
    def <- .simstudy_definition(def, variable)
  }

  generated <- as.data.frame(simstudy::genData(n, def), stringsAsFactors = FALSE)
  generated <- generated[, names(variables), drop = FALSE]

  for (variable_name in names(variables)) {
    variable <- variables[[variable_name]]
    if (variable$type == "continuous") {
      generated[[variable_name]] <- .coerce_native_continuous(
        generated[[variable_name]],
        variable$rtype,
        variable$name
      )
    } else if (variable$type == "categorical") {
      generated[[variable_name]] <- .coerce_native_categorical(
        .normalize_simstudy_categorical(generated[[variable_name]], variable),
        as.character(variable$levels),
        variable$rtype,
        variable$name
      )
    }
  }

  generated
}

.generate_native_only_baseline <- function(variables, n) {
  if (length(variables) == 0) {
    return(.empty_native_data(n))
  }

  columns <- lapply(variables, .generate_native_variable, n = n)
  names(columns) <- names(variables)
  as.data.frame(columns, stringsAsFactors = FALSE, check.names = FALSE)
}

#' Generate mock data with the optional simstudy backend
#'
#' `generate_mock_data_simstudy()` consumes a validated `mock_spec` and
#' generates baseline valid values through the optional `simstudy` package for
#' supported uniform continuous and categorical variables. MockData remains
#' responsible for missing-code injection, garbage values, and diagnostics
#' through [postprocess_mock_data()].
#'
#' Variables that need MockData semantics not covered by this milestone, such as
#' truncated normal ranges and calendar dates, are generated by MockData's native
#' path inside the same seeded call.
#'
#' @param spec A `mock_spec` object.
#' @param n Non-negative whole number of rows to generate.
#' @param seed Optional whole-number random seed. The previous R random state is
#'   restored after generation.
#'
#' @return A data frame with one column per `mock_spec` variable and `n` rows.
#' @family mock generation APIs
#' @seealso [generate_mock_data_native()], [postprocess_mock_data()],
#'   [mock_spec()]
#'
#' @examples
#' spec <- mock_continuous("age", range = c(18, 85), rtype = "integer")
#' if (requireNamespace("simstudy", quietly = TRUE)) {
#'   data <- generate_mock_data_simstudy(spec, n = 10, seed = 1)
#'   head(data)
#' }
#'
#' @export
generate_mock_data_simstudy <- function(spec, n, seed = NULL) {
  .require_simstudy()
  validate_mock_spec(spec, n = n, strict = TRUE)
  .check_native_backend_scope(spec)

  simstudy_variables <- .simstudy_variables(spec)
  native_only_variables <- .native_only_variables(spec)

  .with_mock_seed(seed, {
    simstudy_data <- .generate_simstudy_baseline(simstudy_variables, n)
    native_data <- .generate_native_only_baseline(native_only_variables, n)

    columns <- c(simstudy_data, native_data)
    if (length(spec$variables) == 0) {
      return(.empty_native_data(n))
    }

    as.data.frame(
      columns[names(spec$variables)],
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
}
