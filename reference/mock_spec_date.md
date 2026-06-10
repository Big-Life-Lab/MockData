# Create a date variable specification

Create a date variable specification

## Usage

``` r
mock_spec_date(
  name,
  range,
  rtype = "date",
  source_format = "analysis",
  missing_codes = character(0),
  missing_proportions = numeric(0),
  garbage_rules = list(),
  provenance = "direct",
  model_hint = "native-postprocess"
)
```

## Arguments

- name:

  Variable name.

- range:

  Date vector of length two giving the inclusive valid date range.

- rtype:

  R output type. Defaults to `"date"`.

- source_format:

  Source-format hint. Defaults to `"analysis"`.

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
[`mock_date()`](https://big-life-lab.github.io/MockData/reference/mock_date.md)

Other mock specification APIs:
[`mock_spec()`](https://big-life-lab.github.io/MockData/reference/mock_spec.md),
[`mock_spec_categorical()`](https://big-life-lab.github.io/MockData/reference/mock_spec_categorical.md),
[`mock_spec_continuous()`](https://big-life-lab.github.io/MockData/reference/mock_spec_continuous.md),
[`mock_spec_from_recodeflow()`](https://big-life-lab.github.io/MockData/reference/mock_spec_from_recodeflow.md)

## Examples

``` r
interview_date <- mock_spec_date(
  "interview_date",
  range = as.Date(c("2001-01-01", "2005-12-31"))
)
```
