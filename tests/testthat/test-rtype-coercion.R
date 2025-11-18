# ==============================================================================
# Tests for rType coercion
# ==============================================================================
# Tests for language-specific type coercion in continuous and categorical
# variable generators (v0.3.0 API)
# ==============================================================================

# ==============================================================================
# CONTINUOUS VARIABLES: create_con_var() with rType
# ==============================================================================

test_that("create_con_var returns integer when rType = 'integer'", {
  # Setup metadata with rType = integer
  variable_details <- data.frame(
    variable = c("age"),
    recStart = c("[18, 100]"),
    recEnd = c("copy"),
    catLabel = c("Age in years"),
    databaseStart = c("cycle1"),
    stringsAsFactors = FALSE
  )

  variables <- data.frame(
    variable = c("age"),
    rType = c("integer"),  # rType is in variables data frame
    databaseStart = c("cycle1"),
    variableType = c("Continuous"),
    stringsAsFactors = FALSE
  )

  # Generate age variable using v0.3.0 API
  result <- create_con_var(
    var = "age",
    databaseStart = "cycle1",
    variables = variables,
    variable_details = variable_details,
    n = 100,
    seed = 123
  )

  # Check that result is integer
  expect_type(result$age, "integer")
  expect_true(is.integer(result$age))

  # Check that values are in range
  expect_true(all(result$age >= 18 & result$age <= 100))
})

test_that("create_con_var returns double when rType = 'double'", {
  # Setup metadata with rType = double
  variable_details <- data.frame(
    variable = c("bmi"),
    recStart = c("[10.0, 50.0]"),
    recEnd = c("copy"),
    catLabel = c("Body mass index"),
    databaseStart = c("cycle1"),
    stringsAsFactors = FALSE
  )

  variables <- data.frame(
    variable = c("bmi"),
    rType = c("double"),
    databaseStart = c("cycle1"),
    variableType = c("Continuous"),
    stringsAsFactors = FALSE
  )

  # Generate BMI variable using v0.3.0 API
  result <- create_con_var(
    var = "bmi",
    databaseStart = "cycle1",
    variables = variables,
    variable_details = variable_details,
    n = 100,
    seed = 123
  )

  # Check that result is double
  expect_type(result$bmi, "double")
  expect_true(is.double(result$bmi))

  # Check that values are in range
  expect_true(all(result$bmi >= 10.0 & result$bmi <= 50.0))
})

test_that("create_con_var defaults to double when rType not specified", {
  # Setup metadata WITHOUT rType column
  variable_details <- data.frame(
    variable = c("income"),
    recStart = c("[0, 200000]"),
    recEnd = c("copy"),
    catLabel = c("Total income"),
    databaseStart = c("cycle1"),
    stringsAsFactors = FALSE
  )

  variables <- data.frame(
    variable = c("income"),
    # No rType column - should fall back to default (double)
    databaseStart = c("cycle1"),
    variableType = c("Continuous"),
    stringsAsFactors = FALSE
  )

  # Generate income variable (should default to double)
  result <- create_con_var(
    var = "income",
    databaseStart = "cycle1",
    variables = variables,
    variable_details = variable_details,
    n = 100,
    seed = 123
  )

  # Check that result defaults to double
  expect_type(result$income, "double")
})

# ==============================================================================
# CATEGORICAL VARIABLES: create_cat_var() with rType
# ==============================================================================

test_that("create_cat_var returns factor when rType = 'factor'", {
  # Setup metadata with rType = factor
  variable_details <- data.frame(
    variable = c("smoking", "smoking", "smoking"),
    recStart = c("1", "2", "3"),
    recEnd = c("1", "2", "3"),
    catLabel = c("Daily smoker", "Occasional smoker", "Never smoked"),
    databaseStart = c("cycle1", "cycle1", "cycle1"),
    stringsAsFactors = FALSE
  )

  variables <- data.frame(
    variable = c("smoking"),
    rType = c("factor"),
    databaseStart = c("cycle1"),
    variableType = c("Categorical"),
    stringsAsFactors = FALSE
  )

  # Generate smoking variable using v0.3.0 API
  result <- create_cat_var(
    var = "smoking",
    databaseStart = "cycle1",
    variables = variables,
    variable_details = variable_details,
    n = 100,
    seed = 123
  )

  # Check that result is factor
  expect_true(is.factor(result$smoking))

  # Check that factor has correct levels
  expect_equal(levels(result$smoking), c("1", "2", "3"))
})

test_that("create_cat_var returns character when rType = 'character'", {
  # Setup metadata with rType = character
  variable_details <- data.frame(
    variable = c("province", "province"),
    recStart = c("AB", "ON"),
    recEnd = c("AB", "ON"),
    catLabel = c("Alberta", "Ontario"),
    databaseStart = c("cycle1", "cycle1"),
    stringsAsFactors = FALSE
  )

  variables <- data.frame(
    variable = c("province"),
    rType = c("character"),
    databaseStart = c("cycle1"),
    variableType = c("Categorical"),
    stringsAsFactors = FALSE
  )

  # Generate province variable using v0.3.0 API
  result <- create_cat_var(
    var = "province",
    databaseStart = "cycle1",
    variables = variables,
    variable_details = variable_details,
    n = 100,
    seed = 123
  )

  # Check that result is character
  expect_type(result$province, "character")
  expect_true(is.character(result$province))
})

test_that("create_cat_var returns logical when rType = 'logical'", {
  # Setup metadata with rType = logical
  variable_details <- data.frame(
    variable = c("eligible", "eligible"),
    recStart = c("TRUE", "FALSE"),
    recEnd = c("TRUE", "FALSE"),
    catLabel = c("Eligible", "Not eligible"),
    databaseStart = c("cycle1", "cycle1"),
    stringsAsFactors = FALSE
  )

  variables <- data.frame(
    variable = c("eligible"),
    rType = c("logical"),
    databaseStart = c("cycle1"),
    variableType = c("Categorical"),
    stringsAsFactors = FALSE
  )

  # Generate eligible variable using v0.3.0 API
  result <- create_cat_var(
    var = "eligible",
    databaseStart = "cycle1",
    variables = variables,
    variable_details = variable_details,
    n = 100,
    seed = 123
  )

  # Check that result is logical
  expect_type(result$eligible, "logical")
  expect_true(is.logical(result$eligible))
})

test_that("create_cat_var defaults to character when rType not specified", {
  # Setup metadata WITHOUT rType column
  variable_details <- data.frame(
    variable = c("smoking", "smoking", "smoking"),
    recStart = c("1", "2", "3"),
    recEnd = c("1", "2", "3"),
    catLabel = c("Daily smoker", "Occasional smoker", "Never smoked"),
    databaseStart = c("cycle1", "cycle1", "cycle1"),
    stringsAsFactors = FALSE
  )

  variables <- data.frame(
    variable = c("smoking"),
    # No rType column - should fall back to default (character)
    databaseStart = c("cycle1"),
    variableType = c("Categorical"),
    stringsAsFactors = FALSE
  )

  # Generate smoking variable (should default to character)
  result <- create_cat_var(
    var = "smoking",
    databaseStart = "cycle1",
    variables = variables,
    variable_details = variable_details,
    n = 100,
    seed = 123
  )

  # Check that result defaults to character
  expect_type(result$smoking, "character")
})

# ==============================================================================
# HELPER: apply_rtype_defaults()
# ==============================================================================

test_that("apply_rtype_defaults adds rType column with correct defaults", {
  # Setup metadata WITHOUT rType
  details <- data.frame(
    variable = c("age", "smoking"),
    typeEnd = c("cont", "cat"),
    recStart = c("[18, 100]", "1"),
    recEnd = c("copy", "1"),
    stringsAsFactors = FALSE
  )

  # Apply defaults
  result <- apply_rtype_defaults(details)

  # Check that rType column exists
  expect_true("rType" %in% names(result))

  # Check defaults
  expect_equal(result$rType[result$variable == "age"], "double")
  expect_equal(result$rType[result$variable == "smoking"], "factor")
})

test_that("apply_rtype_defaults preserves existing rType values", {
  # Setup metadata WITH rType
  details <- data.frame(
    variable = c("age"),
    typeEnd = c("cont"),
    recStart = c("[18, 100]"),
    recEnd = c("copy"),
    rType = c("integer"),  # Explicit override
    stringsAsFactors = FALSE
  )

  # Apply defaults (should preserve existing)
  result <- apply_rtype_defaults(details)

  # Check that rType is preserved
  expect_equal(result$rType[1], "integer")
})

test_that("apply_rtype_defaults validates rType values", {
  # Setup metadata with INVALID rType
  details <- data.frame(
    variable = c("age"),
    typeEnd = c("cont"),
    recStart = c("[18, 100]"),
    recEnd = c("copy"),
    rType = c("invalid_type"),
    stringsAsFactors = FALSE
  )

  # Apply defaults (should warn about invalid)
  expect_warning(
    apply_rtype_defaults(details),
    "Invalid rType values found"
  )
})
