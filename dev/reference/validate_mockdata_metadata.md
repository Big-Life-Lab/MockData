# Validate MockData Extension Fields

Validate MockData Extension Fields

## Usage

``` r
validate_mockdata_metadata(
  variables_path,
  variable_details_path,
  mode = "basic"
)
```

## Arguments

- variables_path:

  Path to variables.csv file

- variable_details_path:

  Path to variable_details.csv file

- mode:

  Validation mode: "basic" or "strict" (default: "basic")

## Value

Validation result object with errors, warnings, and info
