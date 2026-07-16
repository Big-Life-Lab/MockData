# tests/testthat/test-formula-vars.R
# Formula-derived variables (#39, Phase A). ADR: development/adr/v05-formula-evaluator.md

test_that("mock_formula constructs a validated formula variable", {
  spec <- mock_spec(
    mock_spec_continuous("height", range = c(1.4, 2.1)),
    mock_spec_continuous("weight", range = c(45, 150)),
    mock_spec_formula("bmi", formula = "weight / (height^2)")
  )
  expect_true(validate_mock_spec(spec)$valid)
  expect_identical(spec$variables$bmi$type, "formula")
  expect_identical(spec$variables$bmi$formula, "weight / (height^2)")
  expect_setequal(spec$variables$bmi$depends_on, c("weight", "height"))
})

test_that("a formula referencing an unknown variable fails validation", {
  expect_error(
    mock_spec(
      mock_spec_continuous("height", range = c(1.4, 2.1)),
      mock_spec_formula("bmi", formula = "weight / (height^2)")
    ),
    "references unknown variable"
  )
})

test_that("a disallowed function symbol fails validation before generation", {
  expect_error(
    mock_spec(
      mock_spec_continuous("x", range = c(0, 1)),
      mock_spec_formula("bad", formula = "system('echo pwned') + x")
    ),
    "not permitted in mockFormula"
  )
})

test_that("a dependency cycle among formula variables errors clearly", {
  expect_error(
    mock_spec(
      mock_spec_formula("a", formula = "b + 1"),
      mock_spec_formula("b", formula = "a + 1")
    ),
    "dependency cycle"
  )
})

test_that("an unparseable formula errors at validation", {
  expect_error(
    mock_spec(
      mock_spec_continuous("x", range = c(0, 1)),
      mock_spec_formula("bad", formula = "x +* 2")
    ),
    "could not be parsed"
  )
})
