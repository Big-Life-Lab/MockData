# Extract proportions from details subset

Parses proportion column and organizes by type (valid, missing,
garbage). Validates that valid + missing proportions sum to 1.0 (±0.001
tolerance). Auto-normalizes with warning if sum != 1.0.

## Usage

``` r
extract_proportions(details_subset, variable_name = "variable")
```

## Arguments

- details_subset:

  Data frame. Rows from details for one variable.

- variable_name:

  Character. Variable name for error messages.

## Value

Named list with:

- valid: Numeric. Proportion for valid values (sum of all non-missing,
  non-garbage)

- missing: Named list. Proportion for each missing code (e.g., "7" =
  0.03)

- garbage: Named list. Proportion for each garbage type (e.g.,
  corrupt_low = 0.02)

- categories: Character vector. All non-garbage recEnd values

- category_proportions: Numeric vector. Proportions for sampling
  (aligned with categories)

## Details

Population proportions (valid + missing) must sum to 1.0. Garbage
proportions are separate and applied to valid values only.

If proportions are NA or missing, returns uniform probabilities.

## See also

Other mockdata-helpers:
[`apply_missing_codes()`](https://big-life-lab.github.io/MockData/reference/apply_missing_codes.md),
[`apply_rtype_defaults()`](https://big-life-lab.github.io/MockData/reference/apply_rtype_defaults.md),
[`extract_distribution_params()`](https://big-life-lab.github.io/MockData/reference/extract_distribution_params.md),
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
details <- read_mock_data_config_details("details.csv")
details_subset <- details[details$variable == "ADL_01", ]
props <- extract_proportions(details_subset, "ADL_01")
# Returns: list(valid = 0.92, missing = list("7" = 0.03, "9" = 0.05), ...)
} # }
```
