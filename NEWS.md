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

- New `create_survival_dates()` function for cohort studies
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
- `create_survival_dates()` - Paired survival dates with temporal ordering
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

**Deprecation timeline:**
- v0.2.0 (current): Both formats supported
- v0.3.0 (planned 2026-Q1): Deprecation warnings for v0.1
- v0.4.0 (planned 2026-Q3): v0.1 format removed

**File changes:**
- Renamed `R/mockdata-helpers.R` → `R/mockdata_helpers.R`
- ICES metadata removed (maintained in recodeflow package)

## Bug fixes

- Fixed 'else' handling in `recEnd` rules (issue #5)
- Fixed create_survival_dates() compatibility with create_mock_data()
- Fixed Roxygen documentation link syntax errors

## Known issues

- Survival variable type must be generated manually with `create_survival_dates()`
- Cannot be used in `create_mock_data()` batch generation (requires paired variables)

## Supersedes

- PR #5 (issue-5-fix-else): 'else' handling fix included
- Incorporates CHMS updates from documentation-restructure branch

---

# MockData 0.1.0

Initial release with basic categorical and continuous variable generation.
