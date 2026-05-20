# ==============================================================================
# MockData v0.4 Post-processing Layer
# ==============================================================================
# Applies missing-code and garbage-value rules after baseline generation while
# preserving diagnostics that distinguish assigned states from coincidental
# value collisions.
# ==============================================================================

#' @noRd
.postprocess_empty_diagnostics <- function(spec, n) {
  variables <- lapply(spec$variables, function(variable) {
    garbage_rule_names <- names(variable$garbage_rules)
    if (is.null(garbage_rule_names)) {
      garbage_rule_names <- character(0)
    }
    garbage_rule_names <- .ordered_garbage_rule_names(garbage_rule_names)
    garbage_indices <- stats::setNames(
      rep(list(integer(0)), length(garbage_rule_names)),
      garbage_rule_names
    )
    garbage_values <- stats::setNames(
      rep(list(character(0)), length(garbage_rule_names)),
      garbage_rule_names
    )

    list(
      n = n,
      preexisting_missing_code_indices = integer(0),
      assigned_missing_indices = integer(0),
      assigned_missing_codes = character(0),
      assigned_garbage_indices = garbage_indices,
      assigned_garbage_values = garbage_values
    )
  })

  list(
    spec_version = spec$spec_version,
    variables = variables
  )
}

#' @noRd
.values_match_codes <- function(values, codes) {
  if (length(codes) == 0) {
    return(rep(FALSE, length(values)))
  }

  as.character(values) %in% as.character(codes)
}

#' @noRd
.sample_postprocess_indices <- function(candidates, n, avoid = integer(0)) {
  if (n == 0) {
    return(integer(0))
  }
  if (length(candidates) < n) {
    stop("Not enough candidate rows are available for post-processing.", call. = FALSE)
  }

  preferred <- setdiff(candidates, avoid)
  if (length(preferred) >= n) {
    return(.sample_values(preferred, n))
  }

  c(
    preferred,
    .sample_values(setdiff(candidates, preferred), n - length(preferred))
  )
}

#' @noRd
.coerce_postprocess_values <- function(values, variable, target) {
  if (inherits(target, "factor")) {
    return(as.character(values))
  }

  if (inherits(target, "Date") || variable$rtype == "date") {
    converted <- as.Date(values)
    if (any(is.na(converted) & !is.na(values))) {
      stop("Variable '", variable$name, "' has date post-processing values that cannot be parsed.", call. = FALSE)
    }
    return(converted)
  }

  if (is.integer(target) || variable$rtype == "integer") {
    converted <- suppressWarnings(as.integer(round(as.numeric(values))))
    if (any(is.na(converted) & !is.na(values))) {
      stop("Variable '", variable$name, "' has integer post-processing values that cannot be parsed.", call. = FALSE)
    }
    return(converted)
  }

  if (is.numeric(target) || variable$rtype %in% c("double", "numeric")) {
    converted <- suppressWarnings(as.numeric(values))
    if (any(is.na(converted) & !is.na(values))) {
      stop("Variable '", variable$name, "' has numeric post-processing values that cannot be parsed.", call. = FALSE)
    }
    return(converted)
  }

  if (is.logical(target) || variable$rtype == "logical") {
    value_chr <- as.character(values)
    if (!all(value_chr %in% c("TRUE", "FALSE", "true", "false", "1", "0"))) {
      stop("Variable '", variable$name, "' has logical post-processing values that cannot be parsed.", call. = FALSE)
    }
    return(value_chr %in% c("TRUE", "true", "1"))
  }

  as.character(values)
}

#' @noRd
.assign_postprocess_values <- function(target, indices, values) {
  if (length(indices) == 0) {
    return(target)
  }

  if (inherits(target, "factor")) {
    missing_levels <- setdiff(as.character(values), levels(target))
    if (length(missing_levels) > 0) {
      levels(target) <- c(levels(target), missing_levels)
    }
  }

  target[indices] <- values
  target
}

#' @noRd
.generate_garbage_for_rule <- function(rule, variable, n) {
  if (n == 0) {
    return(vector(mode = "character", length = 0))
  }

  parsed <- parse_range_notation(rule$range)
  if (is.null(parsed)) {
    stop(
      "Variable '", variable$name, "' has an invalid garbage range: ",
      rule$range,
      call. = FALSE
    )
  }

  if (identical(parsed$type, "date")) {
    date_values <- seq(parsed$min, parsed$max, by = "day")
    return(.sample_values(date_values, n, replace = TRUE))
  }

  if (identical(parsed$type, "integer") && !is.null(parsed$values)) {
    return(.sample_values(parsed$values, n, replace = TRUE))
  }

  values <- stats::runif(n, parsed$min, parsed$max)
  if (variable$type == "categorical" || variable$rtype == "integer") {
    values <- round(values)
  }

  values
}

#' @noRd
.ordered_garbage_rule_names <- function(rule_names) {
  # Keep the long-standing garbage convention deterministic: low rules run
  # before high rules; any future rule names follow in caller order.
  c(intersect(c("low", "high"), rule_names), setdiff(rule_names, c("low", "high")))
}

#' @noRd
.postprocess_missing <- function(values, variable, diagnostics) {
  if (length(variable$missing_codes) == 0) {
    return(list(values = values, diagnostics = diagnostics))
  }
  if (sum(variable$missing_proportions) > 1 + .mock_spec_probability_tolerance) {
    stop(
      "Variable '", variable$name,
      "' missing proportions request more rows than are available.",
      call. = FALSE
    )
  }

  available <- seq_along(values)
  # Record values that naturally collide with declared missing codes before
  # assigning any new missing codes; this is the auditability contract.
  preexisting <- which(.values_match_codes(values, variable$missing_codes))
  assigned <- integer(0)
  assigned_codes <- character(0)

  for (i in seq_along(variable$missing_codes)) {
    proportion <- variable$missing_proportions[[i]]
    n_assign <- round(length(values) * proportion)
    if (n_assign == 0) {
      next
    }

    code <- variable$missing_codes[[i]]
    code_values <- rep(code, n_assign)
    assign_idx <- .sample_postprocess_indices(
      available,
      n_assign,
      avoid = union(preexisting, assigned)
    )
    coerced <- .coerce_postprocess_values(code_values, variable, values)
    values <- .assign_postprocess_values(values, assign_idx, coerced)

    available <- setdiff(available, assign_idx)
    assigned <- c(assigned, assign_idx)
    assigned_codes <- c(assigned_codes, as.character(code_values))
  }

  diagnostics$preexisting_missing_code_indices <- preexisting
  diagnostics$assigned_missing_indices <- assigned
  diagnostics$assigned_missing_codes <- assigned_codes

  list(values = values, diagnostics = diagnostics)
}

#' @noRd
.postprocess_garbage <- function(values, variable, diagnostics) {
  if (length(variable$garbage_rules) == 0) {
    return(list(values = values, diagnostics = diagnostics))
  }
  if (is.null(names(variable$garbage_rules)) || any(names(variable$garbage_rules) == "")) {
    rule_names <- names(variable$garbage_rules)
    unnamed <- if (is.null(rule_names)) {
      seq_along(variable$garbage_rules)
    } else {
      which(rule_names == "")
    }
    stop(
      "Variable '", variable$name, "' garbage_rules must be a named list; ",
      "unnamed rule index: ", paste(unnamed, collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  protected_idx <- union(
    diagnostics$assigned_missing_indices,
    diagnostics$preexisting_missing_code_indices
  )
  # Garbage must not overwrite either assigned missing rows or naturally drawn
  # missing-code collisions, otherwise diagnostics would no longer describe the
  # returned data.
  valid_idx <- setdiff(which(!is.na(values)), protected_idx)
  remaining_idx <- valid_idx

  requested <- vapply(variable$garbage_rules, function(rule) {
    proportion <- rule$proportion %||% 0
    if (is.na(proportion)) {
      proportion <- 0
    }
    as.integer(round(length(valid_idx) * proportion))
  }, integer(1))

  if (sum(requested) > length(valid_idx)) {
    stop(
      "Variable '", variable$name,
      "' garbage rules request more rows than are available after missing-code assignment.",
      call. = FALSE
    )
  }

  for (rule_name in .ordered_garbage_rule_names(names(variable$garbage_rules))) {
    rule <- variable$garbage_rules[[rule_name]]
    n_assign <- requested[[rule_name]]
    if (n_assign == 0) {
      next
    }

    if (is.null(rule$range) || is.na(rule$range) || trimws(rule$range) == "") {
      stop("Variable '", variable$name, "' garbage rule '", rule_name, "' is missing a range.", call. = FALSE)
    }

    assign_idx <- .sample_postprocess_indices(remaining_idx, n_assign)
    raw_values <- .generate_garbage_for_rule(rule, variable, n_assign)
    coerced <- .coerce_postprocess_values(raw_values, variable, values)
    values <- .assign_postprocess_values(values, assign_idx, coerced)

    diagnostics$assigned_garbage_indices[[rule_name]] <- assign_idx
    diagnostics$assigned_garbage_values[[rule_name]] <- coerced
    remaining_idx <- setdiff(remaining_idx, assign_idx)
  }

  list(values = values, diagnostics = diagnostics)
}

#' @noRd
.postprocess_variable <- function(values, variable, diagnostics) {
  missing_result <- .postprocess_missing(values, variable, diagnostics)
  garbage_result <- .postprocess_garbage(
    missing_result$values,
    variable,
    missing_result$diagnostics
  )

  garbage_result
}

#' Apply mock_spec post-processing rules
#'
#' `postprocess_mock_data()` applies v0.4 `mock_spec` missing-code and
#' garbage-value rules to an already generated baseline data frame. It records a
#' `mockdata_diagnostics` attribute so downstream checks can distinguish values
#' assigned by post-processing from values that were drawn naturally by the
#' baseline generator.
#'
#' @param data Data frame with one column for each variable in `spec`.
#' @param spec A validated `mock_spec` object.
#' @param seed Optional whole-number random seed. The previous R random state is
#'   restored after post-processing.
#' @param diagnostics Logical. If `TRUE`, attach a `mockdata_diagnostics`
#'   attribute to the returned data frame.
#'
#' @return A data frame with post-processing applied.
#'
#' @details
#' Missing-code diagnostics separate values that were naturally drawn as a
#' declared missing code (`preexisting_missing_code_indices`) from values that
#' were assigned by post-processing (`assigned_missing_indices`). Garbage rules
#' are applied only to rows that are not missing-code diagnostics, preserving the
#' audit trail for collision cases such as a valid category code that is also a
#' declared missing code.
#'
#' Garbage rules are applied in canonical order: `low`, then `high`, then any
#' other named rules in caller order. Diagnostics are stored as a data-frame
#' attribute. Base R subsetting and some downstream tools may drop attributes,
#' so preserve the original post-processed object when diagnostics are part of
#' the audit trail.
#'
#' @family mock generation APIs
#' @seealso [generate_mock_data_native()], [generate_mock_data_simstudy()],
#'   [mock_spec()]
#'
#' @examples
#' spec <- mock_categorical(
#'   "smoking",
#'   levels = c("never", "former", "current"),
#'   proportions = c(0.5, 0.3, 0.2),
#'   rtype = "character",
#'   missing_codes = "9",
#'   missing_proportions = 0.05
#' )
#' baseline <- generate_mock_data_native(spec, n = 20, seed = 1)
#' result <- postprocess_mock_data(baseline, spec, seed = 2)
#' attr(result, "mockdata_diagnostics")$variables$smoking
#'
#' @export
postprocess_mock_data <- function(data, spec, seed = NULL, diagnostics = TRUE) {
  if (!is.data.frame(data)) {
    stop("data must be a data frame.", call. = FALSE)
  }
  if (!is.null(attr(data, "mockdata_diagnostics"))) {
    stop(
      "postprocess_mock_data() appears to have already run on this data. ",
      "Start from baseline generated data to avoid double post-processing.",
      call. = FALSE
    )
  }
  validate_mock_spec(spec, n = nrow(data), strict = TRUE)

  missing_columns <- setdiff(names(spec$variables), names(data))
  if (length(missing_columns) > 0) {
    stop(
      "data is missing column(s) required by spec: ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }

  .with_mock_seed(seed, {
    output <- data
    diag <- .postprocess_empty_diagnostics(spec, nrow(data))

    for (variable_name in names(spec$variables)) {
      variable <- spec$variables[[variable_name]]
      result <- .postprocess_variable(
        output[[variable_name]],
        variable,
        diag$variables[[variable_name]]
      )
      output[[variable_name]] <- result$values
      diag$variables[[variable_name]] <- result$diagnostics
    }

    if (isTRUE(diagnostics)) {
      attr(output, "mockdata_diagnostics") <- diag
    }

    output
  })
}
