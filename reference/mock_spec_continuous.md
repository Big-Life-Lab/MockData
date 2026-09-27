# Create a continuous variable specification

Create a continuous variable specification

## Usage

``` r
mock_spec_continuous(
  name,
  range,
  distribution = "uniform",
  mean = NA_real_,
  sd = NA_real_,
  rtype = "double",
  rate = NA_real_,
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

- range:

  Numeric vector of length two giving the inclusive valid range.

- distribution:

  Distribution name. Defaults to `"uniform"`.

- mean, sd:

  Optional distribution parameters.

- rtype:

  R output type. Defaults to `"double"`.

- rate:

  Rate parameter; required when `distribution = "exponential"`.

- missing_codes:

  Explicit missing-code values.

- missing_proportions:

  Missing-code probabilities aligned to `missing_codes`.

- garbage_rules:

  List of intentional invalid-value rules.

- provenance:

  Provenance metadata.

- model_hint:

  Backend hint.

## Value

A `mock_spec_variable` object.

## See also

[`mock_spec()`](https://big-life-lab.github.io/MockData/reference/mock_spec.md),
[`mock_continuous()`](https://big-life-lab.github.io/MockData/reference/mock_continuous.md)

Other mock specification APIs:
[`mock_spec()`](https://big-life-lab.github.io/MockData/reference/mock_spec.md),
[`mock_spec_categorical()`](https://big-life-lab.github.io/MockData/reference/mock_spec_categorical.md),
[`mock_spec_date()`](https://big-life-lab.github.io/MockData/reference/mock_spec_date.md),
[`mock_spec_formula()`](https://big-life-lab.github.io/MockData/reference/mock_spec_formula.md),
[`mock_spec_from_recodeflow()`](https://big-life-lab.github.io/MockData/reference/mock_spec_from_recodeflow.md),
[`mock_spec_survival()`](https://big-life-lab.github.io/MockData/reference/mock_spec_survival.md)

## Examples

``` r
age <- mock_spec_continuous(
  "age",
  range = c(18, 85),
  distribution = "normal",
  mean = 50,
  sd = 12,
  rtype = "integer"
)

wait_spec <- mock_spec_continuous(
  "wait",
  range = c(0, 100),
  distribution = "exponential",
  rate = 0.1
)
```
