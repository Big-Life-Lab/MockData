# Convert recodeflow metadata to a MockData specification

`mock_spec_from_recodeflow()` adapts recodeflow-style `variables` and
`variable_details` metadata into the normalized v0.4 `mock_spec` shape.
It returns a validated specification; it does not generate data.

## Usage

``` r
mock_spec_from_recodeflow(
  variables,
  variable_details = NULL,
  databaseStart = NULL,
  role = "enabled",
  exclude_derived = TRUE,
  spec_version = .mock_spec_version,
  model_hint = "auto"
)
```

## Arguments

- variables:

  Data frame or CSV path for recodeflow-style `variables` metadata.

- variable_details:

  Data frame, CSV path, or `NULL` for recodeflow-style
  `variable_details` metadata.

- databaseStart:

  Optional database/cycle token used to filter metadata by exact
  comma-separated `databaseStart` values.

- role:

  Character vector of role tokens to include. Defaults to `"enabled"`.
  Use `NULL` to skip role filtering.

- exclude_derived:

  Logical. If `TRUE`, exclude variables identified by `DerivedVar::` or
  `Func::` rows in `variable_details`.

- spec_version:

  Character version of the specification shape.

- model_hint:

  Backend hint for the returned specification.

## Value

A validated `mock_spec` object.

## Details

This adapter preserves recodeflow semantics instead of treating metadata
as a generic table. It uses exact role and `databaseStart` token
matching, parses valid ranges from `recStart`, classifies missing codes
from `recEnd` values that begin with `NA::`, preserves categorical
levels and proportions, carries `garbage_*` settings into
`garbage_rules`, and stores survival/date fields such as `rate`,
`shape`, `followup_min`, `followup_max`, and `event_prop` on date
variables for later backend milestones.

By default, variables identified by `DerivedVar::` or `Func::` rows are
excluded because they should be evaluated after raw mock variables are
generated. Set `exclude_derived = FALSE` only when you want those rows
to appear in the adapter input and fail or be handled by later formula
support.

CSV path inputs are read with `stringsAsFactors = FALSE`,
`check.names = FALSE`, and `na.strings = c("", "NA")` so path-based
inputs preserve recodeflow column names and treat blank metadata cells
like missing values. The adapter normalizes `rType = "numeric"` to
`"double"` to match the v0.4 `mock_spec` type vocabulary.

## See also

[`mock_spec()`](https://big-life-lab.github.io/MockData/reference/mock_spec.md),
[`mock_continuous()`](https://big-life-lab.github.io/MockData/reference/mock_continuous.md),
[`mock_categorical()`](https://big-life-lab.github.io/MockData/reference/mock_categorical.md),
[`mock_date()`](https://big-life-lab.github.io/MockData/reference/mock_date.md),
[`generate_mock_data_native()`](https://big-life-lab.github.io/MockData/reference/generate_mock_data_native.md),
[`postprocess_mock_data()`](https://big-life-lab.github.io/MockData/reference/postprocess_mock_data.md)

Other mock specification APIs:
[`mock_spec()`](https://big-life-lab.github.io/MockData/reference/mock_spec.md),
[`mock_spec_categorical()`](https://big-life-lab.github.io/MockData/reference/mock_spec_categorical.md),
[`mock_spec_continuous()`](https://big-life-lab.github.io/MockData/reference/mock_spec_continuous.md),
[`mock_spec_date()`](https://big-life-lab.github.io/MockData/reference/mock_spec_date.md)

## Examples

``` r
variables <- data.frame(
  variable = "age",
  variableType = "Continuous",
  rType = "integer",
  role = "enabled",
  distribution = "uniform"
)
details <- data.frame(
  variable = "age",
  recStart = "[18, 85]",
  recEnd = "copy",
  proportion = 1
)
spec <- mock_spec_from_recodeflow(variables, details)
validate_mock_spec(spec)
#> MockData mock_spec validation result: valid

variables_file <- tempfile(fileext = ".csv")
details_file <- tempfile(fileext = ".csv")
write.csv(variables, variables_file, row.names = FALSE)
write.csv(details, details_file, row.names = FALSE)
spec_from_files <- mock_spec_from_recodeflow(variables_file, details_file)
```
