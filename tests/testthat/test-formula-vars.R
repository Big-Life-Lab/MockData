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

test_that("mock_spec_formula() defers parse errors instead of throwing eagerly", {
  # The constructor itself must not throw on bad syntax; depends_on falls
  # back to character(0) and the parse error is reported by validation.
  variable <- mock_spec_formula("bad", formula = "x +* 2")
  expect_identical(variable$depends_on, character(0))
})

test_that("validate = FALSE constructs a spec with a bad-syntax formula", {
  expect_no_error(
    spec <- mock_spec(
      mock_spec_continuous("x", range = c(0, 1)),
      mock_spec_formula("bad", formula = "x +* 2"),
      validate = FALSE
    )
  )

  result <- validate_mock_spec(spec, strict = FALSE)
  expect_false(result$valid)
  expect_true(any(grepl("could not be parsed", result$errors)))
})

test_that("validate_mock_spec accumulates errors for multiple bad-syntax formulas", {
  spec <- mock_spec(
    mock_spec_formula("bad1", formula = "x +* 2"),
    mock_spec_formula("bad2", formula = "y +* 3"),
    validate = FALSE
  )

  result <- validate_mock_spec(spec, strict = FALSE)
  expect_false(result$valid)
  expect_true(any(grepl("bad1", result$errors) & grepl("could not be parsed", result$errors)))
  expect_true(any(grepl("bad2", result$errors) & grepl("could not be parsed", result$errors)))
})
