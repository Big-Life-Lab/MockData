# MockData 0.2.0 (Development)

## Major Changes

### New Features

* **Full recodeflow schema notation support** (#package-repatriation)
  - Added `parse_variable_start()` to handle all variableStart notation formats
  - Added `parse_range_notation()` to parse recStart/recFrom value ranges
  - Support for database-prefixed format: `cycle1::var1, cycle2::var2`
  - Support for bracket format: `[varname]`
  - Support for mixed format: `cycle1::var1, [var2]` (DEFAULT pattern)
  - Support for range notation: `[7,9]`, `[18.5,25)`, `(0,100]`, `[30,inf)`
  - Support for special values: `copy`, `else`, `NA::a`

* **Helper functions for metadata extraction**
  - `get_cycle_variables()`: Filter metadata by cycle
  - `get_raw_variables()`: Get unique raw variables to generate
  - `get_variable_details_for_raw()`: Retrieve category specifications
  - `get_variable_categories()`: Extract valid category codes

* **Three comprehensive vignettes**
  - CCHS example workflow
  - CHMS example workflow
  - DemPoRT example workflow

### Package Infrastructure

* Converted to proper R package structure
  - Added DESCRIPTION, NAMESPACE, LICENSE
  - Generated documentation for all exported functions
  - Added 224 comprehensive tests (100% passing)
  - Created proper package-level documentation

* **Reorganized data files**
  - `inst/extdata/`: Example metadata worksheets by survey (CCHS, CHMS, DemPoRT)
  - `inst/examples/`: Generated mock data examples
  - `inst/metadata/`: Recodeflow schema documentation

* **Validation tools** moved to `mockdata-tools/` at package root
  - `validate-metadata.R`: Check metadata quality
  - `test-all-cycles.R`: Test coverage across cycles
  - `create-comparison.R`: Compare generation approaches

### Refactoring

* Split generator functions into dedicated files
  - `create_cat_var()` → `R/create_cat_var.R`
  - `create_con_var()` → `R/create_con_var.R`
  - Removed `R/mockdata-generators.R`
  - **Original logic preserved** - only reorganized for maintainability

* Standardized file naming conventions
  - Consistent use of underscores in inst/extdata/
  - Removed spaces from filenames

### Terminology

* Deprecated "PHIAT-YLL" terminology in favour of "CCHS"
  - PHIAT-YLL is a project using CCHS data, not a distinct survey type
  - Renamed files: `phiatyll_variables.csv` → `cchs_variables.csv`
  - Updated all documentation and examples

### Testing & Validation

* 224 tests covering parsers, helpers, and generators
* 99.4% coverage across all CHMS cycles
* Battle-tested on Rafidul's chmsflow repository

## Bug Fixes

* Fixed stats package imports (rnorm, runif) to eliminate R CMD check NOTEs
* Removed unused stringr dependency from Imports (moved to Suggests)

## Documentation

* Updated README.md with current package structure
* All vignettes use proper `system.file()` paths
* Added package-level documentation (`?MockData`)
* Consistent authorship attribution across all vignettes

---

# MockData 0.1.0 (Initial Development)

## Initial Features

* Basic categorical variable generation (`create_cat_var()`)
* Basic continuous variable generation (`create_con_var()`)
* Support for tagged NA values
* Reproducible generation with seeds
* Example data from DemPoRT project

**Note**: Version 0.1.0 was Juan Li's original development version before package formalization.
