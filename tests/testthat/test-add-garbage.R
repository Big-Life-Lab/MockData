test_that("add_garbage() adds garbage specifications to variables data frame", {
  # Setup: minimal variables data frame
  variables <- data.frame(
    variable = c("age", "smoking", "BMI"),
    variableType = c("Continuous", "Categorical", "Continuous"),
    stringsAsFactors = FALSE
  )

  # Test 1: Add high-range garbage to age
  result <- add_garbage(variables, "age",
    garbage_high_prop = 0.03, garbage_high_range = "[150, 200]")

  expect_true("garbage_high_prop" %in% names(result))
  expect_true("garbage_high_range" %in% names(result))
  expect_equal(result$garbage_high_prop[result$variable == "age"], 0.03)
  expect_equal(result$garbage_high_range[result$variable == "age"], "[150, 200]")

  # Other variables should have NA
  expect_true(is.na(result$garbage_high_prop[result$variable == "smoking"]))
  expect_true(is.na(result$garbage_high_prop[result$variable == "BMI"]))
})

test_that("add_garbage() adds low-range garbage specifications", {
  variables <- data.frame(
    variable = c("smoking"),
    variableType = c("Categorical"),
    stringsAsFactors = FALSE
  )

  result <- add_garbage(variables, "smoking",
    garbage_low_prop = 0.02, garbage_low_range = "[-2, 0]")

  expect_equal(result$garbage_low_prop[result$variable == "smoking"], 0.02)
  expect_equal(result$garbage_low_range[result$variable == "smoking"], "[-2, 0]")
})

test_that("add_garbage() adds two-sided garbage (low + high)", {
  variables <- data.frame(
    variable = c("BMI"),
    variableType = c("Continuous"),
    stringsAsFactors = FALSE
  )

  result <- add_garbage(variables, "BMI",
    garbage_low_prop = 0.02, garbage_low_range = "[-10, 15)",
    garbage_high_prop = 0.01, garbage_high_range = "[60, 150]")

  expect_equal(result$garbage_low_prop[result$variable == "BMI"], 0.02)
  expect_equal(result$garbage_low_range[result$variable == "BMI"], "[-10, 15)")
  expect_equal(result$garbage_high_prop[result$variable == "BMI"], 0.01)
  expect_equal(result$garbage_high_range[result$variable == "BMI"], "[60, 150]")
})

test_that("add_garbage() is pipe-friendly (returns modified data frame)", {
  variables <- data.frame(
    variable = c("age", "smoking"),
    variableType = c("Continuous", "Categorical"),
    stringsAsFactors = FALSE
  )

  # Chain multiple add_garbage() calls
  result <- add_garbage(variables, "age", garbage_high_prop = 0.03, garbage_high_range = "[150, 200]")
  result <- add_garbage(result, "smoking", garbage_low_prop = 0.02, garbage_low_range = "[-2, 0]")

  # Check both variables have garbage
  expect_equal(result$garbage_high_prop[result$variable == "age"], 0.03)
  expect_equal(result$garbage_low_prop[result$variable == "smoking"], 0.02)
})

test_that("add_garbage() validates input parameters", {
  variables <- data.frame(
    variable = c("age"),
    variableType = c("Continuous"),
    stringsAsFactors = FALSE
  )

  # Test 1: Variable not found
  expect_error(
    add_garbage(variables, "nonexistent", garbage_high_prop = 0.03, garbage_high_range = "[150, 200]"),
    "Variable 'nonexistent' not found"
  )

  # Test 2: Invalid proportion (> 1)
  expect_error(
    add_garbage(variables, "age", garbage_high_prop = 1.5, garbage_high_range = "[150, 200]"),
    "must be a single numeric value between 0 and 1"
  )

  # Test 3: Invalid proportion (< 0)
  expect_error(
    add_garbage(variables, "age", garbage_high_prop = -0.1, garbage_high_range = "[150, 200]"),
    "must be a single numeric value between 0 and 1"
  )

  # Test 4: Missing variable column
  invalid_df <- data.frame(var = c("age"), stringsAsFactors = FALSE)
  expect_error(
    add_garbage(invalid_df, "age", garbage_high_prop = 0.03, garbage_high_range = "[150, 200]"),
    "must contain a 'variable' column"
  )
})

test_that("add_garbage() creates columns if they don't exist", {
  # Start with minimal data frame (no garbage columns)
  variables <- data.frame(
    variable = c("age"),
    variableType = c("Continuous"),
    stringsAsFactors = FALSE
  )

  expect_false("garbage_high_prop" %in% names(variables))
  expect_false("garbage_high_range" %in% names(variables))

  result <- add_garbage(variables, "age", garbage_high_prop = 0.03, garbage_high_range = "[150, 200]")

  # Columns should now exist
  expect_true("garbage_high_prop" %in% names(result))
  expect_true("garbage_high_range" %in% names(result))

  # Should have correct value for age
  expect_equal(result$garbage_high_prop[result$variable == "age"], 0.03)
  expect_equal(result$garbage_high_range[result$variable == "age"], "[150, 200]")
})

test_that("add_garbage() handles NULL parameters (no-op)", {
  variables <- data.frame(
    variable = c("age"),
    variableType = c("Continuous"),
    stringsAsFactors = FALSE
  )

  # Call with all NULL parameters
  result <- add_garbage(variables, "age",
    garbage_low_prop = NULL, garbage_low_range = NULL,
    garbage_high_prop = NULL, garbage_high_range = NULL)

  # Should return unchanged data frame (no new columns)
  expect_equal(names(result), names(variables))
  expect_equal(nrow(result), nrow(variables))
})

test_that("add_garbage() works with existing garbage columns", {
  # Start with data frame that already has garbage columns
  variables <- data.frame(
    variable = c("age", "BMI"),
    variableType = c("Continuous", "Continuous"),
    garbage_high_prop = c(NA, 0.05),
    garbage_high_range = c(NA, "[100, 200]"),
    stringsAsFactors = FALSE
  )

  # Add garbage to age (which has NA)
  result <- add_garbage(variables, "age", garbage_high_prop = 0.03, garbage_high_range = "[150, 200]")

  # Age should now have garbage
  expect_equal(result$garbage_high_prop[result$variable == "age"], 0.03)
  expect_equal(result$garbage_high_range[result$variable == "age"], "[150, 200]")

  # BMI should remain unchanged
  expect_equal(result$garbage_high_prop[result$variable == "BMI"], 0.05)
  expect_equal(result$garbage_high_range[result$variable == "BMI"], "[100, 200]")
})
