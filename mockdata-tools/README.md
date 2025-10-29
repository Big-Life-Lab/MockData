# MockData Validation and Testing Tools

## Status: Interim Development Tools

**⚠️ Note**: These validation tools are temporary development utilities that will eventually be replaced by the comprehensive validation infrastructure being developed in the recodeflow and cchsflow packages.

### Future Migration Plan

The recodeflow ecosystem is building a unified validation system:

- **cchsflow v3.0.0**: Developing `schema-validation.R` and `validate_variable_details_csv()` functions
  - See `feature/v3.0.0-validation-infrastructure` branch
  - CSV validation against YAML schemas
  - Standardised validation reporting with R CMD check style output
  - Multiple validation modes (basic, collaboration, full)

- **recodeflow** (planned): Common validation utilities shared across all flow packages
  - Centralised metadata validators
  - Harmonised variable cleaners
  - Shared schema definitions

Once the unified validation system is mature, these tools should be:
1. Migrated to use the common validation functions
2. Deprecated in favour of recodeflow/cchsflow validators
3. Eventually removed from this package

For now, these tools remain useful for:
- Quick metadata quality checks during development
- Testing mock data generation across cycles
- Identifying parsing issues specific to MockData

---

## Overview

This folder contains diagnostic and validation tools for working with MockData and metadata files. These tools help identify issues in metadata, test parsing logic, and validate generated mock data.

**Quick start:**

```bash
# Validate metadata quality
Rscript mockdata-tools/validate-metadata.R

# Test all cycles
Rscript mockdata-tools/test-all-cycles.R

# Compare different generation approaches
Rscript mockdata-tools/create-comparison.R
```

## Tools

### 1. validate-metadata.R

**Purpose**: Validate metadata quality and identify common issues

**What it checks**:
- Valid cycle names in `databaseStart`
- `variableStart` entries parse correctly for all declared cycles
- Format pattern distribution (bracket, mixed, cycle-prefixed, etc.)
- Case sensitivity issues (variables differing only by case)
- Categorical variables have `variable_details` specifications

**Usage**:

```bash
Rscript mockdata-tools/validate-metadata.R
```

**Output**: R CMD check-style report with errors, warnings, and statistics

**Exit codes**:
- 0 = passed (with or without warnings)
- 1 = failed (errors found)

### 2. test-all-cycles.R

**Purpose**: Test mock data generation across all cycles to verify coverage

**What it tests**:
- All unique raw variables can be generated
- Coverage percentage for each cycle
- Identifies variables that fail to generate

**Usage**:

```bash
Rscript mockdata-tools/test-all-cycles.R
```

**Output**: Coverage report showing success/failure counts per cycle

### 3. create-comparison.R

**Purpose**: Compare different mock data generation approaches

**What it does**:
- Generates mock data using different methods
- Compares output structure and values
- Helps validate consistency

**Usage**:

```bash
Rscript mockdata-tools/create-comparison.R
```

## Development Notes

- These tools are **excluded from package builds** via `.Rbuildignore`
- They use test data from `inst/extdata/chms/`
- Run from repository root, not from within this directory

## Related Documentation

- **cchsflow validation**: See `cchsflow::validate_variable_details_csv()` (v3.0.0+)
- **Metadata schemas**: See `inst/metadata/schemas/` in this package
- **MockData functions**: See `R/mockdata-*.R` for core parsing/generation logic
