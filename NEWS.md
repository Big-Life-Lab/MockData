# MockData 0.3.0

## Breaking changes

**New function API** - All generator functions now accept full metadata data frames instead of pre-filtered subsets:

```r
# Before (v0.2.x)
var_row <- variables[variables$variable == "age", ]
details_subset <- variable_details[variable_details$variable == "age", ]
result <- create_con_var(var_row, details_subset, n = 1000)

# After (v0.3.0)
result <- create_con_var(
  var = "age",
  databaseStart = "minimal-example",
  variables = variables,
  variable_details = variable_details,
  n = 1000
)
```

**Affected functions:** `create_cat_var()`, `create_con_var()`, `create_date_var()`, `create_wide_survival_data()`, `create_mock_data()`

**Deprecated:** `prop_garbage` parameter in `create_wide_survival_data()`. Use garbage parameters in metadata instead:

```r
# Old way (no longer supported)
surv <- create_wide_survival_data(..., prop_garbage = 0.03)

# New way
vars_with_garbage <- add_garbage(variables, "death_date",
  garbage_high_prop = 0.03, garbage_high_range = "[2025-01-01, 2099-12-31]")
surv <- create_wide_survival_data(..., variables = vars_with_garbage)
```

## New features

**Unified garbage generation** across all variable types (categorical, continuous, date, survival):

- `garbage_low_prop` + `garbage_low_range` for values below valid range
- `garbage_high_prop` + `garbage_high_range` for values above valid range
- New helper function `add_garbage()` for easy garbage specification
- Categorical garbage now supported (treats codes as ordinal to generate out-of-range values)

```r
# Add garbage to any variable type
vars_with_garbage <- add_garbage(variables, "smoking",
  garbage_low_prop = 0.02, garbage_low_range = "[-2, 0]")

# Pipe-friendly
vars_with_garbage <- variables %>%
  add_garbage("age", garbage_high_prop = 0.03, garbage_high_range = "[150, 200]") %>%
  add_garbage("smoking", garbage_low_prop = 0.02, garbage_low_range = "[-2, 0]")
```

**Derived variable identification:**

- `identify_derived_vars()` - Identifies derived variables using `DerivedVar::` and `Func::` patterns
- `get_raw_var_dependencies()` - Extracts raw variable dependencies
- Compatible with recodeflow patterns

## Bug fixes

- Fixed categorical garbage factor level bug - garbage values were being converted to NA during factor creation
- Fixed `recEnd` column requirement - now optional for simple configurations
- Fixed derived variable generation in `create_mock_data()` - derived variables now correctly excluded

## Documentation

**Restructured using Divio framework:**

- Removed 6 vignettes (cchs-example, chms-example, demport-example, dates, schema-change-dates, tutorial-config-files)
- Added 2 new vignettes (tutorial-categorical-continuous, tutorial-survival-data)
- Massively expanded reference-config (2,028 lines of comprehensive metadata schema documentation)
- All vignettes updated to v0.3.0 API
- All examples now use `inst/extdata/minimal-example/` only

**Final structure (9 vignettes):**

- **Tutorials (6):** getting-started, tutorial-categorical-continuous, tutorial-dates, tutorial-survival-data, tutorial-missing-data, tutorial-garbage-data
- **How-to guides (1):** for-recodeflow-users
- **Explanation (1):** advanced-topics
- **Reference (1):** reference-config

**Metadata simplification:**

- Removed `inst/extdata/cchs/`, `inst/extdata/chms/`, `inst/extdata/demport/`
- Only `inst/extdata/minimal-example/` remains as canonical reference

## Migration guide

**Update function calls:**

1. Pass variable name as string (not pre-filtered row)
2. Pass full metadata data frames (not subsets)
3. Add `databaseStart` parameter
4. Remove manual filtering

**Update garbage specification:**

1. Remove `prop_garbage` from `create_wide_survival_data()` calls
2. Add garbage to metadata using `add_garbage()` helper
3. Update parameter names:
   - `low_prop` → `garbage_low_prop`
   - `low_range` → `garbage_low_range`
   - `high_prop` → `garbage_high_prop`
   - `high_range` → `garbage_high_range`

---

# MockData 0.2.2 (Released)

## Major changes

### Removed `_mock` suffix convention

**Breaking change**: The `_mock` suffix convention introduced in v0.2.1 has been removed. MockData-specific parameters now use standard names without the suffix.

**Migration**:
- `followup_min_mock` → `followup_min`
- `followup_max_mock` → `followup_max`
- `distribution_mock` → `distribution`
- `event_occurs_mock` → `event_occurs`
- `prop_invalid_mock` → `prop_invalid`

**Rationale**: The `_mock` suffix added complexity without clear benefit. The current three-file architecture makes the distinction clear:
1. Study specifications in `variable_details.csv`
2. Optional MockData parameters in separate `mock_config.csv`
3. No suffix needed when separation is structural

### Parameter renames

**Breaking change**: Renamed `cycle` parameter to `database_name` across all functions:
- `create_cat_var(cycle = "cchs2001")` → `create_cat_var(database_name = "cchs2001")`
- `create_con_var(cycle = "cycle1")` → `create_con_var(database_name = "cycle1")`
- `create_date_var(cycle = "study2024")` → `create_date_var(database_name = "study2024")`

**Rationale**: `database_name` is more universally understood than `cycle`, which is CCHS/CHMS-specific terminology.

## Documentation rewrite

Complete documentation overhaul with "show first, explain later" approach:

**README.md**:
- Leads with 30-second executable example
- Shows metadata approach immediately
- Targets two audiences: recodeflow users and new users
- Removed all architecture-first explanations

**New vignettes**:
- `getting-started.qmd`: Progressive examples from single variable to full dataset
- `for-recodeflow-users.qmd`: Quick start for users with existing metadata

**Updated vignettes**:
- All vignettes use `database_name` instead of `cycle`
- Removed all `_mock` suffix references
- Focused on executable examples

**New minimal example**:
- `inst/extdata/minimal-example/`: Simplest possible metadata configuration
- 3 variables (age, smoking, death_date) across 2 CSV files
- Used throughout documentation for consistency

---

# MockData 0.2.1

## Major changes

### Function rename

- **Breaking change**: `create_survival_dates()` renamed to `create_wide_survival_data()`
- New name clarifies wide-format output (one row per individual)
- Old function name no longer exported
- All vignettes and documentation updated

### MockData-specific recEnd codes (_mock suffix)

New three-file architecture separates study specifications from MockData-specific parameters:

**MockData-specific recEnd codes** (in `mock_data_config_details.csv`):
- `followup_min_mock` / `followup_max_mock`: Override study follow-up ranges
- `distribution_mock`: Event timing distribution (uniform, gompertz, exponential)
- `event_occurs_mock`: Proportion of individuals who experience event (enables competing risks)
- `prop_invalid_mock`: Proportion of temporal violations for validation testing

The `_mock` suffix separates MockData-specific parameters from study specifications. When both exist, `_mock` codes take precedence.

### Survival data enhancements

- `create_wide_survival_data()` now supports multiple event distributions (uniform, gompertz, exponential)
- Event occurrence probability enables competing risks (some individuals don't experience event)
- Temporal violation support for validation testing
- Complete MockSurvWide v1 specification implementation

### Configuration architecture

Three-file conceptual architecture documented:
1. **Project data dictionary** (`mock_data_config.csv` or `variables.csv`) - READ-ONLY for MockData
2. **Study specifications** (`mock_data_config_details.csv` or `variable_details.csv`) - READ-ONLY for MockData
3. **MockData-specific parameters** (rows with `_mock` suffix in config_details) - WRITE-only for MockData

This design:
- Separates concerns (study specs don't contain MockData-only parameters)
- Maintains compatibility (existing metadata files work unchanged)
- Enables flexibility (MockData can override study parameters for testing)

## New features

- Example survival configuration files in `inst/extdata/survival/`
- Comprehensive survival data generation tests
- Architecture documentation in README and getting-started vignette

## Documentation updates

- **README**: Added "Configuration architecture" section with three-file structure explanation
- **getting-started vignette**: Added architecture section explaining file roles and `_mock` suffix
- **DemPoRT vignette**: Removed birth_date references, added MockSurvWide v1 examples
- **All vignettes**: Updated function name from `create_survival_dates()` to `create_wide_survival_data()`

## Bug fixes

- None in this release

---

# MockData 0.2.0

## Major changes

### New configuration format (v0.2)

- **Breaking change**: New configuration schema with `uid`/`uid_detail` system
- Replaces v0.1 `cat`/`catLabel` columns with unified metadata structure
- Adds `rType` field for explicit R type coercion (factor, integer, double, Date)
- Adds `proportion` field for direct distribution control
- Adds date-specific fields: `date_start`, `date_end`, `distribution`

**Backward compatibility**: v0.1 format still supported via dual interface. Both formats work side-by-side.

### Date variable generation

- New `create_date_var()` function for date variables
- Multiple distribution options: uniform, gompertz, exponential
- Support for survival analysis patterns
- SAS date format parsing
- Three source formats: analysis (R Date), csv (ISO strings), sas (numeric)

### Survival analysis support

- New `create_wide_survival_data()` function for cohort studies
- Generates paired entry and event dates with guaranteed temporal ordering
- Supports censoring and multiple event distributions
- **Note**: Must be called manually (not compatible with `create_mock_data()` batch generation)

### Data quality testing (garbage data)

- New `prop_invalid` parameter across all generators
- Generates intentionally invalid data for testing validation pipelines
- Supports garbage types: `corrupt_future`, `corrupt_past`, `corrupt_range`
- Critical for testing data cleaning workflows

### Batch generation

- New `create_mock_data()` function for batch generation from CSV configuration
- New `read_mock_data_config()` and `read_mock_data_config_details()` readers
- Processes multiple variables in single call
- Fallback mode when details not provided

### Type coercion

- Explicit `rType` field controls R type conversion
- Proper factor handling with levels
- Integer vs double distinction for age/count variables
- Makes generated data match real survey data types

## New functions

- `create_date_var()` - Date variable generation
- `create_wide_survival_data()` - Paired survival dates with temporal ordering
- `create_mock_data()` - Batch generation orchestrator
- `read_mock_data_config()` - Configuration file reader
- `read_mock_data_config_details()` - Details file reader
- `determine_proportions()` - Unified proportion determination
- `import_from_recodeflow()` - Helper to adapt recodeflow metadata

## Function updates

- `create_cat_var()`: Add rType support, proportion parameter, uid-based filtering
- `create_con_var()`: Add rType support, proportion parameter for missing codes
- Consolidate helpers in `mockdata_helpers.R`, `config_helpers.R`, `scalar_helpers.R`

## Documentation

### New vignettes

- `getting-started.qmd` - Comprehensive introduction
- `tutorial-dates.qmd` - Date configuration patterns
- `tutorial-config-files.qmd` - Batch generation workflow
- `reference-config.qmd` - Complete v0.2 schema documentation
- `advanced-topics.qmd` - Technical implementation details

### Updated vignettes

- `cchs-example.qmd` - Modernized to v0.2 with inline R
- `chms-example.qmd` - Modernized to v0.2 with inline R
- `demport-example.qmd` - Modernized to v0.2 with inline R
- `dates.qmd` - Aligned with v0.2 date configuration
- All vignettes use modern inline R approach

### Metadata updates

- `mock_data_schema.yaml` - LinkML-style schema documentation (1,222 lines)
- `metadata_registry.yaml` - Document v0.2 format
- Renamed CCHS/CHMS sample files for consistency
- Updated DemPoRT metadata with v0.2 format
- Removed deprecated ICES metadata (moved to recodeflow)

## Package infrastructure

- Added `_pkgdown.yml` for documentation website
- Updated NAMESPACE with new imports (stats::rexp, utils::read.csv, etc.)
- Updated DESCRIPTION with new dependencies

## Breaking changes

**Configuration format changes:**
- Variable details now require `uid` and `uid_detail` columns
- `rType` field required for proper type coercion
- New date fields: `date_start`, `date_end`, `distribution`

**Migration path:**
- v0.1 format still works (backward compatibility maintained)
- Dual interface auto-detects format based on parameters
- v0.2 recommended for new projects

**File changes:**
- Renamed `R/mockdata-helpers.R` → `R/mockdata_helpers.R`
- ICES metadata removed (maintained in recodeflow package)

## Bug fixes

- Fixed 'else' handling in `recEnd` rules (issue #5)
- Fixed create_wide_survival_data() compatibility with create_mock_data()
- Fixed Roxygen documentation link syntax errors

## Known issues

- Survival variable type must be generated manually with `create_wide_survival_data()`
- Cannot be used in `create_mock_data()` batch generation (requires paired variables)

---

# MockData 0.1.0

Initial release with basic categorical and continuous variable generation.
