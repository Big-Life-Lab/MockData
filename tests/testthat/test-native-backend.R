test_that("generate_mock_data_native generates baseline direct specs", {
  spec <- mock_spec(
    mock_spec_continuous(
      "age",
      range = c(18, 85),
      distribution = "normal",
      mean = 50,
      sd = 12,
      rtype = "integer"
    ),
    mock_spec_categorical(
      "smoking",
      levels = c("never", "former", "current"),
      proportions = c(0.5, 0.3, 0.2),
      rtype = "character"
    ),
    mock_spec_date(
      "interview_date",
      range = as.Date(c("2001-01-01", "2005-12-31"))
    )
  )

  result <- generate_mock_data_native(spec, n = 500, seed = 101)

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 500)
  expect_named(result, c("age", "smoking", "interview_date"))
  expect_true(all(result$age >= 18 & result$age <= 85))
  expect_type(result$age, "integer")
  expect_true(all(result$smoking %in% c("never", "former", "current")))
  expect_s3_class(result$interview_date, "Date")
  expect_true(all(result$interview_date >= as.Date("2001-01-01")))
  expect_true(all(result$interview_date <= as.Date("2005-12-31")))
})

test_that("generate_mock_data_native is reproducible without leaking RNG state", {
  spec <- mock_continuous("age", range = c(18, 85), rtype = "integer")

  set.seed(999)
  before <- runif(1)
  result_1 <- generate_mock_data_native(spec, n = 10, seed = 42)
  after_1 <- runif(1)

  set.seed(999)
  expect_equal(runif(1), before)
  result_2 <- generate_mock_data_native(spec, n = 10, seed = 42)
  after_2 <- runif(1)

  expect_equal(result_1, result_2)
  expect_equal(after_1, after_2)
})

test_that("generate_mock_data_native handles empty specs and n = 0", {
  empty <- generate_mock_data_native(mock_spec(), n = 5, seed = 1)
  expect_s3_class(empty, "data.frame")
  expect_equal(nrow(empty), 5)
  expect_equal(ncol(empty), 0)

  spec <- mock_categorical("smoking", levels = c("never", "former", "current"))
  zero <- generate_mock_data_native(spec, n = 0, seed = 1)
  expect_equal(nrow(zero), 0)
  expect_named(zero, "smoking")
})

test_that("generate_mock_data_native consumes simple recodeflow specs", {
  variables <- data.frame(
    variable = c("age", "smoking", "interview_date"),
    variableType = c("Continuous", "Categorical", "Continuous"),
    rType = c("integer", "character", "date"),
    role = "enabled",
    distribution = c("uniform", "", "uniform"),
    stringsAsFactors = FALSE
  )
  details <- data.frame(
    variable = c("age", "smoking", "smoking", "interview_date"),
    recStart = c("[18, 85]", "never", "current", "[2001-01-01,2001-01-31]"),
    recEnd = c("copy", "never", "current", "copy"),
    proportion = c(1, 0.75, 0.25, 1),
    stringsAsFactors = FALSE
  )

  spec <- mock_spec_from_recodeflow(variables, details)
  result <- generate_mock_data_native(spec, n = 100, seed = 55)

  expect_named(result, c("age", "smoking", "interview_date"))
  expect_true(all(result$age >= 18 & result$age <= 85))
  expect_true(all(result$smoking %in% c("never", "current")))
  expect_s3_class(result$interview_date, "Date")
})

test_that("generate_mock_data_native fails loudly for unsupported native features", {
  survival_like <- mock_spec(
    mock_spec_date(
      "event_date",
      range = as.Date(c("2001-01-01", "2005-12-31"))
    ),
    validate = FALSE
  )
  survival_like$variables$event_date$distribution <- "gompertz"

  expect_error(
    generate_mock_data_native(survival_like, n = 10),
    "does not yet support date distribution"
  )

  expect_error(
    generate_mock_data_native(list(), n = 10),
    "mock_spec"
  )
})

test_that("generate_mock_data_native rejects lossy categorical coercion", {
  spec <- mock_categorical(
    "smoking",
    levels = c("never", "former", "current"),
    rtype = "integer"
  )

  expect_error(
    generate_mock_data_native(spec, n = 10, seed = 1),
    "integer-like levels"
  )
})
