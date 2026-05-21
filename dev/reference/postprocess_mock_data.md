# Apply mock_spec post-processing rules

`postprocess_mock_data()` applies v0.4 `mock_spec` missing-code and
garbage-value rules to an already generated baseline data frame. It
records a `mockdata_diagnostics` attribute so downstream checks can
distinguish values assigned by post-processing from values that were
drawn naturally by the baseline generator.

## Usage

``` r
postprocess_mock_data(data, spec, seed = NULL, diagnostics = TRUE)
```

## Arguments

- data:

  Data frame with one column for each variable in `spec`.

- spec:

  A validated `mock_spec` object.

- seed:

  Optional whole-number random seed. The previous R random state is
  restored after post-processing.

- diagnostics:

  Logical. If `TRUE`, attach a `mockdata_diagnostics` attribute to the
  returned data frame.

## Value

A data frame with post-processing applied.

## Details

Missing-code diagnostics separate values that were naturally drawn as a
declared missing code (`preexisting_missing_code_indices`) from values
that were assigned by post-processing (`assigned_missing_indices`).
Garbage rules are applied only to rows that are not missing-code
diagnostics, preserving the audit trail for collision cases such as a
valid category code that is also a declared missing code.

Garbage rules are applied in canonical order: `low`, then `high`, then
any other named rules in caller order. Each garbage rule is a named list
with a `proportion` field and a `range` field using MockData range
notation, for example
`list(high = list(proportion = 0.05, range = "[150, 200]"))`.

Diagnostics are stored as a data-frame attribute. Base R subsetting and
some downstream tools may drop attributes, so preserve the original
post-processed object when diagnostics are part of the audit trail.

## See also

[`generate_mock_data_native()`](https://big-life-lab.github.io/MockData/reference/generate_mock_data_native.md),
[`generate_mock_data_simstudy()`](https://big-life-lab.github.io/MockData/reference/generate_mock_data_simstudy.md),
[`mock_spec()`](https://big-life-lab.github.io/MockData/reference/mock_spec.md)

Other mock generation APIs:
[`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md),
[`generate_mock_data_native()`](https://big-life-lab.github.io/MockData/reference/generate_mock_data_native.md),
[`generate_mock_data_simstudy()`](https://big-life-lab.github.io/MockData/reference/generate_mock_data_simstudy.md)

## Examples

``` r
spec <- mock_categorical(
  "smoking",
  levels = c("never", "former", "current"),
  proportions = c(0.5, 0.3, 0.2),
  rtype = "character",
  missing_codes = "9",
  missing_proportions = 0.05
)
baseline <- generate_mock_data_native(spec, n = 20, seed = 1)
result <- postprocess_mock_data(baseline, spec, seed = 2)
attr(result, "mockdata_diagnostics")$variables$smoking
#> $n
#> [1] 20
#> 
#> $preexisting_missing_code_indices
#> integer(0)
#> 
#> $assigned_missing_indices
#> [1] 15
#> 
#> $assigned_missing_codes
#> [1] "9"
#> 
#> $assigned_garbage_indices
#> named list()
#> 
#> $assigned_garbage_values
#> named list()
#> 
```
