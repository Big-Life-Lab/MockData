# Apply rType defaults to variable details

Adds rType column with smart defaults if missing. This enables
language-specific type coercion (R types like integer, double, factor).

## Usage

``` r
apply_rtype_defaults(details)
```

## Arguments

- details:

  Data frame. Variable details metadata.

## Value

Data frame with rType column added (if missing) or validated (if
present).

## Details

### Default rType values

If rType column is missing, defaults are applied based on variable type:

- `continuous`/`cont` → `"double"`

- `categorical`/`cat` → `"factor"`

- `date` → `"Date"`

- `logical` → `"logical"`

- Unknown → `"character"`

### Valid rType values

- `"integer"`: Whole numbers (age, counts, years)

- `"double"`: Decimal numbers (BMI, income, percentages)

- `"factor"`: Categorical with levels

- `"character"`: Text codes

- `"logical"`: TRUE/FALSE values

- `"Date"`: Date objects

- `"POSIXct"`: Datetime objects

## See also

Other mockdata-helpers:
[`apply_missing_codes()`](https://big-life-lab.github.io/MockData/reference/apply_missing_codes.md),
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
# Missing rType - defaults applied
details <- data.frame(
  variable = "age",
  typeEnd = "cont",
  recStart = "[18, 100]"
)
details <- apply_rtype_defaults(details)
# details$rType is now "double"

# Existing rType - preserved
details <- data.frame(
  variable = "age",
  typeEnd = "cont",
  rType = "integer"
)
details <- apply_rtype_defaults(details)
# details$rType remains "integer"
} # }
```
