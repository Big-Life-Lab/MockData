# MockData

Generate mock testing data from recodeflow metadata (variables.csv and variable-details.csv).

## Overview

MockData creates realistic mock data for testing harmonisation workflows across recodeflow projects (CHMS, CCHS, etc.). It reads variable specifications from metadata files and generates appropriate categorical and continuous variables with correct value ranges, tagged NAs, and reproducible seeds.

## Features

- **Metadata-driven**: Uses existing `variables.csv` and `variable-details.csv` - no duplicate specifications needed
- **Recodeflow-standard**: Supports all recodeflow notation formats (database-prefixed, bracket, mixed)
- **Metadata validation**: Tools to check metadata quality
- **Universal**: Works across CHMS, CCHS, and future recodeflow projects
- **Test availability**: 224 tests covering parsers, helpers, and generators

## Installation

```r
# Install from local directory
devtools::install_local("~/github/mock-data")

# Or install from GitHub (once published)
# devtools::install_github("your-org/MockData")
```

**Note**: Package vignettes are in Quarto format (.qmd). To build vignettes locally, you need [Quarto](https://quarto.org/) installed. For team use, this is our standard going forward.

## Quick start

```r
library(MockData)

# Load metadata (CHMS example with sample data)
variables <- read.csv(
  system.file("extdata/chms/chmsflow_sample_variables.csv", package = "MockData"),
  stringsAsFactors = FALSE
)
variable_details <- read.csv(
  system.file("extdata/chms/chmsflow_sample_variable_details.csv", package = "MockData"),
  stringsAsFactors = FALSE
)

# Create empty data frame
df_mock <- data.frame(id = 1:1000)

# Generate a categorical variable
df_mock <- create_cat_var(
  var_raw = "alc_11",
  cycle = "cycle1",
  variable_details = variable_details,
  variables = variables,
  df_mock = df_mock,
  prop_NA = 0.05  # 5% missing values
)

# Generate a continuous variable
df_mock <- create_con_var(
  var_raw = "alcdwky",
  cycle = "cycle1",
  variable_details = variable_details,
  variables = variables,
  length = 1000,
  df_mock = df_mock,
  distribution = "uniform",
  prop_NA = 0.03  # 3% missing values
)
```

## Documentation

- **[Getting started](vignettes/getting-started.qmd)**: Hands-on tutorial for new users
- **[User guide](vignettes/user-guide.qmd)**: Comprehensive feature documentation
- **[Advanced topics](vignettes/advanced-topics.qmd)**: Technical details and edge cases

### Database-specific examples

- **[CCHS example](vignettes/cchs-example.qmd)**: Generate CCHS mock data
- **[CHMS example](vignettes/chms-example.qmd)**: Generate CHMS mock data
- **[DemPoRT example](vignettes/demport-example.qmd)**: Generate DemPoRT mock data

## Validation tools

Located in `mockdata-tools/`:

```bash
# Validate metadata quality
Rscript mockdata-tools/validate-metadata.R

# Test all cycles
Rscript mockdata-tools/test-all-cycles.R

# Compare different approaches
Rscript mockdata-tools/create-comparison.R
```

See `mockdata-tools/README.md` for detailed documentation.

## Architecture

### Core modules

1. **Parsers** (`R/mockdata-parsers.R`):
   - `parse_variable_start()`: Extracts raw variable names from variableStart
   - `parse_range_notation()`: Handles range syntax like `[7,9]`, `[18.5,25)`, `else`

2. **Helpers** (`R/mockdata-helpers.R`):
   - `get_cycle_variables()`: Filters metadata by cycle
   - `get_raw_variables()`: Returns unique raw variables with harmonisation groupings
   - `get_variable_details_for_raw()`: Retrieves category specifications
   - `get_variable_categories()`: Extracts valid category codes

3. **Generators**:
   - `create_cat_var()` (`R/create_cat_var.R`): Generates categorical variables with tagged NA support
   - `create_con_var()` (`R/create_con_var.R`): Generates continuous variables with realistic distributions


## Testing

```r
# Run all tests
devtools::test()

# Run specific test file
testthat::test_file("tests/testthat/test-mockdata.R")
```

## Contributing

This package is part of the recodeflow ecosystem. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Related Projects

- [**chmsflow**](https://github.com/Big-Life-Lab/chmsflow): CHMS harmonisation workflows
- [**cchsflow**](https://github.com/Big-Life-Lab/cchsflow): CCHS harmonisation workflows
