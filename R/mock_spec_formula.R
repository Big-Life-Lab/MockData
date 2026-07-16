# ==============================================================================
# Formula-derived variables (#39, Phase A) — spec-side helpers.
# Evaluation itself lives in evaluate_mock_formulas() (same file, Task 2).
# ADR: development/adr/v05-formula-evaluator.md
# ==============================================================================

# Base functions/operators a mockFormula may call. Deliberately closed and
# RNG-free: Phase A formulas are deterministic transformations of generated
# columns. Widen only on concrete need (ADR D3).
.formula_allowlist <- c(
  "+", "-", "*", "/", "^", "%%", "%/%", "(",
  "<", "<=", ">", ">=", "==", "!=", "&", "|", "!",
  "ifelse", "pmin", "pmax", "min", "max", "abs", "round", "floor",
  "ceiling", "sqrt", "exp", "log", "log10", "sum", "mean", "cut",
  "as.numeric", "as.integer", "as.factor", "factor", "c"
)

#' @noRd
.parse_mock_formula <- function(variable) {
  tryCatch(
    str2lang(variable$formula),
    error = function(e) {
      stop(
        "Formula for variable '", variable$name, "' could not be parsed: ",
        conditionMessage(e),
        call. = FALSE
      )
    }
  )
}

#' @noRd
.is_formula_variable <- function(variable) {
  identical(variable$type, "formula")
}

#' @noRd
.formula_dependencies <- function(variable) {
  if (!.is_formula_variable(variable)) {
    return(character(0))
  }
  all.vars(.parse_mock_formula(variable))
}

#' @noRd
.formula_function_symbols <- function(variable) {
  expr <- .parse_mock_formula(variable)
  setdiff(all.names(expr), all.vars(expr))
}

#' @noRd
.validate_formula_referents <- function(spec) {
  spec_names <- names(spec$variables)
  for (variable in spec$variables) {
    if (!.is_formula_variable(variable)) next
    missing <- setdiff(.formula_dependencies(variable), spec_names)
    if (length(missing) > 0) {
      stop(
        "Formula for variable '", variable$name,
        "' references unknown variable(s): ",
        paste(missing, collapse = ", "),
        call. = FALSE
      )
    }
    disallowed <- setdiff(.formula_function_symbols(variable), .formula_allowlist)
    if (length(disallowed) > 0) {
      stop(
        "Formula for variable '", variable$name,
        "' uses function(s) not permitted in mockFormula expressions: ",
        paste(disallowed, collapse = ", "),
        call. = FALSE
      )
    }
  }
  invisible(TRUE)
}

#' @noRd
.order_formula_variables <- function(spec) {
  formula_names <- names(spec$variables)[
    vapply(spec$variables, .is_formula_variable, logical(1))
  ]
  remaining <- formula_names
  ordered <- character(0)
  while (length(remaining) > 0) {
    progressed <- FALSE
    for (name in remaining) {
      deps <- intersect(.formula_dependencies(spec$variables[[name]]), formula_names)
      if (all(deps %in% ordered)) {
        ordered <- c(ordered, name)
        remaining <- setdiff(remaining, name)
        progressed <- TRUE
      }
    }
    if (!progressed) {
      stop(
        "Formula dependency cycle or unresolved ordering among: ",
        paste(remaining, collapse = ", "),
        call. = FALSE
      )
    }
  }
  ordered
}
