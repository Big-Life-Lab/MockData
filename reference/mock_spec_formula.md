# Create a formula-derived variable specification

`mock_spec_formula()` describes a variable computed from other generated
variables by evaluating an algebraic expression (a `mockFormula`),
rather than sampled from a distribution. Evaluation happens in a
restricted environment exposing only the generated columns and a fixed
allow-list of base functions; see
[`evaluate_mock_formulas()`](https://big-life-lab.github.io/MockData/reference/evaluate_mock_formulas.md).

## Usage

``` r
mock_spec_formula(
  name,
  formula,
  rtype = "double",
  missing_codes = numeric(0),
  missing_proportions = numeric(0),
  garbage_rules = list(),
  provenance = "direct",
  model_hint = "auto"
)
```

## Arguments

- name:

  Variable name.

- formula:

  Character scalar. An algebraic expression over other variable names,
  e.g. `"weight / (height^2)"`.

- rtype:

  R output type for the computed column. Defaults to `"double"`.

- missing_codes, missing_proportions, garbage_rules, provenance,
  model_hint:

  As for other variable specifications; applied by post-processing.

## Value

A `mock_spec_variable` object of type `"formula"`.

## See also

[`mock_formula()`](https://big-life-lab.github.io/MockData/reference/mock_formula.md),
[`evaluate_mock_formulas()`](https://big-life-lab.github.io/MockData/reference/evaluate_mock_formulas.md)

Other mock specification APIs:
[`mock_spec()`](https://big-life-lab.github.io/MockData/reference/mock_spec.md),
[`mock_spec_categorical()`](https://big-life-lab.github.io/MockData/reference/mock_spec_categorical.md),
[`mock_spec_continuous()`](https://big-life-lab.github.io/MockData/reference/mock_spec_continuous.md),
[`mock_spec_date()`](https://big-life-lab.github.io/MockData/reference/mock_spec_date.md),
[`mock_spec_from_recodeflow()`](https://big-life-lab.github.io/MockData/reference/mock_spec_from_recodeflow.md),
[`mock_spec_survival()`](https://big-life-lab.github.io/MockData/reference/mock_spec_survival.md)
