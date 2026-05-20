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
  expect_equal(spec$variables$age$provenance$adapter, "direct")
  expect_equal(spec$variables$age$provenance$source, "mock_continuous")
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
  expect_equal(spec$provenance$adapter, "direct")
  expect_equal(spec$provenance$source, "mock_categorical")
  expect_equal(spec$variables$smoking$provenance$adapter, "direct")
  expect_equal(spec$variables$smoking$provenance$source, "mock_categorical")
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
  expect_equal(spec$variables$interview_date$model_hint, "native-postprocess")
  expect_equal(spec$provenance$adapter, "direct")
  expect_equal(spec$provenance$source, "mock_date")
  expect_equal(spec$variables$interview_date$provenance$adapter, "direct")
  expect_equal(spec$variables$interview_date$provenance$source, "mock_date")
  expect_true(validate_mock_spec(spec)$valid)
})

test_that("direct mock APIs are equivalent to explicit mock_spec wrappers", {
  continuous_provenance <- list(adapter = "direct", source = "mock_continuous")
  expect_equal(
    mock_continuous("age", range = c(18, 85), rtype = "integer"),
    mock_spec(
      mock_spec_continuous(
        "age",
        range = c(18, 85),
        rtype = "integer",
        provenance = continuous_provenance
      ),
      provenance = continuous_provenance
    )
  )

  categorical_provenance <- list(adapter = "direct", source = "mock_categorical")
  expect_equal(
    mock_categorical(
      "smoking",
      levels = c("never", "former", "current"),
      proportions = c(0.5, 0.3, 0.2)
    ),
    mock_spec(
      mock_spec_categorical(
        "smoking",
        levels = c("never", "former", "current"),
        proportions = c(0.5, 0.3, 0.2),
        provenance = categorical_provenance
      ),
      provenance = categorical_provenance
    )
  )

  date_provenance <- list(adapter = "direct", source = "mock_date")
  expect_equal(
    mock_date(
      "interview_date",
      range = as.Date(c("2001-01-01", "2005-12-31"))
    ),
    mock_spec(
      mock_spec_date(
        "interview_date",
        range = as.Date(c("2001-01-01", "2005-12-31")),
        provenance = date_provenance
      ),
      provenance = date_provenance,
      model_hint = "native-postprocess"
    )
  )
})

test_that("direct mock APIs keep adapter provenance fixed as direct", {
  spec <- mock_continuous(
    "age",
    range = c(18, 85),
    provenance = list(adapter = "not-direct", source = "custom-note")
  )

  expect_equal(spec$provenance$adapter, "direct")
  expect_equal(spec$provenance$source, "custom-note")
  expect_equal(spec$variables$age$provenance$adapter, "direct")
  expect_equal(spec$variables$age$provenance$source, "custom-note")
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
