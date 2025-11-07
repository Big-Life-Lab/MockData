# Get enabled variables

Convenience function to get all variables marked with role "enabled",
excluding derived variables by default. Derived variables should be
calculated after generating raw mock data, not generated directly.

## Usage

``` r
get_enabled_variables(config, exclude_derived = TRUE)
```

## Arguments

- config:

  Data frame. Configuration from read_mock_data_config().

- exclude_derived:

  Logical. If TRUE (default), exclude variables with role "derived".
  Derived variables are calculated from raw variables and should not be
  generated as mock data.

## Value

Data frame with subset of config rows where role contains "enabled" but
not "derived" (unless exclude_derived = FALSE).

## Details

The "enabled" role indicates variables that should be included when
generating mock data. However, variables with role "derived" are
calculated from other variables and should NOT be generated directly.

**Derived variables**: Variables calculated from raw data (e.g., BMI
from height and weight, pack-years from smoking variables). These have
`role = "derived,enabled"` in metadata and `variableStart` starting with
"DerivedVar::".

**Default behavior**: Excludes derived variables to prevent generating
variables that should be calculated from raw data.

## See also

Other configuration:
[`get_variables_by_role()`](https://big-life-lab.github.io/MockData/reference/get_variables_by_role.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Load configuration
config <- read_mock_data_config("inst/extdata/mock_data_config.csv")

# Get only enabled RAW variables (excludes derived, default)
enabled_vars <- get_enabled_variables(config)

# Include derived variables (not recommended)
all_enabled <- get_enabled_variables(config, exclude_derived = FALSE)

# View enabled variable names
enabled_vars$variable
} # }
```
