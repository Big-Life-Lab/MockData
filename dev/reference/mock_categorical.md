# Create a direct categorical mock-data specification

`mock_categorical()` is the simple direct API for categorical variables.
It returns a validated `mock_spec`; it does not generate data.

## Usage

``` r
mock_categorical(
  name,
  levels,
  proportions = NULL,
  rtype = "factor",
  missing_codes = character(0),
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

- levels:

  Character vector of valid levels or codes.

- proportions:

  Optional probabilities aligned to `levels`.

- rtype:

  R output type. Defaults to `"factor"`.

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

A validated `mock_spec` object containing one categorical variable.

## Details

Use `mock_categorical()` when specifying one variable directly in R
code. Use
[`mock_spec_categorical()`](https://big-life-lab.github.io/MockData/reference/mock_spec_categorical.md)
with
[`mock_spec()`](https://big-life-lab.github.io/MockData/reference/mock_spec.md)
when composing several variables or when writing an adapter from another
metadata source.

## See also

[`mock_spec()`](https://big-life-lab.github.io/MockData/reference/mock_spec.md),
[`mock_spec_categorical()`](https://big-life-lab.github.io/MockData/reference/mock_spec_categorical.md)

Other direct specification APIs:
[`mock_continuous()`](https://big-life-lab.github.io/MockData/reference/mock_continuous.md),
[`mock_date()`](https://big-life-lab.github.io/MockData/reference/mock_date.md)

## Examples

``` r
smoking_spec <- mock_categorical(
  "smoking",
  levels = c("never", "former", "current"),
  proportions = c(0.5, 0.3, 0.2),
  rtype = "character"
)
validate_mock_spec(smoking_spec)
#> MockData mock_spec validation result: valid
```
