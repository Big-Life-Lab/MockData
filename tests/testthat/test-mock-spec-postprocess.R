test_that("postprocess_mock_data distinguishes missing-code collisions", {
  spec <- mock_categorical(
    "response",
    levels = c("1", "97"),
    proportions = c(0.7, 0.3),
    rtype = "character",
    missing_codes = "97",
    missing_proportions = 0.2
  )
  baseline <- generate_mock_data_native(spec, n = 200, seed = 11)

  result <- postprocess_mock_data(baseline, spec, seed = 12)
  diagnostics <- attr(result, "mockdata_diagnostics")$variables$response

  expect_true(length(diagnostics$preexisting_missing_code_indices) > 0)
  expect_equal(length(diagnostics$assigned_missing_indices), 40)
  expect_length(intersect(
    diagnostics$preexisting_missing_code_indices,
    diagnostics$assigned_missing_indices
  ), 0)
  expect_true(all(result$response[diagnostics$assigned_missing_indices] == "97"))
  expect_true(any(baseline$response[diagnostics$preexisting_missing_code_indices] == "97"))
})

test_that("postprocess_mock_data does not overwrite preexisting missing-code collisions with garbage", {
  spec <- mock_categorical(
    "response",
    levels = c("1", "97"),
    proportions = c(0.5, 0.5),
    rtype = "character",
    missing_codes = "97",
    missing_proportions = 0,
    garbage_rules = list(low = list(proportion = 1, range = "[-2, 0]"))
  )
  baseline <- generate_mock_data_native(spec, n = 100, seed = 13)
  expect_true(any(baseline$response == "97"))

  result <- postprocess_mock_data(baseline, spec, seed = 14)
  diagnostics <- attr(result, "mockdata_diagnostics")$variables$response

  preexisting <- diagnostics$preexisting_missing_code_indices
  garbage <- diagnostics$assigned_garbage_indices$low

  expect_length(intersect(preexisting, garbage), 0)
  expect_true(all(result$response[preexisting] == "97"))
})

test_that("postprocess_mock_data rejects missing-proportion overflow", {
  spec <- mock_categorical(
    "response",
    levels = c("1", "2"),
    proportions = c(0.5, 0.5),
    rtype = "character",
    missing_codes = c("97", "98"),
    missing_proportions = c(0.1, 0.1)
  )
  spec$variables$response$missing_proportions <- c(0.6, 0.6)
  baseline <- data.frame(response = rep(c("1", "2"), each = 10))

  expect_error(
    postprocess_mock_data(baseline, spec, seed = 16),
    "missing proportions must sum"
  )
})

test_that("postprocess_mock_data applies integer missing and garbage rules", {
  spec <- mock_continuous(
    "age",
    range = c(18, 85),
    rtype = "integer",
    missing_codes = 997,
    missing_proportions = 0.1,
    garbage_rules = list(high = list(proportion = 0.05, range = "[150, 200]"))
  )
  baseline <- generate_mock_data_native(spec, n = 100, seed = 21)

  result <- postprocess_mock_data(baseline, spec, seed = 22)
  diagnostics <- attr(result, "mockdata_diagnostics")$variables$age
  high_idx <- diagnostics$assigned_garbage_indices$high

  expect_type(result$age, "integer")
  expect_equal(length(diagnostics$assigned_missing_indices), 10)
  expect_equal(result$age[diagnostics$assigned_missing_indices], rep(997L, 10))
  expect_equal(length(high_idx), round(90 * 0.05))
  expect_true(all(result$age[high_idx] >= 150L & result$age[high_idx] <= 200L))
  expect_length(intersect(high_idx, diagnostics$assigned_missing_indices), 0)
})

test_that("postprocess_mock_data preserves Date values", {
  spec <- mock_date(
    "interview_date",
    range = as.Date(c("2001-01-01", "2001-01-31")),
    missing_codes = "2099-01-01",
    missing_proportions = 0.1,
    garbage_rules = list(high = list(
      proportion = 0.1,
      range = "[2025-01-01, 2025-01-31]"
    ))
  )
  baseline <- generate_mock_data_native(spec, n = 50, seed = 31)

  result <- postprocess_mock_data(baseline, spec, seed = 32)
  diagnostics <- attr(result, "mockdata_diagnostics")$variables$interview_date
  high_idx <- diagnostics$assigned_garbage_indices$high

  expect_s3_class(result$interview_date, "Date")
  expect_equal(
    result$interview_date[diagnostics$assigned_missing_indices],
    rep(as.Date("2099-01-01"), 5)
  )
  expect_true(all(result$interview_date[high_idx] >= as.Date("2025-01-01")))
  expect_true(all(result$interview_date[high_idx] <= as.Date("2025-01-31")))
})

test_that("postprocess_mock_data is reproducible without leaking RNG state", {
  spec <- mock_continuous(
    "age",
    range = c(18, 85),
    rtype = "integer",
    missing_codes = 997,
    missing_proportions = 0.1,
    garbage_rules = list(high = list(proportion = 0.1, range = "[150, 200]"))
  )
  baseline <- generate_mock_data_native(spec, n = 100, seed = 71)

  set.seed(999)
  before <- runif(1)
  result_1 <- postprocess_mock_data(baseline, spec, seed = 72)
  after_1 <- runif(1)

  set.seed(999)
  expect_equal(runif(1), before)
  result_2 <- postprocess_mock_data(baseline, spec, seed = 72)
  after_2 <- runif(1)

  expect_equal(result_1, result_2)
  expect_equal(after_1, after_2)
})

test_that("postprocess_mock_data preserves and extends factor levels", {
  spec <- mock_categorical(
    "smoking",
    levels = c("1", "2", "3"),
    proportions = c(0.5, 0.3, 0.2),
    missing_codes = "9",
    missing_proportions = 0.1,
    garbage_rules = list(low = list(proportion = 0.1, range = "[-2, 0]"))
  )
  baseline <- generate_mock_data_native(spec, n = 60, seed = 41)

  result <- postprocess_mock_data(baseline, spec, seed = 42)
  diagnostics <- attr(result, "mockdata_diagnostics")$variables$smoking
  low_idx <- diagnostics$assigned_garbage_indices$low

  expect_s3_class(result$smoking, "factor")
  expect_true("9" %in% levels(result$smoking))
  expect_true(all(as.character(result$smoking[diagnostics$assigned_missing_indices]) == "9"))
  expect_true(all(as.character(result$smoking[low_idx]) %in% c("-2", "-1", "0")))
})

test_that("postprocess_mock_data applies garbage rules in canonical order", {
  spec <- mock_continuous(
    "age",
    range = c(18, 85),
    garbage_rules = list(
      high = list(proportion = 0.1, range = "[150, 200]"),
      low = list(proportion = 0.1, range = "[-10, 0]")
    )
  )
  baseline <- generate_mock_data_native(spec, n = 20, seed = 81)

  result <- postprocess_mock_data(baseline, spec, seed = 82)
  diagnostics <- attr(result, "mockdata_diagnostics")$variables$age

  expect_equal(names(diagnostics$assigned_garbage_indices), c("low", "high"))
})

test_that("postprocess_mock_data rejects unnamed garbage rules", {
  spec <- mock_continuous(
    "age",
    range = c(18, 85),
    garbage_rules = list(list(proportion = 0.1, range = "[150, 200]"))
  )
  baseline <- generate_mock_data_native(spec, n = 10, seed = 81)

  expect_error(
    postprocess_mock_data(baseline, spec, seed = 82),
    "unnamed rule index: 1"
  )
})

test_that("postprocess_mock_data rejects impossible garbage requests", {
  spec <- mock_continuous(
    "age",
    range = c(18, 85),
    garbage_rules = list(
      low = list(proportion = 0.8, range = "[-10, 0]"),
      high = list(proportion = 0.8, range = "[150, 200]")
    )
  )
  baseline <- generate_mock_data_native(spec, n = 10, seed = 51)

  expect_error(
    postprocess_mock_data(baseline, spec, seed = 52),
    "request more rows"
  )
})

test_that("postprocess_mock_data validates input shape and diagnostics opt-out", {
  spec <- mock_continuous("age", range = c(18, 85))
  baseline <- generate_mock_data_native(spec, n = 10, seed = 61)

  expect_error(
    postprocess_mock_data(data.frame(other = 1:10), spec),
    "missing column"
  )

  result <- postprocess_mock_data(baseline, spec, diagnostics = FALSE)
  expect_null(attr(result, "mockdata_diagnostics"))
})

test_that("postprocess_mock_data rejects idempotent re-call", {
  spec <- mock_continuous(
    "age",
    range = c(18, 85),
    missing_codes = 997,
    missing_proportions = 0.1
  )
  baseline <- generate_mock_data_native(spec, n = 20, seed = 91)
  result <- postprocess_mock_data(baseline, spec, seed = 92)

  expect_error(
    postprocess_mock_data(result, spec, seed = 93),
    "already run"
  )
})
