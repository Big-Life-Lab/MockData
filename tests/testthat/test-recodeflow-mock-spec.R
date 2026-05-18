minimal_example_path <- function(...) {
  file.path("..", "..", "inst", "extdata", "minimal-example", ...)
}

test_that("mock_spec_from_recodeflow converts minimal metadata", {
  variables <- read.csv(
    minimal_example_path("variables.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  variable_details <- read.csv(
    minimal_example_path("variable_details.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  spec <- mock_spec_from_recodeflow(variables, variable_details)

  expect_s3_class(spec, "mock_spec")
  expect_equal(spec$provenance$adapter, "recodeflow")
  expect_true(validate_mock_spec(spec)$valid)
  expect_false("BMI_derived" %in% names(spec$variables))
  expect_true(all(c("age", "smoking", "interview_date") %in% names(spec$variables)))

  expect_equal(spec$variables$age$type, "continuous")
  expect_equal(spec$variables$age$rtype, "integer")
  expect_equal(spec$variables$age$distribution, "normal")
  expect_equal(spec$variables$age$range, c(18, 100))
  expect_equal(spec$variables$age$missing_codes, c("997", "998", "999"))
  expect_length(spec$variables$age$garbage_rules, 0)

  expect_equal(spec$variables$smoking$type, "categorical")
  expect_equal(spec$variables$smoking$levels, c("1", "2", "3"))
  expect_equal(sum(spec$variables$smoking$proportions), 1)

  expect_equal(spec$variables$interview_date$type, "date")
  expect_s3_class(spec$variables$interview_date$range, "Date")
  expect_equal(spec$variables$interview_date$source_format, "analysis")
})

test_that("mock_spec_from_recodeflow filters exact role and databaseStart tokens", {
  variables <- data.frame(
    variable = c("age", "disabled_age", "cycle10_age"),
    variableType = "Continuous",
    rType = "integer",
    role = c("enabled", "disabled", "enabled"),
    databaseStart = c("cycle1, cycle2", "cycle1", "cycle10"),
    distribution = "uniform",
    stringsAsFactors = FALSE
  )
  details <- data.frame(
    variable = c("age", "disabled_age", "cycle10_age"),
    recStart = c("[18, 85]", "[18, 85]", "[18, 85]"),
    recEnd = "copy",
    databaseStart = c("cycle1", "cycle1", "cycle10"),
    proportion = 1,
    stringsAsFactors = FALSE
  )

  spec <- mock_spec_from_recodeflow(
    variables,
    details,
    databaseStart = "cycle1",
    role = "enabled"
  )

  expect_named(spec$variables, "age")
})

test_that("mock_spec_from_recodeflow preserves garbage and survival fields", {
  variables <- read.csv(
    minimal_example_path("variables.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  variable_details <- read.csv(
    minimal_example_path("variable_details.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  spec <- mock_spec_from_recodeflow(variables, variable_details)

  expect_equal(spec$variables$BMI$garbage_rules$low$proportion, 0.02)
  expect_equal(spec$variables$BMI$garbage_rules$low$range, "[-10;15])")
  expect_equal(spec$variables$BMI$garbage_rules$high$proportion, 0.01)

  expect_equal(spec$variables$primary_event_date$distribution, "gompertz")
  expect_equal(spec$variables$primary_event_date$event_prop, 0.3)
  expect_equal(spec$variables$primary_event_date$followup_max, 5475)
})

test_that("mock_spec_from_recodeflow validates adapter inputs", {
  variables <- data.frame(
    variable = "age",
    variableType = "Continuous",
    rType = "integer",
    role = "enabled",
    stringsAsFactors = FALSE
  )

  expect_error(
    mock_spec_from_recodeflow(variables, variable_details = NULL),
    "no valid recodeflow detail rows"
  )

  variables$role <- "disabled"
  expect_error(
    mock_spec_from_recodeflow(variables, data.frame(variable = "age", recStart = "[18, 85]")),
    "No variables matched"
  )
})
