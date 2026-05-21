# Migrate from MockData v0.3 to v0.4

**About this vignette:** This how-to is for users moving existing
[`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md)
workflows from v0.3 to v0.4. It focuses on the compatibility wrapper,
routing messages, diagnostics, and reproducibility differences.

## What stayed the same

The main entry point is still
[`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md),
and the existing arguments are still available.

``` r

variables <- data.frame(
  variable = c("age", "smoking"),
  variableType = c("Continuous", "Categorical"),
  rType = c("integer", "character"),
  role = c("enabled", "enabled"),
  position = c(10, 20),
  distribution = c("normal", NA),
  mean = c(50, NA),
  sd = c(12, NA),
  stringsAsFactors = FALSE
)

variable_details <- data.frame(
  variable = c("age", "age", "smoking", "smoking", "smoking"),
  recStart = c("[18, 85]", "999", "1", "2", "7"),
  recEnd = c("copy", "NA::b", "copy", "copy", "NA::b"),
  proportion = c(0.95, 0.05, 0.60, 0.35, 0.05),
  stringsAsFactors = FALSE
)
```

``` r

mock_data <- create_mock_data(
  databaseStart = "study",
  variables = variables,
  variable_details = variable_details,
  n = 100,
  seed = 123
)

head(mock_data)
```

      age smoking
    1  43       1
    2  47       2
    3  69       1
    4  51       1
    5 999       1
    6  71       7

For supported metadata, v0.4 routes this call through the new
`mock_spec` pipeline.

## See which path ran

Use `verbose = TRUE` when migrating. The message tells you whether the
v0.4 path or the legacy path was used.

``` r

strict_data <- create_mock_data(
  databaseStart = "study",
  variables = variables,
  variable_details = variable_details,
  n = 50,
  seed = 456,
  verbose = TRUE
)
```

    Generating via v0.4 mock_spec pipeline.

The v0.4 path returns a data frame with a diagnostics attribute.

``` r

!is.null(attr(strict_data, "mockdata_diagnostics"))
```

    [1] TRUE

## Opt into legacy behavior

Set `validate = FALSE` when you need the legacy v0.3 dispatch path
during migration. This is the explicit compatibility opt-out.

``` r

legacy_data <- create_mock_data(
  databaseStart = "study",
  variables = variables,
  variable_details = variable_details,
  n = 50,
  seed = 456,
  validate = FALSE,
  verbose = TRUE
)
```

    validate = FALSE requested; using legacy create_* dispatch.

    Filtering for enabled variables...

    Found 2 enabled variable(s) for database 'study': age, smoking

    Setting random seed: 456

    Generating 50 observations...

      [1/2] Generating age (integer)

      [2/2] Generating smoking (character)

    Mock data generation complete!

      Rows: 50

      Variables: 2

Legacy output is a plain data frame without the v0.4 diagnostics
attribute.

``` r

is.null(attr(legacy_data, "mockdata_diagnostics"))
```

    [1] TRUE

The strict and legacy paths should agree on the broad shape of supported
data, but exact values can differ.

``` r

names(strict_data)
```

    [1] "age"     "smoking"

``` r

names(legacy_data)
```

    [1] "age"     "smoking"

``` r

table(strict_data$smoking)
```


     1  2  7
    23 25  2 

``` r

table(legacy_data$smoking)
```


     1  2  7
    23 24  3 

## Understand seed differences

In v0.3, the public seed controlled the legacy generators. In v0.4, the
wrapper uses the public seed for baseline generation and `seed + 1L` for
missing-code and garbage-value post-processing.

That makes both stages reproducible, but it means exact values may
differ from v0.3 even when you pass the same seed.

``` r

strict_again <- create_mock_data(
  databaseStart = "study",
  variables = variables,
  variable_details = variable_details,
  n = 50,
  seed = 456
)

identical(strict_data, strict_again)
```

    [1] TRUE

When testing migrations, compare structure, types, ranges, and
proportions rather than expecting row-for-row equality with v0.3 output.

``` r

str(strict_data)
```

    'data.frame':   50 obs. of  2 variables:
     $ age    : int  34 57 60 33 41 46 58 999 62 57 ...
     $ smoking: chr  "1" "1" "1" "1" ...
     - attr(*, "mockdata_diagnostics")=List of 2
      ..$ spec_version: chr "0.4.0"
      ..$ variables   :List of 2
      .. ..$ age    :List of 6
      .. .. ..$ n                               : int 50
      .. .. ..$ preexisting_missing_code_indices: int(0)
      .. .. ..$ assigned_missing_indices        : int [1:2] 8 13
      .. .. ..$ assigned_missing_codes          : chr [1:2] "999" "999"
      .. .. ..$ assigned_garbage_indices        : Named list()
      .. .. ..$ assigned_garbage_values         : Named list()
      .. ..$ smoking:List of 6
      .. .. ..$ n                               : int 50
      .. .. ..$ preexisting_missing_code_indices: int(0)
      .. .. ..$ assigned_missing_indices        : int [1:2] 12 35
      .. .. ..$ assigned_missing_codes          : chr [1:2] "7" "7"
      .. .. ..$ assigned_garbage_indices        : Named list()
      .. .. ..$ assigned_garbage_values         : Named list()

``` r

prop.table(table(strict_data$smoking))
```


       1    2    7
    0.46 0.50 0.04 

## Know the fallback conditions

[`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md)
deliberately uses the legacy path when:

- `validate = FALSE`
- `variable_details = NULL`
- detail-level `databaseStart` filtering is needed but `variables` has
  no `databaseStart` column
- the requested metadata uses a feature not yet supported by the v0.4
  native backend

For example, `variable_details = NULL` keeps the simple legacy fallback.

``` r

fallback_data <- create_mock_data(
  databaseStart = "study",
  variables = variables[1, ],
  variable_details = NULL,
  n = 20,
  seed = 789,
  verbose = TRUE
)
```

    No details file provided - using simple fallback generation

    variable_details = NULL; using legacy create_* fallback dispatch.

    Filtering for enabled variables...

    Found 1 enabled variable(s) for database 'study': age

    Setting random seed: 789

    Generating 20 observations...

      [1/1] Generating age (integer)

    Warning in create_con_var(var = var_name, databaseStart = databaseStart, : No
    variable_details rows found for variable 'age' and databaseStart 'study'. Using
    fallback uniform range [0, 100].

    Mock data generation complete!

      Rows: 20

      Variables: 1

``` r

head(fallback_data)
```

      age
    1  70
    2   9
    3   1
    4  59
    5  49
    6   2

``` r

is.null(attr(fallback_data, "mockdata_diagnostics"))
```

    [1] TRUE

Unsupported v0.4 backend features also route to legacy dispatch. This
example uses an exponential continuous distribution, which remains
available through the legacy generator.

``` r

exp_variables <- data.frame(
  variable = "time_to_visit",
  variableType = "Continuous",
  rType = "double",
  role = "enabled",
  distribution = "exponential",
  rate = 0.5,
  stringsAsFactors = FALSE
)

exp_details <- data.frame(
  variable = "time_to_visit",
  recStart = "[0, 10]",
  recEnd = "copy",
  proportion = 1,
  stringsAsFactors = FALSE
)

exp_data <- create_mock_data(
  databaseStart = "study",
  variables = exp_variables,
  variable_details = exp_details,
  n = 20,
  seed = 321,
  verbose = TRUE
)
```

    v0.4 mock_spec pipeline does not yet support every requested variable; using legacy create_* dispatch. Unsupported variable(s): time_to_visit

    Filtering for enabled variables...

    Found 1 enabled variable(s) for database 'study': time_to_visit

    Setting random seed: 321

    Generating 20 observations...

      [1/1] Generating time_to_visit (double)

    Mock data generation complete!

      Rows: 20

      Variables: 1

``` r

head(exp_data)
```

      time_to_visit
    1     0.3302437
    2     1.4268834
    3     2.5103901
    4     2.1157332
    5     1.7882266
    6     1.2263829

## Inspect the v0.4 path directly

When debugging a migration, split the wrapper into its three v0.4 steps:

``` r

spec <- mock_spec_from_recodeflow(variables, variable_details)
validate_mock_spec(spec, strict = TRUE)
```

    MockData mock_spec validation result: valid

``` r

baseline <- generate_mock_data_native(spec, n = 50, seed = 456)
postprocessed <- postprocess_mock_data(baseline, spec, seed = 457)

identical(strict_data, postprocessed)
```

    [1] TRUE

This makes it easier to tell whether an issue is coming from metadata
parsing, baseline generation, or post-processing.

## What to check in sibling packages

For cchsflow, chmsflow, and recodeflow workflows, test representative
`variables.csv` and `variable_details.csv` files with:

``` r

mock <- create_mock_data(
  databaseStart = "your-cycle",
  variables = "variables.csv",
  variable_details = "variable_details.csv",
  n = 100,
  seed = 123,
  validate = TRUE,
  verbose = TRUE
)

str(mock)
attr(mock, "mockdata_diagnostics")
```

Report cases where metadata unexpectedly falls back to legacy dispatch,
where a variable generated in v0.3 but errors in v0.4, or where the
generated values, types, or diagnostics are surprising.
