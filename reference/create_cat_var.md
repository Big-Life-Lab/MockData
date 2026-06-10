# Create categorical variable for MockData

Generates a categorical mock variable based on specifications from
metadata.

## Usage

``` r
create_cat_var(
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

  - `rType`: R output type (factor/character/integer/logical)

  - `garbage_low_prop`, `garbage_high_prop`: Garbage data parameters

  Can also be a file path (character) to variables.csv.

- variable_details:

  data.frame or character. Detail-level metadata containing:

  - `variable`: Variable name (for joining)

  - `recStart`: Category code or range

  - `recEnd`: Classification (numeric code, "NA::a", "NA::b")

  - `proportion`: Category proportion (0-1, must sum to 1)

  - `catLabel`: Category label/description

  Can also be a file path (character) to variable_details.csv.

- df_mock:

  data.frame. Optional. Existing mock data (to check if variable already
  exists).

- prop_missing:

  numeric. Proportion of missing values (0-1). Default 0 (no missing).
  If \> 0, function looks for rows with recEnd containing "NA::" in
  variable_details.

- n:

  integer. Number of observations to generate.

- seed:

  integer. Optional. Random seed for reproducibility.

## Value

data.frame with one column (the generated categorical variable), or NULL
if:

- Variable already exists in df_mock (a message is emitted)

- No valid categories found in variable_details

Errors if the variable is not found in the variables metadata. Warns and
uses the first row if multiple variables rows match.

## Details

**v0.3.0 API**: This function now accepts full metadata data frames and
filters internally for the specified variable and database. This is the
"recodeflow pattern" where filtering is handled inside the function.

**Generation process**:

1.  Filter metadata: Extract rows for specified var + database

2.  Extract proportions: Read from variable_details (proportion column)

3.  Generate population: Sample categories based on proportions

4.  Apply missing codes: If prop_missing \> 0 or proportions in metadata

5.  Apply garbage: Read garbage parameters from variables.csv

6.  Apply rType: Coerce to specified R type
    (factor/character/integer/logical)

**Type coercion (rType)**: The rType column in variables.csv controls
output data type:

- `"factor"`: Factor with levels from category codes (default for
  categorical)

- `"character"`: Character vector

- `"integer"`: Integer (for numeric category codes)

- `"logical"`: Logical (for TRUE/FALSE categories)

**Missing data**: Missing codes are identified by `recEnd` containing
"NA::":

- `NA::a`: Skip codes (not applicable)

- `NA::b`: Missing codes (don't know, refusal, not stated)

Proportions for missing codes are read from the proportion column in
variable_details.

**Garbage data**: Garbage parameters are read from variables.csv:

- `garbage_low_prop`, `garbage_low_range`: Below-range invalid values

- `garbage_high_prop`, `garbage_high_range`: Above-range invalid values

## See also

Other generators:
[`create_con_var()`](https://big-life-lab.github.io/MockData/reference/create_con_var.md),
[`create_date_var()`](https://big-life-lab.github.io/MockData/reference/create_date_var.md),
[`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md),
[`create_survival_dates()`](https://big-life-lab.github.io/MockData/reference/create_survival_dates.md),
[`create_wide_survival_data()`](https://big-life-lab.github.io/MockData/reference/create_wide_survival_data.md)

## Examples

``` r
variables <- data.frame(
  variable = "smoking",
  variableType = "Categorical",
  rType = "factor",
  stringsAsFactors = FALSE
)
variable_details <- data.frame(
  variable = "smoking",
  recStart = c("1", "2", "3", "7"),
  recEnd = c("1", "2", "3", "NA::b"),
  proportion = c(0.5, 0.3, 0.17, 0.03),
  catLabel = c(
    "Never smoker", "Former smoker", "Current smoker", "Don't know"
  ),
  stringsAsFactors = FALSE
)

smoking <- create_cat_var(
  var = "smoking",
  databaseStart = "example",
  variables = variables,
  variable_details = variable_details,
  n = 100,
  seed = 123
)
# Code 7 ("Don't know") is an NA::b missing code, generated at its
# configured proportion alongside the substantive categories.
table(smoking$smoking)
#> 
#>  1  2  3  7 
#> 51 31 15  3 

if (FALSE) { # \dontrun{
# Not run: requires your own metadata CSV files
# With file paths instead of data frames
result <- create_cat_var(
  var = "smoking",
  databaseStart = "cchs2001_p",
  variables = "path/to/variables.csv",
  variable_details = "path/to/variable_details.csv",
  n = 1000
)
} # }
```
