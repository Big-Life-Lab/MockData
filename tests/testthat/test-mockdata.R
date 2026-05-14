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
# v0.1 legacy tests removed
# New v0.2 tests should be added here
# ==============================================================================
