test_that("native exponential generates within the declared range", {
  spec <- mock_continuous("wait", range = c(0, 100),
                          distribution = "exponential", rate = 0.1)
  result <- generate_mock_data_native(spec, n = 500, seed = 42)
  expect_true(all(result$wait >= 0 & result$wait <= 100))
  expect_type(result$wait, "double")
})

test_that("native exponential is seed-reproducible", {
  spec <- mock_continuous("wait", range = c(0, 100),
                          distribution = "exponential", rate = 0.1)
  expect_identical(
    generate_mock_data_native(spec, n = 50, seed = 7),
    generate_mock_data_native(spec, n = 50, seed = 7)
  )
})

test_that("exponential without a positive rate is rejected", {
  # Constructors document that they return a validated mock_spec; expect the
  # error at construction.
  expect_error(
    mock_continuous("wait", range = c(0, 100), distribution = "exponential"),
    "exponential distribution requires rate > 0"
  )
})

test_that("rate parameter shapes native exponential generation", {
  spec <- mock_continuous("wait", range = c(0, 50),
                          distribution = "exponential", rate = 0.5)
  result <- generate_mock_data_native(spec, n = 200, seed = 11)
  # rate = 0.5 on [0, 50]: truncated mean ~ 2; loose two-sided sanity bound
  expect_gt(mean(result$wait), 0.5)
  expect_lt(mean(result$wait), 6)
})

test_that("recodeflow-sourced rate flows through create_mock_data to the native generator", {
  # Regression pin for #37: mock_spec_recodeflow.R forwards `rate` from
  # metadata and create_mock_data.R's v0.4 allowlist includes "exponential".
  # Without both fixes, this call hard-errors or silently falls back to the
  # legacy path (no mockdata_diagnostics attribute).
  variables <- data.frame(
    variable = "wait",
    variableType = "Continuous",
    rType = "double",
    role = "enabled",
    distribution = "exponential",
    rate = 0.5,
    stringsAsFactors = FALSE
  )
  variable_details <- data.frame(
    variable = "wait",
    recStart = "[0, 50]",
    recEnd = "copy",
    proportion = 1,
    stringsAsFactors = FALSE
  )

  result <- create_mock_data(
    databaseStart = "study",
    variables = variables,
    variable_details = variable_details,
    n = 200,
    seed = 11,
    validate = TRUE
  )

  expect_true(all(result$wait >= 0 & result$wait <= 50))
  expect_false(is.null(attr(result, "mockdata_diagnostics")))

  repeat_result <- create_mock_data(
    databaseStart = "study",
    variables = variables,
    variable_details = variable_details,
    n = 200,
    seed = 11,
    validate = TRUE
  )
  expect_identical(result, repeat_result)
})

test_that("exponential rejects zero and negative rate", {
  expect_error(
    mock_continuous("wait", range = c(0, 100), distribution = "exponential", rate = 0),
    "exponential distribution requires rate > 0"
  )
  expect_error(
    mock_continuous("wait", range = c(0, 100), distribution = "exponential", rate = -1),
    "exponential distribution requires rate > 0"
  )
})

test_that("distribution case is normalized so validation applies", {
  expect_error(
    mock_continuous("wait", range = c(0, 100), distribution = "Exponential"),
    "exponential distribution requires rate > 0"
  )
})

test_that("no-probability-mass guard fires for degenerate and far-tail ranges", {
  degenerate <- mock_continuous("wait", range = c(5, 5),
                                distribution = "exponential", rate = 0.5)
  expect_error(
    generate_mock_data_native(degenerate, n = 10),
    "no probability mass inside range"
  )
  far_tail <- mock_continuous("wait", range = c(1000, 2000),
                              distribution = "exponential", rate = 10)
  expect_error(
    generate_mock_data_native(far_tail, n = 10),
    "no probability mass inside range"
  )
})

test_that("n = 0 returns an empty column even when the range has no mass", {
  degenerate <- mock_continuous("wait", range = c(5, 5),
                                distribution = "exponential", rate = 0.5)
  result <- generate_mock_data_native(degenerate, n = 0)
  expect_identical(nrow(result), 0L)
  expect_named(result, "wait")
})

test_that("invalid exponential metadata fails with diagnosis and guidance", {
  variables <- data.frame(
    variable = "wait",
    variableType = "Continuous",
    rType = "double",
    role = "enabled",
    distribution = "exponential",
    stringsAsFactors = FALSE
  )
  variable_details <- data.frame(
    variable = "wait",
    recStart = "[0, 50]",
    recEnd = "copy",
    proportion = 1,
    stringsAsFactors = FALSE
  )
  err <- tryCatch(
    suppressMessages(create_mock_data(
      databaseStart = "study",
      variables = variables,
      variable_details = variable_details,
      n = 5
    )),
    error = function(e) conditionMessage(e)
  )
  expect_match(err, "requires rate > 0")
  expect_match(err, "validate = FALSE")
})
