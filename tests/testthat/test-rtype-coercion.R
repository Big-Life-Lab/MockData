# ==============================================================================
# Tests for rType coercion
# ==============================================================================
# Tests for language-specific type coercion in continuous and categorical
# variable generators
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
    variableStart = c("AGE_01"),
    databaseStart = c("cycle1"),
    rType = c("integer")
  )

  variables <- data.frame(
    variable = c("age"),
    variableStart = c("AGE_01"),
    databaseStart = c("cycle1"),
    databaseEnd = c("cycle1"),
    variableType = c("continuous")
  )

  # Generate age variable
  result <- create_con_var(
    var_raw = "AGE_01",
    cycle = "cycle1",
    variable_details = variable_details,
    variables = variables,
    length = 100,
    seed = 123
  )

  # Check that result is integer
  expect_type(result$AGE_01, "integer")
  expect_true(is.integer(result$AGE_01))

  # Check that values are in range
  expect_true(all(result$AGE_01 >= 18 & result$AGE_01 <= 100))
})

test_that("create_con_var returns double when rType = 'double'", {
  # Setup metadata with rType = double
  variable_details <- data.frame(
    variable = c("bmi"),
    recStart = c("[10.0, 50.0]"),
    recEnd = c("copy"),
    catLabel = c("Body mass index"),
    variableStart = c("BMI_01"),
    databaseStart = c("cycle1"),
    rType = c("double")
  )

  variables <- data.frame(
    variable = c("bmi"),
    variableStart = c("BMI_01"),
    databaseStart = c("cycle1"),
    databaseEnd = c("cycle1"),
    variableType = c("continuous")
  )

  # Generate BMI variable
  result <- create_con_var(
    var_raw = "BMI_01",
    cycle = "cycle1",
    variable_details = variable_details,
    variables = variables,
    length = 100,
    seed = 123
  )

  # Check that result is double
  expect_type(result$BMI_01, "double")
  expect_true(is.double(result$BMI_01))

  # Check that values are in range
  expect_true(all(result$BMI_01 >= 10.0 & result$BMI_01 <= 50.0))
})

test_that("create_con_var defaults to double when rType not specified", {
  # Setup metadata WITHOUT rType column
  variable_details <- data.frame(
    variable = c("income"),
    recStart = c("[0, 200000]"),
    recEnd = c("copy"),
    catLabel = c("Total income"),
    variableStart = c("INC_01"),
    databaseStart = c("cycle1")
  )

  variables <- data.frame(
    variable = c("income"),
    variableStart = c("INC_01"),
    databaseStart = c("cycle1"),
    databaseEnd = c("cycle1"),
    variableType = c("continuous")
  )

  # Generate income variable
  result <- create_con_var(
    var_raw = "INC_01",
    cycle = "cycle1",
    variable_details = variable_details,
    variables = variables,
    length = 100,
    seed = 123
  )

  # Check that result is double (default)
  expect_type(result$INC_01, "double")
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
    variableStart = c("SMK_01", "SMK_01", "SMK_01"),
    databaseStart = c("cycle1", "cycle1", "cycle1"),
    rType = c("factor", "factor", "factor")
  )

  variables <- data.frame(
    variable = c("smoking"),
    variableStart = c("SMK_01"),
    databaseStart = c("cycle1"),
    databaseEnd = c("cycle1"),
    variableType = c("categorical")
  )

  # Generate smoking variable
  result <- create_cat_var(
    var_raw = "SMK_01",
    cycle = "cycle1",
    variable_details = variable_details,
    variables = variables,
    length = 100,
    seed = 123
  )

  # Check that result is factor
  expect_true(is.factor(result$SMK_01))

  # Check that factor has correct levels
  expect_equal(levels(result$SMK_01), c("1", "2", "3"))
})

test_that("create_cat_var returns character when rType = 'character'", {
  # Setup metadata with rType = character
  variable_details <- data.frame(
    variable = c("province", "province"),
    recStart = c("AB", "ON"),
    recEnd = c("AB", "ON"),
    catLabel = c("Alberta", "Ontario"),
    variableStart = c("PROV_01", "PROV_01"),
    databaseStart = c("cycle1", "cycle1"),
    rType = c("character", "character")
  )

  variables <- data.frame(
    variable = c("province"),
    variableStart = c("PROV_01"),
    databaseStart = c("cycle1"),
    databaseEnd = c("cycle1"),
    variableType = c("categorical")
  )

  # Generate province variable
  result <- create_cat_var(
    var_raw = "PROV_01",
    cycle = "cycle1",
    variable_details = variable_details,
    variables = variables,
    length = 100,
    seed = 123
  )

  # Check that result is character
  expect_type(result$PROV_01, "character")
  expect_true(is.character(result$PROV_01))
})

test_that("create_cat_var returns logical when rType = 'logical'", {
  # Setup metadata with rType = logical
  variable_details <- data.frame(
    variable = c("eligible", "eligible"),
    recStart = c("TRUE", "FALSE"),
    recEnd = c("TRUE", "FALSE"),
    catLabel = c("Eligible", "Not eligible"),
    variableStart = c("ELIG_01", "ELIG_01"),
    databaseStart = c("cycle1", "cycle1"),
    rType = c("logical", "logical")
  )

  variables <- data.frame(
    variable = c("eligible"),
    variableStart = c("ELIG_01"),
    databaseStart = c("cycle1"),
    databaseEnd = c("cycle1"),
    variableType = c("categorical")
  )

  # Generate eligible variable
  result <- create_cat_var(
    var_raw = "ELIG_01",
    cycle = "cycle1",
    variable_details = variable_details,
    variables = variables,
    length = 100,
    seed = 123
  )

  # Check that result is logical
  expect_type(result$ELIG_01, "logical")
  expect_true(is.logical(result$ELIG_01))
})

test_that("create_cat_var defaults to character when rType not specified", {
  # Setup metadata WITHOUT rType column
  variable_details <- data.frame(
    variable = c("smoking", "smoking", "smoking"),
    recStart = c("1", "2", "3"),
    recEnd = c("1", "2", "3"),
    catLabel = c("Daily smoker", "Occasional smoker", "Never smoked"),
    variableStart = c("SMK_01", "SMK_01", "SMK_01"),
    databaseStart = c("cycle1", "cycle1", "cycle1")
  )

  variables <- data.frame(
    variable = c("smoking"),
    variableStart = c("SMK_01"),
    databaseStart = c("cycle1"),
    databaseEnd = c("cycle1"),
    variableType = c("categorical")
  )

  # Generate smoking variable
  result <- create_cat_var(
    var_raw = "SMK_01",
    cycle = "cycle1",
    variable_details = variable_details,
    variables = variables,
    length = 100,
    seed = 123
  )

  # Check that result is character (default)
  expect_type(result$SMK_01, "character")
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
    recEnd = c("copy", "1")
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
    rType = c("integer")  # Explicit override
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
    rType = c("invalid_type")
  )

  # Apply defaults (should warn about invalid)
  expect_warning(
    apply_rtype_defaults(details),
    "Invalid rType values found"
  )
})
