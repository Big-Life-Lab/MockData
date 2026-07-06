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
  RNGkind("Marsaglia-Multicarry")
  b <- generate_mock_data_native(spec, n = 100, seed = 7)
  expect_identical(a, b)
})
