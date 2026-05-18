# ==============================================================================
# MockData v0.4 Recodeflow Adapter
# ==============================================================================
# Converts recodeflow-style variables and variable_details metadata into the
# normalized mock_spec representation.
# ==============================================================================

.read_recodeflow_table <- function(x, label) {
  if (is.data.frame(x)) {
    return(x)
  }

  if (is.character(x) && length(x) == 1) {
    if (!file.exists(x)) {
      stop(label, " file does not exist: ", x, call. = FALSE)
    }
    return(read.csv(
      x,
      stringsAsFactors = FALSE,
      check.names = FALSE,
      na.strings = c("", "NA")
    ))
  }

  stop(label, " must be a data frame or a single CSV path.", call. = FALSE)
}

.is_blank <- function(x) {
  is.null(x) || length(x) == 0 || is.na(x[1]) || trimws(as.character(x[1])) == ""
}

.row_value <- function(row, name, default = NA) {
  if (!name %in% names(row)) {
    return(default)
  }

  value <- row[[name]][1]
  if (length(value) == 0) {
    return(default)
  }

  value
}

.row_character <- function(row, name, default = NA_character_) {
  value <- .row_value(row, name, default)
  if (.is_blank(value)) {
    return(default)
  }
  as.character(value)
}

.row_numeric <- function(row, name, default = NA_real_) {
  value <- .row_value(row, name, default)
  if (.is_blank(value)) {
    return(default)
  }

  numeric_value <- suppressWarnings(as.numeric(value))
  if (is.na(numeric_value)) {
    stop(
      "Column '", name, "' for variable '",
      .row_character(row, "variable", "<unknown>"),
      "' must be numeric; got '", as.character(value), "'.",
      call. = FALSE
    )
  }

  numeric_value
}

.recodeflow_required_columns <- function(data, required, label) {
  missing <- setdiff(required, names(data))
  if (length(missing) > 0) {
    stop(label, " is missing required column(s): ", paste(missing, collapse = ", "), call. = FALSE)
  }
}

.filter_recodeflow_by_database <- function(data, databaseStart, allow_empty = TRUE) {
  if (is.null(databaseStart)) {
    return(data)
  }
  if (!"databaseStart" %in% names(data)) {
    stop(
      "databaseStart filtering was requested, but metadata has no 'databaseStart' column.",
      call. = FALSE
    )
  }

  data[.database_start_matches(data$databaseStart, databaseStart, allow_empty = allow_empty), , drop = FALSE]
}

.filter_recodeflow_details <- function(variable_details, variable, databaseStart) {
  if (is.null(variable_details)) {
    return(NULL)
  }

  details <- variable_details[variable_details$variable == variable, , drop = FALSE]
  .filter_recodeflow_by_database(details, databaseStart, allow_empty = TRUE)
}

.recodeflow_variable_kind <- function(var_row) {
  rtype <- tolower(.row_character(var_row, "rType", ""))
  variable_type <- tolower(.row_character(var_row, "variableType", ""))

  if (rtype == "date" || variable_type == "date") {
    return("date")
  }
  if (variable_type == "categorical" || rtype %in% c("factor", "character", "logical")) {
    return("categorical")
  }
  if (variable_type == "continuous" || rtype %in% c("integer", "double", "numeric")) {
    return("continuous")
  }

  stop(
    "Variable '", .row_character(var_row, "variable", "<unknown>"),
    "' has unsupported variableType/rType combination: variableType = '",
    variable_type, "', rType = '", rtype, "'.",
    call. = FALSE
  )
}

.recodeflow_rtype <- function(var_row, kind) {
  rtype <- tolower(.row_character(var_row, "rType", ""))
  if (rtype != "") {
    if (rtype == "numeric") {
      return("double")
    }
    return(rtype)
  }

  switch(
    kind,
    continuous = "double",
    categorical = "factor",
    date = "date"
  )
}

.parse_single_date <- function(value) {
  if (.is_blank(value)) {
    return(NULL)
  }

  parsed <- parse_range_notation(paste0("[", value, ",", value, "]"))
  if (!is.null(parsed) && identical(parsed$type, "date")) {
    return(c(parsed$min, parsed$max))
  }

  NULL
}

.recodeflow_valid_rows <- function(details) {
  if (is.null(details) || nrow(details) == 0) {
    return(details)
  }

  rec_start <- as.character(details$recStart)
  rec_end <- if ("recEnd" %in% names(details)) as.character(details$recEnd) else rep("", nrow(details))

  keep <- !is.na(rec_start) &
    rec_start != "" &
    rec_start != "else" &
    !grepl("^garbage_", rec_start, ignore.case = TRUE) &
    !grepl("^NA::", rec_end) &
    !grepl("^DerivedVar::", rec_start) &
    !grepl("^Func::", rec_start)

  details[keep, , drop = FALSE]
}

.recodeflow_range <- function(details, variable, kind) {
  valid_rows <- .recodeflow_valid_rows(details)
  if (is.null(valid_rows) || nrow(valid_rows) == 0) {
    stop("Variable '", variable, "' has no valid recodeflow detail rows for range extraction.", call. = FALSE)
  }

  for (i in seq_len(nrow(valid_rows))) {
    rec_start <- valid_rows$recStart[i]
    parsed <- parse_range_notation(rec_start)

    if (kind == "date") {
      if (!is.null(parsed) && identical(parsed$type, "date")) {
        return(c(parsed$min, parsed$max))
      }

      single_date <- .parse_single_date(rec_start)
      if (!is.null(single_date)) {
        return(single_date)
      }
    } else {
      if (!is.null(parsed) && parsed$type %in% c("integer", "continuous", "single_value")) {
        return(c(parsed$min, parsed$max))
      }
    }
  }

  stop("Variable '", variable, "' has no parseable ", kind, " range in recStart.", call. = FALSE)
}

.recodeflow_missing <- function(details) {
  if (is.null(details) || nrow(details) == 0 || !"recEnd" %in% names(details)) {
    return(list(codes = character(0), proportions = numeric(0)))
  }

  is_missing <- grepl("^NA::", details$recEnd) &
    !is.na(details$recStart) &
    details$recStart != "" &
    details$recStart != "else"

  missing_rows <- details[is_missing, , drop = FALSE]
  if (nrow(missing_rows) == 0) {
    return(list(codes = character(0), proportions = numeric(0)))
  }

  proportions <- if ("proportion" %in% names(missing_rows)) missing_rows$proportion else rep(NA_real_, nrow(missing_rows))
  proportions[is.na(proportions)] <- 0

  list(
    codes = as.character(missing_rows$recStart),
    proportions = as.numeric(proportions)
  )
}

.recodeflow_distribution <- function(var_row, details) {
  distribution <- tolower(.row_character(var_row, "distribution", ""))
  if (distribution != "") {
    return(distribution)
  }

  params <- tryCatch(
    extract_distribution_params(details),
    error = function(e) {
      warning(
        "Could not infer distribution for variable '",
        .row_character(var_row, "variable", "<unknown>"),
        "' from details; using uniform. Reason: ",
        conditionMessage(e),
        call. = FALSE
      )
      list(distribution = "uniform")
    }
  )
  params$distribution %||% "uniform"
}

.recodeflow_garbage_rules <- function(var_row) {
  rules <- list()

  low_prop <- .row_numeric(var_row, "garbage_low_prop")
  low_range <- .row_character(var_row, "garbage_low_range", "")
  if (low_range == "[;]") {
    low_range <- ""
  }
  if ((!is.na(low_prop) && low_prop > 0) || low_range != "") {
    rules$low <- list(proportion = low_prop, range = low_range)
  }

  high_prop <- .row_numeric(var_row, "garbage_high_prop")
  high_range <- .row_character(var_row, "garbage_high_range", "")
  if (high_range == "[;]") {
    high_range <- ""
  }
  if ((!is.na(high_prop) && high_prop > 0) || high_range != "") {
    rules$high <- list(proportion = high_prop, range = high_range)
  }

  rules
}

.recodeflow_provenance <- function(variable, databaseStart = NULL) {
  provenance <- list(adapter = "recodeflow", source = variable)
  if (!is.null(databaseStart)) {
    provenance$databaseStart <- paste(databaseStart, collapse = ",")
  }
  provenance
}

.recodeflow_to_spec_variable <- function(var_row, details, databaseStart) {
  variable <- .row_character(var_row, "variable")
  kind <- .recodeflow_variable_kind(var_row)
  rtype <- .recodeflow_rtype(var_row, kind)
  provenance <- .recodeflow_provenance(variable, databaseStart)
  missing <- .recodeflow_missing(details)
  garbage_rules <- .recodeflow_garbage_rules(var_row)

  if (kind == "categorical") {
    proportions <- extract_proportions(details, variable_name = variable)
    if (length(proportions$categories) == 0) {
      stop("Variable '", variable, "' has no valid categorical levels.", call. = FALSE)
    }

    return(mock_spec_categorical(
      name = variable,
      levels = proportions$categories,
      proportions = proportions$category_proportions,
      rtype = rtype,
      missing_codes = names(proportions$missing),
      missing_proportions = as.numeric(unlist(proportions$missing, use.names = FALSE)),
      garbage_rules = garbage_rules,
      provenance = provenance,
      model_hint = "native"
    ))
  }

  if (kind == "continuous") {
    distribution <- .recodeflow_distribution(var_row, details)

    return(mock_spec_continuous(
      name = variable,
      range = .recodeflow_range(details, variable, "continuous"),
      distribution = distribution,
      mean = .row_numeric(var_row, "mean"),
      sd = .row_numeric(var_row, "sd"),
      rtype = rtype,
      missing_codes = missing$codes,
      missing_proportions = missing$proportions,
      garbage_rules = garbage_rules,
      provenance = provenance,
      model_hint = "native"
    ))
  }

  source_format <- .row_character(var_row, "sourceFormat", "analysis")

  .new_mock_spec_variable(
    name = variable,
    type = "date",
    rtype = rtype,
    distribution = .recodeflow_distribution(var_row, details),
    range = .recodeflow_range(details, variable, "date"),
    source_format = source_format,
    missing_codes = missing$codes,
    missing_proportions = missing$proportions,
    garbage_rules = garbage_rules,
    provenance = provenance,
    model_hint = "native-postprocess",
    rate = .row_numeric(var_row, "rate"),
    shape = .row_numeric(var_row, "shape"),
    followup_min = .row_numeric(var_row, "followup_min"),
    followup_max = .row_numeric(var_row, "followup_max"),
    event_prop = .row_numeric(var_row, "event_prop")
  )
}

#' Convert recodeflow metadata to a MockData specification
#'
#' `mock_spec_from_recodeflow()` adapts recodeflow-style `variables` and
#' `variable_details` metadata into the normalized v0.4 `mock_spec` shape. It
#' returns a validated specification; it does not generate data.
#'
#' @details
#' This adapter preserves recodeflow semantics instead of treating metadata as a
#' generic table. It uses exact role and `databaseStart` token matching, parses
#' valid ranges from `recStart`, classifies missing codes from `recEnd` values
#' that begin with `NA::`, preserves categorical levels and proportions, carries
#' `garbage_*` settings into `garbage_rules`, and stores survival/date fields
#' such as `rate`, `shape`, `followup_min`, `followup_max`, and `event_prop` on
#' date variables for later backend milestones.
#'
#' By default, variables identified by `DerivedVar::` or `Func::` rows are
#' excluded because they should be evaluated after raw mock variables are
#' generated. Set `exclude_derived = FALSE` only when you want those rows to
#' appear in the adapter input and fail or be handled by later formula support.
#'
#' @param variables Data frame or CSV path for recodeflow-style `variables`
#'   metadata.
#' @param variable_details Data frame, CSV path, or `NULL` for recodeflow-style
#'   `variable_details` metadata.
#' @param databaseStart Optional database/cycle token used to filter metadata by
#'   exact comma-separated `databaseStart` values.
#' @param role Character vector of role tokens to include. Defaults to
#'   `"enabled"`. Use `NULL` to skip role filtering.
#' @param exclude_derived Logical. If `TRUE`, exclude variables identified by
#'   `DerivedVar::` or `Func::` rows in `variable_details`.
#' @param spec_version Character version of the specification shape.
#' @param model_hint Backend hint for the returned specification.
#'
#' @return A validated `mock_spec` object.
#' @family mock specification APIs
#' @seealso [mock_spec()], [mock_continuous()], [mock_categorical()],
#'   [mock_date()]
#'
#' @examples
#' variables <- data.frame(
#'   variable = "age",
#'   variableType = "Continuous",
#'   rType = "integer",
#'   role = "enabled",
#'   distribution = "uniform"
#' )
#' details <- data.frame(
#'   variable = "age",
#'   recStart = "[18, 85]",
#'   recEnd = "copy",
#'   proportion = 1
#' )
#' spec <- mock_spec_from_recodeflow(variables, details)
#' validate_mock_spec(spec)
#'
#' @export
mock_spec_from_recodeflow <- function(variables,
                                      variable_details = NULL,
                                      databaseStart = NULL,
                                      role = "enabled",
                                      exclude_derived = TRUE,
                                      spec_version = .mock_spec_version,
                                      model_hint = "auto") {
  variables <- .read_recodeflow_table(variables, "variables")
  variables <- .migrate_garbage_aliases(variables)
  .recodeflow_required_columns(variables, "variable", "variables")

  if (!is.null(variable_details)) {
    variable_details <- .read_recodeflow_table(variable_details, "variable_details")
    .recodeflow_required_columns(variable_details, c("variable", "recStart"), "variable_details")
  }

  if (!is.null(role)) {
    if (!"role" %in% names(variables)) {
      stop("variables must have a 'role' column when role filtering is requested.", call. = FALSE)
    }
    variables <- variables[.role_matches(variables$role, role, ignore.case = TRUE), , drop = FALSE]
  }

  variables <- .filter_recodeflow_by_database(variables, databaseStart, allow_empty = TRUE)

  if (nrow(variables) == 0) {
    stop("No variables matched the requested role/database filters.", call. = FALSE)
  }

  if (isTRUE(exclude_derived) && !is.null(variable_details)) {
    derived <- identify_derived_vars(variables, variable_details)
    removed <- intersect(variables$variable, derived)
    if (length(removed) > 0) {
      message(
        "Excluding derived recodeflow variable(s): ",
        paste(removed, collapse = ", ")
      )
    }
    variables <- variables[!variables$variable %in% derived, , drop = FALSE]
  }

  if (nrow(variables) == 0) {
    stop("No non-derived variables remain after filtering.", call. = FALSE)
  }

  spec_variables <- lapply(seq_len(nrow(variables)), function(i) {
    var_row <- variables[i, , drop = FALSE]
    details <- .filter_recodeflow_details(variable_details, var_row$variable[1], databaseStart)
    .recodeflow_to_spec_variable(var_row, details, databaseStart)
  })

  provenance <- list(adapter = "recodeflow", source = "variables+variable_details")
  if (!is.null(databaseStart)) {
    provenance$databaseStart <- paste(databaseStart, collapse = ",")
  }
  if (!is.null(role)) {
    provenance$role <- paste(role, collapse = ",")
  }

  mock_spec(
    spec_variables,
    spec_version = spec_version,
    provenance = provenance,
    model_hint = model_hint
  )
}
