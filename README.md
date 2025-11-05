# MockData

Generate mock testing data from recodeflow metadata (variables.csv and variable-details.csv).

## Overview

MockData generates realistic test data from variable descriptive statistics—**not from real individual-level data**. Unlike synthetic data generators that preserve statistical relationships from actual datasets, MockData creates data purely from metadata definitions (variable types, value ranges, category labels).

**Key distinction**: MockData is for testing data pipelines and harmonization workflows, not for statistical analysis or research. It generates data that *looks* realistic but has no relationship to any actual population.

**Use cases**:
- Test data harmonization code (cchsflow, chmsflow)
- Develop analysis scripts before data access
- Create reproducible examples for documentation
- Train new analysts on survey data structure
- Validate data processing pipelines

MockData reads recodeflow metadata files (variables.csv and variable_details.csv) and generates appropriate categorical and continuous variables with correct value ranges, labeled categories, tagged NAs, and reproducible seeds.

## Features

- **Metadata-driven**: Uses existing `variables.csv` and `variable-details.csv` from recodeflow package - no duplicate specifications needed
- **Universal**: Works across CHMS, CCHS, and future recodeflow projects
- **Recodeflow-standard**: Supports all recodeflow notation formats (database-prefixed, bracket, mixed)
- **Data quality testing**: Generate invalid/out-of-range values to test validation pipelines (`prop_invalid`)
- **Validation**: Tools to check metadata quality

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
  system.file("extdata/chms/variables_chmsflow_sample.csv", package = "MockData"),
  stringsAsFactors = FALSE
)
variable_details <- read.csv(
  system.file("extdata/chms/variable_details_chmsflow_sample.csv", package = "MockData"),
  stringsAsFactors = FALSE
)

# Get variables for a specific cycle
cycle1_vars <- get_cycle_variables("cycle1", variables, variable_details)

# Get unique raw variables to generate
raw_vars <- get_raw_variables("cycle1", variables, variable_details)

# Create empty data frame
df_mock <- data.frame(id = 1:1000)

# Generate a categorical variable
result <- create_cat_var("alc_11", "cycle1", variable_details, variables,
                        length = 1000, df_mock = df_mock, seed = 123)
if (!is.null(result)) {
  df_mock <- cbind(df_mock, result)
}

# Generate a continuous variable
result <- create_con_var("alcdwky", "cycle1", variable_details, variables,
                        length = 1000, df_mock = df_mock, seed = 123)
if (!is.null(result)) {
  df_mock <- cbind(df_mock, result)
}
```

## Documentation

**Vignettes**:

- [Date variables and temporal data](vignettes/dates.qmd) - Date generation, distributions, and survival analysis prep
- [CCHS example](vignettes/cchs-example.qmd) - CCHS workflow demonstration
- [CHMS example](vignettes/chms-example.qmd) - CHMS workflow demonstration
- [DemPoRT example](vignettes/demport-example.qmd) - Survival analysis workflow

## Contributing

This package is part of the recodeflow ecosystem. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## The recodeflow universe

MockData is part of the **recodeflow universe** — a metadata-driven approach to variable recoding and harmonization. The core philosophy is to define variable transformations once in metadata files, then reuse those definitions for harmonization, documentation, and mock data generation.

**Design principles:**

- **Metadata-driven**: Variable definitions and recode rules live in structured metadata (CSV files)
- **Reusable**: Same metadata drives harmonization code, documentation, and testing data
- **Survey-focused**: Built for health surveys (CCHS, CHMS) but applicable to any categorical/continuous data
- **Open and reproducible**: Transparent recode logic that anyone can inspect and verify

**Related packages:**

- [**cchsflow**](https://github.com/Big-Life-Lab/cchsflow): Harmonization workflows for Canadian Community Health Survey (CCHS)
- [**chmsflow**](https://github.com/Big-Life-Lab/chmsflow): Harmonization workflows for Canadian Health Measures Survey (CHMS)
- [**recodeflow**](https://github.com/Big-Life-Lab/recodeflow): Core metadata specifications and utilities

## Data sources and acknowledgements

The example metadata in this package is derived from:

- **Canadian Community Health Survey (CCHS)** — Statistics Canada
- **Canadian Health Measures Survey (CHMS)** — Statistics Canada

**Statistics Canada Open License:**

The use of CCHS and CHMS metadata examples in this package falls under Statistics Canada's Open License, which permits use, reproduction, and distribution of Statistics Canada data products. We acknowledge Statistics Canada as the source of the survey designs and variable definitions that informed our example metadata files.

**Important:** This package generates **mock data only**. It does not contain, distribute, or provide access to any actual Statistics Canada microdata. Real CCHS and CHMS data are available through Statistics Canada's Research Data Centres (RDCs) and Public Use Microdata Files (PUMFs) under appropriate data access agreements.

For more information: [Statistics Canada Open License](https://www.statcan.gc.ca/en/reference/licence)
