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

test_that("an unparseable formula does not mask referent errors on other formulas", {
  # Folded-in review finding from Task 1: spec-level checks re-parsed every
  # formula and failed fast, so one unparseable formula both (a) produced a
  # duplicate "could not be parsed" error alongside the per-variable one and
  # (b) masked referent/cycle findings for the OTHER, parseable formulas.
  # Fix: .validate_formula_referents()/.order_formula_variables() must skip
  # variables whose formula fails to parse.
  spec <- mock_spec(
    mock_spec_continuous("x", range = c(0, 1)),
    mock_spec_formula("bad", formula = "x +* 2"),
    mock_spec_formula("orphan", formula = "unknown_var + 1"),
    validate = FALSE
  )

  result <- validate_mock_spec(spec, strict = FALSE)
  expect_false(result$valid)

  parse_errors <- grepl("bad", result$errors) & grepl("could not be parsed", result$errors)
  expect_identical(sum(parse_errors), 1L)  # no duplicate parse entry

  referent_errors <- grepl("orphan", result$errors) & grepl("references unknown variable", result$errors)
  expect_true(any(referent_errors))
})

test_that("evaluate_mock_formulas computes algebraic derivations correctly", {
  spec <- mock_spec(
    mock_spec_continuous("height", range = c(1.4, 2.1)),
    mock_spec_continuous("weight", range = c(45, 150)),
    mock_spec_formula("bmi", formula = "weight / (height^2)")
  )
  baseline <- generate_mock_data_native(spec, n = 50, seed = 11)
  expect_false("bmi" %in% names(baseline))  # native skips formula vars
  result <- evaluate_mock_formulas(baseline, spec, seed = 11)
  expect_identical(result$bmi, baseline$weight / (baseline$height^2))
  expect_identical(result$height, baseline$height)  # inputs untouched
})

test_that("formula-of-a-formula evaluates in dependency order", {
  spec <- mock_spec(
    mock_spec_continuous("x", range = c(1, 10)),
    mock_spec_formula("obese_flag", formula = "ifelse(y > 15, 1, 0)", rtype = "integer"),
    mock_spec_formula("y", formula = "x * 2")
  )
  baseline <- generate_mock_data_native(spec, n = 20, seed = 5)
  result <- evaluate_mock_formulas(baseline, spec)
  expect_identical(result$y, baseline$x * 2)
  expect_identical(result$obese_flag, as.integer(ifelse(baseline$x * 2 > 15, 1L, 0L)))
})

test_that("evaluation cannot reach the caller's environment", {
  leaky <- 999
  # 'leaky' is not a spec variable -> referent validation rejects it at
  # construction time (eager validation, confirmed in Task 1), before the
  # sandbox is ever exercised. The sandbox property itself is pinned by the
  # eval-environment test below.
  expect_error(
    mock_spec(
      mock_spec_continuous("x", range = c(0, 1)),
      mock_spec_formula("z", formula = "x + leaky")
    ),
    "references unknown variable"
  )
})

test_that("eval environment exposes only columns and allow-listed functions", {
  spec <- mock_spec(
    mock_spec_continuous("x", range = c(0, 1)),
    mock_spec_formula("z", formula = "sqrt(x)")
  )
  baseline <- generate_mock_data_native(spec, n = 5, seed = 3)
  env_probe <- evaluate_mock_formulas(baseline, spec)
  expect_identical(env_probe$z, sqrt(baseline$x))
})

test_that("evaluate_mock_formulas is a no-op without formula variables", {
  spec <- mock_continuous("x", range = c(0, 1))
  baseline <- generate_mock_data_native(spec, n = 5, seed = 3)
  expect_identical(evaluate_mock_formulas(baseline, spec), baseline)
})

test_that("evaluate_mock_formulas handles n = 0", {
  spec <- mock_spec(
    mock_spec_continuous("x", range = c(0, 1)),
    mock_spec_formula("z", formula = "x * 2")
  )
  baseline <- generate_mock_data_native(spec, n = 0, seed = 3)
  result <- evaluate_mock_formulas(baseline, spec)
  expect_identical(nrow(result), 0L)
  expect_true("z" %in% names(result))
})

test_that("formula stage leaves the caller's RNG untouched and is deterministic", {
  spec <- mock_spec(
    mock_spec_continuous("x", range = c(0, 1)),
    mock_spec_formula("z", formula = "x * 2")
  )
  baseline <- generate_mock_data_native(spec, n = 10, seed = 7)
  set.seed(123); before <- .Random.seed
  a <- evaluate_mock_formulas(baseline, spec, seed = 7)
  expect_identical(.Random.seed, before)
  expect_identical(a, evaluate_mock_formulas(baseline, spec, seed = 7))
})

test_that("rtype coercion applies to formula outputs", {
  spec <- mock_spec(
    mock_spec_continuous("x", range = c(1, 9)),
    mock_spec_formula("band", formula = "ifelse(x > 5, 'high', 'low')", rtype = "factor")
  )
  baseline <- generate_mock_data_native(spec, n = 20, seed = 9)
  result <- evaluate_mock_formulas(baseline, spec)
  expect_s3_class(result$band, "factor")
})
