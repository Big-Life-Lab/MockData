# ==============================================================================
# Tests for MockData Functions
# ==============================================================================
# Comprehensive tests for all MockData parsers, helpers, and generators
# ==============================================================================

# ==============================================================================
# PARSERS: parse_variable_start()
# ==============================================================================

test_that("parse_variable_start handles database-prefixed format", {
  # Single database format
  expect_equal(parse_variable_start("cycle1::amsdmva1", "cycle1"), "amsdmva1")

  # Multiple databases, first match
  expect_equal(
    parse_variable_start("cycle1::amsdmva1, cycle2::ammdmva1", "cycle1"),
    "amsdmva1"
  )

  # Multiple databases, second match
  expect_equal(
    parse_variable_start("cycle1::amsdmva1, cycle2::ammdmva1", "cycle2"),
    "ammdmva1"
  )
})

test_that("parse_variable_start handles bracket format", {
  # Simple bracket format
  expect_equal(parse_variable_start("[gen_015]", "cycle1"), "gen_015")
  expect_equal(parse_variable_start("[alc_11]", "cycle1"), "alc_11")
  expect_equal(parse_variable_start("[ammdmva1]", "cycle2"), "ammdmva1")
})

test_that("parse_variable_start handles mixed format - bracket as DEFAULT", {
  # Mixed format: database::var1, [var2]
  # [var2] is the DEFAULT for databases not explicitly listed

  # Cycle1 has explicit override
  expect_equal(
    parse_variable_start("cycle1::amsdmva1, [ammdmva1]", "cycle1"),
    "amsdmva1"
  )

  # Cycle2-6 use bracket segment as DEFAULT
  expect_equal(
    parse_variable_start("cycle1::amsdmva1, [ammdmva1]", "cycle2"),
    "ammdmva1"
  )
  expect_equal(
    parse_variable_start("cycle1::amsdmva1, [ammdmva1]", "cycle3"),
    "ammdmva1"
  )
  expect_equal(
    parse_variable_start("cycle1::amsdmva1, [ammdmva1]", "cycle6"),
    "ammdmva1"
  )

  # Real example from metadata
  expect_equal(
    parse_variable_start("cycle1::gen_15, [gen_025]", "cycle1"),
    "gen_15"
  )
  expect_equal(
    parse_variable_start("cycle1::gen_15, [gen_025]", "cycle5"),
    "gen_025"
  )
})

test_that("parse_variable_start handles plain format", {
  # Plain variable name (no decoration)
  expect_equal(parse_variable_start("bmi", "cycle1"), "bmi")
  expect_equal(parse_variable_start("alcdwky", "cycle3"), "alcdwky")
})

test_that("parse_variable_start returns NULL for invalid input", {
  # Empty string
  expect_null(parse_variable_start("", "cycle1"))

  # NULL inputs
  expect_null(parse_variable_start(NULL, "cycle1"))
  expect_null(parse_variable_start("cycle1::var", NULL))

  # DerivedVar format (requires custom logic)
  expect_null(parse_variable_start("DerivedVar::[var1, var2]", "cycle1"))

  # No match for specified database
  expect_null(parse_variable_start("cycle2::age", "cycle1"))
})

# ==============================================================================
# HELPERS: get_cycle_variables()
# ==============================================================================

test_that("get_cycle_variables filters by exact cycle match", {
  # Load test metadata
  variables <- read.csv(
    system.file("extdata", "variables.csv", package = "chmsflow"),
    stringsAsFactors = FALSE
  )
  variable_details <- read.csv(
    system.file("extdata", "variable-details.csv", package = "chmsflow"),
    stringsAsFactors = FALSE
  )

  # Get cycle1 variables
  cycle1_vars <- get_cycle_variables("cycle1", variables, variable_details)

  # Should have variables
  expect_true(nrow(cycle1_vars) > 0)

  # Check that all returned variables have cycle1 in their databaseStart
  for (i in 1:nrow(cycle1_vars)) {
    db_start <- cycle1_vars$databaseStart[i]
    cycles <- strsplit(db_start, ",")[[1]]
    cycles <- trimws(cycles)
    expect_true(
      "cycle1" %in% cycles,
      info = paste(
        "Variable",
        cycle1_vars$variable[i],
        "should have cycle1 in databaseStart"
      )
    )
  }
})

test_that("get_cycle_variables uses exact match (not substring)", {
  # Load test metadata
  variables <- read.csv(
    system.file("extdata", "variables.csv", package = "chmsflow"),
    stringsAsFactors = FALSE
  )
  variable_details <- read.csv(
    system.file("extdata", "variable-details.csv", package = "chmsflow"),
    stringsAsFactors = FALSE
  )

  # Get cycle1 variables (should NOT include cycle1_meds)
  cycle1_vars <- get_cycle_variables("cycle1", variables, variable_details)

  # Check that no cycle1_meds-only variables are included
  # (Variables that ONLY have cycle1_meds, not cycle1)
  for (i in 1:nrow(cycle1_vars)) {
    db_start <- cycle1_vars$databaseStart[i]
    cycles <- strsplit(db_start, ",")[[1]]
    cycles <- trimws(cycles)

    # If this variable is in cycle1_meds but NOT in cycle1, that's an error
    if ("cycle1_meds" %in% cycles && !"cycle1" %in% cycles) {
      fail(paste(
        "Found cycle1_meds-only variable in cycle1 results:",
        cycle1_vars$variable[i]
      ))
    }
  }

  expect_true(TRUE) # Test passed if we got here
})

test_that("get_cycle_variables extracts variable_raw correctly", {
  # Load test metadata
  variables <- read.csv(
    system.file("extdata", "variables.csv", package = "chmsflow"),
    stringsAsFactors = FALSE
  )
  variable_details <- read.csv(
    system.file("extdata", "variable-details.csv", package = "chmsflow"),
    stringsAsFactors = FALSE
  )

  cycle1_vars <- get_cycle_variables("cycle1", variables, variable_details)

  # Check that variable_raw is populated for non-DerivedVar
  non_derived <- cycle1_vars[
    !grepl("DerivedVar::", cycle1_vars$variableStart),
  ]

  if (nrow(non_derived) > 0) {
    # Should have variable_raw for most non-derived variables
    has_raw <- sum(!is.na(non_derived$variable_raw))
    expect_true(
      has_raw > 0,
      info = "Should have some variables with raw names extracted"
    )
  }
})

# ==============================================================================
# HELPERS: get_raw_variables()
# ==============================================================================

test_that("get_raw_variables returns unique raw variable names", {
  # Load test metadata
  variables <- read.csv(
    system.file("extdata", "variables.csv", package = "chmsflow"),
    stringsAsFactors = FALSE
  )
  variable_details <- read.csv(
    system.file("extdata", "variable-details.csv", package = "chmsflow"),
    stringsAsFactors = FALSE
  )

  raw_vars <- get_raw_variables("cycle1", variables, variable_details)

  # Check that all variable_raw are unique
  expect_equal(
    nrow(raw_vars),
    length(unique(raw_vars$variable_raw)),
    info = "All raw variable names should be unique"
  )
})

test_that("get_raw_variables groups harmonized variables correctly", {
  # Load test metadata
  variables <- read.csv(
    system.file("extdata", "variables.csv", package = "chmsflow"),
    stringsAsFactors = FALSE
  )
  variable_details <- read.csv(
    system.file("extdata", "variable-details.csv", package = "chmsflow"),
    stringsAsFactors = FALSE
  )

  raw_vars <- get_raw_variables("cycle1", variables, variable_details)

  # Check that n_harmonized matches the count in harmonized_vars
  for (i in 1:nrow(raw_vars)) {
    harmonized_list <- strsplit(raw_vars$harmonized_vars[i], ", ")[[1]]
    expect_equal(
      raw_vars$n_harmonized[i],
      length(harmonized_list),
      info = paste(
        "Count should match list length for",
        raw_vars$variable_raw[i]
      )
    )
  }
})

test_that("get_raw_variables excludes derived variables by default", {
  # Load test metadata
  variables <- read.csv(
    system.file("extdata", "variables.csv", package = "chmsflow"),
    stringsAsFactors = FALSE
  )
  variable_details <- read.csv(
    system.file("extdata", "variable-details.csv", package = "chmsflow"),
    stringsAsFactors = FALSE
  )

  # Default: include_derived = FALSE
  raw_vars <- get_raw_variables("cycle1", variables, variable_details)

  # Should not have NA in variable_raw (DerivedVar returns NA)
  expect_true(
    all(!is.na(raw_vars$variable_raw)),
    info = "No NA raw variable names when derived excluded"
  )
})

# ==============================================================================
# GENERATORS: create_cat_var()
# ==============================================================================

test_that("create_cat_var generates categorical variable", {
  # Load test metadata
  variables <- read.csv(
    system.file("extdata", "variables.csv", package = "chmsflow"),
    stringsAsFactors = FALSE
  )
  variable_details <- read.csv(
    system.file("extdata", "variable-details.csv", package = "chmsflow"),
    stringsAsFactors = FALSE
  )

  # Create empty mock data frame
  df_mock <- data.frame(id = 1:100)

  # Create a categorical variable
  result <- create_cat_var(
    var_raw = "clc_sex",
    cycle = "cycle1",
    variable_details = variable_details,
    variables = variables,
    length = 100,
    df_mock = df_mock,
    seed = 123
  )

  # Should return a data frame
  expect_true(is.data.frame(result) || is.null(result))

  if (!is.null(result)) {
    # Should have one column
    expect_equal(ncol(result), 1)

    # Should have 100 rows
    expect_equal(nrow(result), 100)

    # Column name should be the raw variable name
    expect_equal(names(result)[1], "clc_sex")
  }
})

test_that("create_cat_var returns NULL if variable already exists", {
  # Load test metadata
  variables <- read.csv(
    system.file("extdata", "variables.csv", package = "chmsflow"),
    stringsAsFactors = FALSE
  )
  variable_details <- read.csv(
    system.file("extdata", "variable-details.csv", package = "chmsflow"),
    stringsAsFactors = FALSE
  )

  # Create mock data with clc_sex already present
  df_mock <- data.frame(
    id = 1:100,
    clc_sex = sample(c("1", "2"), 100, replace = TRUE)
  )

  # Try to create clc_sex again
  result <- create_cat_var(
    var_raw = "clc_sex",
    cycle = "cycle1",
    variable_details = variable_details,
    variables = variables,
    length = 100,
    df_mock = df_mock,
    seed = 123
  )

  # Should return NULL (variable already exists)
  expect_null(result)
})

test_that("create_cat_var returns NULL if no variable details found", {
  # Load test metadata
  variables <- read.csv(
    system.file("extdata", "variables.csv", package = "chmsflow"),
    stringsAsFactors = FALSE
  )
  variable_details <- read.csv(
    system.file("extdata", "variable-details.csv", package = "chmsflow"),
    stringsAsFactors = FALSE
  )

  df_mock <- data.frame(id = 1:100)

  # Try to create a variable that doesn't exist
  result <- create_cat_var(
    var_raw = "nonexistent_variable",
    cycle = "cycle1",
    variable_details = variable_details,
    variables = variables,
    length = 100,
    df_mock = df_mock
  )

  # Should return NULL
  expect_null(result)
})

# ==============================================================================
# GENERATORS: create_date_var()
# ==============================================================================

test_that("create_date_var generates date variable", {
  # Load test metadata
  variable_details <- read.csv(
    system.file(
      "extdata",
      "ices",
      "variable_details.csv",
      package = "MockData"
    ),
    stringsAsFactors = FALSE
  )

  # Create empty mock data frame
  df_mock <- data.frame()

  # Create a date variable
  result <- create_date_var(
    var_raw = "birth_date",
    cycle = "ices",
    variable_details = variable_details,
    length = 100,
    df_mock = df_mock
  )

  # Should return a data frame
  expect_true(is.data.frame(result))

  if (!is.null(result)) {
    # Should have one column
    expect_equal(ncol(result), 1)

    # Should have 100 rows
    expect_equal(nrow(result), 100)

    # Column name should be the raw variable name
    expect_equal(names(result)[1], "birth_date")

    # Values should be Date objects
    expect_true(inherits(result[[1]], "Date"))
  }
})

test_that("create_date_var returns NULL if no variable details found", {
  # Load test metadata
  variable_details <- read.csv(
    system.file(
      "extdata",
      "ices",
      "variable_details.csv",
      package = "MockData"
    ),
    stringsAsFactors = FALSE
  )

  # Create empty mock data frame
  df_mock <- data.frame()

  # Try to create a variable not found in variable details
  result <- create_date_var(
    var_raw = "diagnosis_date",
    cycle = "ices",
    variable_details = variable_details,
    length = 100,
    df_mock = df_mock
  )

  # Should return NULL
  expect_null(result)
})

test_that("create_date_var returns NULL if variable already exists", {
  # Load test metadata
  variable_details <- read.csv(
    system.file(
      "extdata",
      "ices",
      "variable_details.csv",
      package = "MockData"
    ),
    stringsAsFactors = FALSE
  )

  # Create mock data frame with "death_date" already present
  df_mock <- data.frame(
    death_date = sample(seq(as.Date("2023-01-01"), as.Date("2023-12-31")), 100)
  )

  # Try to create "death_date" again
  result <- create_date_var(
    var_raw = "death_date",
    cycle = "ices",
    variable_details = variable_details,
    length = 100,
    df_mock = df_mock
  )

  # Should return NULL
  expect_null(result)
})

# Tests for prop_invalid functionality -------------------------------------------

test_that("create_cat_var generates invalid category codes", {
  # Load test metadata
  variables <- read.csv(
    system.file("extdata", "variables.csv", package = "chmsflow"),
    stringsAsFactors = FALSE
  )
  variable_details <- read.csv(
    system.file("extdata", "variable-details.csv", package = "chmsflow"),
    stringsAsFactors = FALSE
  )

  df_mock <- data.frame()

  # Create categorical variable with 10% invalid codes
  result <- create_cat_var(
    var_raw = "clc_sex",
    cycle = "cycle1",
    variable_details = variable_details,
    variables = variables,
    length = 1000,
    df_mock = df_mock,
    prop_invalid = 0.10,
    seed = 123
  )

  # Should return a data frame
  expect_s3_class(result, "data.frame")
  expect_equal(ncol(result), 1)
  expect_equal(nrow(result), 1000)

  # Get valid categories from metadata
  valid_categories <- c("1", "2")  # clc_sex has categories 1, 2
  invalid_categories <- setdiff(unique(result$clc_sex), valid_categories)

  # Should have some invalid codes
  expect_true(length(invalid_categories) > 0)

  # Approximately 10% should be invalid (allowing for randomness)
  n_invalid <- sum(!result$clc_sex %in% valid_categories)
  expect_true(n_invalid > 50 && n_invalid < 150)  # 10% of 1000 ± tolerance
})

test_that("create_con_var generates out-of-range values", {
  # Load test metadata
  variables <- read.csv(
    system.file("extdata", "variables.csv", package = "chmsflow"),
    stringsAsFactors = FALSE
  )
  variable_details <- read.csv(
    system.file("extdata", "variable-details.csv", package = "chmsflow"),
    stringsAsFactors = FALSE
  )

  df_mock <- data.frame()

  # Create continuous variable with 5% invalid values
  result <- create_con_var(
    var_raw = "clc_age",
    cycle = "cycle1",
    variable_details = variable_details,
    variables = variables,
    length = 1000,
    df_mock = df_mock,
    prop_invalid = 0.05,
    seed = 123
  )

  # Should return a data frame
  expect_s3_class(result, "data.frame")
  expect_equal(ncol(result), 1)
  expect_equal(nrow(result), 1000)

  # Valid range for clc_age is [3, 80]
  min_valid <- 3
  max_valid <- 80

  # Should have some out-of-range values
  n_below <- sum(result$clc_age < min_valid, na.rm = TRUE)
  n_above <- sum(result$clc_age > max_valid, na.rm = TRUE)
  n_invalid <- n_below + n_above

  # Approximately 5% should be invalid (allowing for randomness)
  expect_true(n_invalid > 20 && n_invalid < 80)  # 5% of 1000 ± tolerance
})

test_that("create_date_var generates out-of-period dates", {
  # Load test metadata
  variable_details <- read.csv(
    system.file(
      "extdata",
      "ices",
      "variable_details.csv",
      package = "MockData"
    ),
    stringsAsFactors = FALSE
  )

  df_mock <- data.frame()

  # Create date variable with 3% invalid dates
  result <- create_date_var(
    var_raw = "death_date",
    cycle = "ices",
    variable_details = variable_details,
    length = 1000,
    df_mock = df_mock,
    prop_invalid = 0.03,
    seed = 123
  )

  # Should return a data frame
  expect_s3_class(result, "data.frame")
  expect_equal(ncol(result), 1)
  expect_equal(nrow(result), 1000)

  # Valid range is [01JAN2001, 31MAR2017]
  min_valid <- as.Date("2001-01-01")
  max_valid <- as.Date("2017-03-31")

  # Should have some out-of-period dates
  n_before <- sum(result$death_date < min_valid, na.rm = TRUE)
  n_after <- sum(result$death_date > max_valid, na.rm = TRUE)
  n_invalid <- n_before + n_after

  # Approximately 3% should be invalid (allowing for randomness)
  expect_true(n_invalid > 10 && n_invalid < 50)  # 3% of 1000 ± tolerance
})

test_that("prop_NA and prop_invalid work together", {
  # Load test metadata
  variables <- read.csv(
    system.file("extdata", "variables.csv", package = "chmsflow"),
    stringsAsFactors = FALSE
  )
  variable_details <- read.csv(
    system.file("extdata", "variable-details.csv", package = "chmsflow"),
    stringsAsFactors = FALSE
  )

  df_mock <- data.frame()

  # Create categorical variable with both NA and invalid values
  result <- create_cat_var(
    var_raw = "clc_sex",
    cycle = "cycle1",
    variable_details = variable_details,
    variables = variables,
    length = 1000,
    df_mock = df_mock,
    prop_NA = 0.05,
    prop_invalid = 0.10,
    seed = 123
  )

  # Should return a data frame
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 1000)

  # Valid categories
  valid_categories <- c("1", "2")
  na_codes <- c("6", "7", "8", "9")  # NA codes from metadata (6 is NA::a, [7,9] is NA::b)

  # Count each type
  n_na <- sum(result$clc_sex %in% na_codes)
  n_valid <- sum(result$clc_sex %in% valid_categories)
  n_invalid <- sum(!result$clc_sex %in% c(valid_categories, na_codes))

  # Approximately 5% NA and 10% invalid
  expect_true(n_na > 20 && n_na < 80)      # 5% of 1000 ± tolerance
  expect_true(n_invalid > 60 && n_invalid < 140)  # 10% of 1000 ± tolerance
})

test_that("prop_NA + prop_invalid cannot exceed 1.0", {
  # Load test metadata
  variables <- read.csv(
    system.file("extdata", "variables.csv", package = "chmsflow"),
    stringsAsFactors = FALSE
  )
  variable_details <- read.csv(
    system.file("extdata", "variable-details.csv", package = "chmsflow"),
    stringsAsFactors = FALSE
  )

  df_mock <- data.frame()

  # Should error if prop_NA + prop_invalid > 1
  expect_error(
    create_cat_var(
      var_raw = "clc_sex",
      cycle = "cycle1",
      variable_details = variable_details,
      variables = variables,
      length = 1000,
      df_mock = df_mock,
      prop_NA = 0.6,
      prop_invalid = 0.5,
      seed = 123
    ),
    "exceeds 1.0"
  )

  expect_error(
    create_con_var(
      var_raw = "clc_age",
      cycle = "cycle1",
      variable_details = variable_details,
      variables = variables,
      length = 1000,
      df_mock = df_mock,
      prop_NA = 0.7,
      prop_invalid = 0.4,
      seed = 123
    ),
    "exceeds 1.0"
  )
})
