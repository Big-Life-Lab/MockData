# Generate mock data with the native backend

`generate_mock_data_native()` consumes a validated `mock_spec` and
generates baseline valid values using MockData's native R backend. This
milestone does not yet apply missing-code injection, garbage values,
diagnostics, formula evaluation, or optional `simstudy` features.

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

  Optional whole-number random seed. The previous R random state is
  restored after generation.

## Value

A data frame with one column per `mock_spec` variable and `n` rows.

## Details

The native backend is the default MIT-licensed baseline engine. It
currently supports uniform continuous variables, truncated-normal
continuous variables, categorical variables, and uniform calendar dates.
Missing codes, garbage values, and diagnostics are intentionally handled
by
[`postprocess_mock_data()`](https://big-life-lab.github.io/MockData/reference/postprocess_mock_data.md)
so that all backends share the same audit trail.

If `seed` is supplied, the previous R random state is restored after
generation. This gives reproducible output without advancing the
caller's RNG stream. Formula variables are rejected loudly until the
formula/dependency milestone promotes the spike evaluator into
production.

## See also

[`mock_spec()`](https://big-life-lab.github.io/MockData/reference/mock_spec.md),
[`mock_continuous()`](https://big-life-lab.github.io/MockData/reference/mock_continuous.md),
[`mock_spec_from_recodeflow()`](https://big-life-lab.github.io/MockData/reference/mock_spec_from_recodeflow.md),
[`postprocess_mock_data()`](https://big-life-lab.github.io/MockData/reference/postprocess_mock_data.md),
[`generate_mock_data_simstudy()`](https://big-life-lab.github.io/MockData/reference/generate_mock_data_simstudy.md)

Other mock generation APIs:
[`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md),
[`generate_mock_data_simstudy()`](https://big-life-lab.github.io/MockData/reference/generate_mock_data_simstudy.md),
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
#> 1  36   never
#> 2  43   never
#> 3  56  former
#> 4  79   never
#> 5  32  former
#> 6  78   never
```
