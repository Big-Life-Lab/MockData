# Use recodeflow metadata with MockData v0.4

**About this vignette:** This how-to shows how to generate mock data
from recodeflow-style `variables.csv` and `variable_details.csv` files.
The code writes temporary CSV files and reads them back, so the vignette
exercises the same path as a file-based user workflow.

## Starting point

Use this path when you already have recodeflow metadata. MockData reads
the metadata, converts it to a v0.4 `mock_spec`, generates baseline
values, and applies missing-code and garbage-value post-processing.

For a compact example, define three variables:

- `age`: continuous integer with a normal distribution and one missing
  code
- `smoking`: categorical code with one `recEnd = "NA::b"` missing-code
  row
- `interview_date`: date variable with a valid calendar range

``` r

variables <- data.frame(
  variable = c("age", "smoking", "interview_date"),
  label = c("Age in years", "Smoking status", "Interview date"),
  variableType = c("Continuous", "Categorical", "Date"),
  rType = c("integer", "factor", "date"),
  role = c("enabled,table1", "enabled,table1", "enabled"),
  position = c(10, 20, 30),
  databaseStart = c("cycle1", "cycle1", "cycle1"),
  distribution = c("normal", NA, "uniform"),
  mean = c(50, NA, NA),
  sd = c(12, NA, NA),
  garbage_low_prop = c(0.02, NA, NA),
  garbage_low_range = c("[0, 17]", NA, NA),
  stringsAsFactors = FALSE
)

variable_details <- data.frame(
  variable = c(
    "age",
    "age",
    "smoking",
    "smoking",
    "smoking",
    "smoking",
    "interview_date"
  ),
  recStart = c(
    "[18, 85]",
    "999",
    "1",
    "2",
    "3",
    "7",
    "[2020-01-01, 2020-12-31]"
  ),
  recEnd = c("copy", "NA::b", "copy", "copy", "copy", "NA::b", "copy"),
  catLabel = c(
    "Valid age range",
    "Not stated",
    "Never smoker",
    "Former smoker",
    "Current smoker",
    "Don't know",
    "Interview date range"
  ),
  proportion = c(0.95, 0.05, 0.50, 0.30, 0.17, 0.03, 1),
  databaseStart = "cycle1",
  stringsAsFactors = FALSE
)
```

When `databaseStart` filtering is requested, include `databaseStart` in
both metadata tables. If the detail metadata has the filter column but
the variables metadata does not,
[`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md)
uses the legacy path for compatibility.

## Write metadata as CSV files

In a real project, these files already exist. Here we write them to a
temporary directory so this vignette remains self-contained.

``` r

metadata_dir <- tempfile("mockdata-recodeflow-")
dir.create(metadata_dir)

variables_file <- file.path(metadata_dir, "variables.csv")
details_file <- file.path(metadata_dir, "variable_details.csv")

write.csv(variables, variables_file, row.names = FALSE, na = "")
write.csv(variable_details, details_file, row.names = FALSE, na = "")
```

## Inspect the normalized specification

[`mock_spec_from_recodeflow()`](https://big-life-lab.github.io/MockData/reference/mock_spec_from_recodeflow.md)
reads either data frames or CSV file paths. It returns a validated
`mock_spec` without generating data.

``` r

spec <- mock_spec_from_recodeflow(
  variables = variables_file,
  variable_details = details_file,
  databaseStart = "cycle1"
)

names(spec$variables)
```

    [1] "age"            "smoking"        "interview_date"

The spec preserves the recodeflow pieces MockData needs: variable types,
categorical levels, proportions, valid ranges, missing-code rows, and
garbage rules.

``` r

spec$variables$smoking$levels
```

    [1] "1" "2" "3"

``` r

spec$variables$smoking$missing_codes
```

    [1] "7"

``` r

spec$variables$age$range
```

    [1] 18 85

``` r

spec$variables$age$garbage_rules
```

    $low
    $low$proportion
    [1] 0.02

    $low$range
    [1] "[0, 17]"

## Generate mock data with the compatibility wrapper

Most recodeflow users should start with
[`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md).
In strict mode (`validate = TRUE`, the default), supported metadata
routes through the v0.4 pipeline.

``` r

mock_data <- create_mock_data(
  databaseStart = "cycle1",
  variables = variables_file,
  variable_details = details_file,
  n = 200,
  seed = 123,
  verbose = TRUE
)
```

    Reading variables file: /tmp/RtmpAVTsbk/mockdata-recodeflow-63bf248d5737/variables.csv

    Reading variable_details file: /tmp/RtmpAVTsbk/mockdata-recodeflow-63bf248d5737/variable_details.csv

    Generating via v0.4 mock_spec pipeline.

``` r

head(mock_data)
```

      age smoking interview_date
    1  38       1     2020-06-17
    2  58       1     2020-03-22
    3  68       2     2020-11-15
    4  28       2     2020-03-18
    5 999       1     2020-12-17
    6  36       2     2020-03-08

The output is a regular data frame.

``` r

str(mock_data)
```

    'data.frame':   200 obs. of  3 variables:
     $ age           : int  38 58 68 28 999 36 52 25 45 50 ...
     $ smoking       : Factor w/ 4 levels "1","2","3","7": 1 1 2 2 1 2 1 2 2 1 ...
     $ interview_date: Date, format: "2020-06-17" "2020-03-22" ...
     - attr(*, "mockdata_diagnostics")=List of 2
      ..$ spec_version: chr "0.4.0"
      ..$ variables   :List of 3
      .. ..$ age           :List of 6
      .. .. ..$ n                               : int 200
      .. .. ..$ preexisting_missing_code_indices: int(0)
      .. .. ..$ assigned_missing_indices        : int [1:10] 83 166 68 132 5 175 199 119 130 159
      .. .. ..$ assigned_missing_codes          : chr [1:10] "999" "999" "999" "999" ...
      .. .. ..$ assigned_garbage_indices        :List of 1
      .. .. .. ..$ low: int [1:4] 46 129 187 51
      .. .. ..$ assigned_garbage_values         :List of 1
      .. .. .. ..$ low: int [1:4] 15 17 5 16
      .. ..$ smoking       :List of 6
      .. .. ..$ n                               : int 200
      .. .. ..$ preexisting_missing_code_indices: int(0)
      .. .. ..$ assigned_missing_indices        : int [1:6] 72 44 186 127 81 62
      .. .. ..$ assigned_missing_codes          : chr [1:6] "7" "7" "7" "7" ...
      .. .. ..$ assigned_garbage_indices        : Named list()
      .. .. ..$ assigned_garbage_values         : Named list()
      .. ..$ interview_date:List of 6
      .. .. ..$ n                               : int 200
      .. .. ..$ preexisting_missing_code_indices: int(0)
      .. .. ..$ assigned_missing_indices        : int(0)
      .. .. ..$ assigned_missing_codes          : chr(0)
      .. .. ..$ assigned_garbage_indices        : Named list()
      .. .. ..$ assigned_garbage_values         : Named list()

## Check diagnostics

When
[`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md)
uses the v0.4 path, the returned data frame has a `mockdata_diagnostics`
attribute. The attribute records which rows were changed during
missing-code and garbage-value post-processing.

``` r

diagnostics <- attr(mock_data, "mockdata_diagnostics")
names(diagnostics$variables)
```

    [1] "age"            "smoking"        "interview_date"

For example, `smoking` has a missing-code rule for code `7`, and `age`
has a low garbage rule.

``` r

length(diagnostics$variables$smoking$assigned_missing_indices)
```

    [1] 6

``` r

diagnostics$variables$smoking$assigned_missing_indices[1:6]
```

    [1]  72  44 186 127  81  62

``` r

length(diagnostics$variables$age$assigned_garbage_indices$low)
```

    [1] 4

``` r

diagnostics$variables$age$assigned_garbage_indices$low
```

    [1]  46 129 187  51

Use the diagnostics as an audit trail, not as columns in the mock
dataset. Some base R operations and downstream tools can drop
attributes, so inspect or save diagnostics before heavy reshaping.

## Generate explicitly from the spec

The wrapper is convenient, but the v0.4 pipeline can also be called step
by step. This is useful when you want to inspect baseline values before
post-processing.

``` r

baseline <- generate_mock_data_native(spec, n = 200, seed = 123)
head(baseline)
```

      age smoking interview_date
    1  38       1     2020-06-17
    2  58       1     2020-03-22
    3  68       2     2020-11-15
    4  28       2     2020-03-18
    5  54       1     2020-12-17
    6  36       2     2020-03-08

``` r

postprocessed <- postprocess_mock_data(baseline, spec, seed = 123)
head(postprocessed)
```

      age smoking interview_date
    1  38       1     2020-06-17
    2  58       1     2020-03-22
    3  68       2     2020-11-15
    4  28       2     2020-03-18
    5 999       1     2020-12-17
    6  36       2     2020-03-08

The wrapper uses the same idea: baseline generation and post-processing
are both passed the same public `seed`, and each stage internally draws
from its own independent L’Ecuyer-CMRG sub-stream derived from that seed
(not `seed + 1L`, as in earlier v0.4 releases - see `NEWS.md` for the
v0.5 reproducibility change).

## Database filtering

`databaseStart` filtering is exact token matching. A variable tagged for
`cycle10` will not accidentally match `cycle1`.

``` r

variables_cycle10 <- variables
variables_cycle10$variable[1] <- "age_cycle10"
variables_cycle10$databaseStart[1] <- "cycle10"

combined_variables <- rbind(variables, variables_cycle10[1, ])
combined_details <- rbind(
  variable_details,
  transform(variable_details[variable_details$variable == "age", ],
            variable = "age_cycle10")
)

filtered_spec <- mock_spec_from_recodeflow(
  variables = combined_variables,
  variable_details = combined_details,
  databaseStart = "cycle1"
)

names(filtered_spec$variables)
```

    [1] "age"            "smoking"        "interview_date"

## Troubleshooting

If
[`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md)
cannot use the v0.4 path, set `verbose = TRUE` to see which path was
chosen.

``` r

mock_data <- create_mock_data(
  databaseStart = "cycle1",
  variables = variables_file,
  variable_details = details_file,
  n = 200,
  seed = 123,
  verbose = TRUE
)
```

Common reasons for legacy fallback include `validate = FALSE`,
`variable_details = NULL`, detail-level `databaseStart` filtering
without a variable-level `databaseStart` column, and features that are
intentionally deferred from the v0.4 native backend.

For deeper diagnostics examples, see the diagnostics and garbage how-to
when it lands in the v0.4 documentation sprint.
