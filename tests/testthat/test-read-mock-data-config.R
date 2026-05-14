test_that("read_mock_data_config loads variables.csv successfully", {
  # Load minimal-example variables
  variables <- read_mock_data_config(
    system.file("extdata/minimal-example/variables.csv", package = "MockData")
  )

  # Check structure
  expect_s3_class(variables, "data.frame")
  expect_true(nrow(variables) > 0)
  expect_true("variable" %in% names(variables))
  expect_true("variableType" %in% names(variables))

  # Check that all minimal-example variables are present
  expect_true("age" %in% variables$variable)
  expect_true("smoking" %in% variables$variable)
  expect_true("BMI" %in% variables$variable)
})

test_that("read_mock_data_config preserves column names", {
  variables <- read_mock_data_config(
    system.file("extdata/minimal-example/variables.csv", package = "MockData")
  )

  # Check that column names are preserved (not modified by check.names = TRUE)
  expect_false("variable.type" %in% names(variables))  # check.names would create this
  expect_true("variableType" %in% names(variables))
})

test_that("read_mock_data_config handles strings correctly", {
  variables <- read_mock_data_config(
    system.file("extdata/minimal-example/variables.csv", package = "MockData")
  )

  # Check that strings are not converted to factors
  expect_type(variables$variable, "character")
  expect_type(variables$variableType, "character")
})

test_that("read_mock_data_config errors on missing file", {
  expect_error(
    read_mock_data_config("nonexistent_file.csv"),
    "Configuration file does not exist"
  )
})

test_that("read_mock_data_config errors on invalid path", {
  expect_error(
    read_mock_data_config(""),
    "Configuration file does not exist"
  )
})

test_that("read_mock_data_config loads file with garbage columns", {
  # Create a temporary file with garbage columns
  temp_file <- tempfile(fileext = ".csv")

  test_data <- data.frame(
    variable = c("age", "smoking"),
    variableType = c("Continuous", "Categorical"),
    role = c("enabled", "enabled"),
    position = c(1, 2),
    databaseStart = c("minimal-example", "minimal-example"),
    garbage_low_prop = c(0.02, NA),
    garbage_low_range = c("[-10, 10]", NA),
    garbage_high_prop = c(NA, 0.03),
    garbage_high_range = c(NA, "[10, 15]"),
    stringsAsFactors = FALSE
  )

  write.csv(test_data, temp_file, row.names = FALSE)

  variables <- read_mock_data_config(temp_file)

  # Check that garbage columns are loaded
  expect_true("garbage_low_prop" %in% names(variables))
  expect_true("garbage_low_range" %in% names(variables))
  expect_true("garbage_high_prop" %in% names(variables))
  expect_true("garbage_high_range" %in% names(variables))

  # Check values
  expect_equal(variables$garbage_low_prop[1], 0.02)
  expect_true(is.na(variables$garbage_low_prop[2]))
  expect_equal(variables$garbage_high_prop[2], 0.03)

  unlink(temp_file)
})

test_that("read_mock_data_config handles quoted fields", {
  # Create a temporary file with quoted fields
  temp_file <- tempfile(fileext = ".csv")

  test_data <- data.frame(
    variable = c("test_var", "another_var"),
    variableType = c("Categorical", "Continuous"),
    role = c("enabled", "enabled"),
    position = c(1, 2),
    databaseStart = c("study1", "study2"),
    notes = c("This has, a comma", "This has \"quotes\""),
    stringsAsFactors = FALSE
  )

  write.csv(test_data, temp_file, row.names = FALSE)

  variables <- read_mock_data_config(temp_file)

  # Check that quoted fields are parsed correctly
  expect_equal(variables$notes[1], "This has, a comma")
  expect_equal(variables$notes[2], "This has \"quotes\"")

  unlink(temp_file)
})
