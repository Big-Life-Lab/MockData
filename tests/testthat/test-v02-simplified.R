# ==============================================================================
# Simplified v0.2 Tests
# ==============================================================================
# Tests for key v0.2 functionality with correct function signatures
# ==============================================================================

test_that("create_mock_data works with file paths", {
  # Create temporary files
  config_file <- tempfile(fileext = ".csv")
  details_file <- tempfile(fileext = ".csv")

  # Write test data
  config <- data.frame(
    uid = "smoking_v1",
    variable = "smoking",
    role = "enabled",
    variableType = "Categorical",
    rType = "factor",
    variableLabel = "Smoking status",
    position = 1,
    stringsAsFactors = FALSE
  )

  details <- data.frame(
    uid = c("smoking_v1", "smoking_v1"),
    uid_detail = c("smoking_v1_d1", "smoking_v1_d2"),
    variable = c("smoking", "smoking"),
    recStart = c("1", "2"),
    recEnd = c("1", "2"),
    catLabel = c("Daily", "Never"),
    proportion = c(0.5, 0.5),
    rType = c("factor", "factor")
  )

  write.csv(config, config_file, row.names = FALSE)
  write.csv(details, details_file, row.names = FALSE)

  # Generate mock data
  result <- create_mock_data(
    databaseStart = "test_db",
    variables = config_file,
    variable_details = details_file,
    n = 50,
    seed = 123
  )

  # Tests
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 50)
  expect_true("smoking" %in% names(result))

  # Clean up
  unlink(c(config_file, details_file))
})

test_that("parse_variable_start handles database-prefixed format", {
  expect_equal(parse_variable_start("cycle1::var1", "cycle1"), "var1")
  expect_equal(parse_variable_start("cycle1::age, cycle2::AGE", "cycle2"), "AGE")
})

test_that("parse_variable_start handles bracket format", {
  expect_equal(parse_variable_start("[gen_015]", "cycle1"), "gen_015")
  expect_equal(parse_variable_start("[alc_11]", "any_cycle"), "alc_11")
})

test_that("create_cat_var handles 'else' in recEnd", {
  variable_details <- data.frame(
    variable = c("smoking", "smoking", "smoking"),
    recStart = c("1", "2", "else"),
    recEnd = c("1", "2", "3"),
    catLabel = c("Daily", "Occasional", "Never"),
    variableStart = c("SMK_01", "SMK_01", "SMK_01"),
    databaseStart = c("cycle1", "cycle1", "cycle1"),
    rType = c("factor", "factor", "factor"),
    stringsAsFactors = FALSE
  )

  variables <- data.frame(
    variable = "smoking",
    rType = "factor",
    databaseStart = "cycle1",
    variableType = "Categorical",
    stringsAsFactors = FALSE
  )

  result <- create_cat_var(
    var = "smoking",
    databaseStart = "cycle1",
    variables = variables,
    variable_details = variable_details,
    n = 100,
    seed = 999
  )

  expect_s3_class(result$smoking, "factor")
  expect_true(all(result$smoking %in% c("1", "2", "3")))
})

test_that("determine_proportions extracts from proportion column", {
  details_subset <- data.frame(
    uid_detail = c("v1", "v2", "v3"),
    recStart = c("1", "2", "3"),
    recEnd = c("1", "2", "3"),
    proportion = c(0.2, 0.5, 0.3)
  )

  categories <- c("1", "2", "3")
  result <- determine_proportions(categories, proportions_param = NULL, var_details = details_subset)

  expect_type(result, "double")
  expect_equal(length(result), 3)
  expect_equal(sum(result), 1.0)
})

test_that("get_enabled_variables filters correctly", {
  config <- data.frame(
    uid = c("v1", "v2", "v3"),
    variable = c("var1", "var2", "var3"),
    role = c("enabled", "disabled", "covariate;enabled")
  )

  # No derived variables in this test, so set exclude_derived = FALSE
  result <- get_enabled_variables(config, exclude_derived = FALSE)

  expect_equal(nrow(result), 2)
  expect_true("var1" %in% result$variable)
  expect_true("var3" %in% result$variable)
  expect_false("var2" %in% result$variable)
})
