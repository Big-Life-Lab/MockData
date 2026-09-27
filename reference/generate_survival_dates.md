# Generate survival dates from their anchor dates

Computes each `type = "survival"` variable in `spec` from its anchor
column in `data`: `floor(n * event_prop)` rows receive a date a
follow-up time after the anchor (whole days, within
`[followup_min, followup_max]`), and the rest are `NA`. Variables are
processed in dependency order; each is drawn and then has its rules
applied: a date earlier than its anchor becomes `NA`, and, if
`censored_by` is set, a date later than the censoring date becomes `NA`.
Draws use the isolated `survival` sub-stream of the seed contract.

## Usage

``` r
generate_survival_dates(data, spec, seed = NULL)
```

## Arguments

- data:

  Data frame of generated baseline values (from
  [`generate_mock_data_native()`](https://big-life-lab.github.io/MockData/reference/generate_mock_data_native.md)
  or
  [`generate_mock_data_simstudy()`](https://big-life-lab.github.io/MockData/reference/generate_mock_data_simstudy.md)),
  containing each anchor column as class `Date`.

- spec:

  A `mock_spec`. Strict-validated at entry.

- seed:

  Optional whole-number seed. The caller's RNG state and kind are
  restored on exit.

## Value

`data` with one appended `Date` column per survival variable. Returns
`data` unchanged if the spec has no survival variables.

## Details

Survival dates describe true values.
[`postprocess_mock_data()`](https://big-life-lab.github.io/MockData/reference/postprocess_mock_data.md)
applies missing codes and garbage afterwards, independently for each
column.

## See also

[`mock_spec_survival()`](https://big-life-lab.github.io/MockData/reference/mock_spec_survival.md),
[`evaluate_mock_formulas()`](https://big-life-lab.github.io/MockData/reference/evaluate_mock_formulas.md),
[`postprocess_mock_data()`](https://big-life-lab.github.io/MockData/reference/postprocess_mock_data.md)

Other mock generation APIs:
[`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md),
[`generate_mock_data_native()`](https://big-life-lab.github.io/MockData/reference/generate_mock_data_native.md),
[`generate_mock_data_simstudy()`](https://big-life-lab.github.io/MockData/reference/generate_mock_data_simstudy.md),
[`postprocess_mock_data()`](https://big-life-lab.github.io/MockData/reference/postprocess_mock_data.md)

## Examples

``` r
spec <- mock_spec(
  mock_spec_date("entry", range = as.Date(c("2001-01-01", "2005-12-31"))),
  mock_spec_survival("death", anchor = "entry",
    followup_min = 365, followup_max = 7300, event_prop = 0.2)
)
baseline <- generate_mock_data_native(spec, n = 10, seed = 1)
generate_survival_dates(baseline, spec, seed = 1)
#>         entry      death
#> 1  2004-10-26       <NA>
#> 2  2004-10-14 2009-01-17
#> 3  2001-09-28       <NA>
#> 4  2004-04-09       <NA>
#> 5  2003-04-21       <NA>
#> 6  2004-12-21       <NA>
#> 7  2002-10-18       <NA>
#> 8  2005-12-14       <NA>
#> 9  2005-06-09 2011-02-24
#> 10 2001-02-16       <NA>
```
