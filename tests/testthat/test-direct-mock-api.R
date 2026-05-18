test_that("mock_continuous creates a validated one-variable spec", {
  spec <- mock_continuous(
    "age",
    range = c(18, 85),
    distribution = "normal",
    mean = 50,
    sd = 12,
    rtype = "integer",
    missing_codes = c(997, 998),
    missing_proportions = c(0.02, 0.01)
  )

  expect_s3_class(spec, "mock_spec")
  expect_named(spec$variables, "age")
  expect_equal(spec$variables$age$type, "continuous")
  expect_equal(spec$variables$age$rtype, "integer")
  expect_equal(spec$provenance$adapter, "direct")
  expect_equal(spec$provenance$source, "mock_continuous")
  expect_true(validate_mock_spec(spec)$valid)
})

test_that("mock_categorical creates a validated one-variable spec", {
  spec <- mock_categorical(
    "smoking",
    levels = c("never", "former", "current"),
    proportions = c(0.5, 0.3, 0.2),
    rtype = "character"
  )

  expect_s3_class(spec, "mock_spec")
  expect_named(spec$variables, "smoking")
  expect_equal(spec$variables$smoking$type, "categorical")
  expect_equal(spec$variables$smoking$levels, c("never", "former", "current"))
  expect_equal(spec$variables$smoking$proportions, c(0.5, 0.3, 0.2))
  expect_equal(spec$provenance$source, "mock_categorical")
  expect_true(validate_mock_spec(spec)$valid)
})

test_that("mock_date creates a validated one-variable spec", {
  spec <- mock_date(
    "interview_date",
    range = as.Date(c("2001-01-01", "2005-12-31"))
  )

  expect_s3_class(spec, "mock_spec")
  expect_named(spec$variables, "interview_date")
  expect_equal(spec$variables$interview_date$type, "date")
  expect_s3_class(spec$variables$interview_date$range, "Date")
  expect_equal(spec$model_hint, "native-postprocess")
  expect_equal(spec$provenance$source, "mock_date")
  expect_true(validate_mock_spec(spec)$valid)
})

test_that("direct mock APIs validate immediately", {
  expect_error(
    mock_continuous(
      "age",
      range = c(18, 85),
      distribution = "normal",
      mean = 50
    ),
    "sd > 0"
  )

  expect_error(
    mock_categorical(
      "smoking",
      levels = c("never", "former", "current"),
      proportions = c(0.5, 0.3)
    ),
    "one proportion per level"
  )

  expect_error(
    mock_date(
      "interview_date",
      range = c("2001-01-01", "2005-12-31")
    ),
    "range must be Date"
  )
})
