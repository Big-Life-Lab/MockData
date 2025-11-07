# Get variable details for specific variable

Filters details data frame to return only rows for a specific variable.
Handles NULL details (fallback mode) and provides consistent sorting.

## Usage

``` r
get_variable_details(details, variable_name = NULL, uid = NULL)
```

## Arguments

- details:

  Data frame. Full details data (or NULL for fallback mode).

- variable_name:

  Character. Variable name to filter (e.g., "ADL_01").

- uid:

  Character. Alternative - filter by uid (e.g., "v_001").

## Value

Subset of details rows for this variable, sorted by uid_detail. Returns
NULL if details is NULL (signals fallback mode). Returns empty data
frame with warning if no matching rows.

## See also

Other mockdata-helpers:
[`apply_missing_codes()`](https://big-life-lab.github.io/MockData/reference/apply_missing_codes.md),
[`apply_rtype_defaults()`](https://big-life-lab.github.io/MockData/reference/apply_rtype_defaults.md),
[`extract_distribution_params()`](https://big-life-lab.github.io/MockData/reference/extract_distribution_params.md),
[`extract_proportions()`](https://big-life-lab.github.io/MockData/reference/extract_proportions.md),
[`generate_garbage_values()`](https://big-life-lab.github.io/MockData/reference/generate_garbage_values.md),
[`get_cycle_variables()`](https://big-life-lab.github.io/MockData/reference/get_cycle_variables.md),
[`get_raw_variables()`](https://big-life-lab.github.io/MockData/reference/get_raw_variables.md),
[`has_garbage()`](https://big-life-lab.github.io/MockData/reference/has_garbage.md),
[`make_garbage()`](https://big-life-lab.github.io/MockData/reference/make_garbage.md),
[`sample_with_proportions()`](https://big-life-lab.github.io/MockData/reference/sample_with_proportions.md)

## Examples

``` r
if (FALSE) { # \dontrun{
details <- read_mock_data_config_details("details.csv")
var_details <- get_variable_details(details, variable_name = "ADL_01")

# Fallback mode
var_details <- get_variable_details(NULL, variable_name = "ADL_01")
# Returns: NULL
} # }
```
