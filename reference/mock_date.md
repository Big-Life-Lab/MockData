# Create a direct date mock-data specification

`mock_date()` is the simple direct API for date variables. It returns a
validated `mock_spec`; it does not generate data.

## Usage

``` r
mock_date(
  name,
  range,
  rtype = "date",
  source_format = "analysis",
  missing_codes = character(0),
  missing_proportions = numeric(0),
  garbage_rules = list(),
  provenance = NULL,
  model_hint = "native-postprocess",
  spec_version = .mock_spec_version
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

  Optional provenance metadata. Defaults to the direct API.

- model_hint:

  Backend hint.

- spec_version:

  Character version of the specification shape.

## Value

A validated `mock_spec` object containing one date variable.

## Details

Date variables default to `model_hint = "native-postprocess"` because
MockData owns calendar-date generation and source-format conversion.
Optional backends may still generate other variables in the same
specification.

## See also

[`mock_spec()`](https://big-life-lab.github.io/MockData/reference/mock_spec.md),
[`mock_spec_date()`](https://big-life-lab.github.io/MockData/reference/mock_spec_date.md)

Other direct specification APIs:
[`mock_categorical()`](https://big-life-lab.github.io/MockData/reference/mock_categorical.md),
[`mock_continuous()`](https://big-life-lab.github.io/MockData/reference/mock_continuous.md)

## Examples

``` r
interview_date_spec <- mock_date(
  "interview_date",
  range = as.Date(c("2001-01-01", "2005-12-31"))
)
validate_mock_spec(interview_date_spec)
#> MockData mock_spec validation result: valid
```
