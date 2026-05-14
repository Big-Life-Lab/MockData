test_that("recEnd column conditional requirement works correctly", {
  # Test 1: File WITH missing codes but WITHOUT recEnd should error
  test_data_no_recEnd <- data.frame(
    uid = c("v_002", "v_002", "v_002"),
    uid_detail = c("d_002", "d_003", "d_004"),
    variable = c("smoking", "smoking", "smoking"),
    recStart = c("1", "2", "7"),  # Code 7 is missing code
    catLabel = c("Never", "Former", "Don't know"),
    proportion = c(0.5, 0.47, 0.03),
    stringsAsFactors = FALSE
  )

  temp_file <- tempfile(fileext = ".csv")
  write.csv(test_data_no_recEnd, temp_file, row.names = FALSE)

  expect_error(
    read_mock_data_config_details(temp_file, validate = TRUE),
    "recEnd column required in variable_details when using missing data codes"
  )

  unlink(temp_file)

  # Test 2: File WITH missing codes AND WITH recEnd should succeed
  test_data_with_recEnd <- data.frame(
    uid = c("v_002", "v_002", "v_002"),
    uid_detail = c("d_002", "d_003", "d_004"),
    variable = c("smoking", "smoking", "smoking"),
    recStart = c("1", "2", "7"),
    recEnd = c("1", "2", "NA::b"),  # Explicit classification
    catLabel = c("Never", "Former", "Don't know"),
    proportion = c(0.5, 0.47, 0.03),
    stringsAsFactors = FALSE
  )

  temp_file2 <- tempfile(fileext = ".csv")
  write.csv(test_data_with_recEnd, temp_file2, row.names = FALSE)

  expect_no_error(
    details <- read_mock_data_config_details(temp_file2, validate = TRUE)
  )

  unlink(temp_file2)

  # Test 3: File WITHOUT missing codes and WITHOUT recEnd should succeed
  test_data_no_missing <- data.frame(
    uid = c("v_010", "v_010"),
    uid_detail = c("d_100", "d_101"),
    variable = c("gender", "gender"),
    recStart = c("1", "2"),  # No missing codes
    catLabel = c("Male", "Female"),
    proportion = c(0.5, 0.5),
    stringsAsFactors = FALSE
  )

  temp_file3 <- tempfile(fileext = ".csv")
  write.csv(test_data_no_missing, temp_file3, row.names = FALSE)

  expect_no_error(
    details <- read_mock_data_config_details(temp_file3, validate = TRUE)
  )

  unlink(temp_file3)
})

test_that("recEnd validation detects all common missing codes", {
  # Test codes: 6, 7, 8, 9, 96, 97, 98, 99
  missing_codes <- c("6", "7", "8", "9", "96", "97", "98", "99")

  for (code in missing_codes) {
    test_data <- data.frame(
      variable = "test_var",
      recStart = c("1", code),
      stringsAsFactors = FALSE
    )

    temp_file <- tempfile(fileext = ".csv")
    write.csv(test_data, temp_file, row.names = FALSE)

    expect_error(
      read_mock_data_config_details(temp_file, validate = TRUE),
      "recEnd column required",
      info = paste("Missing code", code, "should trigger recEnd requirement")
    )

    unlink(temp_file)
  }
})

test_that("recEnd validation detects missing code ranges", {
  # Test range notation like [7,9]
  test_data <- data.frame(
    variable = "test_var",
    recStart = c("[1,5]", "[7,9]"),  # Range includes missing codes
    stringsAsFactors = FALSE
  )

  temp_file <- tempfile(fileext = ".csv")
  write.csv(test_data, temp_file, row.names = FALSE)

  expect_error(
    read_mock_data_config_details(temp_file, validate = TRUE),
    "recEnd column required"
  )

  unlink(temp_file)
})

test_that("get_variable_categories handles missing recEnd gracefully", {
  # Test that function warns when recEnd missing
  test_details <- data.frame(
    variable = "test",
    recStart = c("1", "2", "3"),
    catLabel = c("A", "B", "C"),
    stringsAsFactors = FALSE
  )

  expect_warning(
    result <- get_variable_categories(test_details, include_na = FALSE),
    "recEnd column not found"
  )

  expect_equal(length(result), 0)
})

test_that("get_variable_categories correctly filters by recEnd", {
  test_details <- data.frame(
    variable = "smoking",
    recStart = c("1", "2", "3", "7"),
    recEnd = c("1", "2", "3", "NA::b"),
    catLabel = c("Never", "Former", "Current", "DK"),
    stringsAsFactors = FALSE
  )

  # Get valid codes (recEnd NOT containing "NA")
  valid_codes <- get_variable_categories(test_details, include_na = FALSE)
  expect_equal(length(valid_codes), 3)
  expect_true(all(c("1", "2", "3") %in% valid_codes))

  # Get missing codes (recEnd containing "NA")
  missing_codes <- get_variable_categories(test_details, include_na = TRUE)
  expect_equal(length(missing_codes), 1)
  expect_equal(missing_codes, "7")
})

test_that("NA::a and NA::b classifications work correctly", {
  test_details <- data.frame(
    variable = "test",
    recStart = c("1", "2", "6", "7", "9"),
    recEnd = c("1", "2", "NA::a", "NA::b", "NA::b"),
    catLabel = c("Valid1", "Valid2", "Skip", "DK", "NS"),
    stringsAsFactors = FALSE
  )

  # Both NA::a and NA::b should be returned by include_na=TRUE
  missing_codes <- get_variable_categories(test_details, include_na = TRUE)
  expect_equal(length(missing_codes), 3)
  expect_true(all(c("6", "7", "9") %in% missing_codes))

  # Valid codes should exclude both NA::a and NA::b
  valid_codes <- get_variable_categories(test_details, include_na = FALSE)
  expect_equal(length(valid_codes), 2)
  expect_true(all(c("1", "2") %in% valid_codes))
})

test_that("minimal-example config loads successfully with recEnd", {
  # Test the actual minimal-example file
  details <- read_mock_data_config_details(
    system.file("extdata/minimal-example/variable_details.csv", package = "MockData"),
    validate = TRUE
  )

  expect_true("recEnd" %in% names(details))
  expect_true(nrow(details) > 0)

  # Check that we have both valid and missing classifications
  recEnd_values <- table(details$recEnd)
  expect_true("copy" %in% names(recEnd_values))
  expect_true("NA::b" %in% names(recEnd_values))
})

test_that("age missing codes 997, 998, 999 are properly classified", {
  details <- read_mock_data_config_details(
    system.file("extdata/minimal-example/variable_details.csv", package = "MockData"),
    validate = TRUE
  )

  age_details <- details[details$variable == "age", ]

  # Check age has missing codes 997, 998, 999
  age_missing <- age_details[age_details$recStart %in% c("997", "998", "999"), ]
  expect_equal(nrow(age_missing), 3)

  # All should be classified as NA::b
  expect_true(all(age_missing$recEnd == "NA::b"))

  # Check labels
  expect_true("Don't know" %in% age_missing$catLabel)
  expect_true("Refusal" %in% age_missing$catLabel)
  expect_true("Not stated" %in% age_missing$catLabel)
})

test_that("date variables properly handle missing data codes", {
  details <- read_mock_data_config_details(
    system.file("extdata/minimal-example/variable_details.csv", package = "MockData"),
    validate = TRUE
  )

  # Check interview_date has "else" → "NA::b" pattern for missing data
  interview_details <- details[details$variable == "interview_date", ]
  na_row <- interview_details[interview_details$recStart == "else", ]

  expect_equal(nrow(na_row), 1)
  expect_equal(na_row$recEnd, "NA::b")
  expect_true(grepl("[Mm]issing", na_row$catLabel))
})
