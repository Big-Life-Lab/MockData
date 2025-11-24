# Validate MockData configuration against schema requirements including required columns and unique identifiers

Validates a mock_data_config data frame against schema requirements.
Checks for required columns, unique variable names, valid role values,
and valid variableType values.

## Usage

``` r
validate_mock_data_config(config)
```

## Arguments

- config:

  Data frame. Configuration data read from mock_data_config.csv.

## Value

Invisible NULL. Stops with error message if validation fails.

## Details

Validation checks:

**Required columns:**

- uid, variable, role, variableType, position

**Uniqueness:**

- uid values must be unique

- variable names must be unique

**Valid values:**

- role: Can contain enabled, predictor, outcome, confounder, exposure,
  table1, metadata, intermediate (comma-separated)

- variableType: categorical, continuous, date, survival, character,
  integer

**Safe NA handling:**

- Uses which() to handle NA values in logical comparisons

- Prevents "missing value where TRUE/FALSE needed" errors

## Examples

``` r
if (FALSE) { # \dontrun{
# Validate configuration
config <- read.csv("mock_data_config.csv", stringsAsFactors = FALSE)
validate_mock_data_config(config)
} # }
```
