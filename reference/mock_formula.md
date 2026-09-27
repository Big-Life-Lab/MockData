# Create a direct formula-derived mock-data specification

`mock_formula()` is the simple direct API for formula-derived variables.
It returns a validated `mock_spec`; it does not generate data. Formula
variables have no `range`/`levels`/`distribution` of their own — their
values come from evaluating `formula` over other variables in the same
specification once those have been generated; see
[`evaluate_mock_formulas()`](https://big-life-lab.github.io/MockData/reference/evaluate_mock_formulas.md).

## Usage

``` r
mock_formula(
  name,
  formula,
  rtype = "double",
  missing_codes = numeric(0),
  missing_proportions = numeric(0),
  garbage_rules = list(),
  provenance = NULL,
  model_hint = "auto",
  spec_version = .mock_spec_version
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

- missing_codes:

  Explicit missing-code values.

- missing_proportions:

  Missing-code probabilities aligned to `missing_codes`.

- garbage_rules:

  List of intentional invalid-value rules.

- provenance:

  Optional provenance metadata. Defaults to the direct API.

- model_hint:

  Backend hint.

- spec_version:

  Character version of the specification shape.

## Value

A validated `mock_spec` object containing one formula variable.

## Details

Use `mock_formula()` when specifying one formula variable directly in R
code. Use
[`mock_spec_formula()`](https://big-life-lab.github.io/MockData/reference/mock_spec_formula.md)
with
[`mock_spec()`](https://big-life-lab.github.io/MockData/reference/mock_spec.md)
when composing several variables or when writing an adapter from another
metadata source.

## See also

[`mock_spec()`](https://big-life-lab.github.io/MockData/reference/mock_spec.md),
[`mock_spec_formula()`](https://big-life-lab.github.io/MockData/reference/mock_spec_formula.md),
[`evaluate_mock_formulas()`](https://big-life-lab.github.io/MockData/reference/evaluate_mock_formulas.md)

Other direct specification APIs:
[`mock_categorical()`](https://big-life-lab.github.io/MockData/reference/mock_categorical.md),
[`mock_continuous()`](https://big-life-lab.github.io/MockData/reference/mock_continuous.md),
[`mock_date()`](https://big-life-lab.github.io/MockData/reference/mock_date.md)

## Examples

``` r
bmi_spec <- mock_spec(
  mock_spec_continuous("height", range = c(1.4, 2.1)),
  mock_spec_continuous("weight", range = c(45, 150)),
  mock_spec_formula("bmi", formula = "weight / (height^2)")
)
validate_mock_spec(bmi_spec)
#> MockData mock_spec validation result: valid
```
