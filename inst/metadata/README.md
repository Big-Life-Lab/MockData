# Metadata Documentation for MockData

**Last updated**: 2025-10-18

This directory contains metadata schema documentation for recodeflow-based harmonization projects. These schemas define the structure, validation rules, and conventions used across all recodeflow projects (CCHS, CHMS, and any other study using recodeflow for data harmonization).

## Purpose

MockData is a **generic** tool for generating mock data from recodeflow metadata. It works with any study that uses:
- `variables.csv` - harmonized variable definitions
- `variable_details.csv` - variable recoding specifications
- Recodeflow conventions (variableStart formats, range notation, etc.)

These YAML files document the recodeflow conventions that MockData relies on.

## Directory Structure

```
inst/metadata/
├── README.md                          # This file
├── documentation/                     # Recodeflow standards (from cchsflow)
│   ├── database_metadata.yaml        # Dublin Core database-level metadata schema
│   └── metadata_registry.yaml        # Central registry of shared specifications
└── schemas/                           # Data structure schemas (from cchsflow)
    ├── variables.yaml                # Schema for variables.csv
    ├── variable_details.yaml         # Schema for variable-details.csv
    ├── templates.yaml                # Template specifications
    └── missing_priority_rules.yaml   # Missing data handling rules
```

## Key Files

### documentation/database_metadata.yaml

Defines Dublin Core-compliant database-level metadata:
- Dataset titles, descriptions, creators
- Coverage (temporal, spatial, population)
- Rights and access information
- Keywords and subject classification

**Applies to**: Any recodeflow project documenting datasets

### documentation/metadata_registry.yaml

Central registry of shared specifications used across all recodeflow schema files:
- CSV format specifications
- Tier system (core, optional, versioning, extension)
- Validation patterns (variable names, dates, etc.)
- **Transformation patterns for variableStart field**

**Applies to**: All recodeflow projects (CCHS, CHMS, etc.)

### schemas/variables.yaml

Schema for `variables.csv` used in any recodeflow project:
- Field definitions (variable, label, variableType, databaseStart, variableStart)
- Validation rules and constraints
- Examples and usage notes
- Tier classification (core vs optional fields)

**Applies to**: Any project using recodeflow for harmonization

### schemas/variable_details.yaml

Schema for `variable_details.csv`:
- Field definitions (variable, database, recodes, catLabel)
- Recoding specifications
- Missing data handling
- Category label requirements

**Applies to**: Any project using recodeflow for harmonization

### schemas/templates.yaml

Template specifications for reusable variable patterns.

### schemas/missing_priority_rules.yaml

Rules for handling missing data priority across different missing value codes.

## Recodeflow Conventions Used by MockData

MockData functions rely on these **universal recodeflow conventions**:

### 1. variableStart Formats

The `variableStart` field in `variables.csv` uses recodeflow-standard formats:

#### Bracket format: `[varname]`
```yaml
variable: age
variableStart: [age]
databaseStart: study2020, study2021, study2022
```
Used when variable name is **consistent across all databases**.

#### Database-prefixed format: `database::varname`
```yaml
variable: height
variableStart: study2020::HGT_CM, study2021::height_cm, study2022::height_cm
databaseStart: study2020, study2021, study2022
```
Used when variable name **changes across databases**.

Format: `database_name::variable_name`
- In CHMS: database = cycle1, cycle2, etc.
- In CCHS: database = cchs2001, cchs2017_p, etc.
- In any study: database = your database names

#### Mixed format: `database::var1, [var2]`
```yaml
variable: weight
variableStart: study2020::WGT_KG, [weight_kg]
databaseStart: study2020, study2021, study2022
```
Used when **one database has different naming**:
- For specified database: use database::varname
- For other databases: use [varname] as fallback

**Example use case**: Initial pilot study used different variable names than later waves.

#### DerivedVar format: `DerivedVar::[var1, var2, ...]`
```yaml
variable: bmi
variableStart: DerivedVar::[weight_kg, height_cm]
databaseStart: study2020, study2021, study2022
```
Used for variables requiring **calculation from multiple sources**.

**MockData behavior**: Currently returns NULL for DerivedVar (future enhancement).

### 2. Range Notation

The `recodes` field in `variable_details.csv` uses recodeflow-standard range notation:

```yaml
# Integer ranges
[7,9]         # Includes 7, 8, 9
[1,5)         # Includes 1, 2, 3, 4 (excludes 5)

# Continuous ranges
[18.5,25)     # BMI: 18.5 ≤ x < 25
[25,30)       # BMI: 25 ≤ x < 30

# Special values
else          # Catch-all for values not covered by other rules
```

This notation is parsed by `parse_range_notation()` (also used in cchsflow/recodeflow).

### 3. databaseStart Format

Comma-separated list of valid database names:

```yaml
# Single database
databaseStart: study2020

# Multiple databases
databaseStart: study2020, study2021, study2022

# Study-specific naming
databaseStart: wave1, wave2, wave3
databaseStart: baseline, followup_12mo, followup_24mo
```

**Validation**: Database names should match your project's naming conventions.

## How MockData Uses These Schemas

### parse_variable_start()

Generic parser for any recodeflow project:

```r
# Works with any database naming scheme
parse_variable_start("study2020::var1, [var2]", "study2021")  # Returns: "var2"
parse_variable_start("cycle1::var1, [var2]", "cycle2")        # Returns: "var2"
parse_variable_start("wave1::var1, [var2]", "wave2")          # Returns: "var2"
```

Parsing strategies:
1. **Strategy 1**: Look for `database::varname` matching requested database
2. **Strategy 2**: Check if entire string is `[varname]` format
3. **Strategy 2b**: Check if any segment is `[varname]` (mixed format fallback)
4. **Strategy 3**: Use plain text as-is
5. **Return NULL**: For DerivedVar format

### create_cat_var() and create_con_var()

Generate mock data from metadata specifications:
- Parse `variableStart` to get raw variable name
- Read `variable_details` for recoding rules
- Generate mock values following range notation
- Work with any study using recodeflow conventions

## Adapting MockData to Your Study

MockData is **study-agnostic**. To use it for your recodeflow project:

1. **Create your metadata**:
   - `variables.csv` following schema in `variables.yaml`
   - `variable_details.csv` following schema in `variable_details.yaml`
   - Use your own database naming (study2020, wave1, cohort_a, etc.)

2. **Use recodeflow conventions**:
   - variableStart formats: `[varname]`, `database::varname`, mixed, DerivedVar
   - Range notation: `[min,max]`, `[min,max)`, `else`
   - databaseStart: comma-separated database names

3. **Run MockData functions**:
   ```r
   source("R/create_cat_var.R")
   source("R/create_con_var.R")

   # Works with any database names
   mock_data <- create_cat_var(
     var_raw = "your_variable",
     database = "your_database_name",
     variable_details = your_variable_details,
     ...
   )
   ```

## Examples Across Different Studies

### CHMS (Canadian Health Measures Survey)
```yaml
variable: clc_age
variableStart: [clc_age]
databaseStart: cycle1, cycle2, cycle3, cycle4, cycle5, cycle6
```

### CCHS (Canadian Community Health Survey)
```yaml
variable: age
variableStart: [age]
databaseStart: cchs2001, cchs2015, cchs2017_p
```

### Generic cohort study
```yaml
variable: participant_age
variableStart: baseline::age_years, [participant_age]
databaseStart: baseline, followup_12mo, followup_24mo
```

### Multi-site study
```yaml
variable: blood_pressure_systolic
variableStart: site_a::SBP, site_b::sys_bp, [sbp]
databaseStart: site_a, site_b, site_c
```

## Validation

Create a validation script for your project based on these schemas:

```r
# Check 1: All databaseStart values are valid for your study
valid_databases <- c("your", "database", "names")

# Check 2: All variableStart entries parse correctly
# Check 3: Categorical variables have variable_details entries
# Check 4: Continuous variables have units specified
```

## Relationship to cchsflow and recodeflow

These schema files are **recodeflow conventions** sourced from cchsflow:

**From cchsflow (unchanged)**:
- `documentation/database_metadata.yaml` - Dublin Core standard (recodeflow)
- `documentation/metadata_registry.yaml` - Shared specifications (recodeflow)
- `schemas/variables.yaml` - Core variable schema (recodeflow)
- `schemas/variable_details.yaml` - Variable details schema (recodeflow)
- `schemas/templates.yaml` - Template specifications (recodeflow)
- `schemas/missing_priority_rules.yaml` - Missing data rules (recodeflow)

**MockData adds**:
- Generic functions that work with any recodeflow metadata
- Study-agnostic parsers and generators
- This documentation emphasizing universal applicability

## Key Principle: Study-Agnostic Design

MockData does **NOT** care about:
- Your database names (cycle1 vs study2020 vs wave1)
- Your study domain (health survey vs clinical trial vs registry)
- Your variable naming conventions (camelCase vs snake_case)

MockData **DOES** require:
- Recodeflow-standard `variableStart` formats
- Recodeflow-standard range notation in recodes
- Valid `variables.csv` and `variable_details.csv` structure

## Common Questions

### Can MockData work with my study?

**Yes**, if your study:
- Uses recodeflow for data harmonization
- Has `variables.csv` and `variable_details.csv` files
- Follows recodeflow conventions for variableStart and range notation

### Do I need to modify MockData functions?

**No**. MockData functions are generic and work with any recodeflow metadata. You only need to:
- Create metadata for your study
- Pass your database names to functions
- Ensure metadata follows recodeflow schemas

### What if my study uses different database naming?

**No problem**. MockData parses `databaseStart` and `variableStart` generically:
- CHMS uses: cycle1, cycle2, ...
- CCHS uses: cchs2001, cchs2017_p, ...
- Your study can use: anything (study_baseline, wave_1, cohort_a, etc.)

The parser doesn't hardcode database names - it works with whatever is in your metadata.

### What about DerivedVar variables?

DerivedVar is a recodeflow convention for variables requiring custom calculation logic.
MockData currently returns NULL for these (future enhancement could add generic derivation support).

## References

- **cchsflow metadata**: Source of these recodeflow schemas
- **recodeflow**: Framework for data harmonization (in development)
- **Dublin Core standard**: https://www.dublincore.org/specifications/dublin-core/
- **DCAT vocabulary**: https://www.w3.org/TR/vocab-dcat-2/

## Maintenance

These schema files should be updated when:
- Recodeflow conventions change (sync with cchsflow)
- New variableStart patterns are introduced
- New range notation patterns are added
- Field definitions change in recodeflow standards

**Schema source**: cchsflow/inst/metadata/ (recodeflow conventions)
**Maintainer**: MockData development team
