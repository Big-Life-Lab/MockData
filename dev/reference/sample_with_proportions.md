# Sample with proportions

Generates category assignments with specified proportions. Handles NA
proportions (uniform fallback) and validates inputs.

## Usage

``` r
sample_with_proportions(categories, proportions, n, seed = NULL)
```

## Arguments

- categories:

  Character or numeric vector. Category values.

- proportions:

  Numeric vector. Proportions (same length, sum to 1.0).

- n:

  Integer. Number of samples.

- seed:

  Integer. Optional random seed.

## Value

Vector of length n with category assignments.

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
[`make_garbage()`](https://big-life-lab.github.io/MockData/reference/make_garbage.md)

## Examples

``` r
if (FALSE) { # \dontrun{
categories <- c("1", "2", "7", "9")
proportions <- c(0.4, 0.52, 0.03, 0.05)
assignments <- sample_with_proportions(categories, proportions, n = 1000)
} # }
```
