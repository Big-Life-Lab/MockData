# CHMS Test Data

This directory contains CHMS metadata files for testing and development of the MockData package.

## Files

- **chms-variables.csv**: CHMS variable metadata from chmsflow
- **chms-variable-details.csv**: CHMS variable details specifications from chmsflow

## Purpose

These files are used for:
1. Running the test suite (`tests/testthat/test-mockdata.R`)
2. Validation tool testing (`inst/validation/mockdata-tools/`)
3. Development and debugging

## Usage

```r
# Load CHMS metadata
variables <- read.csv(
  system.file("testdata/chms/chms-variables.csv", package = "MockData"),
  stringsAsFactors = FALSE
)
variable_details <- read.csv(
  system.file("testdata/chms/chms-variable-details.csv", package = "MockData"),
  stringsAsFactors = FALSE
)

# Generate mock data for CHMS cycle1
cycle1_vars <- get_cycle_variables("cycle1", variables, variable_details)
```

## Notes

- These files are copied from the chmsflow package
- Valid CHMS cycles: cycle1-7, cycle1_meds-6_meds
- Total: 212 variables across 12 cycles
