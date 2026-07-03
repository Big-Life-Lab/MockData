# tests/testthat/test-edge-case-contract.R
# Characterization tests pinning the edge-case input contract (issue #35).
# Probe evidence: development/post-v040-development-plan.md, Evidence Base.

minimal_example <- function() {
  vars <- system.file("extdata", "minimal-example", "variables.csv",
                      package = "MockData")
  dets <- system.file("extdata", "minimal-example", "variable_details.csv",
                      package = "MockData")
  if (!nzchar(vars) || !nzchar(dets)) {
    skip("minimal-example fixtures not installed")
  }
  list(
    variables = read.csv(vars, stringsAsFactors = FALSE, check.names = FALSE),
    variable_details = read.csv(dets, stringsAsFactors = FALSE, check.names = FALSE)
  )
}

test_that("native backend returns typed zero-row output for n = 0", {
  spec <- mock_continuous("age", range = c(18, 80))
  result <- generate_mock_data_native(spec, n = 0)
  expect_s3_class(result, "data.frame")
  expect_identical(nrow(result), 0L)
  expect_named(result, "age")
  expect_type(result$age, "double")
})

test_that("native backend returns n rows and zero columns for an empty spec", {
  expect_identical(dim(generate_mock_data_native(mock_spec(), n = 10)), c(10L, 0L))
  expect_identical(dim(generate_mock_data_native(mock_spec(), n = 0)), c(0L, 0L))
})

test_that("native backend rejects invalid n with a clear message", {
  spec <- mock_continuous("age", range = c(18, 80))
  expect_error(generate_mock_data_native(spec, n = -1),
               "non-negative whole number")
  expect_error(generate_mock_data_native(spec, n = 1.5),
               "non-negative whole number")
  expect_error(generate_mock_data_native(spec, n = NA),
               "non-negative whole number")
})

test_that("postprocess_mock_data preserves zero-row shape and names", {
  spec <- mock_continuous("age", range = c(18, 80))
  baseline <- generate_mock_data_native(spec, n = 0)
  result <- postprocess_mock_data(baseline, spec)
  expect_identical(nrow(result), 0L)
  expect_named(result, "age")
})

test_that("create_mock_data fails loudly when no variables match filters", {
  fx <- minimal_example()
  expect_error(
    suppressMessages(create_mock_data(
      "minimal-example", fx$variables[0, ], fx$variable_details, n = 5
    )),
    "No variables matched"
  )
})

test_that("create_mock_data handles single-row variables metadata", {
  fx <- minimal_example()
  result <- suppressMessages(create_mock_data(
    "minimal-example", fx$variables[1, ], fx$variable_details, n = 5
  ))
  expect_identical(nrow(result), 5L)
  expect_identical(ncol(result), 1L)
})

test_that("create_mock_data generates the minimal example (sanity anchor)", {
  fx <- minimal_example()
  result <- suppressWarnings(suppressMessages(create_mock_data(
    "minimal-example", fx$variables, fx$variable_details, n = 20, seed = 1
  )))
  expect_identical(nrow(result), 20L)
  expect_true(all(c("age", "smoking") %in% names(result)))
  expect_true(all(names(result) %in% fx$variables$variable))
})

test_that("create_mock_data accepts n = 0 and returns a full-schema empty frame", {
  fx <- minimal_example()
  result <- suppressWarnings(suppressMessages(create_mock_data(
    "minimal-example", fx$variables, fx$variable_details, n = 0
  )))
  expect_identical(nrow(result), 0L)
  expect_true(all(c("age", "smoking") %in% names(result)))
})

test_that("create_mock_data rejects fractional, negative, and NA n clearly", {
  fx <- minimal_example()
  for (bad_n in list(1.5, -1, NA)) {
    expect_error(
      suppressMessages(create_mock_data(
        "minimal-example", fx$variables, fx$variable_details, n = bad_n
      )),
      "non-negative whole number"
    )
  }
})

test_that("missing databaseStart produces a named, friendly error", {
  fx <- minimal_example()
  expect_error(
    create_mock_data(variables = fx$variables,
                     variable_details = fx$variable_details, n = 5),
    "databaseStart is required"
  )
})
