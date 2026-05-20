test_that("create_mock_data uses the v0.4 pipeline for strict supported metadata", {
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
    recStart = c("1", "2", "97"),
    recEnd = c("copy", "copy", "NA::b"),
    proportion = c(0.6, 0.3, 0.1),
    stringsAsFactors = FALSE
  )

  result <- create_mock_data(
    databaseStart = "study",
    variables = variables,
    variable_details = variable_details,
    n = 100,
    seed = 101
  )
  diagnostics <- attr(result, "mockdata_diagnostics")$variables$smoking

  expect_equal(names(result), "smoking")
  expect_true(all(result$smoking %in% c("1", "2", "97", "-2", "-1", "0")))
  expect_equal(length(diagnostics$assigned_missing_indices), 10)
  expect_equal(length(diagnostics$assigned_garbage_indices$low), 9)
  expect_length(intersect(
    diagnostics$assigned_missing_indices,
    diagnostics$assigned_garbage_indices$low
  ), 0)
})

test_that("create_mock_data keeps legacy fallback for unsupported v0.4 backend features", {
  variables <- data.frame(
    variable = "time_to_visit",
    variableType = "Continuous",
    rType = "double",
    role = "enabled",
    distribution = "exponential",
    rate = 0.5,
    stringsAsFactors = FALSE
  )
  variable_details <- data.frame(
    variable = "time_to_visit",
    recStart = "[0, 10]",
    recEnd = "copy",
    proportion = 1,
    stringsAsFactors = FALSE
  )

  expect_message(
    result <- create_mock_data(
      databaseStart = "study",
      variables = variables,
      variable_details = variable_details,
      n = 50,
      seed = 202,
      verbose = TRUE
    ),
    "legacy create_\\* dispatch"
  )

  expect_equal(names(result), "time_to_visit")
  expect_equal(nrow(result), 50)
  expect_true(is.numeric(result$time_to_visit))
  expect_null(attr(result, "mockdata_diagnostics"))
})

test_that("create_mock_data keeps legacy detail-level databaseStart filtering", {
  variables <- data.frame(
    variable = "smoking",
    variableType = "Categorical",
    rType = "character",
    role = "enabled",
    stringsAsFactors = FALSE
  )
  variable_details <- data.frame(
    variable = c("smoking", "smoking"),
    recStart = c("1", "2"),
    recEnd = c("copy", "copy"),
    proportion = c(1, 1),
    databaseStart = c("cycle1", "cycle10"),
    stringsAsFactors = FALSE
  )

  expect_message(
    result <- create_mock_data(
      databaseStart = "cycle1",
      variables = variables,
      variable_details = variable_details,
      n = 10,
      seed = 303,
      verbose = TRUE
    ),
    "detail-level databaseStart filtering"
  )

  expect_equal(unique(result$smoking), "1")
  expect_null(attr(result, "mockdata_diagnostics"))
})
