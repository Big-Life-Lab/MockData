test_that("mock_spec creates an empty specification", {
  spec <- mock_spec()

  expect_s3_class(spec, "mock_spec")
  expect_true(is_mock_spec(spec))
  expect_equal(spec$spec_version, "0.4.0")
  expect_equal(length(spec$variables), 0)
  expect_true(validate_mock_spec(spec)$valid)
})

test_that("mock_spec accepts NULL as an empty specification", {
  spec <- mock_spec(NULL)

  expect_s3_class(spec, "mock_spec")
  expect_equal(length(spec$variables), 0)
  expect_true(validate_mock_spec(spec, n = 0)$valid)
})

test_that("mock_spec supports single continuous variable specs", {
  age <- mock_spec_continuous(
    name = "age",
    range = c(18, 85),
    distribution = "normal",
    mean = 50,
    sd = 12,
    rtype = "integer",
    missing_codes = c(997, 998),
    missing_proportions = c(0.02, 0.01)
  )
  spec <- mock_spec(age)

  expect_s3_class(age, "mock_spec_variable")
  expect_named(spec$variables, "age")
  expect_equal(spec$variables$age$type, "continuous")
  expect_equal(spec$variables$age$range, c(18, 85))
  expect_equal(spec$variables$age$provenance$adapter, "direct")
  expect_true(validate_mock_spec(spec, n = 1)$valid)
})

test_that("mock_spec supports categorical variable specs", {
  smoking <- mock_spec_categorical(
    name = "smoking",
    levels = c("never", "former", "current"),
    proportions = c(0.5, 0.3, 0.2),
    rtype = "character"
  )
  spec <- mock_spec(list(smoking))

  expect_named(spec$variables, "smoking")
  expect_equal(spec$variables$smoking$type, "categorical")
  expect_equal(spec$variables$smoking$levels, c("never", "former", "current"))
  expect_equal(spec$variables$smoking$proportions, c(0.5, 0.3, 0.2))
  expect_true(validate_mock_spec(spec)$valid)
})

test_that("mock_spec supports date variable specs", {
  interview_date <- mock_spec_date(
    name = "interview_date",
    range = as.Date(c("2001-01-01", "2005-12-31")),
    source_format = "analysis"
  )
  spec <- mock_spec(interview_date)

  expect_named(spec$variables, "interview_date")
  expect_equal(spec$variables$interview_date$type, "date")
  expect_s3_class(spec$variables$interview_date$range, "Date")
  expect_equal(spec$variables$interview_date$model_hint, "native-postprocess")
  expect_true(validate_mock_spec(spec, n = 0)$valid)
})

test_that("mock_spec validates n as a non-negative whole number", {
  spec <- mock_spec()

  expect_true(validate_mock_spec(spec, n = 0)$valid)
  expect_error(validate_mock_spec(spec, n = -1), "non-negative whole number")
  expect_error(validate_mock_spec(spec, n = 1.5), "non-negative whole number")
  expect_error(validate_mock_spec(spec, n = NA_real_), "non-negative whole number")
})

test_that("validate_mock_spec returns structured errors when strict is FALSE", {
  spec <- mock_spec(mock_spec_categorical(
    name = "smoking",
    levels = c("never", "former", "current"),
    proportions = c(0.5, 0.3)
  ), validate = FALSE)

  result <- validate_mock_spec(spec, strict = FALSE)

  expect_false(result$valid)
  expect_true(any(grepl("one proportion per level", result$errors)))
})

test_that("validate_mock_spec catches malformed continuous and date ranges", {
  bad_continuous <- mock_spec(mock_spec_continuous(
    name = "age",
    range = c(85, 18)
  ), validate = FALSE)
  expect_error(validate_mock_spec(bad_continuous), "lower bound")

  bad_date <- mock_spec(mock_spec_date(
    name = "interview_date",
    range = c("2001-01-01", "2005-12-31")
  ), validate = FALSE)
  expect_error(validate_mock_spec(bad_date), "range must be Date")
})

test_that("validate_mock_spec catches normal distribution parameter errors", {
  bad_normal <- mock_spec(mock_spec_continuous(
    name = "age",
    range = c(18, 85),
    distribution = "normal",
    mean = 50,
    sd = 0
  ), validate = FALSE)

  expect_error(validate_mock_spec(bad_normal), "sd > 0")
})

test_that("mock_spec rejects duplicate variable names", {
  spec <- mock_spec(
    mock_spec_continuous("age", range = c(18, 85)),
    mock_spec_continuous("age", range = c(0, 100)),
    validate = FALSE
  )

  result <- validate_mock_spec(spec, strict = FALSE)

  expect_false(result$valid)
  expect_true(any(grepl("unique", result$errors)))
})

test_that("mock_spec validates model hints", {
  expect_error(
    mock_spec_continuous("age", range = c(18, 85), model_hint = "magic"),
    "model_hint"
  )
})

test_that("validate_mock_spec rejects non-spec objects", {
  result <- validate_mock_spec(list(), strict = FALSE)

  expect_false(result$valid)
  expect_true(any(grepl("mock_spec", result$errors)))
})

test_that("mock_spec validates on construction by default", {
  expect_error(
    mock_spec(mock_spec_categorical(
      name = "smoking",
      levels = c("never", "former", "current"),
      proportions = c(0.5, 0.3)
    )),
    "one proportion per level"
  )
})

test_that("validate_mock_spec accumulates multiple errors", {
  spec <- mock_spec(
    mock_spec_categorical(
      name = "smoking",
      levels = character(0),
      proportions = c(0.5, 0.5)
    ),
    validate = FALSE
  )

  result <- validate_mock_spec(spec, strict = FALSE)

  expect_false(result$valid)
  expect_true(length(result$errors) >= 2)
  expect_true(any(grepl("at least one level", result$errors)))
  expect_true(any(grepl("one proportion per level", result$errors)))
})

test_that("is_mock_spec returns FALSE for non-spec objects", {
  expect_false(is_mock_spec(list()))
  expect_false(is_mock_spec(NULL))
  expect_false(is_mock_spec(data.frame()))
})

test_that("mock_spec preserves spec_version and rejects missing spec_version", {
  spec <- mock_spec(spec_version = "0.4.0-test")

  expect_equal(spec$spec_version, "0.4.0-test")

  spec$spec_version <- NA_character_
  result <- validate_mock_spec(spec, strict = FALSE)

  expect_false(result$valid)
  expect_true(any(grepl("spec_version", result$errors)))

  spec$spec_version <- ""
  result <- validate_mock_spec(spec, strict = FALSE)

  expect_false(result$valid)
  expect_true(any(grepl("spec_version", result$errors)))
})

test_that("validate_mock_spec checks provenance and model_hint after mutation", {
  spec <- mock_spec(mock_spec_continuous("age", range = c(18, 85)))

  spec$provenance <- "not-a-list"
  result <- validate_mock_spec(spec, strict = FALSE)
  expect_false(result$valid)
  expect_true(any(grepl("provenance must be a list", result$errors)))

  spec <- mock_spec(mock_spec_continuous("age", range = c(18, 85)))
  spec$provenance$adapter <- ""
  result <- validate_mock_spec(spec, strict = FALSE)
  expect_false(result$valid)
  expect_true(any(grepl("provenance\\$adapter", result$errors)))

  spec <- mock_spec(mock_spec_continuous("age", range = c(18, 85)))
  spec$provenance$source <- NA_character_
  result <- validate_mock_spec(spec, strict = FALSE)
  expect_false(result$valid)
  expect_true(any(grepl("provenance\\$source", result$errors)))

  spec <- mock_spec(mock_spec_continuous("age", range = c(18, 85)))
  spec$model_hint <- "magic"
  result <- validate_mock_spec(spec, strict = FALSE)
  expect_false(result$valid)
  expect_true(any(grepl("mock_spec model_hint", result$errors)))

  spec <- mock_spec(mock_spec_continuous("age", range = c(18, 85)))
  spec$variables$age$provenance$adapter <- ""
  spec$variables$age$model_hint <- "magic"
  result <- validate_mock_spec(spec, strict = FALSE)
  expect_false(result$valid)
  expect_true(any(grepl("Variable 'age' provenance\\$adapter", result$errors)))
  expect_true(any(grepl("Variable 'age' model_hint", result$errors)))
})

test_that("proportion sums use floating-point tolerance consistently", {
  spec <- mock_spec(mock_spec_categorical(
    "smoking",
    levels = c("never", "former"),
    proportions = c(0.5, 0.5 + 1e-15),
    missing_codes = c("7", "9"),
    missing_proportions = c(0.5, 0.5 + 1e-15)
  ))

  expect_true(validate_mock_spec(spec)$valid)
})

test_that("print.mock_spec_validation_result summarizes errors", {
  result <- validate_mock_spec(list(), strict = FALSE)

  expect_output(print(result), "invalid")
  expect_output(print(result), "Errors")
  expect_output(print(result), "spec must be a mock_spec object")
})
