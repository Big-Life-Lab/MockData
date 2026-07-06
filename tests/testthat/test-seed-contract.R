# tests/testthat/test-seed-contract.R
# Contract pinned by ADR development/adr/v05-seed-contract.md (#38).

test_that("distinct stages yield distinct, reproducible streams from one seed", {
  draw <- function(stage) MockData:::.with_mock_seed(1L, runif(5), stage = stage)
  expect_false(identical(draw("baseline"), draw("postprocess")))
  expect_identical(draw("baseline"), draw("baseline"))
})

test_that("seeded generation leaves the caller's RNG state and kind untouched", {
  set.seed(999)
  before_state <- .Random.seed
  before_kind <- RNGkind()
  spec <- mock_continuous("age", range = c(18, 80))
  generate_mock_data_native(spec, n = 50, seed = 42)
  expect_identical(.Random.seed, before_state)
  expect_identical(RNGkind(), before_kind)
})

test_that("same seed and spec give identical native output", {
  spec <- mock_continuous("age", range = c(18, 80))
  expect_identical(
    generate_mock_data_native(spec, n = 100, seed = 7),
    generate_mock_data_native(spec, n = 100, seed = 7)
  )
})

test_that("native output is independent of the caller's ambient RNGkind", {
  spec <- mock_continuous("age", range = c(18, 80))
  old <- RNGkind()
  on.exit(RNGkind(kind = old[1], normal.kind = old[2], sample.kind = old[3]), add = TRUE)
  RNGkind("Mersenne-Twister")
  a <- generate_mock_data_native(spec, n = 100, seed = 7)
  suppressWarnings({
    RNGkind("Marsaglia-Multicarry")
    b <- generate_mock_data_native(spec, n = 100, seed = 7)
  })
  expect_identical(a, b)
})

test_that("legacy path (validate = FALSE) leaves the caller's RNG untouched", {
  vars <- system.file("extdata", "minimal-example", "variables.csv", package = "MockData")
  dets <- system.file("extdata", "minimal-example", "variable_details.csv", package = "MockData")
  if (!nzchar(vars) || !nzchar(dets)) skip("minimal-example fixtures not installed")
  variables <- read.csv(vars, stringsAsFactors = FALSE, check.names = FALSE)
  variable_details <- read.csv(dets, stringsAsFactors = FALSE, check.names = FALSE)

  set.seed(123)
  before <- .Random.seed
  suppressWarnings(suppressMessages(
    create_mock_data("minimal-example", variables, variable_details,
                     n = 20, seed = 42, validate = FALSE)
  ))
  expect_identical(.Random.seed, before)
})

test_that("legacy path is reproducible for a given seed", {
  vars <- system.file("extdata", "minimal-example", "variables.csv", package = "MockData")
  dets <- system.file("extdata", "minimal-example", "variable_details.csv", package = "MockData")
  if (!nzchar(vars) || !nzchar(dets)) skip("minimal-example fixtures not installed")
  variables <- read.csv(vars, stringsAsFactors = FALSE, check.names = FALSE)
  variable_details <- read.csv(dets, stringsAsFactors = FALSE, check.names = FALSE)
  a <- suppressWarnings(suppressMessages(
    create_mock_data("minimal-example", variables, variable_details, n = 20, seed = 42, validate = FALSE)))
  b <- suppressWarnings(suppressMessages(
    create_mock_data("minimal-example", variables, variable_details, n = 20, seed = 42, validate = FALSE)))
  expect_identical(a, b)
})
