# Create a direct continuous mock-data specification

`mock_continuous()` is the simple direct API for continuous variables.
It returns a validated `mock_spec`; it does not generate data.
Generation backends will consume this specification in a later v0.4
milestone.

## Usage

``` r
mock_continuous(
  name,
  range,
  distribution = "uniform",
  mean = NA_real_,
  sd = NA_real_,
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

- range:

  Numeric vector of length two giving the inclusive valid range.

- distribution:

  Distribution name. Defaults to `"uniform"`.

- mean, sd:

  Optional distribution parameters. Required when
  `distribution = "normal"`.

- rtype:

  R output type. Defaults to `"double"`.

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

A validated `mock_spec` object containing one continuous variable.

## Details

Use `mock_continuous()` when specifying one variable directly in R code.
Use
[`mock_spec_continuous()`](https://big-life-lab.github.io/MockData/reference/mock_spec_continuous.md)
with
[`mock_spec()`](https://big-life-lab.github.io/MockData/reference/mock_spec.md)
when composing several variables or when writing an adapter from another
metadata source.

## See also

[`mock_spec()`](https://big-life-lab.github.io/MockData/reference/mock_spec.md),
[`mock_spec_continuous()`](https://big-life-lab.github.io/MockData/reference/mock_spec_continuous.md)

Other direct specification APIs:
[`mock_categorical()`](https://big-life-lab.github.io/MockData/reference/mock_categorical.md),
[`mock_date()`](https://big-life-lab.github.io/MockData/reference/mock_date.md)

## Examples

``` r
age_spec <- mock_continuous(
  "age",
  range = c(18, 85),
  distribution = "normal",
  mean = 50,
  sd = 12,
  rtype = "integer"
)
validate_mock_spec(age_spec)
#> MockData mock_spec validation result: valid
```
