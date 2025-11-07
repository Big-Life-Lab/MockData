# Apply missing codes to values

Replaces category assignments with actual missing code values (7, 8, 9,
etc.). Handles different data types (numeric, Date, character).

## Usage

``` r
apply_missing_codes(values, category_assignments, missing_code_map)
```

## Arguments

- values:

  Vector. Generated values (numeric, date, or categorical).

- category_assignments:

  Vector. Category assignments ("valid", "7", "8", "9", etc.).

- missing_code_map:

  Named list. Maps category names to codes (e.g., list("7" = 7, "9" =
  9)).

## Value

Vector with missing codes applied.

## See also

Other mockdata-helpers:
[`apply_rtype_defaults()`](https://big-life-lab.github.io/MockData/reference/apply_rtype_defaults.md),
[`extract_distribution_params()`](https://big-life-lab.github.io/MockData/reference/extract_distribution_params.md),
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
values <- c(23.5, 45.2, 18.9, 30.1, 25.6)
assignments <- c("valid", "valid", "7", "valid", "9")
missing_map <- list("7" = 7, "9" = 9)
result <- apply_missing_codes(values, assignments, missing_map)
# Returns: c(23.5, 45.2, 7, 30.1, 9)
} # }
```
