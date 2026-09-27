# Create mock data from configuration files

Main orchestrator function that generates complete mock datasets from
configuration files. Reads metadata, filters for enabled variables,
dispatches to type-specific create\_\* functions, and assembles results
into a complete data frame.

## Usage

``` r
create_mock_data(
  databaseStart,
  variables,
  variable_details = NULL,
  n = 1000,
  seed = NULL,
  validate = TRUE,
  verbose = FALSE
)
```

## Arguments

- databaseStart:

  Character. The database identifier (e.g., "cchs2001_p",
  "minimal-example"). Used to filter variables to those available in the
  specified database.

- variables:

  data.frame or character. Variable-level metadata containing:

  - `variable`: Variable names

  - `variableType`: Variable type (Categorical/Continuous/Date)

  - `role`: Role tags (enabled, predictor, outcome, etc.)

  - `position`: Display order (optional)

  - `database`: Database filter (optional)

  Can also be a file path (character) to variables.csv.

- variable_details:

  data.frame or character. Detail-level metadata containing:

  - `variable`: Variable name (for joining)

  - `recStart`: Category code/range or date interval

  - `recEnd`: Classification (numeric code, "NA::a", "NA::b")

  - `proportion`: Category proportion (for categorical)

  - `catLabel`: Category label/description

  Can also be a file path (character) to variable_details.csv. If NULL,
  uses simple fallback generation.

- n:

  Integer. Number of observations to generate (default 1000). `n = 0` is
  supported and returns a zero-row data frame with the full generated
  schema.

- seed:

  Integer. Optional random seed for reproducibility.

- validate:

  Logical. Whether to use strict generation checks (default TRUE). When
  TRUE, unsupported variable types and generator errors stop generation.
  When FALSE, those errors are converted to warnings and the affected
  variable is skipped.

- verbose:

  Logical. Whether to print progress messages (default FALSE).

## Value

Data frame with n rows and one column per enabled variable. When the
v0.4 `mock_spec` path is used, the result also carries a
`mockdata_diagnostics` attribute from
[`postprocess_mock_data()`](https://big-life-lab.github.io/MockData/reference/postprocess_mock_data.md).
Legacy fallback paths return plain data frames without that attribute.

## Details

**v0.4.0 transition**: In strict mode, this function first attempts to
use the v0.4 `mock_spec` pipeline:
[`mock_spec_from_recodeflow()`](https://big-life-lab.github.io/MockData/reference/mock_spec_from_recodeflow.md),
[`generate_mock_data_native()`](https://big-life-lab.github.io/MockData/reference/generate_mock_data_native.md),
and
[`postprocess_mock_data()`](https://big-life-lab.github.io/MockData/reference/postprocess_mock_data.md).
If the metadata requests a feature not yet supported by the v0.4 native
backend, it falls back to the v0.3 `create_*` dispatch path so existing
users can migrate gradually.

The wrapper deliberately stays on the legacy path when
`validate = FALSE`, when `variable_details = NULL`, when detail-level
`databaseStart` filtering is needed but the variables metadata has no
`databaseStart` column, or when a variable uses a feature not yet
supported by the v0.4 native backend. Set `verbose = TRUE` to see which
path was chosen. Survival dates (rows that set `anchor`) are generated
only by the v0.4 pipeline: if the legacy path is selected for metadata
that sets `anchor`, `create_mock_data()` stops and names the survival
variables.

In the v0.4 path, baseline generation and post-processing draw from
distinct, independent sub-streams derived from a single `seed`; output
is reproducible for a given seed and package version but changed in v0.5
(see NEWS).

**v0.3.0 API**: This function follows the "recodeflow pattern" where it
passes full metadata data frames to create\_\* functions, which handle
internal filtering.

**Generation process**:

1.  Load metadata from file paths or accept data frames

2.  Filter for enabled variables (role has an exact "enabled" token)

3.  Generate within an isolated RNG sub-stream (if seeded), leaving the
    caller's RNG state untouched

4.  Loop through variables in position order: - Dispatch to
    create_cat_var, create_con_var, or create_date_var - Pass full
    metadata data frames (functions filter internally) - Merge result
    into data frame

5.  Return complete dataset

**Fallback mode**: If variable_details = NULL, uses simple default
generators for enabled variables (two-category categorical values,
continuous values from `[0, 100]`, and dates from 2000-01-01 to
2025-12-31).

**Variable types supported**:

- `Categorical`: create_cat_var()

- `Continuous`: create_con_var()

- `Date`: create_date_var()

**Configuration schema**: For complete documentation of all
configuration columns, see
[`vignette("reference-config", package = "MockData")`](https://big-life-lab.github.io/MockData/articles/reference-config.md).

## See also

[`mock_spec_from_recodeflow()`](https://big-life-lab.github.io/MockData/reference/mock_spec_from_recodeflow.md),
[`generate_mock_data_native()`](https://big-life-lab.github.io/MockData/reference/generate_mock_data_native.md),
[`postprocess_mock_data()`](https://big-life-lab.github.io/MockData/reference/postprocess_mock_data.md),
[`generate_mock_data_simstudy()`](https://big-life-lab.github.io/MockData/reference/generate_mock_data_simstudy.md),
[`mock_spec()`](https://big-life-lab.github.io/MockData/reference/mock_spec.md)

Other generators:
[`create_cat_var()`](https://big-life-lab.github.io/MockData/reference/create_cat_var.md),
[`create_con_var()`](https://big-life-lab.github.io/MockData/reference/create_con_var.md),
[`create_date_var()`](https://big-life-lab.github.io/MockData/reference/create_date_var.md),
[`create_survival_dates()`](https://big-life-lab.github.io/MockData/reference/create_survival_dates.md),
[`create_wide_survival_data()`](https://big-life-lab.github.io/MockData/reference/create_wide_survival_data.md)

Other mock generation APIs:
[`generate_mock_data_native()`](https://big-life-lab.github.io/MockData/reference/generate_mock_data_native.md),
[`generate_mock_data_simstudy()`](https://big-life-lab.github.io/MockData/reference/generate_mock_data_simstudy.md),
[`generate_survival_dates()`](https://big-life-lab.github.io/MockData/reference/generate_survival_dates.md),
[`postprocess_mock_data()`](https://big-life-lab.github.io/MockData/reference/postprocess_mock_data.md)

## Examples

``` r
# The packaged minimal example covers every variable type, including
# survival dates anchored on interview_date. It auto-normalizes some
# proportions, so warnings about that are expected.
mock_data <- create_mock_data(
  databaseStart = "minimal-example",
  variables = system.file("extdata/minimal-example/variables.csv",
    package = "MockData"
  ),
  variable_details = system.file("extdata/minimal-example/variable_details.csv",
    package = "MockData"
  ),
  n = 100,
  seed = 123
)
#> Excluding derived recodeflow variable(s): BMI_derived
str(mock_data)
#> 'data.frame':    100 obs. of  10 variables:
#>  $ age               : int  35 999 72 997 55 998 52 19 43 50 ...
#>  $ smoking           : Factor w/ 4 levels "1","2","3","7": 3 1 1 2 1 3 1 2 3 3 ...
#>  $ BMI               : num  996 31.5 21 28.4 29.5 ...
#>  $ height            : num  1.69 1.67 2.39 1.51 1.96 ...
#>  $ weight            : num  54.5 89.1 78.8 73.6 65.4 ...
#>  $ interview_date    : Date, format: "2004-10-20" "2004-01-11" ...
#>  $ death_date        : Date, format: NA NA ...
#>  $ ltfu_date         : Date, format: NA NA ...
#>  $ admin_censor_date : Date, format: "2006-06-15" "2017-08-27" ...
#>  $ primary_event_date: Date, format: NA NA ...
#>  - attr(*, "mockdata_diagnostics")=List of 2
#>   ..$ spec_version: chr "0.4.0"
#>   ..$ variables   :List of 10
#>   .. ..$ age               :List of 6
#>   .. .. ..$ n                               : int 100
#>   .. .. ..$ preexisting_missing_code_indices: int(0) 
#>   .. .. ..$ assigned_missing_indices        : int [1:10] 83 38 68 73 4 6 49 40 75 2
#>   .. .. ..$ assigned_missing_codes          : chr [1:10] "997" "997" "997" "997" ...
#>   .. .. ..$ assigned_garbage_indices        : Named list()
#>   .. .. ..$ assigned_garbage_values         : Named list()
#>   .. ..$ smoking           :List of 6
#>   .. .. ..$ n                               : int 100
#>   .. .. ..$ preexisting_missing_code_indices: int(0) 
#>   .. .. ..$ assigned_missing_indices        : int [1:3] 31 45 50
#>   .. .. ..$ assigned_missing_codes          : chr [1:3] "7" "7" "7"
#>   .. .. ..$ assigned_garbage_indices        : Named list()
#>   .. .. ..$ assigned_garbage_values         : Named list()
#>   .. ..$ BMI               :List of 6
#>   .. .. ..$ n                               : int 100
#>   .. .. ..$ preexisting_missing_code_indices: int(0) 
#>   .. .. ..$ assigned_missing_indices        : int [1:39] 50 16 100 85 70 81 72 86 44 58 ...
#>   .. .. ..$ assigned_missing_codes          : chr [1:39] "996" "996" "996" "996" ...
#>   .. .. ..$ assigned_garbage_indices        :List of 2
#>   .. .. .. ..$ low : int 49
#>   .. .. .. ..$ high: int 80
#>   .. .. ..$ assigned_garbage_values         :List of 2
#>   .. .. .. ..$ low : num -10
#>   .. .. .. ..$ high: num 136
#>   .. ..$ height            :List of 6
#>   .. .. ..$ n                               : int 100
#>   .. .. ..$ preexisting_missing_code_indices: int(0) 
#>   .. .. ..$ assigned_missing_indices        : int(0) 
#>   .. .. ..$ assigned_missing_codes          : chr(0) 
#>   .. .. ..$ assigned_garbage_indices        :List of 2
#>   .. .. .. ..$ low : int 20
#>   .. .. .. ..$ high: int 3
#>   .. .. ..$ assigned_garbage_values         :List of 2
#>   .. .. .. ..$ low : num 0.166
#>   .. .. .. ..$ high: num 2.39
#>   .. ..$ weight            :List of 6
#>   .. .. ..$ n                               : int 100
#>   .. .. ..$ preexisting_missing_code_indices: int(0) 
#>   .. .. ..$ assigned_missing_indices        : int(0) 
#>   .. .. ..$ assigned_missing_codes          : chr(0) 
#>   .. .. ..$ assigned_garbage_indices        : Named list()
#>   .. .. ..$ assigned_garbage_values         : Named list()
#>   .. ..$ interview_date    :List of 6
#>   .. .. ..$ n                               : int 100
#>   .. .. ..$ preexisting_missing_code_indices: int(0) 
#>   .. .. ..$ assigned_missing_indices        : int(0) 
#>   .. .. ..$ assigned_missing_codes          : chr(0) 
#>   .. .. ..$ assigned_garbage_indices        : Named list()
#>   .. .. ..$ assigned_garbage_values         : Named list()
#>   .. ..$ primary_event_date:List of 11
#>   .. .. ..$ n                               : int 100
#>   .. .. ..$ preexisting_missing_code_indices: int(0) 
#>   .. .. ..$ assigned_missing_indices        : int(0) 
#>   .. .. ..$ assigned_missing_codes          : chr(0) 
#>   .. .. ..$ assigned_garbage_indices        :List of 1
#>   .. .. .. ..$ high: int 97
#>   .. .. ..$ assigned_garbage_values         :List of 1
#>   .. .. .. ..$ high: Date[1:1], format: "2039-11-19"
#>   .. .. ..$ derived                         : logi TRUE
#>   .. .. ..$ anchor                          : chr "interview_date"
#>   .. .. ..$ censored_by                     : chr "death_date"
#>   .. .. ..$ depends_on                      : chr [1:2] "interview_date" "death_date"
#>   .. .. ..$ n_events                        : int 30
#>   .. ..$ death_date        :List of 10
#>   .. .. ..$ n                               : int 100
#>   .. .. ..$ preexisting_missing_code_indices: int(0) 
#>   .. .. ..$ assigned_missing_indices        : int(0) 
#>   .. .. ..$ assigned_missing_codes          : chr(0) 
#>   .. .. ..$ assigned_garbage_indices        :List of 1
#>   .. .. .. ..$ high: int 28
#>   .. .. ..$ assigned_garbage_values         :List of 1
#>   .. .. .. ..$ high: Date[1:1], format: "2053-05-01"
#>   .. .. ..$ derived                         : logi TRUE
#>   .. .. ..$ anchor                          : chr "interview_date"
#>   .. .. ..$ depends_on                      : chr "interview_date"
#>   .. .. ..$ n_events                        : int 20
#>   .. ..$ ltfu_date         :List of 10
#>   .. .. ..$ n                               : int 100
#>   .. .. ..$ preexisting_missing_code_indices: int(0) 
#>   .. .. ..$ assigned_missing_indices        : int(0) 
#>   .. .. ..$ assigned_missing_codes          : chr(0) 
#>   .. .. ..$ assigned_garbage_indices        :List of 1
#>   .. .. .. ..$ high: int(0) 
#>   .. .. ..$ assigned_garbage_values         :List of 1
#>   .. .. .. ..$ high: chr(0) 
#>   .. .. ..$ derived                         : logi TRUE
#>   .. .. ..$ anchor                          : chr "interview_date"
#>   .. .. ..$ depends_on                      : chr "interview_date"
#>   .. .. ..$ n_events                        : int 10
#>   .. ..$ admin_censor_date :List of 10
#>   .. .. ..$ n                               : int 100
#>   .. .. ..$ preexisting_missing_code_indices: int(0) 
#>   .. .. ..$ assigned_missing_indices        : int(0) 
#>   .. .. ..$ assigned_missing_codes          : chr(0) 
#>   .. .. ..$ assigned_garbage_indices        : Named list()
#>   .. .. ..$ assigned_garbage_values         : Named list()
#>   .. .. ..$ derived                         : logi TRUE
#>   .. .. ..$ anchor                          : chr "interview_date"
#>   .. .. ..$ depends_on                      : chr "interview_date"
#>   .. .. ..$ n_events                        : int 100

# Columns with straightforward metadata generate cleanly:
head(mock_data[, c("age", "smoking", "interview_date")])
#>   age smoking interview_date
#> 1  35       3     2004-10-20
#> 2 999       1     2004-01-11
#> 3  72       1     2002-01-21
#> 4 997       2     2004-06-25
#> 5  55       1     2001-02-22
#> 6 998       3     2004-01-12

# Fallback mode: no variable_details, simple default generators. Survival
# dates need the v0.4 pipeline, so drop the rows that set an anchor first.
fallback_variables <- read.csv(
  system.file("extdata/minimal-example/variables.csv", package = "MockData"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
mock_data <- create_mock_data(
  databaseStart = "minimal-example",
  variables = fallback_variables[fallback_variables$anchor == "", ],
  variable_details = NULL,
  n = 500
)
#> Warning: No variable_details rows found for variable 'age' and databaseStart 'minimal-example'. Using fallback uniform range [0, 100].
#> Warning: No variable_details rows found for variable 'smoking' and databaseStart 'minimal-example'. Using fallback categories c('1', '2').
#> Warning: No variable_details rows found for variable 'BMI' and databaseStart 'minimal-example'. Using fallback uniform range [0, 100].
#> Warning: No variable_details rows found for variable 'height' and databaseStart 'minimal-example'. Using fallback uniform range [0, 100].
#> Warning: No variable_details rows found for variable 'weight' and databaseStart 'minimal-example'. Using fallback uniform range [0, 100].
#> Warning: No variable_details rows found for variable 'BMI_derived' and databaseStart 'minimal-example'. Using fallback uniform range [0, 100].
#> Warning: No variable_details rows found for variable 'interview_date' and databaseStart 'minimal-example'. Using fallback date range [2000-01-01, 2025-12-31].
```
