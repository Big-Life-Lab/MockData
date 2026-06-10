# Create continuous variable for MockData

Generates a continuous mock variable based on specifications from
metadata.

## Usage

``` r
create_con_var(
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

  - `rType`: R output type (integer/double)

  - `distribution`: Distribution type (uniform/normal/exponential)

  - `mean`, `sd`: Normal distribution parameters

  - `rate`, `shape`: Exponential/Gompertz parameters

  - `garbage_low_prop`, `garbage_high_prop`: Garbage data parameters

  Can also be a file path (character) to variables.csv.

- variable_details:

  data.frame or character. Detail-level metadata containing:

  - `variable`: Variable name (for joining)

  - `recStart`: Valid range in interval notation (e.g., `[18,100]`)

  - `recEnd`: Classification (copy, NA::a, NA::b)

  - `proportion`: Category proportion for missing codes

  Can also be a file path (character) to variable_details.csv.

- df_mock:

  data.frame. Optional. Existing mock data (to check if variable already
  exists).

- prop_missing:

  numeric. Proportion of missing values (0-1). Default 0 (no missing).

- n:

  integer. Number of observations to generate.

- seed:

  integer. Optional. Random seed for reproducibility.

## Value

data.frame with one column (the generated continuous variable), or NULL
(with a message) if the variable already exists in df_mock.

Errors if the variable is not found in the variables metadata. Warns and
uses the first row if multiple variables rows match.

## Details

**v0.3.0 API**: This function now accepts full metadata data frames and
filters internally for the specified variable and database. This is the
"recodeflow pattern" where filtering is handled inside the function.

**Generation process**:

1.  Filter metadata: Extract rows for specified var + database

2.  Extract distribution parameters: Read from variables.csv

3.  Extract valid range: Parse from variable_details recStart column

4.  Generate population: Based on distribution type
    (uniform/normal/exponential)

5.  Apply missing codes: If proportions specified in metadata

6.  Apply garbage: Read garbage parameters from variables.csv

7.  Apply rType: Coerce to specified R type (integer/double)

**Type coercion (rType)**: The rType column in variables.csv controls
output data type:

- `\"integer\"`: Rounds and converts to integer (for age, counts)

- `\"double\"`: Double precision (default for continuous)

**Distribution types**:

- `\"uniform\"`: Uniform distribution over `[min, max]` from recStart

- `\"normal\"`: Normal distribution (requires mean, sd in variables.csv)

- `\"exponential\"`: Exponential distribution (requires rate in
  variables.csv)

**Missing data**: Missing codes are identified by recEnd containing
"NA::":

- `NA::a`: Skip codes (not applicable)

- `NA::b`: Missing codes (don't know, refusal, not stated)

**Garbage data**: Garbage parameters are read from variables.csv:

- `garbage_low_prop`, `garbage_low_range`: Below-range invalid values

- `garbage_high_prop`, `garbage_high_range`: Above-range invalid values

## See also

Other generators:
[`create_cat_var()`](https://big-life-lab.github.io/MockData/reference/create_cat_var.md),
[`create_date_var()`](https://big-life-lab.github.io/MockData/reference/create_date_var.md),
[`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md),
[`create_survival_dates()`](https://big-life-lab.github.io/MockData/reference/create_survival_dates.md),
[`create_wide_survival_data()`](https://big-life-lab.github.io/MockData/reference/create_wide_survival_data.md)

## Examples

``` r
variables <- data.frame(
  variable = "age",
  variableType = "Continuous",
  rType = "integer",
  stringsAsFactors = FALSE
)
variable_details <- data.frame(
  variable = "age",
  recStart = "[18,85]",
  recEnd = "copy",
  proportion = 1,
  stringsAsFactors = FALSE
)

age <- create_con_var(
  var = "age",
  databaseStart = "example",
  variables = variables,
  variable_details = variable_details,
  n = 100,
  seed = 123
)
head(age)
#>   age
#> 1  37
#> 2  71
#> 3  45
#> 4  77
#> 5  81
#> 6  21

if (FALSE) { # \dontrun{
# Not run: requires your own metadata CSV files
# With file paths instead of data frames
result <- create_con_var(
  var = "BMI",
  databaseStart = "minimal-example",
  variables = "path/to/variables.csv",
  variable_details = "path/to/variable_details.csv",
  n = 1000
)
} # }
```
