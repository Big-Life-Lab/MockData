# Create date variable for MockData

Generates a date mock variable based on specifications from metadata.

## Usage

``` r
create_date_var(
  var,
  databaseStart,
  variables,
  variable_details,
  df_mock = NULL,
  prop_missing = 0,
  n,
  seed = NULL
)
```

## Arguments

- var:

  character. Variable name to generate (column name in output)

- databaseStart:

  character. Database/cycle identifier for filtering metadata (e.g.,
  "cchs2001_p", "minimal-example"). Used to filter variables and
  variable_details to the specified database.

- variables:

  data.frame or character. Variable-level metadata containing:

  - `variable`: Variable names

  - `database`: Database identifier (optional, for filtering)

  - `sourceFormat`: Output format ("analysis"/"csv"/"sas")

  - `distribution`: Distribution type (uniform/gompertz/exponential)

  - `followup_min`, `followup_max`: Followup period parameters

  - `event_prop`: Proportion experiencing event

  - `garbage_high_prop`, `garbage_high_range`: Garbage data parameters

  Can also be a file path (character) to variables.csv.

- variable_details:

  data.frame or character. Detail-level metadata containing:

  - `variable`: Variable name (for joining)

  - `recStart`: Date range (e.g., 01JAN2001,31DEC2020) or followup
    period

  - `recEnd`: Classification (copy, NA::a, NA::b)

  - `proportion`: Category proportion for missing codes

  Can also be a file path (character) to variable_details.csv.

- df_mock:

  data.frame. Optional. Existing mock data (to check if variable already
  exists). For survival variables, may contain anchor_date column for
  computing event dates.

- prop_missing:

  numeric. Proportion of missing values (0-1). Default 0 (no missing).

- n:

  integer. Number of observations to generate.

- seed:

  integer. Optional. Random seed for reproducibility.

## Value

data.frame with one column (the generated date variable), or NULL if:

- Variable not found in metadata

- Variable already exists in df_mock

- No valid date range found in variable_details

## Details

**v0.3.0 API**: This function now accepts full metadata data frames and
filters internally for the specified variable and database. This is the
"recodeflow pattern" where filtering is handled inside the function.

**Generation process**:

1.  Filter metadata: Extract rows for specified var + database

2.  Extract date parameters: Read from variables.csv and
    variable_details

3.  Generate population: Based on distribution type
    (uniform/gompertz/exponential)

4.  Apply missing codes: If proportions specified in metadata

5.  Apply garbage: Read garbage parameters from variables.csv

6.  Apply sourceFormat: Convert to specified format (analysis/csv/sas)

**Output format (sourceFormat)**: The sourceFormat column in
variables.csv controls output data type:

- `"analysis"`: R Date objects (default)

- `"csv"`: Character ISO strings (e.g., "2001-01-15")

- `"sas"`: Numeric days since 1960-01-01

**Distribution types**:

- `"uniform"`: Uniform distribution over date range

- `"gompertz"`: Gompertz survival distribution (for time-to-event data)

- `"exponential"`: Exponential distribution (events concentrated near
  start)

**Survival data generation**: For variables with
followup_min/followup_max/event_prop in variables.csv:

- Requires anchor_date column in df_mock (cohort entry/baseline date)

- Generates event times within followup window

- event_prop controls proportion experiencing event (vs. censored)

- Distribution controls event timing (Gompertz typical for survival)

**Missing data**: Missing codes are identified by recEnd containing
"NA::":

- `NA::a`: Skip codes (not applicable)

- `NA::b`: Missing codes (don't know, refusal, not stated)

**Garbage data**: Garbage parameters are read from variables.csv:

- `garbage_high_prop`, `garbage_high_range`: Future dates (temporal
  violations)

## See also

Other generators:
[`create_cat_var()`](https://big-life-lab.github.io/MockData/reference/create_cat_var.md),
[`create_con_var()`](https://big-life-lab.github.io/MockData/reference/create_con_var.md),
[`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md),
[`create_survival_dates()`](https://big-life-lab.github.io/MockData/reference/create_survival_dates.md),
[`create_wide_survival_data()`](https://big-life-lab.github.io/MockData/reference/create_wide_survival_data.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Basic usage with metadata data frames
interview_date <- create_date_var(
  var = "interview_date",
  databaseStart = "minimal-example",
  variables = variables,
  variable_details = variable_details,
  n = 1000,
  seed = 123
)

# Expected output: data.frame with 1000 rows, 1 column ("interview_date")
# Values: R Date objects (if sourceFormat="analysis" in metadata)
# Distribution: Based on distribution in metadata (uniform/gompertz)

# Survival data generation (requires anchor_date in df_mock)
death_date <- create_date_var(
  var = "death_date",
  databaseStart = "minimal-example",
  variables = variables,
  variable_details = variable_details,
  df_mock = df_mock,  # Must contain anchor_date column
  n = 1000,
  seed = 456
)
} # }
```
