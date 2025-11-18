# ==============================================================================
# Derived Variable Identification Tests
# ==============================================================================
# Tests for identify_derived_vars() and get_raw_var_dependencies()
# Tests use ONLY pattern-based detection (DerivedVar::, Func::)
# role = "derived" is NOT used (recodeflow pattern)
# ==============================================================================

test_that("identify_derived_vars() requires variable_details parameter", {
  variables <- data.frame(
    variable = c("height", "weight", "BMI_der"),
    role = c("enabled", "enabled", "enabled"),  # No "derived" in role
    stringsAsFactors = FALSE
  )

  expect_error(
    identify_derived_vars(variables, variable_details = NULL),
    "variable_details is required"
  )

  expect_error(
    identify_derived_vars(variables),
    "variable_details is required"
  )
})

test_that("identify_derived_vars() detects variables with DerivedVar:: pattern", {
  variables <- data.frame(
    variable = c("HWTGHTM", "HWTGWTK", "HWTGBMI_der"),
    role = c("enabled", "enabled", "enabled"),  # No "derived" in role!
    stringsAsFactors = FALSE
  )

  variable_details <- data.frame(
    variable = c("HWTGHTM", "HWTGWTK", "HWTGBMI_der"),
    recStart = c("[1.4,2.1]", "[45,150]", "DerivedVar::[HWTGHTM, HWTGWTK]"),
    recEnd = c("copy", "copy", "copy"),
    stringsAsFactors = FALSE
  )

  result <- identify_derived_vars(variables, variable_details)

  expect_equal(result, "HWTGBMI_der")
  expect_length(result, 1)
})

test_that("identify_derived_vars() detects variables with Func:: pattern in recEnd", {
  variables <- data.frame(
    variable = c("HWTGHTM", "HWTGWTK", "HWTGBMI_der"),
    role = c("enabled", "enabled", "enabled"),  # No "derived" in role!
    stringsAsFactors = FALSE
  )

  variable_details <- data.frame(
    variable = c("HWTGHTM", "HWTGWTK", "HWTGBMI_der"),
    recStart = c("[1.4,2.1]", "[45,150]", "NA"),
    recEnd = c("copy", "copy", "Func::bmi_fun"),
    stringsAsFactors = FALSE
  )

  result <- identify_derived_vars(variables, variable_details)

  expect_equal(result, "HWTGBMI_der")
  expect_length(result, 1)
})

test_that("identify_derived_vars() combines results from multiple detection methods", {
  variables <- data.frame(
    variable = c("ADL_01", "ADL_02", "ADL_03", "ADL_der", "HWTGHTM", "HWTGWTK", "BMI_der", "pack_years_der"),
    role = c(rep("enabled", 8)),  # All enabled, no "derived" in role
    stringsAsFactors = FALSE
  )

  variable_details <- data.frame(
    variable = c("ADL_01", "ADL_02", "ADL_03", "ADL_der", "HWTGHTM", "HWTGWTK", "BMI_der", "pack_years_der"),
    recStart = c(rep("1", 3), "DerivedVar::[ADL_01, ADL_02, ADL_03]", "[1.4,2.1]", "[45,150]", "DerivedVar::[HWTGHTM, HWTGWTK]", "NA"),
    recEnd = c(rep("1", 3), "Func::adl_fun", "copy", "copy", "Func::bmi_fun", "Func::pack_years_fun"),
    stringsAsFactors = FALSE
  )

  result <- identify_derived_vars(variables, variable_details)

  # Should find all 3 derived variables
  expect_equal(sort(result), c("ADL_der", "BMI_der", "pack_years_der"))
  expect_length(result, 3)
})

test_that("identify_derived_vars() returns empty vector when no derived variables found", {
  variables <- data.frame(
    variable = c("height", "weight", "age"),
    role = c("enabled", "enabled", "enabled"),
    stringsAsFactors = FALSE
  )

  variable_details <- data.frame(
    variable = c("height", "weight", "age"),
    recStart = c("[1.4,2.1]", "[45,150]", "[18,100]"),
    recEnd = c("copy", "copy", "copy"),
    stringsAsFactors = FALSE
  )

  result <- identify_derived_vars(variables, variable_details)

  expect_equal(result, character(0))
  expect_length(result, 0)
})

test_that("identify_derived_vars() validates input data frames", {
  variables_no_variable_col <- data.frame(
    var = c("height", "weight"),
    role = c("enabled", "enabled"),
    stringsAsFactors = FALSE
  )

  expect_error(
    identify_derived_vars(variables_no_variable_col),
    "variables must have a 'variable' column"
  )

  expect_error(
    identify_derived_vars("not a data frame"),
    "variables must be a data frame"
  )
})

test_that("identify_derived_vars() only returns variables that exist in variables df", {
  # Edge case: variable_details has DerivedVar:: for variable not in variables df
  variables <- data.frame(
    variable = c("HWTGHTM", "HWTGWTK"),
    role = c("enabled", "enabled"),
    stringsAsFactors = FALSE
  )

  variable_details <- data.frame(
    variable = c("HWTGHTM", "HWTGWTK", "HWTGBMI_der"),  # BMI_der not in variables!
    recStart = c("[1.4,2.1]", "[45,150]", "DerivedVar::[HWTGHTM, HWTGWTK]"),
    recEnd = c("copy", "copy", "copy"),
    stringsAsFactors = FALSE
  )

  result <- identify_derived_vars(variables, variable_details)

  # Should NOT return HWTGBMI_der since it's not in variables df
  expect_equal(result, character(0))
})

# ==============================================================================
# get_raw_var_dependencies() tests
# ==============================================================================

test_that("get_raw_var_dependencies() extracts raw variables from DerivedVar:: pattern", {
  variable_details <- data.frame(
    variable = c("HWTGBMI_der"),
    recStart = c("DerivedVar::[HWTGHTM, HWTGWTK]"),
    stringsAsFactors = FALSE
  )

  result <- get_raw_var_dependencies("HWTGBMI_der", variable_details)

  expect_equal(result, c("HWTGHTM", "HWTGWTK"))
  expect_length(result, 2)
})

test_that("get_raw_var_dependencies() handles variables with many dependencies", {
  variable_details <- data.frame(
    variable = c("ADL_der"),
    recStart = c("DerivedVar::[ADL_01, ADL_02, ADL_03, ADL_04, ADL_05]"),
    stringsAsFactors = FALSE
  )

  result <- get_raw_var_dependencies("ADL_der", variable_details)

  expect_equal(result, c("ADL_01", "ADL_02", "ADL_03", "ADL_04", "ADL_05"))
  expect_length(result, 5)
})

test_that("get_raw_var_dependencies() trims whitespace from variable names", {
  variable_details <- data.frame(
    variable = c("BMI_der"),
    recStart = c("DerivedVar::[  height  ,  weight  ]"),  # Extra spaces
    stringsAsFactors = FALSE
  )

  result <- get_raw_var_dependencies("BMI_der", variable_details)

  expect_equal(result, c("height", "weight"))
})

test_that("get_raw_var_dependencies() returns empty vector when no DerivedVar:: pattern found", {
  variable_details <- data.frame(
    variable = c("height"),
    recStart = c("[1.4,2.1]"),
    stringsAsFactors = FALSE
  )

  result <- get_raw_var_dependencies("height", variable_details)

  expect_equal(result, character(0))
  expect_length(result, 0)
})

test_that("get_raw_var_dependencies() validates input parameters", {
  variable_details <- data.frame(
    variable = c("BMI_der"),
    recStart = c("DerivedVar::[height, weight]"),
    stringsAsFactors = FALSE
  )

  # Test non-character derived_var
  expect_error(
    get_raw_var_dependencies(123, variable_details),
    "derived_var must be a single character string"
  )

  # Test multiple derived_var values
  expect_error(
    get_raw_var_dependencies(c("BMI_der", "ADL_der"), variable_details),
    "derived_var must be a single character string"
  )

  # Test non-data.frame variable_details
  expect_error(
    get_raw_var_dependencies("BMI_der", "not a data frame"),
    "variable_details must be a data frame"
  )
})

test_that("get_raw_var_dependencies() requires variable and recStart columns", {
  variable_details_no_recstart <- data.frame(
    variable = c("BMI_der"),
    recEnd = c("Func::bmi_fun"),
    stringsAsFactors = FALSE
  )

  expect_error(
    get_raw_var_dependencies("BMI_der", variable_details_no_recstart),
    "variable_details must have 'variable' and 'recStart' columns"
  )
})

# ==============================================================================
# Integration tests with minimal-example
# ==============================================================================

test_that("identify_derived_vars() works with minimal-example configuration", {
  skip_if_not(file.exists("inst/extdata/minimal-example/variables.csv"))

  variables <- read.csv(
    "inst/extdata/minimal-example/variables.csv",
    stringsAsFactors = FALSE
  )

  variable_details <- read.csv(
    "inst/extdata/minimal-example/variable_details.csv",
    stringsAsFactors = FALSE
  )

  result <- identify_derived_vars(variables, variable_details)

  expect_true("BMI_derived" %in% result)
  expect_type(result, "character")
})

test_that("get_raw_var_dependencies() works with minimal-example BMI_derived", {
  skip_if_not(file.exists("inst/extdata/minimal-example/variable_details.csv"))

  variable_details <- read.csv(
    "inst/extdata/minimal-example/variable_details.csv",
    stringsAsFactors = FALSE
  )

  result <- get_raw_var_dependencies("BMI_derived", variable_details)

  expect_equal(sort(result), c("height", "weight"))
})
