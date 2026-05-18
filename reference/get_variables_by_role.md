# Get variables by role

Filters a MockData configuration to return only variables matching one
or more roles. The role column can contain comma-separated values (e.g.,
"predictor, outcome"), so this function uses pattern matching to find
all matching variables.

## Usage

``` r
get_variables_by_role(config, roles)
```

## Arguments

- config:

  Data frame. Configuration from read_mock_data_config().

- roles:

  Character vector. Role(s) to filter for (e.g., c("enabled",
  "predictor")).

## Value

Data frame with subset of config rows matching any of the specified
roles.

## Details

This function handles comma-, semicolon-, or whitespace-separated role
values by exact token matching. A variable matches if any role token
equals one of the requested roles.

Common role values:

- enabled: Variables to generate in mock data

- predictor: Predictor variables for analysis

- outcome: Outcome variables

- confounder: Confounding variables

- exposure: Exposure variables

- intermediate: Intermediate/derived variables

- table1_master, table1_sub: Table 1 display variables

- metadata: Study metadata (dates, identifiers)

## See also

Other configuration:
[`get_enabled_variables()`](https://big-life-lab.github.io/MockData/reference/get_enabled_variables.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Load configuration
config <- read_mock_data_config("inst/extdata/mock_data_config.csv")

# Get all predictor variables
predictors <- get_variables_by_role(config, "predictor")

# Get variables with multiple roles
outcomes <- get_variables_by_role(config, c("outcome", "exposure"))

# Get Table 1 variables
table1_vars <- get_variables_by_role(config, c("table1_master", "table1_sub"))
} # }
```
