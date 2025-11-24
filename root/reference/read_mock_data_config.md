# Read and validate MockData configuration file defining variable specifications for mock data generation

Reads a mock_data_config.csv file containing variable definitions for
mock data generation. Optionally validates the configuration against
schema requirements.

## Usage

``` r
read_mock_data_config(config_path, validate = TRUE)
```

## Arguments

- config_path:

  Character. Path to mock_data_config.csv file.

- validate:

  Logical. Whether to validate the configuration (default TRUE).

## Value

Data frame with configuration variables and their parameters, sorted by
position column.

## Details

The configuration file should have the following columns:

**Core columns:**

- uid: Unique identifier (v_001, v_002, ...)

- variable: Variable name

- role: Comma-separated role values (enabled, predictor, outcome, etc.)

- label: Short label for tables

- labelLong: Descriptive label

- section: Primary grouping for Table 1

- subject: Secondary grouping

- variableType: Data type (categorical, continuous, date, survival,
  character, integer)

- units: Measurement units

- position: Sort order (10, 20, 30...)

**Provenance columns:**

- source_database: Database identifier(s) from import

- source_spec: Source specification file

- version: Configuration version

- last_updated: Date last modified

- notes: Documentation

- seed: Random seed for reproducibility

The function performs the following processing:

1.  Reads CSV file with read.csv()

2.  Converts date columns to Date type

3.  Sorts by position column

4.  Validates if validate = TRUE

## Examples

``` r
if (FALSE) { # \dontrun{
# Read configuration file
config <- read_mock_data_config(
  "inst/extdata/mock_data_config.csv"
)

# Read without validation
config <- read_mock_data_config(
  "inst/extdata/mock_data_config.csv",
  validate = FALSE
)

# View structure
str(config)
head(config)
} # }
```
