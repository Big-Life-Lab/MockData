# MockData

::: {.vignette-about}
Generate realistic test data from `recodeflow` variable configuration files (`variables.csv` and `variable-details.csv`).
:::

30-second example

```r
library(MockData)

# Generate mock data from metadata files
mock_data <- create_mock_data(
  databaseStart = "minimal-example",
  variables = system.file("extdata/minimal-example/variables.csv", package = "MockData"),
  variable_details = system.file("extdata/minimal-example/variable_details.csv", package = "MockData"),
  n = 100,
  seed = 123
)

head(mock_data)
#>  age smoking interview_date
#> 1  42       2     2001-08-05
#> 2  47       2     2002-11-27
#> 3  73       3     2002-11-14
#> 4  51       1     2005-01-14
#> 5  52       1     2001-02-25
#> 6  76       3     2004-07-25
```

**What's in those CSV files?** See [inst/extdata/minimal-example/](inst/extdata/minimal-example/README.md) - just variable names, types, and ranges. Total 9 rows across 2 files.

**Why use variable metadata files?** 

Two paths:

1. **Already using recodeflow?** Use MockData with your existing `variables.csv` and `variable_details.csv` files. No duplicate specifications needed.
2. **New to metadata?** Upfront cost to create configuration files, but you get reproducible data pipelines and documentation that stays in sync with your code.

## What is mock data?

In this package, "mock data" refers to metadata-driven simulated data created solely for software testing and workflow validation. Mock data are generated from variable specifications and contain **no real person-level data** or identifiable information.

**Key distinctions:**

- **Mock data** (this package): Generated from metadata only. Mimics variable structure and ranges but not real-world statistical relationships. Used for testing pipelines, not analysis.
- **Synthetic data**: Preserves statistical properties and relationships from real datasets through generative models. May be used for research when properly validated.
- **Dummy data**: Placeholder or minimal test data, often hardcoded or randomly generated without metadata constraints.

MockData creates data that *looks* realistic (appropriate variable types, value ranges, category labels, tagged NAs) but has **no relationship to any actual population**. Joint distributions and correlations may differ significantly from real-world data.

### Use cases

**Appropriate uses:**

- Workflow testing and data pipeline validation
- Data harmonisation logic checks (cchsflow, chmsflow)
- Developing analysis scripts before data access
- Creating reproducible examples for documentation
- Training new analysts on survey data structure

**Not appropriate for:**

- Population inference or epidemiological modelling
- Predictive algorithm training
- Statistical analysis or research publication
- Any use requiring realistic joint distributions or correlations

### Privacy and ethics

Generated mock data contain **no personal information or individual-level identifiers**. All data are created synthetically from metadata specifications, ensuring negligible risk of re-identification. This approach supports responsible, ethical, and reproducible public-health software development.

## Features

- **Metadata-driven**: Uses existing `variables.csv` and `variable_details.csv` from recodeflow projects
- **Universal**: Works across CHMS, CCHS, and future recodeflow projects
- **Recodeflow-standard**: Supports all recodeflow notation formats (database-prefixed, bracket, mixed)
- **Data quality testing**: Generate invalid/out-of-range values to test validation pipelines
- **Validation**: Tools to check metadata quality

## Installation

```r
# Install from local directory
devtools::install_local("~/github/mock-data")

# Or install from GitHub (once published)
# devtools::install_github("Big-Life-Lab/MockData")
```

**Note**: Package vignettes are in Quarto format (.qmd). To build vignettes locally, you need [Quarto](https://quarto.org/) installed.

## Next steps

**Tutorials:**

- [Getting started](vignettes/getting-started.qmd) - Complete tutorial from single variables to full datasets
- [For recodeflow users](vignettes/for-recodeflow-users.qmd) - Using MockData with existing metadata
- [Survival data](vignettes/survival-data.qmd) - Time-to-event data and temporal patterns

**Examples:**

- [Minimal example](inst/extdata/minimal-example/README.md) - Simplest possible metadata configuration
- [CCHS example](vignettes/cchs-example.qmd) - CCHS workflow demonstration
- [CHMS example](vignettes/chms-example.qmd) - CHMS workflow demonstration

## Configuration architecture

MockData uses a three-file architecture that separates project data dictionaries, study specifications, and MockData-specific parameters:

### File structure

1. **Project data dictionary** (`variables.csv`)

   - Variable names, labels, types, role flags
   - Shared across analysis projects
   - Example: `variable, variableType, label`
2. **Study specifications** (`variable_details.csv`)

   - Study date ranges, follow-up periods
   - Category definitions and value ranges
   - Transformation rules (recStart, recEnd, copy, catLabel)
   - Example: `uvariable, recStart, catLabel`
3. **MockData-specific parameters** (`mock_config.csv`, optional)

   - Proportions of variable categories
   - Event occurrence probabilities (`event_occurs`)
   - Distribution parameters (`distribution`)
   - Garbage data proportions (`prop_invalid`)
   - Advanced features (survival data, data quality testing)

This separation allows MockData to read existing recodeflow metadata files without modification, while supporting optional MockData-specific configurations when needed.

## Contributing

This package is part of the recodeflow ecosystem. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## The recodeflow universe

MockData is part of the **recodeflow universe** — a metadata-driven approach to variable recoding and harmonisation. The core philosophy is to define variable transformations once in metadata files, then reuse those definitions for harmonisation, documentation, and mock data generation.

**Design principles:**

- **Metadata-driven**: Variable definitions and recode rules live in structured metadata (CSV files)
- **Reusable**: Same metadata drives harmonisation code, documentation, and testing data
- **Survey-focused**: Built for health surveys (CCHS, CHMS) but applicable to any categorical/continuous data
- **Open and reproducible**: Transparent recode logic that anyone can inspect and verify

**Related packages:**

- [**cchsflow**](https://github.com/Big-Life-Lab/cchsflow): Harmonisation workflows for Canadian Community Health Survey (CCHS)
- [**chmsflow**](https://github.com/Big-Life-Lab/chmsflow): Harmonisation workflows for Canadian Health Measures Survey (CHMS)
- [**recodeflow**](https://github.com/Big-Life-Lab/recodeflow): Core metadata specifications and utilities

## Data sources and acknowledgements

The example metadata in this package is derived from:

- **Canadian Community Health Survey (CCHS)** — Statistics Canada
- **Canadian Health Measures Survey (CHMS)** — Statistics Canada

**Statistics Canada Open License:**

The use of CCHS and CHMS metadata examples in this package falls under Statistics Canada's Open License, which permits use, reproduction, and distribution of Statistics Canada data products. We acknowledge Statistics Canada as the source of the survey designs and variable definitions that informed our example metadata files.

**Important:** This package generates **mock data only**. It does not contain, distribute, or provide access to any actual Statistics Canada microdata. Real CCHS and CHMS data are available through Statistics Canada's Research Data Centres (RDCs) and Public Use Microdata Files (PUMFs) under appropriate data access agreements.

For more information: [Statistics Canada Open License](https://www.statcan.gc.ca/en/reference/licence)

## Development environment setup

This package uses [renv](https://rstudio.github.io/renv/) for reproducible package development environments.

### For new contributors

After cloning the repository:

```r
# Restore the package environment (installs all dependencies)
renv::restore()

# Install the MockData package itself into the renv library
# (Required for building documentation and running tests)
devtools::install(upgrade = 'never')

# Load the package for development
devtools::load_all()
```

### R version compatibility

- **Supported**: R 4.3.x - 4.4.x
- **Lockfile baseline**: R 4.4.2 (institutional environments typically run 1-2 versions behind current)
- The renv lockfile works across this version range - minor R version differences are handled automatically

### Daily development workflow

```r
# Install new packages as normal
install.packages("packagename")

# After adding dependencies to DESCRIPTION:
devtools::install_dev_deps()  # Install updated dependencies
renv::snapshot()              # Update lockfile
# Commit the updated renv.lock file

# Check environment status anytime:
renv::status()
```

### Building documentation and site

```r
# Generate function documentation
devtools::document()

# Install the package (required before building site)
devtools::install(upgrade = 'never')

# Build pkgdown site (requires Quarto installed)
pkgdown::build_site()

# Run tests
devtools::test()
```

### Troubleshooting

```r
# If packages seem out of sync:
renv::status()

# To update package versions:
renv::update()
renv::snapshot()

# To restore to lockfile state:
renv::restore()
```

For more details, see [CONTRIBUTING.md](CONTRIBUTING.md).
