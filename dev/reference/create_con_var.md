# Create continuous variable for MockData

Creates a continuous mock variable based on specifications from
variable_details.

## Usage

``` r
create_con_var(
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
  prop_NA = NULL,
  prop_invalid = NULL,
  distribution = "uniform"
)
```

## Arguments

- var_row:

  data.frame. Single row from mock_data_config (contains variable
  metadata)

- details_subset:

  data.frame. Rows from mock_data_config_details for this variable

- n:

  integer. Number of observations to generate

- seed:

  integer. Random seed for reproducibility. If NULL, uses global seed.

- df_mock:

  data.frame. The current mock data (to check if variable already
  exists)

  **Configuration v0.1 format (LEGACY):**

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

- prop_NA:

  numeric. Optional. Proportion of NA values (0 to 1). If NULL, no NAs
  introduced.

- prop_invalid:

  numeric. Optional. Proportion of invalid out-of-range values (0 to 1).
  If NULL, no invalid values generated.

- distribution:

  character. Distribution type: "uniform" (default) or "normal"

## Value

data.frame with one column (the new continuous variable), or NULL if:

- Variable details not found (v0.1 only)

- Variable already exists in df_mock

- No valid range found

## Details

**Configuration v0.2 format (NEW):**

**v0.2 format (NEW):**

- Uses
  [`extract_distribution_params()`](https://big-life-lab.github.io/MockData/reference/extract_distribution_params.md)
  to get distribution parameters from details_subset

- Generates population based on specified distribution (uniform, normal,
  exponential)

- Applies missing codes with
  [`apply_missing_codes()`](https://big-life-lab.github.io/MockData/reference/apply_missing_codes.md)

- Adds garbage using
  [`make_garbage()`](https://big-life-lab.github.io/MockData/reference/make_garbage.md)
  if garbage rows present

- Supports fallback mode: uniform `[0, 100]` when details_subset is NULL

**v0.1 format (LEGACY):**

- Uses
  [`get_variable_details_for_raw()`](https://big-life-lab.github.io/MockData/reference/get_variable_details_for_raw.md)
  to find variable specifications

- Parses ranges from recStart using
  [`parse_range_notation()`](https://big-life-lab.github.io/MockData/reference/parse_range_notation.md)

- Supports "uniform" or "normal" distribution via parameter

- Handles prop_NA and prop_invalid parameters

The function auto-detects which format based on parameter names.

**Type coercion (rType):** If the metadata contains an `rType` column,
values will be coerced to the specified R type:

- `"integer"`: Rounds and converts to integer (e.g., for age, counts,
  years)

- `"double"`: Converts to double (default for continuous variables)

- Other types are passed through without coercion

This allows age variables to return integers (45L) instead of doubles
(45.0), matching real survey data. If `rType` is not specified, defaults
to double.

## See also

Other generators:
[`create_cat_var()`](https://big-life-lab.github.io/MockData/reference/create_cat_var.md),
[`create_date_var()`](https://big-life-lab.github.io/MockData/reference/create_date_var.md),
[`create_survival_dates()`](https://big-life-lab.github.io/MockData/reference/create_survival_dates.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# v0.2 format - called by create_mock_data()
config <- read_mock_data_config("mock_data_config.csv")
details <- read_mock_data_config_details("mock_data_config_details.csv")
var_row <- config[config$variable == "ALW_2A1", ]
details_subset <- get_variable_details(details, variable_name = "ALW_2A1")
mock_var <- create_con_var(var_row, details_subset, n = 1000, seed = 123)

# v0.1 format (legacy)
mock_drinks <- create_con_var(
  var_raw = "alcdwky",
  cycle = "cycle1",
  variable_details = variable_details,
  length = 1000,
  df_mock = existing_data,
  prop_NA = 0.02,
  distribution = "normal"
)
} # }
```
