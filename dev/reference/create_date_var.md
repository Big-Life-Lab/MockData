# Create date variable for MockData

Creates a mock date variable based on specifications from
variable_details.

## Usage

``` r
create_date_var(
  var_row = NULL,
  details_subset = NULL,
  n = NULL,
  seed = NULL,
  source_format = "analysis",
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

- source_format:

  character. Format to simulate post-import data: "analysis" (R Date
  objects), "csv" (character ISO strings), "sas" (numeric days since
  1960-01-01). Default: "analysis".

- df_mock:

  data.frame. The current mock data (to check if variable already
  exists)

  **Configuration v0.1 format (LEGACY):**

- var_raw:

  character. The RAW variable name (as it appears in source data)

- cycle:

  character. The database or cycle identifier (e.g., "cycle1", "HC1")

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

  numeric. Optional. Proportion of invalid out-of-period dates (0 to 1).
  If NULL, no invalid dates generated.

- distribution:

  character. Distribution type: "uniform" (default), "gompertz", or
  "exponential"

## Value

data.frame with one column (the new date variable), or NULL if:

- Variable details not found (v0.1 only)

- Variable already exists in df_mock

- No valid date range found

## Details

**Configuration v0.2 format (NEW):**

**v0.2 format (NEW):**

- Extracts date_start and date_end from details_subset

- Generates dates uniformly distributed between start and end

- Applies missing codes with
  [`apply_missing_codes()`](https://big-life-lab.github.io/MockData/reference/apply_missing_codes.md)

- Adds garbage using
  [`make_garbage()`](https://big-life-lab.github.io/MockData/reference/make_garbage.md)
  if garbage rows present

- Supports fallback mode: uniform distribution
  `[2000-01-01, 2025-12-31]` when details_subset is NULL

**v0.1 format (LEGACY):**

- Uses
  [`get_variable_details_for_raw()`](https://big-life-lab.github.io/MockData/reference/get_variable_details_for_raw.md)
  to find variable specifications

- Parses SAS date format from recStart: `"[01JAN2001, 31MAR2017]"`

- Supports "uniform", "gompertz", or "exponential" distribution

- Handles prop_NA and prop_invalid parameters

The function auto-detects which format based on parameter names.

## See also

Other generators:
[`create_cat_var()`](https://big-life-lab.github.io/MockData/reference/create_cat_var.md),
[`create_con_var()`](https://big-life-lab.github.io/MockData/reference/create_con_var.md),
[`create_survival_dates()`](https://big-life-lab.github.io/MockData/reference/create_survival_dates.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# v0.2 format - called by create_mock_data()
config <- read_mock_data_config("mock_data_config.csv")
details <- read_mock_data_config_details("mock_data_config_details.csv")
var_row <- config[config$variable == "index_date", ]
details_subset <- get_variable_details(details, variable_name = "index_date")
mock_var <- create_date_var(var_row, details_subset, n = 1000, seed = 123)

# v0.1 format (legacy)
mock_death_date <- create_date_var(
  var_raw = "death_date",
  cycle = "ices",
  variable_details = variable_details,
  length = 1000,
  df_mock = existing_data,
  prop_NA = 0.02,
  distribution = "gompertz"
)
} # }
```
