# ==============================================================================
# Formula-derived variables (#39, Phase A) — spec-side helpers.
# Evaluation itself lives in evaluate_mock_formulas() (same file, Task 2).
# ADR: development/adr/v05-formula-evaluator.md
# ==============================================================================

# Base functions/operators a mockFormula may call. Deliberately closed and
# RNG-free: Phase A formulas are deterministic transformations of generated
# columns. Widen only on concrete need (ADR D3). is.na was added for deriving
# survival status (ADR v05-survival-dates D8).
.formula_allowlist <- c(
  "+", "-", "*", "/", "^", "%%", "%/%", "(",
  "<", "<=", ">", ">=", "==", "!=", "&", "|", "!",
  "ifelse", "pmin", "pmax", "min", "max", "abs", "round", "floor",
  "ceiling", "sqrt", "exp", "log", "log10", "sum", "mean", "cut",
  "as.numeric", "as.integer", "as.factor", "factor", "c", "is.na"
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
    # Unparseable formulas are reported once, by the per-variable validator
    # branch (R/mock_spec.R) — re-parsing here (via .formula_dependencies())
    # would both duplicate that error and abort this loop before checking the
    # OTHER, parseable formulas, masking their referent/symbol findings.
    parseable <- tryCatch({
      .parse_mock_formula(variable)
      TRUE
    }, error = function(e) FALSE)
    if (!parseable) next
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
.order_dependent_variables <- function(names_in_scope, dependencies, label) {
  # Shared by every derived-variable stage (ADR v05-survival-dates D7):
  # repeated passes in spec order, each placing the variables whose in-scope
  # dependencies are already placed. Dependencies outside `names_in_scope`
  # (baseline columns) are available from the start.
  remaining <- names_in_scope
  ordered <- character(0)
  while (length(remaining) > 0) {
    progressed <- FALSE
    for (name in remaining) {
      deps <- intersect(dependencies[[name]], names_in_scope)
      if (all(deps %in% ordered)) {
        ordered <- c(ordered, name)
        remaining <- setdiff(remaining, name)
        progressed <- TRUE
      }
    }
    if (!progressed) {
      stop(
        label, " dependency cycle or unresolved ordering among: ",
        paste(remaining, collapse = ", "),
        call. = FALSE
      )
    }
  }
  ordered
}

#' @noRd
.order_formula_variables <- function(spec) {
  formula_names <- names(spec$variables)[
    vapply(spec$variables, .is_formula_variable, logical(1))
  ]
  # Skip unparseable formulas here too (see .validate_formula_referents()):
  # the per-variable validator already reports the parse error once, and a
  # variable that can't be parsed has no computable dependency set — leaving
  # it in `formula_names` would either duplicate the parse error (via
  # .formula_dependencies()) or permanently block any variable that
  # references it from ever being ordered.
  parseable_names <- Filter(function(name) {
    tryCatch({
      .parse_mock_formula(spec$variables[[name]])
      TRUE
    }, error = function(e) FALSE)
  }, formula_names)

  dependencies <- lapply(spec$variables[parseable_names], .formula_dependencies)
  .order_dependent_variables(parseable_names, dependencies, "Formula")
}

#' @noRd
.formula_parent_env <- function() {
  # baseNamespace() (the brief's original spelling) is not itself an
  # exported/callable base function - .BaseNamespaceEnv is the base-R builtin
  # binding for the same environment (verified: every .formula_allowlist
  # symbol, including "(" and the operators, resolves via
  # get(fn, envir = .BaseNamespaceEnv)). Its parent is emptyenv(), so nothing
  # beyond this fixed set of base primitives is reachable from here.
  env <- new.env(parent = emptyenv())
  for (fn in .formula_allowlist) {
    env[[fn]] <- get(fn, envir = .BaseNamespaceEnv)
  }
  env
}

#' Evaluate formula-derived variables over generated data
#'
#' Computes each `type = "formula"` variable in `spec` by evaluating its
#' expression over the columns of `data`, in dependency order. Evaluation runs
#' in a restricted environment exposing only the data columns and a fixed
#' allow-list of base functions — formulas cannot reach the caller's
#' environment. Any randomness would draw from the isolated `formula`
#' sub-stream (see the v0.5 seed contract), though the Phase A allow-list is
#' RNG-free, so evaluation is deterministic given `data`.
#'
#' @param data Data frame of generated baseline values (from
#'   [generate_mock_data_native()] or [generate_mock_data_simstudy()]).
#' @param spec A `mock_spec`. Non-formula variables must already be columns of
#'   `data`. Strict-validated at entry (like [postprocess_mock_data()]), so an
#'   unparseable formula, an unknown referent, a disallowed symbol, or a
#'   dependency cycle raises here rather than silently skipping the affected
#'   variable.
#' @param seed Optional whole-number seed; reserved for future formulas with
#'   random components. The caller's RNG state and kind are restored on exit.
#'
#' @return `data` with one appended column per formula variable. Returns
#'   `data` unchanged if the spec has no formula variables.
#' @seealso [mock_formula()], [postprocess_mock_data()]
#' @export
evaluate_mock_formulas <- function(data, spec, seed = NULL) {
  if (!is.data.frame(data)) {
    stop("data must be a data frame.", call. = FALSE)
  }
  # Strict-validate first, exactly as postprocess_mock_data() does: the
  # accumulate-and-skip behaviour inside .order_formula_variables() and
  # .validate_formula_referents() is correct for validate_mock_spec()'s
  # multi-error reporting, but it means an unparseable/cyclic/invalid-referent
  # formula would otherwise be silently excluded from `ordered` below rather
  # than reported — generation must never reach a bad formula. Strict
  # validation already runs .validate_formula_referents()/
  # .order_formula_variables() (see validate_mock_spec()), so the direct call
  # to .validate_formula_referents() that used to live below is redundant and
  # has been removed.
  validate_mock_spec(spec, n = nrow(data), strict = TRUE)

  ordered <- .order_formula_variables(spec)
  if (length(ordered) == 0) {
    return(data)
  }

  non_formula <- setdiff(names(spec$variables), names(spec$variables)[
    vapply(spec$variables, .is_formula_variable, logical(1))
  ])
  missing_inputs <- setdiff(non_formula, names(data))
  if (length(missing_inputs) > 0) {
    stop(
      "data is missing generated column(s) required by formulas: ",
      paste(missing_inputs, collapse = ", "),
      call. = FALSE
    )
  }

  .with_mock_seed(seed, stage = "formula", {
    fn_env <- .formula_parent_env()
    for (name in ordered) {
      variable <- spec$variables[[name]]
      values <- eval(
        .parse_mock_formula(variable),
        envir = as.list(data),
        enclos = fn_env
      )
      if (length(values) == 1 && nrow(data) != 1) {
        values <- rep(values, nrow(data))   # scalar formulas broadcast
      }
      if (length(values) != nrow(data)) {
        stop(
          "Formula for variable '", name, "' returned length ", length(values),
          ", expected ", nrow(data), ".",
          call. = FALSE
        )
      }
      data[[name]] <- .coerce_formula_rtype(values, variable$rtype, name)
    }
    data
  })
}

#' @noRd
.coerce_formula_rtype <- function(values, rtype, variable_name) {
  switch(rtype,
    double = {
      if (is.factor(values)) {
        warning(
          "Variable '", variable_name,
          "' formula produced a factor but rType is '", rtype,
          "'; coercing to its integer level codes. Set rtype = \"factor\" (or \"character\") if that is not intended.",
          call. = FALSE
        )
      }
      as.numeric(values)
    },
    numeric = {
      if (is.factor(values)) {
        warning(
          "Variable '", variable_name,
          "' formula produced a factor but rType is '", rtype,
          "'; coercing to its integer level codes. Set rtype = \"factor\" (or \"character\") if that is not intended.",
          call. = FALSE
        )
      }
      as.numeric(values)
    },
    integer = {
      if (is.factor(values)) {
        warning(
          "Variable '", variable_name,
          "' formula produced a factor but rType is '", rtype,
          "'; coercing to its integer level codes. Set rtype = \"factor\" (or \"character\") if that is not intended.",
          call. = FALSE
        )
      }
      as.integer(values)
    },
    factor = as.factor(values),
    character = as.character(values),
    logical = as.logical(values),
    stop(
      "Variable '", variable_name, "' has unsupported formula rType '",
      rtype, "'.",
      call. = FALSE
    )
  )
}
