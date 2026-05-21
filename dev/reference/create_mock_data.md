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

  Integer. Number of observations to generate (default 1000).

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
path was chosen.

In the v0.4 path, `seed` is used for baseline generation and `seed + 1`
is used for post-processing. This makes both stages deterministic, but
generated values may differ from v0.3.x output for the same seed.

**v0.3.0 API**: This function follows the "recodeflow pattern" where it
passes full metadata data frames to create\_\* functions, which handle
internal filtering.

**Generation process**:

1.  Load metadata from file paths or accept data frames

2.  Filter for enabled variables (role has an exact "enabled" token)

3.  Set global seed (if provided)

4.  Loop through variables in position order: - Dispatch to
    create_cat_var, create_con_var, or create_date_var - Pass full
    metadata data frames (functions filter internally) - Merge result
    into data frame

5.  Return complete dataset

**Fallback mode**: If variable_details = NULL, uses simple default
generators for enabled variables (two-category categorical values,
continuous values from 0, 100, and dates from 2000-01-01 to 2025-12-31).

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
[`postprocess_mock_data()`](https://big-life-lab.github.io/MockData/reference/postprocess_mock_data.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Basic usage with file paths
mock_data <- create_mock_data(
  databaseStart = "minimal-example",
  variables = "inst/extdata/minimal-example/variables.csv",
  variable_details = "inst/extdata/minimal-example/variable_details.csv",
  n = 1000,
  seed = 123
)

# With data frames instead of file paths
variables <- read.csv("inst/extdata/minimal-example/variables.csv",
                      stringsAsFactors = FALSE)
variable_details <- read.csv("inst/extdata/minimal-example/variable_details.csv",
                              stringsAsFactors = FALSE)

mock_data <- create_mock_data(
  databaseStart = "minimal-example",
  variables = variables,
  variable_details = variable_details,
  n = 1000,
  seed = 123
)

# Fallback mode (uniform distributions, no variable_details)
mock_data <- create_mock_data(
  databaseStart = "minimal-example",
  variables = "inst/extdata/minimal-example/variables.csv",
  variable_details = NULL,
  n = 500
)

# View structure
str(mock_data)
head(mock_data)
} # }
```
