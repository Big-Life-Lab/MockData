# Create a categorical variable specification

Create a categorical variable specification

## Usage

``` r
mock_spec_categorical(
  name,
  levels,
  proportions = NULL,
  rtype = "factor",
  missing_codes = character(0),
  missing_proportions = numeric(0),
  garbage_rules = list(),
  provenance = "direct",
  model_hint = "auto"
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

  Provenance metadata.

- model_hint:

  Backend hint.

## Value

A `mock_spec_variable` object.

## See also

[`mock_spec()`](https://big-life-lab.github.io/MockData/reference/mock_spec.md),
[`mock_categorical()`](https://big-life-lab.github.io/MockData/reference/mock_categorical.md)

Other mock specification APIs:
[`mock_spec()`](https://big-life-lab.github.io/MockData/reference/mock_spec.md),
[`mock_spec_continuous()`](https://big-life-lab.github.io/MockData/reference/mock_spec_continuous.md),
[`mock_spec_date()`](https://big-life-lab.github.io/MockData/reference/mock_spec_date.md),
[`mock_spec_from_recodeflow()`](https://big-life-lab.github.io/MockData/reference/mock_spec_from_recodeflow.md)

## Examples

``` r
smoking <- mock_spec_categorical(
  "smoking",
  levels = c("never", "former", "current"),
  proportions = c(0.5, 0.3, 0.2),
  rtype = "character"
)
```
