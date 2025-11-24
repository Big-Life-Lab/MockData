# Apply garbage data from variables.csv

Applies garbage data using parameters from variables.csv extension
columns. Garbage data is specified at the variable level.

## Usage

``` r
apply_garbage(
  values,
  var_row,
  variable_type,
  missing_codes = NULL,
  seed = NULL
)
```

## Arguments

- values:

  Vector. Generated values (already has valid + missing).

- var_row:

  Data frame. Single row from variables.csv (contains garbage data
  parameters).

- variable_type:

  Character. "categorical", "continuous", "integer", "date".

- missing_codes:

  Numeric vector. Optional. Missing codes extracted from metadata (rows
  where recEnd contains "NA::"). Used to exclude missing codes from
  valid range calculations. If NULL, uses hardcoded fallback for
  backward compatibility.

- seed:

  Integer. Optional random seed.

## Value

Vector with garbage data applied.

## Details

**Garbage data fields (in variables.csv):**

**Garbage parameters:**

- garbage_low_prop: Proportion for low garbage values (0-1)

- garbage_low_range: Range for low values (interval notation "min,max")

- garbage_high_prop: Proportion for high garbage values (0-1)

- garbage_high_range: Range for high values (interval notation
  "min,max")

**Application order:**

1.  Apply garbage_low (if specified)

2.  Apply garbage_high (if specified)

3.  No overlap - indices removed after each application

**Config-driven generation:** If var_row is NULL or missing garbage
fields, no garbage data applied.

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
[`make_garbage()`](https://big-life-lab.github.io/MockData/reference/make_garbage.md),
[`sample_with_proportions()`](https://big-life-lab.github.io/MockData/reference/sample_with_proportions.md)

## Examples

``` r
if (FALSE) { # \dontrun{
var_row <- data.frame(
  variable = "BMI",
  garbage_low_prop = 0.02,
  garbage_low_range = "[-10,0]",
  garbage_high_prop = 0.01,
  garbage_high_range = "[60,150]"
)
values <- c(23.5, 45.2, 30.1, 18.9, 25.6)
result <- apply_garbage(values, var_row, "continuous", seed = 123)
} # }
```
