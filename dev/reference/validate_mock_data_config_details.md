# Validate MockData configuration details against schema requirements including proportion sums and parameter completeness

Validates a mock_data_config_details data frame against schema
requirements. Checks for required columns, valid proportions, proportion
sums, parameter requirements, and optionally validates links to config
file.

## Usage

``` r
validate_mock_data_config_details(details, config = NULL)
```

## Arguments

- details:

  Data frame. Details data read from mock_data_config_details.csv.

- config:

  Data frame (optional). Configuration for cross-validation.

## Value

Invisible NULL. Stops with error message if validation fails.

## Details

Validation checks:

**Required columns:**

- uid, uid_detail, variable, recEnd

**Uniqueness:**

- uid_detail values must be unique

**Proportion validation:**

- Values must be in range `[0, 1]`

- Population proportions (valid + missing codes) must sum to 1.0 ±0.001
  per variable

- Contamination proportions (corrupt\_\*) are excluded from sum

- Auto-normalizes with warning if sum ≠ 1.0

**Parameter validation:**

- Distribution-specific requirements:

  - normal → mean + sd

  - gompertz → rate + shape

  - exponential → rate

  - poisson → rate

**Link validation (if config provided):**

- All uid values must exist in config\$uid

**Flexible recEnd validation:**

- Warns but doesn't error on unknown recEnd values

## Examples

``` r
if (FALSE) { # \dontrun{
# Validate details
details <- read.csv("mock_data_config_details.csv", stringsAsFactors = FALSE)
validate_mock_data_config_details(details)

# Validate with cross-check against config
config <- read.csv("mock_data_config.csv", stringsAsFactors = FALSE)
validate_mock_data_config_details(details, config = config)
} # }
```
