test_that("native exponential generates within the declared range", {
  spec <- mock_continuous("wait", range = c(0, 100),
                          distribution = "exponential", rate = 0.1)
  result <- generate_mock_data_native(spec, n = 500, seed = 42)
  expect_true(all(result$wait >= 0 & result$wait <= 100))
  expect_type(result$wait, "double")
})

test_that("native exponential is seed-reproducible", {
  spec <- mock_continuous("wait", range = c(0, 100),
                          distribution = "exponential", rate = 0.1)
  expect_identical(
    generate_mock_data_native(spec, n = 50, seed = 7),
    generate_mock_data_native(spec, n = 50, seed = 7)
  )
})

test_that("exponential without a positive rate is rejected", {
  # Constructors document that they return a validated mock_spec; expect the
  # error at construction. If construction is lazy in this version, assert on
  # validate_mock_spec(spec, strict = FALSE)$errors instead.
  expect_error(
    mock_continuous("wait", range = c(0, 100), distribution = "exponential"),
    "exponential distribution requires rate > 0"
  )
})

test_that("recodeflow-sourced rate flows to the native generator", {
  spec <- mock_continuous("wait", range = c(0, 50),
                          distribution = "exponential", rate = 0.5)
  result <- generate_mock_data_native(spec, n = 200, seed = 11)
  # rate = 0.5 on [0, 50]: truncated mean ~ 2; loose two-sided sanity bound
  expect_gt(mean(result$wait), 0.5)
  expect_lt(mean(result$wait), 6)
})
