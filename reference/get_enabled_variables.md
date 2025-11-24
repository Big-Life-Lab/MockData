# Get enabled variables

Convenience function to get all variables marked with role "enabled",
excluding derived variables by default. Derived variables should be
calculated after generating raw mock data, not generated directly.

## Usage

``` r
get_enabled_variables(config, exclude_derived = TRUE, variable_details = NULL)
```

## Arguments

- config:

  Data frame. Configuration from read_mock_data_config().

- exclude_derived:

  Logical. If TRUE (default), exclude derived variables identified by
  recodeflow patterns (DerivedVar::, Func::). Derived variables are
  calculated from raw variables and should not be generated as mock
  data.

- variable_details:

  Data frame. Required when exclude_derived = TRUE. Detail-level
  metadata with columns: variable, recStart, recEnd. Contains
  DerivedVar:: and Func:: patterns that identify derived variables.

## Value

Data frame with subset of config rows where role contains "enabled" and
not identified as derived (unless exclude_derived = FALSE).

## Details

The "enabled" role indicates variables that should be included when
generating mock data. However, derived variables are calculated from
other variables and should NOT be generated directly.

**Derived variables**: Variables calculated from raw data (e.g., BMI
from height and weight, pack-years from smoking variables). These are
identified by recodeflow patterns in variable_details:

- `DerivedVar::[VAR1, VAR2, ...]` in variable_details.recStart

- `Func::function_name` in variable_details.recEnd

**Default behavior**: Excludes derived variables to prevent generating
variables that should be calculated from raw data.

**Note**: This function uses pattern-based detection (recodeflow
approach), NOT role column flags. The role column is NOT checked for
"derived" status.

## See also

Other configuration:
[`get_variables_by_role()`](https://big-life-lab.github.io/MockData/reference/get_variables_by_role.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Load configuration
config <- read_mock_data_config("inst/extdata/mock_data_config.csv")
variable_details <- read.csv("inst/extdata/variable_details.csv")

# Get only enabled RAW variables (excludes derived, default)
enabled_vars <- get_enabled_variables(config, variable_details = variable_details)

# Include derived variables (not recommended)
all_enabled <- get_enabled_variables(config, exclude_derived = FALSE)

# View enabled variable names
enabled_vars$variable
} # }
```
