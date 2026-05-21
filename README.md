# MockData

<!-- badges: start -->

[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![Version: 0.3.0](https://img.shields.io/badge/version-0.3.0-blue.svg)](https://github.com/Big-Life-Lab/MockData)
[![pkgdown](https://github.com/Big-Life-Lab/MockData/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/Big-Life-Lab/MockData/actions/workflows/pkgdown.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

<!-- badges: end -->

**Status: Experimental, pre-release software**

MockData is a work-in-progress R package for generating mock testing data from
small metadata specifications. It is useful
today for development and documentation workflows, especially when paired
with recodeflow-style metadata (see below), but it should be treated as experimental
infrastructure rather than a stable released package.

People are using MockData and reporting that it is helpful. We take that as an
encouraging signal, not as evidence that the package is mature. Please review
the generated data before using it in any workflow that matters.

**v0.4 release candidate on `dev`:** The next MockData release is currently on
the `dev` branch for testing before it is merged forward to `main`. v0.4 adds
the `mock_spec` pipeline, direct specification helpers, a recodeflow metadata
adapter, native generation, optional `simstudy` generation, post-processing
diagnostics, and a new Divio-style documentation set.

The v0.4 work keeps the existing v0.3 public functions available. Several
larger ideas were deliberately deferred rather than rushed into this release:
formula-derived variables, multi-variable correlation, Table 1 bootstrap,
LinkML/schema-first integration, and advanced survival simulation. MockData
also remains framed as mock data for development and QA, not synthetic data for
privacy release or inference.

Please try the `dev` branch with representative `variables.csv` and
`variable_details.csv` files and report bugs, surprising output, confusing
diagnostics, or migration issues in
[GitHub Issues](https://github.com/Big-Life-Lab/MockData/issues). Broader design
feedback is also welcome there; if the conversation grows beyond issue-sized
feedback, we can open a GitHub Discussion.

**What MockData can currently help with:**

- Generate metadata-driven mock variables for development and testing
- Use inline metadata for small examples, without creating separate CSV files
- Create categorical, continuous, and date-like fields from simple specifications
- Add intentional invalid or out-of-range "garbage" values for QA testing
- Generate basic time-to-event style mock dates for survival-analysis workflows
- Support examples and tutorials without exposing real person-level data

**Current development limitations:**

- APIs may change before a formal release
- Error handling is too permissive and can fail with warnings instead of stopping
- The test suite does not yet cover every important edge case
- Generated data should be manually checked against your intended metadata rules

**30-second standalone example**

For a quick numeric variable, `create_con_var()` can use two small
metadata data frames.

```r
library(MockData)

variables <- data.frame(
  variable = "age",
  label = "Age",
  variableType = "Continuous",
  rType = "integer",
  stringsAsFactors = FALSE
)

variable_details <- data.frame(
  variable = "age",
  recStart = "[18,85]", # range for generated values
  recEnd = "copy", # use recStart as the generation rule
  proportion = 1,
  stringsAsFactors = FALSE
)

age <- create_con_var(
  var = "age",
  databaseStart = "example",
  variables = variables,
  variable_details = variable_details,
  n = 100,
  seed = 123
)

head(age)
#>   age
#> 1  37
#> 2  71
#> 3  45
#> 4  77
#> 5  81
#> 6  21
```

## Standalone example with a continuous age range

Here, `rType = "double"` keeps age as a continuous numeric value while
`variable_details` defines the valid age range.

```r
library(MockData)

variables <- data.frame(
  variable = "age",
  label = "Age",
  variableType = "Continuous",
  rType = "double",
  role = "enabled",
  stringsAsFactors = FALSE
)

variable_details <- data.frame(
  variable = "age",
  recStart = "[18,85]",
  recEnd = "copy",
  proportion = 1,
  stringsAsFactors = FALSE
)

age <- create_con_var(
  var = "age",
  databaseStart = "example",
  variables = variables,
  variable_details = variable_details,
  n = 100,
  seed = 123
)

head(age)
#>        age
#> 1 37.26769
#> 2 70.81644
#> 3 45.40145
#> 4 77.16217
#> 5 81.01131
#> 6 21.05229
```

## Example with metadata files

For use with the [`recodeflow` universe](#the-recodeflow-universe), including cchsflow, chmsflow, and other packages.

```r
library(MockData)

# Generate mock data from recode metadata files
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

**What's in those CSV files?** See [inst/extdata/minimal-example/](inst/extdata/minimal-example/README.md) - just variable names, types, ranges, and optional mock-data parameters.

**When should you use metadata files?**

Two common paths:

1. **Already using recodeflow?** Use MockData with your existing `variables.csv` and `variable_details.csv` files. No duplicate specifications needed.
2. **Building a repeatable mock dataset?** Upfront cost to create configuration files, but you get reproducible data pipelines and documentation that stays in sync with your code.

For one-off examples, tutorials, and quick tests, defining `variables` and
`variable_details` directly in R is often enough.

## What is mock data?

In this package, "mock data" refers to metadata-driven simulated data created solely for software testing and workflow validation. Mock data are generated from variable specifications and contain **no real person-level data** or identifiable information.

**Key distinctions:**

- **Mock data** (this package): Generated from metadata only. Mimics variable structure and ranges but not real-world statistical relationships. Used for testing pipelines, not analysis.
- **Synthetic data**: Preserves statistical properties and relationships from real datasets through generative models. May be used for research when properly validated.
- **Dummy data**: Placeholder or minimal test data, often hardcoded or randomly generated without metadata constraints.

MockData creates data that *looks* realistic (appropriate variable types, value ranges, category labels, tagged NAs) but has **no relationship to any actual population**. Joint distributions and correlations will purposely differ from real-world data.

MockData is used to test data analyses pipelines, including data transformation, cleaning, analyses, and modelling. For example, mockData allow you to create out of range and invalid data (what we call 'garbage' data) to test data cleaning processes.

### Use cases

**Appropriate uses:**

- Workflow testing and data pipeline validation
- Data harmonisation logic checks (cchsflow, chmsflow)
- Developing analysis scripts before data access
- Creating reproducible examples for documentation
- Training new analysts on data structure

**Not appropriate for:**

- Population inference or epidemiological modelling
- Predictive algorithm training
- Statistical analysis or research publication
- Any use requiring realistic joint distributions or correlations

### Privacy and ethics

Generated mock data contain **no personal information or individual-level identifiers**. All data are created synthetically from metadata specifications, ensuring negligible risk of re-identification. This approach supports responsible, ethical, and reproducible public-health software development.

## Features

- **Metadata-driven**: Uses simple variable specifications supplied as data frames or CSV files
- **Recodeflow-compatible**: Works with existing `variables.csv` and `variable_details.csv` metadata from recodeflow projects
- **Flexible parsing**: Supports recodeflow notation formats (database-prefixed, bracket, mixed)
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
- [Survival data](vignettes/tutorial-survival-data.qmd) - Time-to-event data and temporal patterns

**Examples:**

- [Minimal example](inst/extdata/minimal-example/README.md) - Simplest possible metadata configuration
- CHMS sample metadata is included in [inst/extdata/chms/](inst/extdata/chms/)

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
