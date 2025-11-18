test_that("categorical garbage generates invalid codes with unified API", {
  # Setup: minimal-example metadata
  variables <- read.csv(
    system.file("extdata/minimal-example/variables.csv", package = "MockData"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  variable_details <- read.csv(
    system.file("extdata/minimal-example/variable_details.csv", package = "MockData"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  # Add garbage to smoking (valid codes: 1, 2, 3, 7)
  vars_with_garbage <- add_garbage(variables, "smoking",
    garbage_low_prop = 0.05, garbage_low_range = "[-2, 0]")

  # Generate smoking data with garbage
  result <- create_cat_var(
    var = "smoking",
    databaseStart = "minimal-example",
    variables = vars_with_garbage,
    variable_details = variable_details,
    n = 1000,
    seed = 123
  )

  # Convert factor to numeric to check garbage codes
  smoking_numeric <- as.numeric(as.character(result$smoking))

  # Find garbage values (codes < 1)
  garbage_values <- smoking_numeric[smoking_numeric < 1 & !is.na(smoking_numeric)]
  n_garbage <- length(garbage_values)

  # Should have approximately 5% garbage (50 out of 1000)
  expect_true(n_garbage > 30)  # At least 3%
  expect_true(n_garbage < 80)  # At most 8%

  # Garbage codes should be in range [-2, 0]
  expect_true(all(garbage_values >= -2))
  expect_true(all(garbage_values <= 0))
})

test_that("categorical garbage values are included in factor levels", {
  variables <- read.csv(
    system.file("extdata/minimal-example/variables.csv", package = "MockData"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  variable_details <- read.csv(
    system.file("extdata/minimal-example/variable_details.csv", package = "MockData"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  # Add garbage to smoking
  vars_with_garbage <- add_garbage(variables, "smoking",
    garbage_low_prop = 0.03, garbage_low_range = "[-2, 0]")

  result <- create_cat_var(
    var = "smoking",
    databaseStart = "minimal-example",
    variables = vars_with_garbage,
    variable_details = variable_details,
    n = 1000,
    seed = 456
  )

  # Get factor levels
  factor_levels <- levels(result$smoking)

  # Should include garbage codes as levels
  # (Regression test for bug where garbage codes became NA)
  smoking_numeric <- as.numeric(as.character(result$smoking))
  garbage_values <- unique(smoking_numeric[smoking_numeric < 1 & !is.na(smoking_numeric)])

  if (length(garbage_values) > 0) {
    # If garbage was generated, it should be in factor levels
    for (garbage_code in garbage_values) {
      expect_true(as.character(garbage_code) %in% factor_levels,
        info = paste("Garbage code", garbage_code, "should be in factor levels"))
    }
  }
})

test_that("categorical garbage does not convert to NA", {
  # Regression test for factor level bug
  variables <- read.csv(
    system.file("extdata/minimal-example/variables.csv", package = "MockData"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  variable_details <- read.csv(
    system.file("extdata/minimal-example/variable_details.csv", package = "MockData"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  # Add substantial garbage proportion to ensure we get some
  vars_with_garbage <- add_garbage(variables, "smoking",
    garbage_low_prop = 0.10, garbage_low_range = "[-2, 0]")

  result <- create_cat_var(
    var = "smoking",
    databaseStart = "minimal-example",
    variables = vars_with_garbage,
    variable_details = variable_details,
    n = 1000,
    seed = 789
  )

  # Count intentional NAs (from missing data proportions in metadata)
  smoking_details <- variable_details[variable_details$variable == "smoking", ]
  expected_na_prop <- sum(smoking_details$proportion[is.na(smoking_details$recStart)], na.rm = TRUE)

  # Count actual NAs
  n_na <- sum(is.na(result$smoking))
  actual_na_prop <- n_na / nrow(result)

  # NA proportion should be close to expected (not inflated by garbage codes)
  # Allow ±5% tolerance
  expect_true(abs(actual_na_prop - expected_na_prop) < 0.05,
    info = paste("Expected NA prop:", expected_na_prop, "Actual:", actual_na_prop))
})

test_that("categorical garbage works with high-range specification", {
  variables <- read.csv(
    system.file("extdata/minimal-example/variables.csv", package = "MockData"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  variable_details <- read.csv(
    system.file("extdata/minimal-example/variable_details.csv", package = "MockData"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  # Add high-range garbage (codes > 7)
  vars_with_garbage <- add_garbage(variables, "smoking",
    garbage_high_prop = 0.05, garbage_high_range = "[10, 15]")

  result <- create_cat_var(
    var = "smoking",
    databaseStart = "minimal-example",
    variables = vars_with_garbage,
    variable_details = variable_details,
    n = 1000,
    seed = 321
  )

  # Find high-range garbage (codes > 7)
  smoking_numeric <- as.numeric(as.character(result$smoking))
  garbage_values <- smoking_numeric[smoking_numeric > 7 & !is.na(smoking_numeric)]
  n_garbage <- length(garbage_values)

  # Should have approximately 5% garbage
  expect_true(n_garbage > 30)
  expect_true(n_garbage < 80)

  # Garbage codes should be in range [10, 15]
  expect_true(all(garbage_values >= 10))
  expect_true(all(garbage_values <= 15))
})

test_that("categorical garbage works with two-sided specification", {
  variables <- read.csv(
    system.file("extdata/minimal-example/variables.csv", package = "MockData"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  variable_details <- read.csv(
    system.file("extdata/minimal-example/variable_details.csv", package = "MockData"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  # Add both low and high garbage
  vars_with_garbage <- add_garbage(variables, "smoking",
    garbage_low_prop = 0.03, garbage_low_range = "[-2, 0]",
    garbage_high_prop = 0.02, garbage_high_range = "[10, 15]")

  result <- create_cat_var(
    var = "smoking",
    databaseStart = "minimal-example",
    variables = vars_with_garbage,
    variable_details = variable_details,
    n = 1000,
    seed = 654
  )

  smoking_numeric <- as.numeric(as.character(result$smoking))

  # Find low-range garbage
  low_garbage <- smoking_numeric[smoking_numeric < 1 & !is.na(smoking_numeric)]

  # Find high-range garbage
  high_garbage <- smoking_numeric[smoking_numeric > 7 & !is.na(smoking_numeric)]

  # Should have garbage in both ranges
  expect_true(length(low_garbage) > 15)  # ~3%
  expect_true(length(high_garbage) > 10) # ~2%

  # Total garbage should be approximately 5%
  total_garbage <- length(low_garbage) + length(high_garbage)
  expect_true(total_garbage > 35)
  expect_true(total_garbage < 70)
})

test_that("categorical variables without garbage generate clean data", {
  variables <- read.csv(
    system.file("extdata/minimal-example/variables.csv", package = "MockData"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  variable_details <- read.csv(
    system.file("extdata/minimal-example/variable_details.csv", package = "MockData"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  # Generate without adding garbage
  result <- create_cat_var(
    var = "smoking",
    databaseStart = "minimal-example",
    variables = variables,  # No garbage added
    variable_details = variable_details,
    n = 1000,
    seed = 999
  )

  # Get valid codes from metadata
  smoking_details <- variable_details[variable_details$variable == "smoking", ]
  valid_codes <- unique(smoking_details$recStart[!is.na(smoking_details$recStart)])

  # All non-NA values should be valid codes
  non_na_values <- as.character(result$smoking[!is.na(result$smoking)])
  invalid_codes <- non_na_values[!non_na_values %in% valid_codes]

  expect_equal(length(invalid_codes), 0,
    info = paste("Found invalid codes:", paste(invalid_codes, collapse = ", ")))
})
