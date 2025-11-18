test_that("parse_range_notation handles numeric ranges correctly", {
  # Test inclusive range (auto-detects as integer)
  result <- parse_range_notation("[18,100]")
  expect_equal(result$min, 18)
  expect_equal(result$max, 100)
  expect_true(result$min_inclusive)
  expect_true(result$max_inclusive)
  expect_equal(result$type, "integer")

  # Test exclusive lower bound (continuous)
  result <- parse_range_notation("(0,100]")
  expect_equal(result$min, 0)
  expect_equal(result$max, 100)
  expect_false(result$min_inclusive)
  expect_true(result$max_inclusive)
  expect_equal(result$type, "continuous")

  # Test exclusive upper bound (continuous)
  result <- parse_range_notation("[0,100)")
  expect_equal(result$min, 0)
  expect_equal(result$max, 100)
  expect_true(result$min_inclusive)
  expect_false(result$max_inclusive)
  expect_equal(result$type, "continuous")

  # Test both exclusive (continuous)
  result <- parse_range_notation("(0,100)")
  expect_equal(result$min, 0)
  expect_equal(result$max, 100)
  expect_false(result$min_inclusive)
  expect_false(result$max_inclusive)
  expect_equal(result$type, "continuous")
})

test_that("parse_range_notation handles date ranges correctly", {
  # Test inclusive date range
  result <- parse_range_notation("[2001-01-01,2020-12-31]")
  expect_s3_class(result$min, "Date")
  expect_s3_class(result$max, "Date")
  expect_equal(result$min, as.Date("2001-01-01"))
  expect_equal(result$max, as.Date("2020-12-31"))
  expect_true(result$min_inclusive)
  expect_true(result$max_inclusive)
  expect_equal(result$type, "date")

  # Test exclusive bounds
  result <- parse_range_notation("(2001-01-01,2020-12-31)")
  expect_s3_class(result$min, "Date")
  expect_s3_class(result$max, "Date")
  expect_false(result$min_inclusive)
  expect_false(result$max_inclusive)
  expect_equal(result$type, "date")
})

test_that("parse_range_notation handles decimal values", {
  result <- parse_range_notation("[1.4,2.1]")
  expect_equal(result$min, 1.4)
  expect_equal(result$max, 2.1)
  expect_true(result$min_inclusive)
  expect_true(result$max_inclusive)
  expect_equal(result$type, "continuous")
})

test_that("parse_range_notation handles negative values", {
  result <- parse_range_notation("[-10,10]")
  expect_equal(result$min, -10)
  expect_equal(result$max, 10)
  expect_true(result$min_inclusive)
  expect_true(result$max_inclusive)
  expect_equal(result$type, "integer")
})

test_that("parse_range_notation handles spaces", {
  # Spaces should be ignored
  result <- parse_range_notation("[ 18 , 100 ]")
  expect_equal(result$min, 18)
  expect_equal(result$max, 100)
  expect_true(result$min_inclusive)
  expect_true(result$max_inclusive)
  expect_equal(result$type, "integer")
})

test_that("parse_range_notation returns NULL on invalid input", {
  # Invalid format (no brackets)
  expect_null(parse_range_notation("18,100"))

  # Invalid format (only one value)
  expect_null(parse_range_notation("[18]"))

  # Empty string
  expect_null(parse_range_notation(""))
})
