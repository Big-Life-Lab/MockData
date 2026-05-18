run_native_pipeline <- function(spec, n, seed) {
  baseline <- generate_mock_data_native(spec, n = n, seed = seed)
  postprocess_mock_data(baseline, spec, seed = seed + 1)
}

test_that("native mock_spec pipeline preserves categorical codes and diagnostics", {
  spec <- mock_categorical(
    "response",
    levels = c("1", "97"),
    proportions = c(0.55, 0.45),
    rtype = "character",
    missing_codes = "97",
    missing_proportions = 0.2,
    garbage_rules = list(low = list(proportion = 0.4, range = "[-2, 0]"))
  )

  result <- run_native_pipeline(spec, n = 200, seed = 101)
  diagnostics <- attr(result, "mockdata_diagnostics")$variables$response

  expect_true(all(result$response %in% c("1", "97", "-2", "-1", "0")))
  expect_equal(length(diagnostics$assigned_missing_indices), 40)
  expect_true(length(diagnostics$preexisting_missing_code_indices) > 0)
  expect_length(intersect(
    diagnostics$preexisting_missing_code_indices,
    diagnostics$assigned_missing_indices
  ), 0)
  expect_length(intersect(
    diagnostics$preexisting_missing_code_indices,
    diagnostics$assigned_garbage_indices$low
  ), 0)
  expect_true(all(result$response[diagnostics$preexisting_missing_code_indices] == "97"))
  expect_true(all(result$response[diagnostics$assigned_missing_indices] == "97"))
})

test_that("native mock_spec pipeline is reproducible as a composed workflow", {
  spec <- mock_spec(
    mock_spec_continuous(
      "age",
      range = c(18, 85),
      distribution = "normal",
      mean = 50,
      sd = 12,
      rtype = "integer",
      missing_codes = 997,
      missing_proportions = 0.05,
      garbage_rules = list(high = list(proportion = 0.05, range = "[150, 200]"))
    ),
    mock_spec_categorical(
      "smoking",
      levels = c("never", "former", "current"),
      proportions = c(0.5, 0.3, 0.2),
      rtype = "character"
    )
  )

  first <- run_native_pipeline(spec, n = 100, seed = 202)
  second <- run_native_pipeline(spec, n = 100, seed = 202)

  expect_equal(first, second)
  expect_equal(
    attr(first, "mockdata_diagnostics"),
    attr(second, "mockdata_diagnostics")
  )
})

test_that("recodeflow pipeline preserves recEnd-driven missingness and garbage", {
  variables <- data.frame(
    variable = "smoking",
    variableType = "Categorical",
    rType = "character",
    role = "enabled",
    garbage_low_prop = 0.1,
    garbage_low_range = "[-2, 0]",
    stringsAsFactors = FALSE
  )
  variable_details <- data.frame(
    variable = "smoking",
    recStart = c("1", "2", "97", "99"),
    recEnd = c("copy", "copy", "NA::b", "NA::b"),
    proportion = c(0.5, 0.3, 0.1, 0.1),
    stringsAsFactors = FALSE
  )
  spec <- mock_spec_from_recodeflow(variables, variable_details)

  result <- run_native_pipeline(spec, n = 100, seed = 303)
  diagnostics <- attr(result, "mockdata_diagnostics")$variables$smoking

  expect_equal(spec$variables$smoking$levels, c("1", "2"))
  expect_equal(spec$variables$smoking$missing_codes, c("97", "99"))
  expect_equal(length(diagnostics$assigned_missing_indices), 20)
  expect_equal(length(diagnostics$assigned_garbage_indices$low), 8)
  expect_true(all(result$smoking[diagnostics$assigned_missing_indices] %in% c("97", "99")))
  expect_true(all(result$smoking[diagnostics$assigned_garbage_indices$low] %in% c("-2", "-1", "0")))
  expect_length(intersect(
    diagnostics$assigned_missing_indices,
    diagnostics$assigned_garbage_indices$low
  ), 0)
})

test_that("direct and recodeflow pipelines agree for equivalent specs", {
  direct_spec <- mock_categorical(
    "smoking",
    levels = c("1", "2"),
    proportions = c(0.625, 0.375),
    rtype = "character",
    missing_codes = c("97", "99"),
    missing_proportions = c(0.1, 0.1),
    garbage_rules = list(low = list(proportion = 0.1, range = "[-2, 0]"))
  )
  variables <- data.frame(
    variable = "smoking",
    variableType = "Categorical",
    rType = "character",
    role = "enabled",
    garbage_low_prop = 0.1,
    garbage_low_range = "[-2, 0]",
    stringsAsFactors = FALSE
  )
  variable_details <- data.frame(
    variable = "smoking",
    recStart = c("1", "2", "97", "99"),
    recEnd = c("copy", "copy", "NA::b", "NA::b"),
    proportion = c(0.5, 0.3, 0.1, 0.1),
    stringsAsFactors = FALSE
  )
  recodeflow_spec <- mock_spec_from_recodeflow(variables, variable_details)

  direct_result <- run_native_pipeline(direct_spec, n = 100, seed = 404)
  recodeflow_result <- run_native_pipeline(recodeflow_spec, n = 100, seed = 404)

  attr(direct_result, "mockdata_diagnostics") <- NULL
  attr(recodeflow_result, "mockdata_diagnostics") <- NULL
  expect_equal(direct_result, recodeflow_result)
})

test_that("pipeline keeps deferred formula variables loud", {
  variable <- mock_spec_continuous("bmi", range = c(15, 50))
  variable$formula <- "weight / height^2"
  spec <- mock_spec(variable)

  expect_error(
    run_native_pipeline(spec, n = 10, seed = 505),
    "Formula evaluation is not yet implemented"
  )
})
