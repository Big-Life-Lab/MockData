# MockData v0.4 simstudy architecture spike.
#
# This is deliberately a prototype, not package code. It tests whether a small
# normalized mock_spec can sit between recodeflow metadata and simstudy.

local({
  spike_lib <- Sys.getenv("MOCKDATA_SIMSTUDY_LIB", "/private/tmp/mockdata-simstudy-lib")
  if (dir.exists(spike_lib)) {
    .libPaths(c(spike_lib, .libPaths()))
  }
})

simstudy_available <- requireNamespace("simstudy", quietly = TRUE)

source("R/mockdata-parsers.R", local = TRUE)
source("R/mockdata_helpers.R", local = TRUE)

MODEL_HINTS <- c(
  "hybrid",
  "auto",
  "native-postprocess",
  "simstudy-or-native",
  "simstudy-advanced",
  "diagnostic-required"
)

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

mockdata_rtrunc_norm <- function(n, min, max, mu, s) {
  if (any(!is.finite(min)) || any(!is.finite(max)) || any(min >= max)) {
    stop("Truncated normal requires finite min < max.", call. = FALSE)
  }

  f_min <- stats::pnorm(min, mean = mu, sd = s)
  f_max <- stats::pnorm(max, mean = mu, sd = s)
  if (any(!is.finite(f_min)) || any(!is.finite(f_max)) || any(f_min >= f_max)) {
    stop("Truncated normal bounds collapse to an empty probability interval.", call. = FALSE)
  }

  stats::qnorm(stats::runif(n, min = f_min, max = f_max), mean = mu, sd = s)
}

new_mock_spec <- function(vars,
                          spec_version = "0.4-spike-1",
                          provenance = list(adapter = "mixed", source = "prototype"),
                          model_hint = "hybrid",
                          correlation_groups = list()) {
  validate_model_hint(model_hint)

  structure(
    vars,
    class = "mock_spec",
    spec_version = spec_version,
    provenance = provenance,
    model_hint = model_hint,
    correlation_groups = correlation_groups
  )
}

add_spec_metadata <- function(var,
                              spec_version = "0.4-spike-1",
                              provenance = "direct",
                              model_hint = "auto") {
  validate_model_hint(model_hint)

  var$spec_version <- spec_version
  var$provenance <- normalize_provenance(provenance)
  var$model_hint <- model_hint
  var
}

normalize_provenance <- function(provenance) {
  if (is.list(provenance)) {
    return(provenance)
  }

  list(adapter = provenance, source = provenance)
}

format_provenance <- function(provenance) {
  provenance <- normalize_provenance(provenance)
  values <- unique(unname(unlist(provenance, use.names = FALSE)))
  paste(values, collapse = "/")
}

validate_model_hint <- function(model_hint) {
  if (!model_hint %in% MODEL_HINTS) {
    stop(
      "Unknown model_hint: ", model_hint,
      ". Expected one of: ", paste(MODEL_HINTS, collapse = ", "),
      call. = FALSE
    )
  }

  invisible(TRUE)
}

mock_spec_continuous <- function(name,
                                 range,
                                 distribution = "uniform",
                                 mean = NA_real_,
                                 sd = NA_real_,
                                 rtype = "double",
                                 missing_codes = numeric(0),
                                 missing_proportions = numeric(0),
                                 garbage = list(),
                                 source = "direct",
                                 provenance = source,
                                 model_hint = "auto",
                                 correlation_group = NA_character_) {
  add_spec_metadata(list(
    name = name,
    type = "continuous",
    rtype = rtype,
    distribution = distribution,
    range = range,
    mean = mean,
    sd = sd,
    levels = NULL,
    proportions = NULL,
    formula = NULL,
    missing_codes = missing_codes,
    missing_proportions = missing_proportions,
    garbage = garbage,
    source = source,
    correlation_group = correlation_group
  ), provenance = provenance, model_hint = model_hint)
}

mock_spec_categorical <- function(name,
                                  levels,
                                  proportions = NULL,
                                  rtype = "factor",
                                  missing_codes = character(0),
                                  missing_proportions = numeric(0),
                                  garbage = list(),
                                  source = "direct",
                                  provenance = source,
                                  model_hint = "auto") {
  if (is.null(proportions)) {
    proportions <- rep(1 / length(levels), length(levels))
  }

  add_spec_metadata(list(
    name = name,
    type = "categorical",
    rtype = rtype,
    distribution = "categorical",
    range = NULL,
    mean = NA_real_,
    sd = NA_real_,
    levels = levels,
    proportions = proportions,
    formula = NULL,
    missing_codes = missing_codes,
    missing_proportions = missing_proportions,
    garbage = garbage,
    source = source
  ), provenance = provenance, model_hint = model_hint)
}

mock_spec_date <- function(name,
                           range,
                           rtype = "date",
                           source_format = "analysis",
                           source = "direct",
                           provenance = source,
                           model_hint = "native-postprocess") {
  add_spec_metadata(list(
    name = name,
    type = "date",
    rtype = rtype,
    distribution = "uniform",
    range = range,
    mean = NA_real_,
    sd = NA_real_,
    levels = NULL,
    proportions = NULL,
    formula = NULL,
    missing_codes = character(0),
    missing_proportions = numeric(0),
    garbage = list(),
    source_format = source_format,
    source = source
  ), provenance = provenance, model_hint = model_hint)
}

mock_spec_binary_formula <- function(name, formula, rtype = "integer") {
  add_spec_metadata(list(
    name = name,
    type = "binary_formula",
    rtype = rtype,
    distribution = "binary",
    range = c(0, 1),
    mean = NA_real_,
    sd = NA_real_,
    levels = NULL,
    proportions = NULL,
    formula = formula,
    missing_codes = character(0),
    missing_proportions = numeric(0),
    garbage = list(),
    source = "formula"
  ), provenance = "formula", model_hint = "simstudy-or-native")
}

mock_spec_correlated_continuous <- function(name,
                                            mean,
                                            sd,
                                            correlation_group,
                                            range = c(-Inf, Inf),
                                            rtype = "double") {
  mock_spec_continuous(
    name = name,
    range = range,
    distribution = "correlated_normal",
    mean = mean,
    sd = sd,
    rtype = rtype,
    source = "correlation_spec",
    provenance = "direct",
    model_hint = "simstudy-advanced",
    correlation_group = correlation_group
  )
}

spec_table <- function(spec) {
  data.frame(
    name = vapply(spec, `[[`, character(1), "name"),
    type = vapply(spec, `[[`, character(1), "type"),
    rtype = vapply(spec, `[[`, character(1), "rtype"),
    distribution = vapply(spec, `[[`, character(1), "distribution"),
    source = vapply(spec, `[[`, character(1), "source"),
    provenance = vapply(spec, function(x) format_provenance(x$provenance), character(1)),
    model_hint = vapply(spec, `[[`, character(1), "model_hint"),
    stringsAsFactors = FALSE
  )
}

first_range <- function(details_subset) {
  for (value in details_subset$recStart) {
    parsed <- parse_range_notation(value)
    if (!is.null(parsed) && parsed$type %in% c("integer", "continuous", "date")) {
      return(c(parsed$min, parsed$max))
    }
  }

  NULL
}

extract_missing <- function(details_subset) {
  missing_rows <- details_subset[
    grepl("^NA::", details_subset$recEnd %||% "", ignore.case = TRUE),
  ]

  if (nrow(missing_rows) == 0) {
    return(list(codes = character(0), proportions = numeric(0)))
  }

  props <- missing_rows$proportion
  props[is.na(props)] <- 0
  list(
    codes = stats::setNames(missing_rows$recStart, missing_rows$recStart),
    proportions = stats::setNames(props, missing_rows$recStart)
  )
}

extract_garbage <- function(var_row) {
  fields <- c(
    "garbage_low_prop", "garbage_low_range",
    "garbage_high_prop", "garbage_high_range"
  )
  fields <- fields[fields %in% names(var_row)]
  stats::setNames(as.list(var_row[1, fields, drop = TRUE]), fields)
}

as_mock_spec_from_recodeflow <- function(variables, variable_details, databaseStart) {
  out <- list()

  for (i in seq_len(nrow(variables))) {
    var_row <- variables[i, ]
    name <- var_row$variable
    details_subset <- variable_details[
      variable_details$variable == name &
        .database_start_matches(variable_details$databaseStart, databaseStart, allow_empty = TRUE),
    ]

    type <- tolower(var_row$variableType)
    rtype <- tolower(var_row$rType)
    missing <- extract_missing(details_subset)
    garbage <- extract_garbage(var_row)

    if (type %in% c("continuous", "integer", "numeric")) {
      out[[name]] <- mock_spec_continuous(
        name = name,
        range = first_range(details_subset),
        distribution = if ("distribution" %in% names(var_row)) var_row$distribution else "uniform",
        mean = if ("mean" %in% names(var_row)) var_row$mean else NA_real_,
        sd = if ("sd" %in% names(var_row)) var_row$sd else NA_real_,
        rtype = rtype,
        missing_codes = missing$codes,
        missing_proportions = missing$proportions,
        garbage = garbage,
        source = "recodeflow"
      )
    } else if (type %in% c("categorical", "factor")) {
      props <- extract_proportions(details_subset, name)
      missing_codes <- stats::setNames(names(props$missing), names(props$missing))
      out[[name]] <- mock_spec_categorical(
        name = name,
        levels = props$categories,
        proportions = props$category_proportions,
        rtype = rtype,
        missing_codes = missing_codes,
        missing_proportions = unlist(props$missing, use.names = TRUE),
        garbage = garbage,
        source = "recodeflow"
      )
    } else if (type == "date") {
      out[[name]] <- mock_spec_date(
        name = name,
        range = first_range(details_subset),
        rtype = rtype,
        source = "recodeflow"
      )
    } else {
      stop("Unsupported prototype variableType: ", var_row$variableType, call. = FALSE)
    }
  }

  new_mock_spec(out)
}

simstudy_formula <- function(x) {
  paste(x, collapse = ";")
}

formula_dependencies <- function(var) {
  if (is.null(var$formula) || is.na(var$formula)) {
    return(character(0))
  }

  all.vars(str2lang(var$formula))
}

order_spec_by_dependencies <- function(spec) {
  remaining <- names(spec)
  ordered <- character(0)

  while (length(remaining) > 0) {
    progressed <- FALSE

    for (name in remaining) {
      deps <- intersect(formula_dependencies(spec[[name]]), names(spec))
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

  new_mock_spec(
    spec[ordered],
    spec_version = attr(spec, "spec_version"),
    provenance = attr(spec, "provenance"),
    model_hint = attr(spec, "model_hint"),
    correlation_groups = attr(spec, "correlation_groups") %||% list()
  )
}

validate_formula_referents <- function(spec) {
  spec_names <- names(spec)

  for (var in spec) {
    missing <- setdiff(formula_dependencies(var), spec_names)
    if (length(missing) > 0) {
      stop(
        "Formula for variable '", var$name, "' references unknown variable(s): ",
        paste(missing, collapse = ", "),
        call. = FALSE
      )
    }
  }

  invisible(TRUE)
}

correlation_defs_from_spec <- function(spec) {
  groups <- attr(spec, "correlation_groups") %||% list()
  group_names <- unique(na.omit(vapply(
    spec,
    function(var) var$correlation_group %||% NA_character_,
    character(1)
  )))

  lapply(stats::setNames(group_names, group_names), function(group_name) {
    vars <- spec[vapply(
      spec,
      function(var) identical(var$correlation_group %||% NA_character_, group_name),
      logical(1)
    )]
    config <- groups[[group_name]] %||% list(rho = 0, corstr = "cs")

    list(
      group = group_name,
      names = vapply(vars, `[[`, character(1), "name"),
      means = vapply(vars, `[[`, numeric(1), "mean"),
      sds = vapply(vars, `[[`, numeric(1), "sd"),
      rho = config$rho %||% 0,
      corstr = config$corstr %||% "cs"
    )
  })
}

as_simstudy_def <- function(spec) {
  validate_formula_referents(spec)
  spec <- order_spec_by_dependencies(spec)
  def <- NULL

  for (var in spec) {
    if (identical(var$distribution, "correlated_normal")) {
      next
    }

    if (!simstudy_available) {
      stop("simstudy is not available; use backend = 'native' for this spike.", call. = FALSE)
    }

    if (var$type == "continuous") {
      range <- var$range
      if (var$distribution == "normal") {
        def <- simstudy::defData(
          def,
          varname = var$name,
          formula = "mockdata_rtrunc_norm",
          variance = paste0(
            "min = ", range[[1]],
            ", max = ", range[[2]],
            ", mu = ", var$mean,
            ", s = ", var$sd
          ),
          dist = "custom"
        )
      } else if (var$rtype == "integer") {
        def <- simstudy::defData(
          def,
          varname = var$name,
          formula = simstudy_formula(range),
          dist = "uniformInt"
        )
      } else {
        def <- simstudy::defData(
          def,
          varname = var$name,
          formula = simstudy_formula(range),
          dist = "uniform"
        )
      }
    } else if (var$type == "categorical") {
      def <- simstudy::defData(
        def,
        varname = var$name,
        formula = simstudy_formula(var$proportions),
        variance = simstudy_formula(var$levels),
        dist = "categorical"
      )
    } else if (var$type == "date") {
      days <- as.integer(var$range[[2]] - var$range[[1]])
      def <- simstudy::defData(
        def,
        varname = paste0(var$name, "__offset"),
        formula = paste0("0;", days),
        dist = "uniformInt"
      )
    } else if (var$type == "binary_formula") {
      def <- simstudy::defData(
        def,
        varname = var$name,
        formula = var$formula,
        dist = "binary",
        link = "logit"
      )
    }
  }

  structure(
    list(data_def = def, correlation_groups = correlation_defs_from_spec(spec)),
    class = "mock_simstudy_def"
  )
}

generate_mock_data_simstudy <- function(spec, n, seed = NULL) {
  if (!simstudy_available) {
    stop("simstudy is not available; use generate_mock_data_native().", call. = FALSE)
  }

  if (!is.null(seed)) {
    set.seed(seed)
  }

  sim_def <- as_simstudy_def(spec)
  simstudy::genData(n, sim_def$data_def)
}

generate_mock_data_native <- function(spec, n, seed = NULL) {
  validate_formula_referents(spec)
  spec <- order_spec_by_dependencies(spec)

  if (!is.null(seed)) {
    set.seed(seed)
  }

  data <- data.frame(id = seq_len(n))

  for (var in spec) {
    if (var$type == "continuous") {
      if (identical(var$distribution, "normal")) {
        data[[var$name]] <- mockdata_rtrunc_norm(
          n,
          min = var$range[[1]],
          max = var$range[[2]],
          mu = var$mean,
          s = var$sd
        )
      } else if (var$rtype == "integer") {
        data[[var$name]] <- sample(seq(var$range[[1]], var$range[[2]]), n, replace = TRUE)
      } else {
        data[[var$name]] <- stats::runif(n, var$range[[1]], var$range[[2]])
      }
    } else if (var$type == "categorical") {
      data[[var$name]] <- sample(
        var$levels,
        n,
        replace = TRUE,
        prob = var$proportions
      )
    } else if (var$type == "date") {
      days <- as.integer(var$range[[2]] - var$range[[1]])
      data[[paste0(var$name, "__offset")]] <- sample(0:days, n, replace = TRUE)
    } else if (var$type == "binary_formula") {
      linear_predictor <- eval(str2expression(var$formula), envir = data, enclos = parent.frame())
      data[[var$name]] <- stats::rbinom(n, size = 1, prob = stats::plogis(linear_predictor))
    }
  }

  data
}

generate_correlated_simstudy <- function(sim_def, n, seed = NULL) {
  if (!simstudy_available) {
    stop("simstudy is not available; use generate_correlated_native().", call. = FALSE)
  }

  if (!is.null(seed)) {
    set.seed(seed)
  }

  group <- sim_def$correlation_groups[[1]]
  as.data.frame(simstudy::genCorData(
    n,
    mu = group$means,
    sigma = group$sds,
    rho = group$rho,
    corstr = group$corstr,
    cnames = group$names
  ))
}

generate_correlated_native <- function(sim_def, n, seed = NULL) {
  if (!is.null(seed)) {
    set.seed(seed)
  }

  group <- sim_def$correlation_groups[[1]]
  n_vars <- length(group$names)
  cor_matrix <- matrix(group$rho, nrow = n_vars, ncol = n_vars)
  diag(cor_matrix) <- 1
  z <- matrix(stats::rnorm(n * n_vars), nrow = n)
  values <- z %*% chol(cor_matrix)
  values <- sweep(values, 2, group$sds, `*`)
  values <- sweep(values, 2, group$means, `+`)
  out <- as.data.frame(values)
  names(out) <- group$names
  out$id <- seq_len(n)
  out[c("id", group$names)]
}

inject_missing_codes <- function(values,
                                 missing_codes,
                                 missing_proportions,
                                 seed = NULL,
                                 return_assignment = FALSE) {
  assignment <- rep("valid", length(values))

  if (length(missing_codes) == 0 || sum(missing_proportions, na.rm = TRUE) <= 0) {
    if (return_assignment) {
      return(list(values = values, assignment = assignment))
    }
    return(values)
  }

  if (!is.null(seed)) {
    set.seed(seed)
  }

  missing_proportions[is.na(missing_proportions)] <- 0
  valid_prop <- max(0, 1 - sum(missing_proportions))
  assignment <- sample(
    c("valid", names(missing_proportions)),
    length(values),
    replace = TRUE,
    prob = c(valid_prop, missing_proportions)
  )

  values <- apply_missing_codes(values, assignment, as.list(missing_codes))

  if (return_assignment) {
    return(list(values = values, assignment = assignment))
  }

  values
}

coerce_mock_rtype <- function(values, rtype) {
  switch(
    rtype,
    integer = as.integer(round(as.numeric(values))),
    numeric = as.numeric(values),
    double = as.double(values),
    factor = factor(values),
    character = as.character(values),
    date = as.Date(values),
    values
  )
}

postprocess_mock_data <- function(data, spec, seed = NULL) {
  data <- as.data.frame(data)
  diagnostics <- list(missing_assignments = list())

  for (var in spec) {
    if (var$type == "date") {
      offset_name <- paste0(var$name, "__offset")
      data[[var$name]] <- var$range[[1]] + data[[offset_name]]
      data[[offset_name]] <- NULL
    }

    if (!var$name %in% names(data)) {
      next
    }

    missing_result <- inject_missing_codes(
      data[[var$name]],
      missing_codes = var$missing_codes,
      missing_proportions = var$missing_proportions,
      seed = seed,
      return_assignment = TRUE
    )
    data[[var$name]] <- missing_result$values
    diagnostics$missing_assignments[[var$name]] <- missing_result$assignment

    if (length(var$garbage) > 0) {
      var_row <- as.data.frame(var$garbage, stringsAsFactors = FALSE)
      data[[var$name]] <- apply_garbage(
        data[[var$name]],
        var_row = var_row,
        variable_type = var$rtype,
        missing_codes = unname(unlist(var$missing_codes, use.names = FALSE)),
        seed = seed
      )
    }

    data[[var$name]] <- coerce_mock_rtype(data[[var$name]], var$rtype)
  }

  attr(data, "mockdata_diagnostics") <- diagnostics
  data
}

example_recodeflow_metadata <- function() {
  variables <- data.frame(
    variable = c("age", "smoking", "interview_date"),
    variableType = c("continuous", "categorical", "date"),
    rType = c("integer", "integer", "date"),
    distribution = c("normal", NA, "uniform"),
    mean = c(50, NA, NA),
    sd = c(15, NA, NA),
    garbage_low_prop = c(0.02, NA, NA),
    garbage_low_range = c("[0,17]", NA, NA),
    garbage_high_prop = c(0.02, NA, NA),
    garbage_high_range = c("[101,115]", NA, NA),
    stringsAsFactors = FALSE
  )

  variable_details <- data.frame(
    variable = c(
      "age", "age", "age",
      "smoking", "smoking", "smoking", "smoking",
      "interview_date"
    ),
    databaseStart = "minimal-example",
    recStart = c(
      "[18,100]", "997", "998",
      "1", "2", "3", "7",
      "[2001-01-01;2005-12-31]"
    ),
    recEnd = c(
      "valid", "NA::b", "NA::b",
      "valid", "valid", "valid", "NA::b",
      "valid"
    ),
    proportion = c(
      NA, 0.02, 0.01,
      0.50, 0.30, 0.17, 0.03,
      NA
    ),
    catLabel = c(
      NA, "don't know", "refused",
      "never", "former", "current", "don't know",
      NA
    ),
    stringsAsFactors = FALSE
  )

  list(variables = variables, variable_details = variable_details)
}

run_correlated_height_weight <- function(n = 1000,
                                         seed = 123,
                                         backend = c("simstudy", "native")) {
  backend <- match.arg(backend)
  correlation_spec <- new_mock_spec(list(
    height_cm = mock_spec_correlated_continuous(
      "height_cm",
      mean = 170,
      sd = 10,
      correlation_group = "body_size"
    ),
    weight_kg = mock_spec_correlated_continuous(
      "weight_kg",
      mean = 78,
      sd = 16,
      correlation_group = "body_size"
    )
  ),
  provenance = list(adapter = "direct", source = "correlation prototype"),
  correlation_groups = list(body_size = list(rho = 0.65, corstr = "cs")))

  sim_def <- as_simstudy_def(correlation_spec)
  out <- if (backend == "simstudy") {
    generate_correlated_simstudy(sim_def, n = n, seed = seed)
  } else {
    generate_correlated_native(sim_def, n = n, seed = seed)
  }

  list(spec = correlation_spec, simstudy_def = sim_def, data = out)
}

run_survival_anchor <- function(n = 1000, seed = 123) {
  if (!simstudy_available) {
    stop("simstudy is not available; survival generation is an advanced backend test.", call. = FALSE)
  }

  set.seed(seed)
  base_def <- simstudy::defData(varname = "exposed", formula = 0.40, dist = "binary")
  surv_def <- simstudy::defSurv(
    varname = "event_time",
    formula = "0.3 * exposed",
    scale = 600,
    shape = 1
  )
  surv_def <- simstudy::defSurv(surv_def, varname = "censor_time", scale = 1500, shape = 1)

  data <- simstudy::genData(n, base_def)
  data <- simstudy::genSurv(
    data,
    surv_def,
    timeName = "followup_days",
    censorName = "censor_time",
    eventName = "event"
  )

  data <- as.data.frame(data)
  entry_start <- as.Date("2001-01-01")
  data$entry_date <- entry_start + sample(0:365, n, replace = TRUE)
  data$event_date <- as.Date(NA)
  data$censor_date <- as.Date(NA)
  event_idx <- which(data$event == 1)
  censor_idx <- which(data$event == 0)
  data$event_date[event_idx] <- data$entry_date[event_idx] + round(data$followup_days[event_idx])
  data$censor_date[censor_idx] <- data$entry_date[censor_idx] + round(data$followup_days[censor_idx])
  data
}

run_spike <- function(n = 1000, seed = 123, backend = c("simstudy", "native")) {
  backend <- match.arg(backend)

  metadata <- example_recodeflow_metadata()
  spec <- as_mock_spec_from_recodeflow(
    metadata$variables,
    metadata$variable_details,
    databaseStart = "minimal-example"
  )
  spec[["high_visits"]] <- mock_spec_binary_formula(
    "high_visits",
    "-4 + 0.04 * age + 0.8 * (smoking == 3)"
  )

  baseline <- if (backend == "simstudy") {
    generate_mock_data_simstudy(spec, n = n, seed = seed)
  } else {
    generate_mock_data_native(spec, n = n, seed = seed)
  }
  final <- postprocess_mock_data(baseline, spec, seed = seed + 1)
  correlated <- if (backend == "simstudy") run_correlated_height_weight(n, seed = seed) else NULL
  survival <- if (backend == "simstudy") run_survival_anchor(n, seed = seed) else NULL

  list(
    backend = backend,
    spec = spec,
    spec_table = spec_table(spec),
    simstudy_def = if (backend == "simstudy") as_simstudy_def(spec) else NULL,
    baseline = as.data.frame(baseline),
    final = final,
    correlated = correlated,
    survival = survival
  )
}

assert_spike <- function(result) {
  spec <- result$spec
  baseline <- result$baseline
  final <- result$final
  diagnostics <- attr(final, "mockdata_diagnostics")

  stopifnot(identical(attr(spec, "spec_version"), "0.4-spike-1"))
  stopifnot(identical(attr(spec, "model_hint"), "hybrid"))
  stopifnot(isTRUE(all.equal(as.numeric(spec$age$range), c(18, 100))))
  stopifnot(identical(spec$smoking$levels, c("1", "2", "3")))
  if (result$backend == "simstudy") {
    stopifnot(inherits(result$simstudy_def, "mock_simstudy_def"))
    stopifnot("data.table" %in% class(result$simstudy_def$data_def))
  }
  stopifnot(all(c("age", "smoking", "interview_date", "high_visits") %in% names(final)))
  stopifnot(all(baseline$age >= 18 & baseline$age <= 100))
  stopifnot(abs(mean(baseline$age) - 50) < 2)
  stopifnot(abs(stats::sd(baseline$age) - 15) < 3)
  stopifnot(is.integer(final$age))
  stopifnot(all(baseline$smoking %in% c(1, 2, 3)))
  smoking_props <- prop.table(table(baseline$smoking))
  stopifnot(abs(unname(smoking_props["1"]) - 0.50) < 0.07)
  stopifnot(abs(unname(smoking_props["2"]) - 0.30) < 0.07)
  stopifnot(abs(unname(smoking_props["3"]) - 0.20) < 0.07)
  stopifnot(all(final$high_visits %in% c(0, 1)))
  stopifnot(any(final$high_visits == 1))
  stopifnot(inherits(final$interview_date, "Date"))
  stopifnot(all(final$interview_date >= as.Date("2001-01-01")))
  stopifnot(all(final$interview_date <= as.Date("2005-12-31")))
  stopifnot(any(final$age %in% c(997L, 998L)))
  stopifnot(any(final$age < 18L | final$age > 100L))
  age_valid_assignment <- diagnostics$missing_assignments$age == "valid"
  age_garbage_rate <- mean(
    (final$age < 18L | final$age > 100L) & age_valid_assignment,
    na.rm = TRUE
  )
  stopifnot(age_garbage_rate > 0.02)
  stopifnot(age_garbage_rate < 0.06)
  stopifnot(any(final$smoking == 7L))
  stopifnot(any(diagnostics$missing_assignments$smoking == "7"))
  stopifnot(abs(mean(diagnostics$missing_assignments$smoking == "7") - 0.03) < 0.03)

  if (result$backend == "simstudy") {
    correlated <- result$correlated$data
    correlation_spec <- result$correlated$spec
    survival <- result$survival

    stopifnot(all(vapply(correlation_spec, `[[`, character(1), "correlation_group") == "body_size"))
    stopifnot(inherits(result$correlated$simstudy_def, "mock_simstudy_def"))
    stopifnot(abs(stats::cor(correlated$height_cm, correlated$weight_kg) - 0.65) < 0.08)
    stopifnot(abs(mean(correlated$height_cm) - 170) < 2)
    stopifnot(abs(mean(correlated$weight_kg) - 78) < 3)
    stopifnot(abs(stats::sd(correlated$height_cm) - 10) < 2)
    stopifnot(abs(stats::sd(correlated$weight_kg) - 16) < 3)
    stopifnot(all(survival$followup_days >= 0))
    stopifnot(any(survival$event == 1))
    stopifnot(all(is.na(survival$event_date) | survival$event_date >= survival$entry_date))
    stopifnot(all(is.na(survival$censor_date) | survival$censor_date >= survival$entry_date))
    stopifnot(!any(!is.na(survival$event_date) & !is.na(survival$censor_date)))
  }

  invisible(TRUE)
}

assert_native_fallback <- function(n = 1000, seed = 123) {
  native_result <- run_spike(n = n, seed = seed, backend = "native")
  final <- native_result$final

  stopifnot(is.null(native_result$simstudy_def))
  stopifnot(all(c("age", "smoking", "interview_date", "high_visits") %in% names(final)))
  stopifnot(is.integer(final$age))
  stopifnot(inherits(final$interview_date, "Date"))
  stopifnot(any(final$age %in% c(997L, 998L)))
  stopifnot(any(final$smoking == 7L))

  invisible(native_result)
}

assert_missing_collision_case <- function(seed = 123) {
  spec <- new_mock_spec(list(
    collision_code = mock_spec_categorical(
      name = "collision_code",
      levels = c("1", "2", "97", "99"),
      proportions = c(0.20, 0.20, 0.50, 0.10),
      rtype = "integer",
      missing_codes = c("97" = "97"),
      missing_proportions = c("97" = 0.10),
      provenance = "collision-test",
      model_hint = "diagnostic-required"
    )
  ))

  baseline <- generate_mock_data_native(spec, n = 1000, seed = seed)
  final <- postprocess_mock_data(baseline, spec, seed = seed + 1)
  assignment <- attr(final, "mockdata_diagnostics")$missing_assignments$collision_code

  stopifnot(any(baseline$collision_code == "97"))
  stopifnot(any(final$collision_code == 97L & assignment == "valid"))
  stopifnot(any(final$collision_code == 97L & assignment == "97"))

  invisible(final)
}

assert_non_numeric_categorical_labels <- function(seed = 123) {
  spec <- new_mock_spec(list(
    smoking_label = mock_spec_categorical(
      name = "smoking_label",
      levels = c("never", "former", "current"),
      proportions = c(0.50, 0.30, 0.20),
      rtype = "character",
      provenance = "label-test",
      model_hint = "simstudy-or-native"
    )
  ))

  native <- postprocess_mock_data(
    generate_mock_data_native(spec, n = 1000, seed = seed),
    spec,
    seed = seed + 1
  )
  stopifnot(all(native$smoking_label %in% c("never", "former", "current")))

  if (simstudy_available) {
    sim <- postprocess_mock_data(
      generate_mock_data_simstudy(spec, n = 1000, seed = seed),
      spec,
      seed = seed + 1
    )
    stopifnot(all(sim$smoking_label %in% c("never", "former", "current")))
  }

  invisible(TRUE)
}

assert_formula_dependency_validation <- function() {
  spec <- new_mock_spec(list(
    outcome = mock_spec_binary_formula("outcome", "-1 + missing_predictor")
  ))

  error <- tryCatch(
    {
      validate_formula_referents(spec)
      NULL
    },
    error = conditionMessage
  )
  stopifnot(grepl("missing_predictor", error))

  unordered <- new_mock_spec(list(
    outcome = mock_spec_binary_formula("outcome", "-4 + 0.04 * age"),
    age = mock_spec_continuous(
      "age",
      range = c(18, 100),
      distribution = "normal",
      mean = 50,
      sd = 15,
      rtype = "integer"
    )
  ))
  ordered <- order_spec_by_dependencies(unordered)
  stopifnot(identical(names(ordered), c("age", "outcome")))

  invisible(TRUE)
}

assert_truncated_normal_boundaries <- function() {
  error <- tryCatch(
    {
      mockdata_rtrunc_norm(10, min = 5, max = 5, mu = 5, s = 1)
      NULL
    },
    error = conditionMessage
  )
  stopifnot(grepl("min < max", error))

  invisible(TRUE)
}

assert_seed_reproducibility <- function() {
  first <- run_spike(seed = 123, backend = "native")$final
  second <- run_spike(seed = 123, backend = "native")$final
  stopifnot(identical(first, second))

  if (simstudy_available) {
    first_simstudy <- run_spike(seed = 123, backend = "simstudy")$final
    second_simstudy <- run_spike(seed = 123, backend = "simstudy")$final
    stopifnot(identical(first_simstudy, second_simstudy))
  }

  invisible(TRUE)
}

from_linkml <- function(...) {
  stop(
    "from_linkml() is a forward-compatibility placeholder for a future ",
    "third input adapter; it is not implemented in this spike.",
    call. = FALSE
  )
}

spike_result <- if (simstudy_available) {
  run_spike(backend = "simstudy")
} else {
  message("simstudy is not available; running native fallback assertions only.")
  run_spike(backend = "native")
}
assert_spike(spike_result)
native_result <- assert_native_fallback()
collision_result <- assert_missing_collision_case()
assert_non_numeric_categorical_labels()
assert_formula_dependency_validation()
assert_truncated_normal_boundaries()
assert_seed_reproducibility()

cat("MockData v0.4 simstudy spike passed.\n\n")
print(spike_result$spec_table)
cat("\nGenerated data preview:\n")
print(utils::head(spike_result$final))
if (simstudy_available) {
  cat("\nCorrelated height/weight correlation:\n")
  print(stats::cor(
    spike_result$correlated$data$height_cm,
    spike_result$correlated$data$weight_kg
  ))
  cat("\nSurvival preview:\n")
  print(utils::head(spike_result$survival[c("id", "exposed", "followup_days", "event", "entry_date", "event_date", "censor_date")]))
}
cat("\nNative fallback preview:\n")
print(utils::head(native_result$final))
cat("\nMissing-code collision preview:\n")
print(utils::head(collision_result))
