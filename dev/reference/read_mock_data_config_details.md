# Read and validate MockData configuration details file containing distribution parameters and category proportions

Reads a mock_data_config_details.csv file containing distribution
parameters and proportions for mock data generation. Optionally
validates the details against schema requirements and optionally against
a config file.

## Usage

``` r
read_mock_data_config_details(details_path, validate = TRUE, config = NULL)
```

## Arguments

- details_path:

  Character. Path to mock_data_config_details.csv file.

- validate:

  Logical. Whether to validate the details (default TRUE).

- config:

  Data frame (optional). Configuration from read_mock_data_config() for
  cross-validation of variable references.

## Value

Data frame with detail rows for each variable's distribution parameters.

## Details

The details file should have the following columns:

**Link columns:**

- uid: Links to mock_data_config.csv via uid (variable-level)

- uid_detail: Unique identifier for this detail row (d_001, d_002, ...)

- variable: Variable name (denormalized for readability)

**Category/parameter columns:**

- dummyVariable: Recodeflow dummy variable identifier

- recEnd: Category value or parameter name

- catLabel: Short category label

- catLabelLong: Long category label

- units: Measurement units for this parameter

**Distribution parameters:**

- proportion: Proportion for this category (0-1)

- value: Numeric value

- range_min, range_max: Value ranges

- date_start, date_end: Date ranges

- notes: Implementation notes

The function performs the following processing:

1.  Reads CSV file with read.csv()

2.  Converts numeric columns (proportion, value, ranges)

3.  Converts date columns to Date type

4.  Validates if validate = TRUE

## Examples

``` r
if (FALSE) { # \dontrun{
# Read details file
details <- read_mock_data_config_details(
  "inst/extdata/mock_data_config_details.csv"
)

# Read with cross-validation against config
config <- read_mock_data_config("inst/extdata/mock_data_config.csv")
details <- read_mock_data_config_details(
  "inst/extdata/mock_data_config_details.csv",
  config = config
)

# View structure
str(details)
head(details)
} # }
```
