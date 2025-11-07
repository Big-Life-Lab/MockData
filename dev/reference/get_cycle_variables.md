# Get list of variables used in a specific database/cycle

Returns a data frame containing all variables that are available in a
specified database/cycle, with their metadata and extracted raw variable
names.

## Usage

``` r
get_cycle_variables(cycle, variables, variable_details, include_derived = TRUE)
```

## Arguments

- cycle:

  Character string specifying the database/cycle (e.g., "cycle1",
  "cycle1_meds" for CHMS; "cchs2001", "cchs2017_p" for CCHS).

- variables:

  Data frame from variables.csv containing variable metadata.

- variable_details:

  Data frame from variable_details.csv containing detailed recoding
  specifications.

- include_derived:

  Logical. Should derived variables be included? Default is TRUE.

## Value

Data frame with columns:

- variable - Harmonized variable name

- variable_raw - Raw source variable name (extracted from variableStart)

- label - Human-readable label

- variableType - "Categorical" or "Continuous"

- databaseStart - Which databases/cycles the variable appears in

- variableStart - Original variableStart string (for reference)

Returns empty data frame if no variables found for the database/cycle.

## Details

The function filters variables.csv by checking if the database/cycle
appears in the `databaseStart` field (exact match), then uses
[`parse_variable_start`](https://big-life-lab.github.io/MockData/reference/parse_variable_start.md)
to extract the raw variable name from the `variableStart` field.

**Important**: Uses exact matching to avoid false positives (e.g.,
"cycle1" should not match "cycle1_meds").

Derived variables (those with "DerivedVar::" in variableStart) return NA
for variable_raw since they require custom derivation logic.

## See also

[`parse_variable_start`](https://big-life-lab.github.io/MockData/reference/parse_variable_start.md)

Other mockdata-helpers:
[`apply_missing_codes()`](https://big-life-lab.github.io/MockData/reference/apply_missing_codes.md),
[`apply_rtype_defaults()`](https://big-life-lab.github.io/MockData/reference/apply_rtype_defaults.md),
[`extract_distribution_params()`](https://big-life-lab.github.io/MockData/reference/extract_distribution_params.md),
[`extract_proportions()`](https://big-life-lab.github.io/MockData/reference/extract_proportions.md),
[`generate_garbage_values()`](https://big-life-lab.github.io/MockData/reference/generate_garbage_values.md),
[`get_raw_variables()`](https://big-life-lab.github.io/MockData/reference/get_raw_variables.md),
[`get_variable_details()`](https://big-life-lab.github.io/MockData/reference/get_variable_details.md),
[`has_garbage()`](https://big-life-lab.github.io/MockData/reference/has_garbage.md),
[`make_garbage()`](https://big-life-lab.github.io/MockData/reference/make_garbage.md),
[`sample_with_proportions()`](https://big-life-lab.github.io/MockData/reference/sample_with_proportions.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Load metadata
variables <- read.csv("inst/extdata/variables.csv")
variable_details <- read.csv("inst/extdata/variable-details.csv")

# CHMS example
cycle1_vars <- get_cycle_variables("cycle1", variables, variable_details)

# CCHS example
cchs2001_vars <- get_cycle_variables("cchs2001", variables, variable_details)

# Exclude derived variables
cycle1_original <- get_cycle_variables("cycle1", variables, variable_details,
                                        include_derived = FALSE)
} # }
```
