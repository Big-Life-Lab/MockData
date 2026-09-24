# tests/testthat/test-survival-vars.R
# Metadata-driven survival dates (#40). ADR: development/adr/v05-survival-dates.md

survival_spec <- function(...) {
  mock_spec(
    mock_spec_date("entry", range = as.Date(c("2001-01-01", "2001-12-31"))),
    ...
  )
}

test_that("mock_spec_survival constructs a validated survival variable", {
  spec <- survival_spec(
    mock_spec_survival("death", anchor = "entry", followup_min = 365,
                       followup_max = 7300, event_prop = 0.2),
    mock_spec_survival("event", anchor = "entry", followup_min = 0,
                       followup_max = 5475, event_prop = 0.3,
                       distribution = "gompertz", shape = 0.1, rate = 1e-4,
                       censored_by = "death")
  )
  expect_true(validate_mock_spec(spec)$valid)
  event <- spec$variables$event
  expect_identical(event$type, "survival")
  expect_identical(event$rtype, "date")
  expect_identical(event$anchor, "entry")
  expect_identical(event$censored_by, "death")
  expect_identical(event$distribution, "gompertz")
  expect_equal(event$followup_max, 5475)
  expect_equal(event$event_prop, 0.3)
  expect_identical(event$depends_on, c("entry", "death"))
  expect_identical(spec$variables$death$depends_on, "entry")
  expect_null(spec$variables$death$censored_by)
})

test_that("an anchor that is not in the spec fails validation", {
  expect_error(
    mock_spec(mock_spec_survival("death", anchor = "entry", followup_min = 0,
                                 followup_max = 10, event_prop = 1)),
    "anchor 'entry', which is not a variable in the spec"
  )
})

test_that("an anchor must be a date variable", {
  expect_error(
    mock_spec(
      mock_spec_continuous("age", range = c(18, 80)),
      mock_spec_survival("death", anchor = "age", followup_min = 0,
                         followup_max = 10, event_prop = 1)
    ),
    "an anchor must be a date variable"
  )
})

test_that("a survival variable cannot anchor another (no chained anchors in v0.5)", {
  expect_error(
    survival_spec(
      mock_spec_survival("a", anchor = "entry", followup_min = 0,
                         followup_max = 10, event_prop = 1),
      mock_spec_survival("b", anchor = "a", followup_min = 0,
                         followup_max = 10, event_prop = 1)
    ),
    "of type 'survival'; an anchor must be a date variable"
  )
})

test_that("censored_by must name a survival variable with the same anchor", {
  expect_error(
    survival_spec(
      mock_spec_survival("event", anchor = "entry", followup_min = 0,
                         followup_max = 10, event_prop = 1, censored_by = "entry")
    ),
    "censored_by 'entry' must be a survival variable"
  )
  expect_error(
    mock_spec(
      mock_spec_date("entry", range = as.Date(c("2001-01-01", "2001-12-31"))),
      mock_spec_date("entry2", range = as.Date(c("2001-01-01", "2001-12-31"))),
      mock_spec_survival("death", anchor = "entry2", followup_min = 0,
                         followup_max = 10, event_prop = 1),
      mock_spec_survival("event", anchor = "entry", followup_min = 0,
                         followup_max = 10, event_prop = 1, censored_by = "death")
    ),
    "must share its anchor"
  )
  expect_error(
    survival_spec(
      mock_spec_survival("event", anchor = "entry", followup_min = 0,
                         followup_max = 10, event_prop = 1, censored_by = "nope")
    ),
    "censored_by 'nope', which is not a variable in the spec"
  )
  expect_error(
    survival_spec(
      mock_spec_survival("event", anchor = "entry", followup_min = 0,
                         followup_max = 10, event_prop = 1, censored_by = "event")
    ),
    "cannot be censored by itself"
  )
})

test_that("chained censored_by is rejected with a message naming the fix (ADR D7)", {
  # A (day 30) censored by B (day 20) censored by C (day 10): sequential rules
  # would report A as observed although observation ended on day 10.
  expect_error(
    survival_spec(
      mock_spec_survival("a", anchor = "entry", followup_min = 30,
                         followup_max = 30, event_prop = 1, censored_by = "b"),
      mock_spec_survival("b", anchor = "entry", followup_min = 20,
                         followup_max = 20, event_prop = 1, censored_by = "c"),
      mock_spec_survival("c", anchor = "entry", followup_min = 10,
                         followup_max = 10, event_prop = 1)
    ),
    "which is itself censored by 'c'. Chained censoring is not supported"
  )
})

test_that("mutual censored_by is reported as a dependency cycle", {
  expect_error(
    survival_spec(
      mock_spec_survival("a", anchor = "entry", followup_min = 0,
                         followup_max = 10, event_prop = 1, censored_by = "b"),
      mock_spec_survival("b", anchor = "entry", followup_min = 0,
                         followup_max = 10, event_prop = 1, censored_by = "a")
    ),
    "Survival dependency cycle or unresolved ordering among: a, b"
  )
})

test_that("survival parameters are validated with messages that name the fix", {
  bad <- function(...) {
    args <- utils::modifyList(
      list(name = "event", anchor = "entry", followup_min = 0,
           followup_max = 10, event_prop = 0.5),
      list(...)
    )
    survival_spec(do.call(mock_spec_survival, args))
  }
  expect_error(bad(anchor = ""), "requires an anchor")
  expect_error(bad(followup_min = NA_real_),
               "requires finite numeric followup_min and followup_max")
  expect_error(bad(followup_min = -1), "followup_min must be >= 0")
  expect_error(bad(followup_min = 20, followup_max = 10),
               "followup_min must be <= followup_max")
  expect_error(bad(event_prop = 1.5), "event_prop must be a number in \\[0, 1\\]")
  expect_error(bad(distribution = "weibull"),
               "distribution must be one of: uniform, exponential, gompertz")
  expect_error(bad(shape = -1), "shape must be a positive number when supplied")
  expect_error(bad(rate = 0), "rate must be a positive number when supplied")
  expect_error(bad(source_format = "csv"), "supports sourceFormat 'analysis' only")
})

test_that("survival ordering places a censored_by target before the variable it censors", {
  spec <- survival_spec(
    mock_spec_survival("event", anchor = "entry", followup_min = 0,
                       followup_max = 10, event_prop = 1, censored_by = "death"),
    mock_spec_survival("death", anchor = "entry", followup_min = 0,
                       followup_max = 10, event_prop = 1),
    mock_spec_survival("ltfu", anchor = "entry", followup_min = 0,
                       followup_max = 10, event_prop = 1)
  )
  # Repeated passes in spec order: pass 1 places death and ltfu, pass 2 event.
  expect_identical(MockData:::.order_survival_variables(spec),
                   c("death", "ltfu", "event"))
})

test_that("formula ordering is unchanged by the shared ordering helper", {
  spec <- mock_spec(
    mock_spec_formula("c", formula = "b + 1"),
    mock_spec_formula("b", formula = "a * 2"),
    mock_spec_continuous("a", range = c(0, 1))
  )
  expect_identical(MockData:::.order_formula_variables(spec), c("b", "c"))
})

run_stage <- function(spec, n = 200, seed = 1) {
  baseline <- generate_mock_data_native(spec, n = n, seed = seed)
  generate_survival_dates(baseline, spec, seed = seed)
}

days_after <- function(data, column, anchor = "entry") {
  as.numeric(data[[column]] - data[[anchor]])
}

test_that("both backends skip survival variables in baseline generation", {
  spec <- survival_spec(
    mock_spec_survival("death", anchor = "entry", followup_min = 0,
                       followup_max = 10, event_prop = 1)
  )
  expect_identical(names(generate_mock_data_native(spec, n = 5, seed = 1)), "entry")
  skip_if_not_installed("simstudy")
  expect_identical(names(generate_mock_data_simstudy(spec, n = 5, seed = 1)), "entry")
})

test_that("the survival stage runs on a simstudy baseline too", {
  skip_if_not_installed("simstudy")
  spec <- survival_spec(
    mock_spec_categorical("smoking", levels = c("never", "former", "current")),
    mock_spec_survival("death", anchor = "entry", followup_min = 0,
                       followup_max = 100, event_prop = 0.5)
  )
  baseline <- generate_mock_data_simstudy(spec, n = 100, seed = 1)
  result <- generate_survival_dates(baseline, spec, seed = 1)
  expect_identical(sum(!is.na(result$death)), 50L)
  expect_true(all(result$death >= result$entry, na.rm = TRUE))
})

test_that("the survival stage reproduces the legacy competing-risk rule", {
  later <- run_stage(survival_spec(
    mock_spec_survival("event", anchor = "entry", followup_min = 1000,
                       followup_max = 2000, event_prop = 1, censored_by = "death"),
    mock_spec_survival("death", anchor = "entry", followup_min = 0,
                       followup_max = 500, event_prop = 1)
  ))
  expect_true(all(is.na(later$event)))
  expect_false(any(is.na(later$death)))

  earlier <- run_stage(survival_spec(
    mock_spec_survival("event", anchor = "entry", followup_min = 0,
                       followup_max = 500, event_prop = 1, censored_by = "death"),
    mock_spec_survival("death", anchor = "entry", followup_min = 1000,
                       followup_max = 2000, event_prop = 1)
  ))
  expect_false(any(is.na(earlier$event)))
})

test_that("censored_by sets NA exactly where the censoring date is earlier", {
  result <- run_stage(survival_spec(
    mock_spec_survival("event", anchor = "entry", followup_min = 0,
                       followup_max = 1000, event_prop = 1, censored_by = "death"),
    mock_spec_survival("death", anchor = "entry", followup_min = 0,
                       followup_max = 1000, event_prop = 0.5)
  ), n = 400)
  both <- !is.na(result$event) & !is.na(result$death)
  expect_false(any(result$death[both] < result$event[both]))
  # event_prop = 1, so the only way an event is NA is censoring by an
  # earlier death.
  expect_true(all(!is.na(result$death[is.na(result$event)])))
  expect_gt(sum(is.na(result$event)), 0)
  expect_gt(sum(both), 0)
})

test_that("exactly floor(n * event_prop) rows receive an event", {
  result <- run_stage(survival_spec(
    mock_spec_survival("event", anchor = "entry", followup_min = 100,
                       followup_max = 200, event_prop = 0.3)
  ), n = 200)
  expect_identical(sum(!is.na(result$event)), 60L)
})

test_that("follow-up days are whole days inside the window for every distribution", {
  for (distribution in c("uniform", "exponential", "gompertz")) {
    result <- run_stage(survival_spec(
      mock_spec_survival("event", anchor = "entry", followup_min = 10,
                         followup_max = 400, event_prop = 1,
                         distribution = distribution)
    ))
    days <- days_after(result, "event")
    expect_false(anyNA(days), info = distribution)
    expect_true(all(days == floor(days)), info = distribution)
    expect_true(all(days >= 10 & days <= 400), info = distribution)
  }
})

test_that("gompertz with the packaged parameters reproduces the legacy clamp (#54)", {
  # Pins behaviour filed as #54; update deliberately when #54 is resolved.
  result <- run_stage(survival_spec(
    mock_spec_survival("death", anchor = "entry", followup_min = 365,
                       followup_max = 7300, event_prop = 1,
                       distribution = "gompertz", shape = 0.1, rate = 1e-4)
  ))
  expect_true(all(days_after(result, "death") == 365))
})

test_that("n = 0 returns a typed zero-row survival column", {
  result <- run_stage(survival_spec(
    mock_spec_survival("event", anchor = "entry", followup_min = 0,
                       followup_max = 10, event_prop = 0.5)
  ), n = 0)
  expect_identical(nrow(result), 0L)
  expect_s3_class(result$event, "Date")
})

test_that("zero events from flooring is an all-NA column, not an error", {
  spec <- survival_spec(
    mock_spec_survival("event", anchor = "entry", followup_min = 0,
                       followup_max = 10, event_prop = 0.2)
  )
  expect_no_warning(result <- run_stage(spec, n = 3))
  expect_true(all(is.na(result$event)))
  expect_s3_class(result$event, "Date")
  diag <- attr(postprocess_mock_data(result, spec, seed = 1), "mockdata_diagnostics")
  expect_identical(diag$variables$event$n_events, 0L)
})

test_that("NA anchors give NA survival dates in those rows only", {
  spec <- survival_spec(
    mock_spec_survival("event", anchor = "entry", followup_min = 1,
                       followup_max = 2, event_prop = 1)
  )
  data <- data.frame(entry = as.Date("2001-01-01") + 0:9)
  data$entry[1:3] <- as.Date(NA)
  result <- generate_survival_dates(data, spec, seed = 1)
  expect_true(all(is.na(result$event[1:3])))
  expect_false(anyNA(result$event[4:10]))
})

test_that("generate_survival_dates rejects a non-Date anchor column", {
  spec <- survival_spec(
    mock_spec_survival("event", anchor = "entry", followup_min = 0,
                       followup_max = 10, event_prop = 1)
  )
  data <- data.frame(entry = c("2001-01-01", "2001-06-01"), stringsAsFactors = FALSE)
  expect_error(
    generate_survival_dates(data, spec, seed = 1),
    "Anchor column 'entry' must be of class Date; got character"
  )
})

test_that("generate_survival_dates fails loudly when an anchor column is missing", {
  spec <- survival_spec(
    mock_spec_survival("event", anchor = "entry", followup_min = 0,
                       followup_max = 10, event_prop = 1)
  )
  expect_error(
    generate_survival_dates(data.frame(other = 1:2), spec, seed = 1),
    "missing anchor column\\(s\\) required by survival variables: entry"
  )
})

test_that("generate_survival_dates is a no-op without survival variables", {
  spec <- mock_spec(mock_spec_continuous("x", range = c(0, 1)))
  data <- generate_mock_data_native(spec, n = 5, seed = 1)
  expect_identical(generate_survival_dates(data, spec, seed = 1), data)
})

test_that("skipping the survival stage makes postprocess fail on the missing column", {
  spec <- survival_spec(
    mock_spec_survival("event", anchor = "entry", followup_min = 0,
                       followup_max = 10, event_prop = 1)
  )
  baseline <- generate_mock_data_native(spec, n = 5, seed = 1)
  expect_error(
    postprocess_mock_data(baseline, spec, seed = 1),
    "missing column\\(s\\) required by spec: event"
  )
})

test_that("the survival stage leaves the caller's RNG untouched and is reproducible", {
  spec <- survival_spec(
    mock_spec_survival("event", anchor = "entry", followup_min = 0,
                       followup_max = 100, event_prop = 0.5)
  )
  baseline <- generate_mock_data_native(spec, n = 50, seed = 3)
  set.seed(99)
  before <- .Random.seed
  a <- generate_survival_dates(baseline, spec, seed = 3)
  expect_identical(.Random.seed, before)
  expect_identical(a, generate_survival_dates(baseline, spec, seed = 3))
})

test_that("postprocess marks survival variables as derived with anchor, dependencies and event count", {
  spec <- survival_spec(
    mock_spec_survival("event", anchor = "entry", followup_min = 0,
                       followup_max = 10, event_prop = 0.5, censored_by = "death"),
    mock_spec_survival("death", anchor = "entry", followup_min = 100,
                       followup_max = 200, event_prop = 0.5)
  )
  staged <- run_stage(spec, n = 100)
  diag <- attr(postprocess_mock_data(staged, spec, seed = 1), "mockdata_diagnostics")$variables
  expect_true(isTRUE(diag$event$derived))
  expect_identical(diag$event$anchor, "entry")
  expect_identical(diag$event$censored_by, "death")
  expect_identical(diag$event$depends_on, c("entry", "death"))
  expect_identical(diag$event$n_events, sum(!is.na(staged$event)))
  expect_null(diag$death$censored_by)
  expect_null(diag$entry$derived)
})

test_that("garbage applied after the rules keeps before-entry violations (D5)", {
  spec <- survival_spec(
    mock_spec_survival("event", anchor = "entry", followup_min = 10,
                       followup_max = 100, event_prop = 1,
                       garbage_rules = list(low = list(
                         proportion = 0.2, range = "[1990-01-01;1990-12-31]"
                       )))
  )
  out <- postprocess_mock_data(run_stage(spec, n = 200), spec, seed = 1)
  before_entry <- which(out$event < out$entry)
  garbage_rows <- attr(out, "mockdata_diagnostics")$variables$event$assigned_garbage_indices$low
  expect_gt(length(before_entry), 0)
  expect_setequal(before_entry, garbage_rows)
})

test_that("the rules use true dates: a censoring death later replaced by garbage still censored (D5)", {
  spec <- survival_spec(
    mock_spec_survival("event", anchor = "entry", followup_min = 1000,
                       followup_max = 2000, event_prop = 1, censored_by = "death"),
    mock_spec_survival("death", anchor = "entry", followup_min = 0,
                       followup_max = 500, event_prop = 1,
                       garbage_rules = list(high = list(
                         proportion = 0.5, range = "[2090-01-01;2090-12-31]"
                       )))
  )
  out <- postprocess_mock_data(run_stage(spec, n = 200), spec, seed = 1)
  # Every death preceded its event before post-processing, so every event is
  # NA; about half the deaths now show a 2090 garbage date.
  expect_true(all(is.na(out$event)))
  expect_true(any(out$death >= as.Date("2090-01-01")))
})
