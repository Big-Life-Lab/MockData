# Comprehensive example - MockData reference metadata

**Purpose:** Complete reference implementation demonstrating all MockData features with v0.2 schema.

**Coverage:** Basic generation + Survival analysis + Contamination + All variable types

**Status:** Combined minimal + survival examples (2025-11-09)

---

## Overview

This example combines basic mock data generation with survival analysis to demonstrate the full range of MockData capabilities:

**Basic variables (3):**
- age, smoking, BMI - Demonstrates integers, categories, continuous distributions, contamination

**Survival variables (4):**
- interview_date, primary_event_date, death_date, ltfu_date - Demonstrates competing risks, Gompertz distributions, event proportions

**Total:** 7 variables, 24 detail specifications

---

## Files

### variables.csv

Demonstrates all 12 variable-level extension fields:

| Variable | Type | Demonstrates |
|----------|------|-------------|
| **age** | integer | Low-contamination only, variable-level seed |
| **smoking** | factor | Categorical with multi-valued role, no contamination |
| **BMI** | double | Normal distribution, two-sided contamination (low + high) |
| **interview_date** | date | Cohort entry (index date), date range generation |
| **primary_event_date** | date | Gompertz distribution, event proportion (10%), temporal violations (3%) |
| **death_date** | date | Competing risk, all individuals eventually die (100%) |
| **ltfu_date** | date | Censoring event, uniform distribution (10% occurrence) |

**Key features:**
- UIDs: Numeric-only format (`v_001`, `v_002`, ..., `v_007`)
- rType: All data types (integer, factor, double, date)
- role: Multi-valued roles ("enabled,predictor,table1", "enabled,outcome", "enabled,metadata")
- position: Deterministic ordering (10, 20, 30, ..., 70)
- Contamination: Low-only (age), two-sided (BMI), high-only (primary_event_date)
- Versioning: MockData semantic versioning independent of recodeflow

### variable_details.csv

Demonstrates all 5 detail-level extension fields across different variable types:

**Basic specifications:**
| Variable | Demonstrates |
|----------|-------------|
| **age** | Valid range using recStart interval notation `[18,100]` |
| **smoking** | Categorical proportions (sum to 1.0), missing code (7 = Don't know) |
| **BMI** | Normal distribution with parameters (distribution, mean, sd, valid range) |

**Survival specifications:**
| Variable | Demonstrates |
|----------|-------------|
| **interview_date** | Date range `[2001-01-01,2005-12-31]` with sourceFormat |
| **primary_event_date** | Gompertz distribution, followup_min/max, event proportion, rate parameter |
| **death_date** | Gompertz distribution with 100% event occurrence (everyone dies) |
| **ltfu_date** | Uniform distribution with 10% event occurrence (loss to follow-up) |

**Key features:**
- UIDs: Foreign keys linking to variables.csv (`v_001` through `v_007`)
- uid_detail: Unique row identifiers (`d_001` through `d_024`)
- recStart: Generation values (what MockData generates) - uses `N/A` for distribution parameters
- recEnd: Specification labels (distribution, mean, sd, valid, copy, followup_min, followup_max, event, rate)
- proportion: Population proportions (smoking) + event proportions (survival)
- value: Distribution type (normal, gompertz, uniform) + numeric parameters
- NO range_min/range_max: Uses recStart interval notation instead

---

## Schema compliance

Validates successfully with expected warnings for survival event proportions:

```r
source("R/validate_mockdata_extensions.R")

result <- validate_mockdata_metadata(
  "inst/extdata/minimal-example/variables.csv",
  "inst/extdata/minimal-example/variable_details.csv"
)

print(result)
# Valid: YES
# Warnings: 2 (event proportions auto-normalized - expected for survival data)
```

**Validation checks:**
1. UID patterns: `^v_[0-9]+$` and `^d_[0-9]+$` ✓
2. Foreign keys: All detail UIDs exist in variables ✓
3. Proportions: Categorical sums to 1.0, survival events auto-normalize ✓
4. Contamination ranges: Use interval notation `[min,max]` ✓
5. Contamination proportions: Between 0-1 ✓
6. rType values: Valid enum (integer/double/factor/date) ✓
7. Versioning: Semantic versioning (1.0.0) and date format (YYYY-MM-DD) ✓

---

## Key patterns demonstrated

### 1. Basic generation (age, smoking, BMI)

**Categorical variable with proportions:**
```csv
# variable_details.csv
uid,recStart,recEnd,catLabel,proportion
v_002,1,1,Never smoker,0.50
v_002,2,2,Former smoker,0.30
v_002,3,3,Current smoker,0.17
v_002,7,7,Don't know,0.03
# Sum: 1.00 ✓
```

**Continuous variable with distribution:**
```csv
# variable_details.csv
uid,recEnd,value
v_003,distribution,normal
v_003,mean,27.5
v_003,sd,5.2
v_003,valid,[18,40]  # Using recStart for truncation bounds
```

### 2. Survival analysis (interview_date, primary_event_date, death_date, ltfu_date)

**Index date (cohort entry):**
```csv
# variable_details.csv
uid,recStart,recEnd
v_004,[2001-01-01,2005-12-31],copy
```

**Event date with Gompertz distribution:**
```csv
# variable_details.csv
uid,recEnd,value,proportion
v_005,distribution,gompertz,
v_005,followup_min,365,        # 1 year minimum
v_005,followup_max,5475,       # 15 years maximum
v_005,event,0.10               # 10% experience event
v_005,rate,0.0001,             # Gompertz rate parameter
```

**Competing risk (all individuals die):**
```csv
uid,recEnd,value,proportion
v_006,distribution,gompertz,
v_006,event,1.00               # 100% occurrence
```

### 3. Contamination

**Variable-level contamination parameters (in variables.csv):**
```csv
uid,corrupt_low_prop,corrupt_low_range,corrupt_high_prop,corrupt_high_range
v_001,0.01,[-5,10],,                     # Age: 1% invalid low values
v_003,0.02,[-10,0],0.01,[60,150]         # BMI: 2% low + 1% high
v_005,,,0.03,[2099-01-01,2099-12-31]     # primary_event: 3% future dates
```

### 4. Standardized recEnd values

**For distributions:**
- `distribution` - Type (normal, gompertz, uniform, exponential)
- `mean`, `sd` - Normal distribution parameters (in value column)
- `rate`, `shape` - Gompertz/exponential parameters (in value column)
- `valid` - Truncation bounds (in recStart column using interval notation)

**For survival:**
- `followup_min`, `followup_max` - Follow-up time range in days (in value column)
- `event` - Proportion who experience event (in proportion column)
- `censored` - Proportion censored (if needed)

**For dates:**
- `copy` - Use date range from recStart interval notation
- Date range specified in recStart: `[2001-01-01,2005-12-31]`

---

## Usage examples

### Basic mock data generation

```r
library(mockData)

# Load metadata
variables <- read.csv("inst/extdata/minimal-example/variables.csv",
                      stringsAsFactors = FALSE, check.names = FALSE)
variable_details <- read.csv("inst/extdata/minimal-example/variable_details.csv",
                              stringsAsFactors = FALSE, check.names = FALSE)

# Generate basic variables only
basic_vars <- c("age", "smoking", "BMI")
basic_details <- variable_details[variable_details$variable %in% basic_vars, ]

mock_data <- create_mock_data(
  variable_details = basic_details,
  variables = variables[variables$variable %in% basic_vars, ],
  n = 1000,
  seed = 12345
)

# Check contamination
summary(mock_data$age)  # Should see some values < 18 (contamination)
summary(mock_data$BMI)  # Should see some values < 18 or > 40
table(mock_data$smoking)
```

### Survival analysis data generation

```r
# Generate survival variables
survival_vars <- c("interview_date", "primary_event_date", "death_date", "ltfu_date")
survival_details <- variable_details[variable_details$variable %in% survival_vars, ]

# Start with interview dates
df <- data.frame(id = 1:1000)

# Generate each date variable
# (See survival vignette for complete workflow)
```

### Combined generation

```r
# Generate complete dataset (basic + survival)
complete_data <- create_mock_data(
  variable_details = variable_details,
  variables = variables,
  n = 1000,
  seed = 12345
)

# Verify all variables present
names(complete_data)
# [1] "age" "smoking" "BMI" "interview_date" "primary_event_date"
# [6] "death_date" "ltfu_date"
```

---

## Survival analysis workflow

MockData generates **raw date columns only**. Derived variables are calculated by the user:

```r
# After generating mock data with survival dates...

# 1. Calculate t_end_date (earliest of: event, death, ltfu, admin censor)
admin_censor <- as.Date("2017-03-31")
df$t_end_date <- pmin(
  df$primary_event_date,
  df$death_date,
  df$ltfu_date,
  admin_censor,
  na.rm = TRUE
)

# 2. Calculate time in years
df$time <- as.numeric(df$t_end_date - df$interview_date) / 365.25

# 3. Calculate failcode (priority rule)
df$failcode <- ifelse(
  !is.na(df$primary_event_date) & df$primary_event_date == df$t_end_date, 1,  # Primary event
  ifelse(!is.na(df$death_date) & df$death_date == df$t_end_date, 4,            # Death
  ifelse(!is.na(df$ltfu_date) & df$ltfu_date == df$t_end_date, 0,              # LTFU
  ifelse(df$t_end_date == admin_censor, 0, NA)))                                # Admin censor
)

# 4. Verify competing risks
table(df$failcode)
#   0    1    4
# 893   97  10
# (0 = censored, 1 = primary event, 4 = death)
```

---

## Next steps

- **Code refactoring:** Use this example to test Phase 2 code changes (rType move, interval notation parsing)
- **Vignettes:** See `vignettes/getting-started.qmd` for full tutorial
- **Advanced:** See `vignettes/dates.qmd` for survival analysis deep dive
- **Schema:** See `inst/metadata/schemas/mockdata_extensions.yaml` for complete field reference

---

## Notes

**Why combine minimal + survival?**
- Single comprehensive example for all testing during refactoring
- Demonstrates full feature range (basic → advanced)
- Easier maintenance (one example to update)
- Tutorials can reference specific variables without needing multiple examples

**Validation warnings:**
- Survival event proportions (0.10, 1.00) trigger auto-normalization warnings
- This is expected - event proportions are parameters, not population distributions
- In basic mode, warnings are acceptable; use strict mode to enforce 1.0 sums
