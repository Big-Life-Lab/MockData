# Get list of unique raw variables for a database/cycle

Returns a data frame of unique raw (source) variables that should be
generated for a specific database/cycle. This is the correct approach
for generating mock data, as we want to create the raw source data, not
the harmonized variables.

## Usage

``` r
get_raw_variables(cycle, variables, variable_details, include_derived = FALSE)
```

## Arguments

- cycle:

  Character string specifying the database/cycle (e.g., "cycle1",
  "cycle1_meds" for CHMS; "cchs2001" for CCHS).

- variables:

  Data frame from variables.csv containing variable metadata.

- variable_details:

  Data frame from variable_details.csv containing detailed
  specifications.

- include_derived:

  Logical. Should derived variables be included? Default is FALSE (since
  derived variables are computed from other variables, not in raw data).

## Value

Data frame with columns:

- variable_raw - Raw source variable name (unique)

- variableType - "Categorical" or "Continuous"

- harmonized_vars - Comma-separated list of harmonized variables that
  use this raw variable

- n_harmonized - Count of how many harmonized variables use this raw
  variable

## Details

This function:

1.  Gets all variables available in the database/cycle using
    [`get_cycle_variables`](https://big-life-lab.github.io/MockData/reference/get_cycle_variables.md)

2.  Extracts unique raw variable names

3.  Groups harmonized variables by their raw source

4.  Returns one row per unique raw variable

This is the correct approach because:

- Mock data should represent raw source data (before harmonization)

- Each raw variable should appear exactly once

- Multiple harmonized variables can derive from the same raw variable

## See also

[`get_cycle_variables`](https://big-life-lab.github.io/MockData/reference/get_cycle_variables.md),
[`parse_variable_start`](https://big-life-lab.github.io/MockData/reference/parse_variable_start.md)

Other mockdata-helpers:
[`apply_missing_codes()`](https://big-life-lab.github.io/MockData/reference/apply_missing_codes.md),
[`apply_rtype_defaults()`](https://big-life-lab.github.io/MockData/reference/apply_rtype_defaults.md),
[`extract_distribution_params()`](https://big-life-lab.github.io/MockData/reference/extract_distribution_params.md),
[`extract_proportions()`](https://big-life-lab.github.io/MockData/reference/extract_proportions.md),
[`generate_garbage_values()`](https://big-life-lab.github.io/MockData/reference/generate_garbage_values.md),
[`get_cycle_variables()`](https://big-life-lab.github.io/MockData/reference/get_cycle_variables.md),
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
raw_vars <- get_raw_variables("cycle1", variables, variable_details)

# CCHS example
raw_vars_cchs <- get_raw_variables("cchs2001", variables, variable_details)

# Generate mock data from raw variables
for (i in 1:nrow(raw_vars)) {
  var_raw <- raw_vars$variable_raw[i]
  var_type <- raw_vars$variableType[i]
  # Generate the raw variable...
}
} # }
```
