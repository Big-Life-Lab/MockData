# Make garbage

Applies garbage model to introduce realistic data quality issues.
Replaces some valid values with implausible values (corrupt_low,
corrupt_high, corrupt_future, etc.).

## Usage

``` r
make_garbage(values, details_subset, variable_type, seed = NULL)
```

## Arguments

- values:

  Vector. Generated values (already has valid + missing).

- details_subset:

  Data frame. Rows from details (contains corrupt\_\* rows).

- variable_type:

  Character. "categorical", "continuous", "date", "survival".

- seed:

  Integer. Optional random seed.

## Value

Vector with garbage applied.

## Details

Two-step garbage model:

1.  Identify valid value indices (not missing codes)

2.  Sample from valid indices based on garbage proportions

3.  Replace with garbage values

4.  Ensure no overlap (use setdiff for sequential garbage application)

Garbage types:

- corrupt_low: Values below valid range (continuous, integer)

- corrupt_high: Values above valid range (continuous, integer)

- corrupt_future: Future dates (date, survival)

## See also

Other mockdata-helpers:
[`apply_missing_codes()`](https://big-life-lab.github.io/MockData/reference/apply_missing_codes.md),
[`apply_rtype_defaults()`](https://big-life-lab.github.io/MockData/reference/apply_rtype_defaults.md),
[`extract_distribution_params()`](https://big-life-lab.github.io/MockData/reference/extract_distribution_params.md),
[`extract_proportions()`](https://big-life-lab.github.io/MockData/reference/extract_proportions.md),
[`generate_garbage_values()`](https://big-life-lab.github.io/MockData/reference/generate_garbage_values.md),
[`get_cycle_variables()`](https://big-life-lab.github.io/MockData/reference/get_cycle_variables.md),
[`get_raw_variables()`](https://big-life-lab.github.io/MockData/reference/get_raw_variables.md),
[`get_variable_details()`](https://big-life-lab.github.io/MockData/reference/get_variable_details.md),
[`has_garbage()`](https://big-life-lab.github.io/MockData/reference/has_garbage.md),
[`sample_with_proportions()`](https://big-life-lab.github.io/MockData/reference/sample_with_proportions.md)

## Examples

``` r
if (FALSE) { # \dontrun{
values <- c(23.5, 45.2, 7, 30.1, 9, 18.9, 25.6)
result <- make_garbage(values, details_subset, "continuous", seed = 123)
# Some valid values replaced with implausible values
} # }
```
