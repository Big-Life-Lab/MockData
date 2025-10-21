# Example Generated Mock Data

This directory contains mock data that has been successfully generated using MockData functions. These files demonstrate:

1. **Expected output format** from mock data generation
2. **Coverage examples** showing successful generation across multiple cycles
3. **Reference data** for validation and comparison

## Directory Structure

```
examples/
└── demport/                       # DemPoRT mock data output
    ├── mock_all_cycles.csv              # Combined data across all cycles
    ├── mock_cchs2001_i.csv              # CCHS 2001 interviewed
    ├── mock_cchs2001_p.csv              # CCHS 2001 pumf
    ├── mock_cchs2003_i.csv
    ├── mock_cchs2003_p.csv
    ├── mock_cchs2005_i.csv
    ├── mock_cchs2005_p.csv
    ├── mock_cchs2007_2008_i.csv
    ├── mock_cchs2007_2008_p.csv
    ├── mock_cchs2009_2010_i.csv
    ├── mock_cchs2009_2010_p.csv
    ├── mock_cchs2009_s.csv              # CCHS 2009 share
    └── ... (28 files total, ~2.2 MB)
```

## Usage

Access these example files in R:

```r
library(MockData)

# Load example DemPoRT mock data
example_data <- read.csv(
  system.file("examples/demport/mock_cchs2001_i.csv", package = "MockData"),
  stringsAsFactors = FALSE
)

head(example_data)
```

## Generation Details

These files were generated using the DemPoRT metadata worksheets in `inst/extdata/demport/`:

- **Source metadata**: `variables_DemPoRT.csv` and `variable_details_DemPoRT.csv`
- **Cycles covered**: CCHS 2001-2018 (multiple formats: interviewed, pumf, share)
- **Generation method**: `create_cat_var()` and `create_con_var()` functions
- **Seed**: Reproducible generation with fixed seeds

## File Size

Total size: ~2.2 MB (acceptable for CRAN package)
- Each file: ~80 KB
- Combined: All cycles merged into `mock_all_cycles.csv`

## Regenerating

To regenerate these files, see:
- `vignettes/demport-example.qmd` - Complete generation workflow
- `mockdata-tools/test-all-cycles.R` - Automated testing across cycles

## Notes

- These are **synthetic mock data**, not real survey data
- Used for testing recodeflow transformations and linkages
- Variables follow recodeflow harmonisation conventions
- All generated values respect category ranges and NA tags defined in metadata
