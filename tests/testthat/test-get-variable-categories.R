# ==============================================================================
# Tests for Issue #5: `else` Bug in NA Handling
# ==============================================================================
# These tests capture the bug where literal string "else" appears in generated
# mock data instead of NA values. Tests should FAIL before fix, PASS after fix.
# ==============================================================================

# ==============================================================================
# HELPER FUNCTION: get_variable_categories()
# ==============================================================================

test_that("get_variable_categories does not return literal 'else' string", {
  # Create test metadata with else rule
  var_details <- data.frame(
    variable = c("alcdwky", "alcdwky", "alcdwky", "alcdwky"),
    recStart = c("[0, 84]", "996", "[997, 999]", "else"),
    recEnd = c("copy", "NA::a", "NA::b", "NA::b"),
    catLabel = c("Drinks in week", "not applicable", "missing", "missing"),
    stringsAsFactors = FALSE
  )

  # Get NA codes (include_na = TRUE)
  na_codes <- get_variable_categories(var_details, include_na = TRUE)

  # Should NOT contain "else" string
  expect_false("else" %in% na_codes,
               info = "NA codes should not include literal 'else' string")

  # Should contain explicit codes
  expect_true("996" %in% na_codes,
              info = "Should include explicit NA code 996")
  expect_true("997" %in% na_codes,
              info = "Should include expanded code 997 from range")
  expect_true("998" %in% na_codes,
              info = "Should include expanded code 998 from range")
  expect_true("999" %in% na_codes,
              info = "Should include expanded code 999 from range")
})

test_that("get_variable_categories handles else rule with other NA codes", {
  # Real-world example: ADL_01 from DemPoRT metadata
  var_details <- data.frame(
    variable = c("ADL_01", "ADL_01", "ADL_01", "ADL_01", "ADL_01"),
    recStart = c("1", "2", "6", "[7,9]", "else"),
    recEnd = c("1", "2", "NA::a", "NA::b", "NA::b"),
    catLabel = c("Yes", "No", "not applicable", "missing", "missing"),
    stringsAsFactors = FALSE
  )

  # Get NA codes
  na_codes <- get_variable_categories(var_details, include_na = TRUE)

  # Should have explicit codes but NOT "else"
  expect_true("6" %in% na_codes)
  expect_true("7" %in% na_codes)
  expect_true("8" %in% na_codes)
  expect_true("9" %in% na_codes)
  expect_false("else" %in% na_codes)

  # Should have 4 values total (6, 7, 8, 9)
  expect_equal(length(na_codes), 4)
})

test_that("get_variable_categories returns empty when only else rule exists", {
  # Edge case: only else rule for NA (no explicit codes)
  var_details <- data.frame(
    variable = c("testvar", "testvar"),
    recStart = c("[0, 100]", "else"),
    recEnd = c("copy", "NA::b"),
    catLabel = c("Valid range", "missing"),
    stringsAsFactors = FALSE
  )

  # Get NA codes
  na_codes <- get_variable_categories(var_details, include_na = TRUE)

  # Should be empty (else is skipped, no other NA codes)
  expect_equal(length(na_codes), 0,
               info = "When only 'else' rule exists, should return empty vector")
})

test_that("get_variable_categories preserves other special codes", {
  # Test that copy, NA::a, NA::b are preserved when used as recStart
  var_details <- data.frame(
    variable = c("testvar", "testvar", "testvar"),
    recStart = c("996", "copy", "NA::b"),
    recEnd = c("NA::a", "NA::b", "NA::b"),
    catLabel = c("skip", "missing", "missing"),
    stringsAsFactors = FALSE
  )

  # Get NA codes
  na_codes <- get_variable_categories(var_details, include_na = TRUE)

  # Should include 996, copy, NA::b (but would NOT include "else" if present)
  expect_true("996" %in% na_codes)
  expect_true("copy" %in% na_codes)
  expect_true("NA::b" %in% na_codes)
})

# ==============================================================================
# GENERATOR: create_con_var()
# ==============================================================================

test_that("create_con_var does not generate literal 'else' string", {
  # Load real metadata with else rule
  variables <- read.csv(
    system.file("extdata/chms/chmsflow_sample_variables.csv", package = "MockData"),
    stringsAsFactors = FALSE
  )
  variable_details <- read.csv(
    system.file("extdata/chms/chmsflow_sample_variable_details.csv", package = "MockData"),
    stringsAsFactors = FALSE
  )

  # Generate continuous variable with prop_NA
  set.seed(123)
  result <- create_con_var(
    var_raw = "alcdwky",
    cycle = "cycle1",
    variable_details = variable_details,
    variables = variables,
    length = 1000,
    df_mock = data.frame(),
    prop_NA = 0.1
  )

  # Should NOT contain "else" as a value
  expect_false(any(result$alcdwky == "else", na.rm = TRUE),
               info = "Generated data should not contain literal 'else' string")

  # Should contain explicit missing codes (996, 997-999)
  unique_vals <- unique(result$alcdwky)
  na_codes <- unique_vals[!is.na(unique_vals) & as.numeric(unique_vals) >= 996]
  expect_true(length(na_codes) > 0,
              info = "Should contain explicit NA codes like 996-999")
})

test_that("create_con_var generates NA when only else rule exists", {
  # Create metadata with only else rule for NA (no explicit codes)
  # Must include all required columns for get_variable_details_for_raw()
  var_details <- data.frame(
    variable = c("testvar", "testvar"),
    variableStart = c("testvar", "testvar"),
    databaseStart = c("test", "test"),
    variableType = c("continuous", "continuous"),
    recStart = c("[0, 100]", "else"),
    recEnd = c("copy", "NA::b"),
    catLabel = c("Valid range", "missing"),
    stringsAsFactors = FALSE
  )

  # Generate variable with prop_NA
  set.seed(456)
  result <- create_con_var(
    var_raw = "testvar",
    cycle = "test",
    variable_details = var_details,
    variables = NULL,
    length = 100,
    df_mock = data.frame(),
    prop_NA = 0.1
  )

  # Should have actual NA values (not "else" string)
  has_na <- any(is.na(result$testvar))
  has_else <- any(result$testvar == "else", na.rm = TRUE)

  expect_true(has_na, info = "Should have actual NA values")
  expect_false(has_else, info = "Should NOT have 'else' string")

  # Check that approximately 10% are NA
  na_proportion <- sum(is.na(result$testvar)) / nrow(result)
  expect_true(na_proportion >= 0.05 && na_proportion <= 0.15,
              info = "Should have approximately 10% NA values")
})

# ==============================================================================
# GENERATOR: create_cat_var()
# ==============================================================================

test_that("create_cat_var does not generate literal 'else' string", {
  # Create categorical metadata with else rule
  # Must include all required columns for get_variable_details_for_raw()
  var_details <- data.frame(
    variable = c("testcat", "testcat", "testcat", "testcat"),
    variableStart = c("testcat", "testcat", "testcat", "testcat"),
    databaseStart = c("test", "test", "test", "test"),
    variableType = c("categorical", "categorical", "categorical", "categorical"),
    recStart = c("1", "2", "[7,9]", "else"),
    recEnd = c("1", "2", "NA::b", "NA::b"),
    catLabel = c("Yes", "No", "missing", "missing"),
    stringsAsFactors = FALSE
  )

  # Generate categorical variable with prop_NA
  set.seed(789)
  result <- create_cat_var(
    var_raw = "testcat",
    cycle = "test",
    variable_details = var_details,
    variables = NULL,
    length = 100,
    df_mock = data.frame(),
    prop_NA = 0.1
  )

  if (!is.null(result)) {
    # Should NOT contain "else" as a value
    expect_false(any(result$testcat == "else", na.rm = TRUE),
                 info = "Categorical data should not contain literal 'else' string")

    # Should contain explicit missing codes (7, 8, 9)
    unique_vals <- unique(result$testcat)
    na_codes <- unique_vals[!is.na(unique_vals) & unique_vals %in% c("7", "8", "9")]
    expect_true(length(na_codes) > 0,
                info = "Should contain explicit NA codes like 7, 8, 9")
  }
})

# ==============================================================================
# EDGE CASES
# ==============================================================================

test_that("get_variable_categories handles multiple else rules", {
  # Edge case: multiple else rules (shouldn't happen, but test robustness)
  var_details <- data.frame(
    variable = c("testvar", "testvar", "testvar"),
    recStart = c("[0, 100]", "else", "else"),
    recEnd = c("copy", "NA::a", "NA::b"),
    catLabel = c("Valid", "missing", "missing"),
    stringsAsFactors = FALSE
  )

  # Get NA codes
  na_codes <- get_variable_categories(var_details, include_na = TRUE)

  # Should not contain any "else" strings
  expect_false(any(na_codes == "else"),
               info = "Should not return 'else' even when multiple else rules exist")
})

test_that("get_variable_categories handles mixed special codes correctly", {
  # Test that else is skipped but other special codes preserved
  var_details <- data.frame(
    variable = c("testvar", "testvar", "testvar", "testvar"),
    recStart = c("[0, 100]", "copy", "else", "NA::b"),
    recEnd = c("copy", "NA::a", "NA::b", "NA::b"),
    catLabel = c("Valid", "skip", "missing", "missing"),
    stringsAsFactors = FALSE
  )

  # Get NA codes
  na_codes <- get_variable_categories(var_details, include_na = TRUE)

  # Should have copy and NA::b, but NOT else
  expect_true("copy" %in% na_codes)
  expect_true("NA::b" %in% na_codes)
  expect_false("else" %in% na_codes)
})
