# Generate mock data with the native backend

`generate_mock_data_native()` consumes a validated `mock_spec` and
generates baseline valid values using MockData's native R backend. This
milestone does not yet apply missing-code injection, garbage values,
diagnostics, or optional `simstudy` features.

## Usage

``` r
generate_mock_data_native(spec, n, seed = NULL)
```

## Arguments

- spec:

  A `mock_spec` object.

- n:

  Non-negative whole number of rows to generate.

- seed:

  Optional whole-number seed. Generation uses an isolated L'Ecuyer-CMRG
  sub-stream and restores the caller's RNG state and kind on exit, so
  output is reproducible for a given seed and package version without
  perturbing the caller's RNG.

## Value

A data frame with `n` rows and one column per non-derived `mock_spec`
variable (`type = "survival"` and `type = "formula"` variables are
appended afterwards by
[`generate_survival_dates()`](https://big-life-lab.github.io/MockData/reference/generate_survival_dates.md)
and
[`evaluate_mock_formulas()`](https://big-life-lab.github.io/MockData/reference/evaluate_mock_formulas.md)).

## Details

The native backend is the default MIT-licensed baseline engine. It
currently supports uniform continuous variables, truncated-normal
continuous variables, truncated-exponential continuous variables,
categorical variables, and uniform calendar dates. Missing codes,
garbage values, and diagnostics are intentionally handled by
[`postprocess_mock_data()`](https://big-life-lab.github.io/MockData/reference/postprocess_mock_data.md)
so that all backends share the same audit trail.

`type = "formula"` variables are skipped by this backend — they carry no
distribution to sample from. They are computed post-baseline by
[`evaluate_mock_formulas()`](https://big-life-lab.github.io/MockData/reference/evaluate_mock_formulas.md),
which evaluates each formula over this function's output columns in
dependency order. A spec containing only formula variables still returns
an `n`-row, zero-column data frame here (see
[`evaluate_mock_formulas()`](https://big-life-lab.github.io/MockData/reference/evaluate_mock_formulas.md)
for how columns are appended afterwards). A stray `formula` field on a
variable of some other type remains an unsupported/fallback trigger.

## See also

[`mock_spec()`](https://big-life-lab.github.io/MockData/reference/mock_spec.md),
[`mock_continuous()`](https://big-life-lab.github.io/MockData/reference/mock_continuous.md),
[`mock_spec_from_recodeflow()`](https://big-life-lab.github.io/MockData/reference/mock_spec_from_recodeflow.md),
[`postprocess_mock_data()`](https://big-life-lab.github.io/MockData/reference/postprocess_mock_data.md),
[`generate_mock_data_simstudy()`](https://big-life-lab.github.io/MockData/reference/generate_mock_data_simstudy.md),
[`evaluate_mock_formulas()`](https://big-life-lab.github.io/MockData/reference/evaluate_mock_formulas.md)

Other mock generation APIs:
[`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md),
[`generate_mock_data_simstudy()`](https://big-life-lab.github.io/MockData/reference/generate_mock_data_simstudy.md),
[`generate_survival_dates()`](https://big-life-lab.github.io/MockData/reference/generate_survival_dates.md),
[`postprocess_mock_data()`](https://big-life-lab.github.io/MockData/reference/postprocess_mock_data.md)

## Examples

``` r
spec <- mock_spec(
  mock_spec_continuous("age", range = c(18, 85), rtype = "integer"),
  mock_spec_categorical(
    "smoking",
    levels = c("never", "former", "current"),
    proportions = c(0.5, 0.3, 0.2)
  )
)
data <- generate_mock_data_native(spec, n = 10, seed = 1)
head(data)
#>   age smoking
#> 1  63 current
#> 2  47 current
#> 3  79   never
#> 4  82  former
#> 5  74   never
#> 6  41   never
```
