# Create mock data from configuration files

Main orchestrator function that generates complete mock datasets from
v0.2 configuration files. Reads config and details files, filters for
enabled variables, dispatches to type-specific create\_\* functions, and
assembles results into a complete data frame.

## Usage

``` r
create_mock_data(
  config_path,
  details_path = NULL,
  n = 1000,
  seed = NULL,
  source_format = "analysis",
  validate = TRUE,
  verbose = FALSE
)
```

## Arguments

- config_path:

  Character. Path to mock_data_config.csv file.

- details_path:

  Character. Optional path to mock_data_config_details.csv. If NULL,
  uses uniform distributions (fallback mode).

- n:

  Integer. Number of observations to generate (default 1000).

- seed:

  Integer. Optional random seed for reproducibility.

- source_format:

  Character. Format to simulate post-import data from different sources.
  Options: "analysis" (default, R Date objects), "csv" (character
  strings), "sas" (numeric days since 1960-01-01). Only affects date
  variables.

- validate:

  Logical. Whether to validate configuration files (default TRUE).

- verbose:

  Logical. Whether to print progress messages (default FALSE).

## Value

Data frame with n rows and one column per enabled variable.

## Details

The function performs the following steps:

1.  Read and validate config file

2.  Read and validate details file (if provided)

3.  Filter for enabled variables

4.  Set global seed (if provided)

5.  Loop through variables in position order:

    - Extract var_row and details_subset

    - Dispatch to create_cat_var, create_con_var, create_date_var, or
      create_survival_dates

    - Merge result into data frame

6.  Return complete dataset

**Fallback mode**: If details_path = NULL, uses uniform distributions
for all enabled variables.

**Variable types supported**:

- categorical: create_cat_var()

- continuous: create_con_var()

- date: create_date_var()

- survival: create_survival_dates()

- character: create_char_var() (if implemented)

- integer: create_int_var() (if implemented)

## Examples

``` r
if (FALSE) { # \dontrun{
# Generate mock data with details
mock_data <- create_mock_data(
  config_path = "inst/extdata/mock_data_config.csv",
  details_path = "inst/extdata/mock_data_config_details.csv",
  n = 1000,
  seed = 123
)

# Fallback mode (uniform distributions)
mock_data <- create_mock_data(
  config_path = "inst/extdata/mock_data_config.csv",
  details_path = NULL,
  n = 500
)

# View structure
str(mock_data)
head(mock_data)
} # }
```
