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

if (!requireNamespace("simstudy", quietly = TRUE)) {
  stop(
    "simstudy is required for this spike. Install it into a temporary library:\n",
    "lib <- '/private/tmp/mockdata-simstudy-lib'\n",
    "dir.create(lib, recursive = TRUE, showWarnings = FALSE)\n",
    "install.packages('simstudy', lib = lib, repos = 'https://cloud.r-project.org')",
    call. = FALSE
  )
}

source("R/mockdata-parsers.R", local = TRUE)
source("R/mockdata_helpers.R", local = TRUE)

mockdata_rtrunc_norm <- function(n, min, max, mu, s) {
  f_min <- stats::pnorm(min, mean = mu, sd = s)
  f_max <- stats::pnorm(max, mean = mu, sd = s)
  stats::qnorm(stats::runif(n, min = f_min, max = f_max), mean = mu, sd = s)
}

new_mock_spec <- function(vars) {
  structure(vars, class = "mock_spec")
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
                                 source = "direct") {
  list(
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
    source = source
  )
}

mock_spec_categorical <- function(name,
                                  levels,
                                  proportions = NULL,
                                  rtype = "factor",
                                  missing_codes = character(0),
                                  missing_proportions = numeric(0),
                                  garbage = list(),
                                  source = "direct") {
  if (is.null(proportions)) {
    proportions <- rep(1 / length(levels), length(levels))
  }

  list(
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
  )
}

mock_spec_date <- function(name,
                           range,
                           rtype = "date",
                           source_format = "analysis",
                           source = "direct") {
  list(
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
  )
}

mock_spec_binary_formula <- function(name, formula, rtype = "integer") {
  list(
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
  )
}

spec_table <- function(spec) {
  data.frame(
    name = vapply(spec, `[[`, character(1), "name"),
    type = vapply(spec, `[[`, character(1), "type"),
    rtype = vapply(spec, `[[`, character(1), "rtype"),
    distribution = vapply(spec, `[[`, character(1), "distribution"),
    source = vapply(spec, `[[`, character(1), "source"),
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

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

simstudy_formula <- function(x) {
  paste(x, collapse = ";")
}

as_simstudy_def <- function(spec) {
  def <- NULL

  for (var in spec) {
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

  def
}

generate_mock_data_simstudy <- function(spec, n, seed = NULL) {
  if (!is.null(seed)) {
    set.seed(seed)
  }

  simstudy::genData(n, as_simstudy_def(spec))
}

inject_missing_codes <- function(values, missing_codes, missing_proportions, seed = NULL) {
  if (length(missing_codes) == 0 || sum(missing_proportions, na.rm = TRUE) <= 0) {
    return(values)
  }

  if (!is.null(seed)) {
    set.seed(seed)
  }

  missing_proportions[is.na(missing_proportions)] <- 0
  valid_prop <- max(0, 1 - sum(missing_proportions))
  assignments <- sample(
    c("valid", names(missing_proportions)),
    length(values),
    replace = TRUE,
    prob = c(valid_prop, missing_proportions)
  )

  apply_missing_codes(values, assignments, as.list(missing_codes))
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

  for (var in spec) {
    if (var$type == "date") {
      offset_name <- paste0(var$name, "__offset")
      data[[var$name]] <- var$range[[1]] + data[[offset_name]]
      data[[offset_name]] <- NULL
    }

    if (!var$name %in% names(data)) {
      next
    }

    data[[var$name]] <- inject_missing_codes(
      data[[var$name]],
      missing_codes = var$missing_codes,
      missing_proportions = var$missing_proportions,
      seed = seed
    )

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

run_correlated_height_weight <- function(n = 1000, seed = 123) {
  set.seed(seed)
  out <- simstudy::genCorData(
    n,
    mu = c(170, 78),
    sigma = c(10, 16),
    rho = 0.65,
    corstr = "cs",
    cnames = c("height_cm", "weight_kg")
  )

  as.data.frame(out)
}

run_survival_anchor <- function(n = 1000, seed = 123) {
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
  event_idx <- which(data$event == 1)
  data$event_date[event_idx] <- data$entry_date[event_idx] + round(data$followup_days[event_idx])
  data$censor_date <- data$entry_date + round(data$followup_days)
  data
}

run_spike <- function(n = 1000, seed = 123) {
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

  baseline <- generate_mock_data_simstudy(spec, n = n, seed = seed)
  final <- postprocess_mock_data(baseline, spec, seed = seed + 1)
  correlated <- run_correlated_height_weight(n, seed = seed)
  survival <- run_survival_anchor(n, seed = seed)

  list(
    spec = spec,
    spec_table = spec_table(spec),
    simstudy_def = as_simstudy_def(spec),
    baseline = as.data.frame(baseline),
    final = final,
    correlated = correlated,
    survival = survival
  )
}

assert_spike <- function(result) {
  baseline <- result$baseline
  final <- result$final
  correlated <- result$correlated
  survival <- result$survival

  stopifnot(all(c("age", "smoking", "interview_date", "high_visits") %in% names(final)))
  stopifnot(all(baseline$age >= 18 & baseline$age <= 100))
  stopifnot(is.integer(final$age))
  stopifnot(all(baseline$smoking %in% c(1, 2, 3)))
  stopifnot(all(final$high_visits %in% c(0, 1)))
  stopifnot(any(final$high_visits == 1))
  stopifnot(inherits(final$interview_date, "Date"))
  stopifnot(all(final$interview_date >= as.Date("2001-01-01")))
  stopifnot(all(final$interview_date <= as.Date("2005-12-31")))
  stopifnot(any(final$age %in% c(997L, 998L)))
  stopifnot(any(final$age < 18L | final$age > 100L))
  stopifnot(any(final$smoking == 7L))
  stopifnot(stats::cor(correlated$height_cm, correlated$weight_kg) > 0.50)
  stopifnot(all(survival$followup_days >= 0))
  stopifnot(any(survival$event == 1))
  stopifnot(all(is.na(survival$event_date) | survival$event_date >= survival$entry_date))

  invisible(TRUE)
}

spike_result <- run_spike()
assert_spike(spike_result)

cat("MockData v0.4 simstudy spike passed.\n\n")
print(spike_result$spec_table)
cat("\nGenerated data preview:\n")
print(utils::head(spike_result$final))
cat("\nCorrelated height/weight correlation:\n")
print(stats::cor(spike_result$correlated$height_cm, spike_result$correlated$weight_kg))
cat("\nSurvival preview:\n")
print(utils::head(spike_result$survival[c("id", "exposed", "followup_days", "event", "entry_date", "event_date", "censor_date")]))
