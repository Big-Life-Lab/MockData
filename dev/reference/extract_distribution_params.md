# Extract distribution parameters from details

Extracts distribution-specific parameters (mean, sd, rate, shape, range)
from details subset. Auto-detects distribution type if not specified.

## Usage

``` r
extract_distribution_params(details_subset, distribution_type = NULL)
```

## Arguments

- details_subset:

  Data frame. Rows from details for one variable.

- distribution_type:

  Character. Optional ("normal", "uniform", "gompertz", "exponential",
  "poisson"). If NULL, attempts auto-detection.

## Value

Named list with distribution type and parameters:

- distribution: Character. Distribution type.

- mean, sd: Numeric. For normal distribution.

- rate, shape: Numeric. For Gompertz/exponential.

- range_min, range_max: Numeric. For uniform or truncation.

## See also

Other mockdata-helpers:
[`apply_missing_codes()`](https://big-life-lab.github.io/MockData/reference/apply_missing_codes.md),
[`apply_rtype_defaults()`](https://big-life-lab.github.io/MockData/reference/apply_rtype_defaults.md),
[`extract_proportions()`](https://big-life-lab.github.io/MockData/reference/extract_proportions.md),
[`generate_garbage_values()`](https://big-life-lab.github.io/MockData/reference/generate_garbage_values.md),
[`get_cycle_variables()`](https://big-life-lab.github.io/MockData/reference/get_cycle_variables.md),
[`get_raw_variables()`](https://big-life-lab.github.io/MockData/reference/get_raw_variables.md),
[`get_variable_details()`](https://big-life-lab.github.io/MockData/reference/get_variable_details.md),
[`has_garbage()`](https://big-life-lab.github.io/MockData/reference/has_garbage.md),
[`make_garbage()`](https://big-life-lab.github.io/MockData/reference/make_garbage.md),
[`sample_with_proportions()`](https://big-life-lab.github.io/MockData/reference/sample_with_proportions.md)

## Examples

``` r
if (FALSE) { # \dontrun{
params <- extract_distribution_params(details_subset, "normal")
# Returns: list(distribution = "normal", mean = 25, sd = 5, range_min = 18.5, range_max = 40)
} # }
```
