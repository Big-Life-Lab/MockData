test_that("generate_mock_data_simstudy fails clearly when simstudy is unavailable", {
  if (requireNamespace("simstudy", quietly = TRUE)) {
    skip("simstudy is installed; unavailable-path test is not applicable")
  }

  spec <- mock_continuous("age", range = c(18, 85))

  expect_error(
    generate_mock_data_simstudy(spec, n = 10, seed = 1),
    "requires the 'simstudy' package"
  )
})

test_that("generate_mock_data_simstudy generates supported baseline specs", {
  skip_if_not_installed("simstudy")

  spec <- mock_spec(
    mock_spec_continuous("age", range = c(18, 85), rtype = "integer"),
    mock_spec_continuous(
      "bmi",
      range = c(15, 50),
      distribution = "normal",
      mean = 27,
      sd = 5
    ),
    mock_spec_categorical(
      "smoking",
      levels = c("never", "former", "current"),
      proportions = c(0.5, 0.3, 0.2),
      rtype = "character"
    ),
    mock_spec_date("interview_date", range = as.Date(c("2001-01-01", "2001-01-31")))
  )

  result <- generate_mock_data_simstudy(spec, n = 1000, seed = 707)

  expect_named(result, c("age", "bmi", "smoking", "interview_date"))
  expect_type(result$age, "integer")
  expect_type(result$bmi, "double")
  expect_type(result$smoking, "character")
  expect_s3_class(result$interview_date, "Date")
  expect_true(all(result$age >= 18 & result$age <= 85))
  expect_true(all(result$bmi >= 15 & result$bmi <= 50))
  expect_equal(mean(result$bmi), 27, tolerance = 1)

  observed <- prop.table(table(factor(
    result$smoking,
    levels = c("never", "former", "current")
  )))
  expect_equal(as.numeric(observed), c(0.5, 0.3, 0.2), tolerance = 0.05)
})

test_that("generate_mock_data_simstudy composes with MockData post-processing", {
  skip_if_not_installed("simstudy")

  spec <- mock_categorical(
    "response",
    levels = c("1", "97"),
    proportions = c(0.6, 0.4),
    rtype = "character",
    missing_codes = "97",
    missing_proportions = 0.2,
    garbage_rules = list(low = list(proportion = 0.2, range = "[-2, 0]"))
  )

  baseline <- generate_mock_data_simstudy(spec, n = 100, seed = 808)
  result <- postprocess_mock_data(baseline, spec, seed = 809)
  diagnostics <- attr(result, "mockdata_diagnostics")$variables$response

  expect_equal(length(diagnostics$assigned_missing_indices), 20)
  expect_true(length(diagnostics$preexisting_missing_code_indices) > 0)
  expect_length(intersect(
    diagnostics$preexisting_missing_code_indices,
    diagnostics$assigned_garbage_indices$low
  ), 0)
})

test_that("generate_mock_data_simstudy is reproducible", {
  skip_if_not_installed("simstudy")

  spec <- mock_spec(
    mock_spec_continuous("age", range = c(18, 85), rtype = "integer"),
    mock_spec_categorical(
      "smoking",
      levels = c("never", "former", "current"),
      proportions = c(0.5, 0.3, 0.2),
      rtype = "character"
    )
  )

  first <- generate_mock_data_simstudy(spec, n = 100, seed = 909)
  second <- generate_mock_data_simstudy(spec, n = 100, seed = 909)

  expect_equal(first, second)
})

test_that("generate_mock_data_simstudy keeps deferred formula variables loud", {
  skip_if_not_installed("simstudy")

  variable <- mock_spec_continuous("bmi", range = c(15, 50))
  variable$formula <- "weight / height^2"
  spec <- mock_spec(variable)

  expect_error(
    generate_mock_data_simstudy(spec, n = 10, seed = 1),
    "Formula evaluation is not yet implemented"
  )
})
