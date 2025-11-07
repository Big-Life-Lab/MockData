# MockData

Generate mock testing data from recodeflow metadata (variables.csv and
variable-details.csv).

## Overview

MockData is a tool for generating metadata-driven mock datasets to
support testing and development of harmonisation workflows across
recodeflow projects such as CHMSFlow and CCHSFlow.

### What is mock data?

In this package, “mock data” refers to metadata-driven simulated data
created solely for software testing and workflow validation. Mock data
are generated from variable specifications (e.g., `variables.csv`,
`variable_details.csv`) and contain **no real person-level data** or
identifiable information.

**Key distinctions**:

- **Mock data** (this package): Generated from metadata only. Mimics
  variable structure and ranges but not real-world statistical
  relationships. Used for testing pipelines, not analysis.
- **Synthetic data**: Preserves statistical properties and relationships
  from real datasets through generative models. May be used for research
  when properly validated.
- **Dummy data**: Placeholder or minimal test data, often hardcoded or
  randomly generated without metadata constraints.

MockData creates data that *looks* realistic (appropriate variable
types, value ranges, category labels, tagged NAs) but has **no
relationship to any actual population**. Joint distributions and
correlations may differ significantly from real-world data.

### Use cases

**Appropriate uses**:

- Workflow testing and data pipeline validation
- Data harmonisation logic checks (cchsflow, chmsflow)
- Developing analysis scripts before data access
- Creating reproducible examples for documentation
- Training new analysts on survey data structure

**Not appropriate for**:

- Population inference or epidemiological modelling
- Predictive algorithm training
- Statistical analysis or research publication
- Any use requiring realistic joint distributions or correlations

### Privacy and ethics

Generated mock data contain **no personal information or
individual-level identifiers**. All data are created synthetically from
metadata specifications, ensuring negligible risk of re-identification.
This approach supports responsible, ethical, and reproducible
public-health software development.

## Features

- **Metadata-driven**: Uses existing `variables.csv` and
  `variable-details.csv` from recodeflow package - no duplicate
  specifications needed
- **Universal**: Works across CHMS, CCHS, and future recodeflow projects
- **Recodeflow-standard**: Supports all recodeflow notation formats
  (database-prefixed, bracket, mixed)
- **Data quality testing**: Generate invalid/out-of-range values to test
  validation pipelines (`prop_invalid`)
- **Validation**: Tools to check metadata quality

## Installation

``` r
# Install from local directory
devtools::install_local("~/github/mock-data")

# Or install from GitHub (once published)
# devtools::install_github("your-org/MockData")
```

**Note**: Package vignettes are in Quarto format (.qmd). To build
vignettes locally, you need [Quarto](https://quarto.org/) installed. For
team use, this is our standard going forward.

## Quick start

**Note**: These steps generate mock data for development and testing
only—not for modelling or analysis. Data are created with reproducible
seeds for consistent test results.

``` r
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

- [Date variables and temporal
  data](https://big-life-lab.github.io/MockData/vignettes/dates.qmd) -
  Date generation, distributions, and survival analysis prep
- [CCHS
  example](https://big-life-lab.github.io/MockData/vignettes/cchs-example.qmd) -
  CCHS workflow demonstration
- [CHMS
  example](https://big-life-lab.github.io/MockData/vignettes/chms-example.qmd) -
  CHMS workflow demonstration
- [DemPoRT
  example](https://big-life-lab.github.io/MockData/vignettes/demport-example.qmd) -
  Survival analysis workflow

## Contributing

This package is part of the recodeflow ecosystem. See
[CONTRIBUTING.md](https://big-life-lab.github.io/MockData/CONTRIBUTING.md)
for details.

## License

MIT License - see
[LICENSE](https://big-life-lab.github.io/MockData/LICENSE) file for
details.

## The recodeflow universe

MockData is part of the **recodeflow universe** — a metadata-driven
approach to variable recoding and harmonization. The core philosophy is
to define variable transformations once in metadata files, then reuse
those definitions for harmonization, documentation, and mock data
generation.

**Design principles:**

- **Metadata-driven**: Variable definitions and recode rules live in
  structured metadata (CSV files)
- **Reusable**: Same metadata drives harmonization code, documentation,
  and testing data
- **Survey-focused**: Built for health surveys (CCHS, CHMS) but
  applicable to any categorical/continuous data
- **Open and reproducible**: Transparent recode logic that anyone can
  inspect and verify

**Related packages:**

- [**cchsflow**](https://github.com/Big-Life-Lab/cchsflow):
  Harmonization workflows for Canadian Community Health Survey (CCHS)
- [**chmsflow**](https://github.com/Big-Life-Lab/chmsflow):
  Harmonization workflows for Canadian Health Measures Survey (CHMS)
- [**recodeflow**](https://github.com/Big-Life-Lab/recodeflow): Core
  metadata specifications and utilities

## Data sources and acknowledgements

The example metadata in this package is derived from:

- **Canadian Community Health Survey (CCHS)** — Statistics Canada
- **Canadian Health Measures Survey (CHMS)** — Statistics Canada

**Statistics Canada Open License:**

The use of CCHS and CHMS metadata examples in this package falls under
Statistics Canada’s Open License, which permits use, reproduction, and
distribution of Statistics Canada data products. We acknowledge
Statistics Canada as the source of the survey designs and variable
definitions that informed our example metadata files.

**Important:** This package generates **mock data only**. It does not
contain, distribute, or provide access to any actual Statistics Canada
microdata. Real CCHS and CHMS data are available through Statistics
Canada’s Research Data Centres (RDCs) and Public Use Microdata Files
(PUMFs) under appropriate data access agreements.

For more information: [Statistics Canada Open
License](https://www.statcan.gc.ca/en/reference/licence)

## Development environment setup

This package uses [renv](https://rstudio.github.io/renv/) for
reproducible package development environments.

### For new contributors

After cloning the repository:

``` r
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
- **Lockfile baseline**: R 4.4.2 (institutional environments typically
  run 1-2 versions behind current)
- The renv lockfile works across this version range - minor R version
  differences are handled automatically

### Daily development workflow

``` r
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

``` r
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

``` r
# If packages seem out of sync:
renv::status()

# To update package versions:
renv::update()
renv::snapshot()

# To restore to lockfile state:
renv::restore()
```

For more details, see
[CONTRIBUTING.md](https://big-life-lab.github.io/MockData/CONTRIBUTING.md).
