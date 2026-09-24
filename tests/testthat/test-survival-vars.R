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
