# Example Metadata Worksheets

This directory contains example `variables.csv` and `variable-details.csv` files from different recodeflow projects. These worksheets serve as:

1. **Test data** for package development and testing
2. **Examples** for users to understand metadata format requirements
3. **Vignette data** used in package documentation

## Directory Structure

```
extdata/
├── cchs/                          # CCHS (Canadian Community Health Survey)
│   ├── cchsflow_variable_details.csv    # CCHS variable details from cchsflow (705 KB)
│   ├── cchs_variables.csv               # CCHS variables (44 KB)
│   └── cchs_variable_details.csv        # Additional CCHS variable details (6 KB)
├── chms/                          # CHMS (Canadian Health Measures Survey)
│   ├── chms-variables.csv               # CHMS variables (213 rows)
│   └── chms-variable-details.csv        # CHMS variable details (1,111 rows)
└── demport/                       # DemPoRT (uses CCHS data)
    ├── variables_DemPoRT.csv            # DemPoRT variables (33 KB)
    ├── variable_details_DemPoRT.csv     # DemPoRT variable details (276 KB)
    └── DemPoRTv2_Mock_Data_Info.*       # DemPoRT documentation
```

## Usage

Access these files in R using `system.file()`:

```r
library(MockData)

# Load CHMS example metadata
variables <- read.csv(
  system.file("extdata/chms/chms-variables.csv", package = "MockData"),
  stringsAsFactors = FALSE
)

variable_details <- read.csv(
  system.file("extdata/chms/chms-variable-details.csv", package = "MockData"),
  stringsAsFactors = FALSE
)
```

## Metadata Format

All files follow the recodeflow metadata conventions documented in `inst/metadata/`. Key requirements:

- **variables.csv**: Defines harmonised variables with `variable`, `variableStart`, and `databaseStart` columns
- **variable-details.csv**: Defines category mappings and transformations

See vignettes for complete examples:
- `vignette("cchs-example")` - CCHS (Canadian Community Health Survey) workflow
- `vignette("chms-example")` - CHMS (Canadian Health Measures Survey) workflow
- `vignette("demport-example")` - DemPoRT (uses CCHS data) workflow

## Survey Context

**CCHS (Canadian Community Health Survey)**:
- Public data available via cchsflow package
- Some detailed data only in secure environments
- Used by projects like DemPoRT

**CHMS (Canadian Health Measures Survey)**:
- Only available in secure data environments
- Mock data essential for chmsflow development and testing

**DemPoRT**:
- Project using CCHS data
- Requires secure detailed CCHS variables
- Example of why mock data is needed

For the latest metadata, see:
- cchsflow package (CCHS)
- chmsflow package (CHMS)
- DemPoRT project repository
