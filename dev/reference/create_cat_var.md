# Create categorical variable for MockData

Creates a categorical mock variable based on specifications from
variable_details.

## Usage

``` r
create_cat_var(
  var_row = NULL,
  details_subset = NULL,
  n = NULL,
  seed = NULL,
  df_mock = NULL,
  var_raw = NULL,
  cycle = NULL,
  variable_details = NULL,
  variables = NULL,
  length = NULL,
  proportions = NULL,
  prop_NA = NULL,
  prop_invalid = NULL
)
```

## Arguments

- var_row:

  data.frame. Single row from mock_data_config (for batch generation)

- details_subset:

  data.frame. Rows from mock_data_config_details (for batch generation)

- n:

  integer. Number of observations (for batch generation)

- seed:

  integer. Random seed for reproducibility. If NULL, uses global seed.

- df_mock:

  data.frame. Existing mock data (to check if variable already exists)

- var_raw:

  character. The RAW variable name (as it appears in source data)

- cycle:

  character. The cycle identifier (e.g., "cycle1", "HC1")

- variable_details:

  data.frame. Variable details metadata

- variables:

  data.frame. Variables metadata (optional, for validation)

- length:

  integer. The desired length of the mock data vector

- proportions:

  Proportions for category generation. Can be:

  - **NULL** (default): Uses uniform distribution across all categories

  - **Named list**: Maps category codes to proportions (e.g.,
    `list("1" = 0.25, "2" = 0.75)`)

  - **Numeric vector**: Proportions in same order as categories appear
    in variable_details

  If provided, overrides any proportion column in variable_details.
  Proportions will be normalized to sum to 1.

- prop_NA:

  numeric. Optional. Proportion of NA values (0 to 1). If NULL, no NAs
  introduced.

- prop_invalid:

  numeric. Optional. Proportion of invalid out-of-range category codes
  (0 to 1). If NULL, no invalid values generated.

## Value

data.frame with one column (the new categorical variable), or NULL if:

- Variable details not found

- Variable already exists in df_mock

- No categories found

## Details

The function determines proportions in this priority order:

1.  Explicit `proportions` parameter (if provided)

2.  `proportion` column in variable_details (if present)

3.  Uniform distribution (default fallback)

Uses
[`determine_proportions()`](https://big-life-lab.github.io/MockData/reference/determine_proportions.md)
helper to handle proportion logic cleanly. Generates values using
vectorized [`sample()`](https://rdrr.io/r/base/sample.html) for
efficiency.

**Type coercion (rType):** If the metadata contains an `rType` column,
values will be coerced to the specified R type:

- `"factor"`: Converts to factor with levels from category codes
  (default for categorical)

- `"character"`: Converts to character vector

- `"integer"`: Converts to integer (for numeric category codes)

- `"logical"`: Converts to logical (for TRUE/FALSE categories)

- Other types are passed through without coercion

This allows categorical variables to be returned as factors with proper
levels, or as other types appropriate to the data. If `rType` is not
specified, defaults to character.

## See also

Other generators:
[`create_con_var()`](https://big-life-lab.github.io/MockData/reference/create_con_var.md),
[`create_date_var()`](https://big-life-lab.github.io/MockData/reference/create_date_var.md),
[`create_survival_dates()`](https://big-life-lab.github.io/MockData/reference/create_survival_dates.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Uniform distribution (no proportions specified)
result <- create_cat_var(
  var_raw = "smoking",
  cycle = "cycle1",
  variable_details = variable_details,
  length = 1000
)

# Custom proportions with named list (recommended)
result <- create_cat_var(
  var_raw = "smoking",
  cycle = "cycle1",
  variable_details = variable_details,
  proportions = list(
    "1" = 0.25,   # Daily smoker
    "2" = 0.50,   # Occasional smoker
    "3" = 0.20,   # Never smoked
    "996" = 0.05  # Missing
  ),
  length = 1000,
  seed = 123
)

# Custom proportions with numeric vector
result <- create_cat_var(
  var_raw = "smoking",
  cycle = "cycle1",
  variable_details = variable_details,
  proportions = c(0.25, 0.50, 0.20, 0.05),
  length = 1000,
  seed = 123
)

# With data quality issues
result <- create_cat_var(
  var_raw = "smoking",
  cycle = "cycle1",
  variable_details = variable_details,
  proportions = list("1" = 0.3, "2" = 0.6, "3" = 0.1),
  length = 1000,
  prop_NA = 0.05,
  prop_invalid = 0.02,
  seed = 123
)
} # }
```
