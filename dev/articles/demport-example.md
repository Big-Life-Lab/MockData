# DemPoRT example: Survival analysis workflow

**About this vignette:** All numeric values shown in this vignette are
computed from the actual DemPoRT metadata files. Code is hidden by
default for readability, but you can view the source `.qmd` file to see
how values are calculated.

## Overview

This vignette demonstrates generating mock data for **DemPoRT**
(Dementia Population Risk Tool), a survival analysis model predicting
dementia risk. DemPoRT uses harmonized data from multiple Canadian
Community Health Survey (CCHS) cycles spanning 2001-2018. Dementia
incidence (onset) is individually linked using administrative data
housed at ICES – along with mortality records and other censoring
information, where it is combined with CCHS survey data.

**The MockData workflow for multi-cycle projects:**

1.  **Generate separate mock datasets** for individual cycles/databases
    (e.g., CCHS 2001, CCHS 2003)
2.  **Hand off to analyst** to test harmonization pipeline (using
    recodeflow/cchsflow)
3.  **Harmonize and bind** the individual datasets using your analysis
    code
4.  **Calculate derived variables** after harmonization

MockData generates **raw, unharmonized data** that mimics individual
source databases. It does NOT pool or bind data—that is the analyst’s
responsibility to test.

**What you’ll learn:**

- Generate mock data for individual survey cycles
- Understand multi-cycle metadata structure
- Test harmonization workflows with mock data
- Validate metadata consistency
- Generate survival analysis variables (dates, events)

**Prerequisites:**

- [Getting
  started](https://big-life-lab.github.io/MockData/articles/getting-started.md) -
  Basic mock data generation
- [Configuration
  files](https://big-life-lab.github.io/MockData/articles/tutorial-config-files.md) -
  Batch generation approach
- [Date
  variables](https://big-life-lab.github.io/MockData/articles/dates.md) -
  Temporal data and survival analysis

## Setup

Load required packages:

``` r
library(MockData)
library(dplyr)
library(stringr)
```

## Required inputs

Typically, you need three configuration files to generate mock data:

1.  **Mock data config file** (`mock_data_config.csv`): Specifies which
    variables to generate and their roles
2.  **Variables file** (`variables.csv`): Defines variable metadata
    (labels, types, cycles)
3.  **Variable details file** (`variable_details.csv`): Specifies
    distributions and categories

**Note**: The mock data config file is not yet complete for DemPoRT.
This example demonstrates generating mock data directly from
harmonization metadata (variables and variable_details files). We will
update this vignette once the mock data config is available.

For DemPoRT, the harmonization metadata describes **20+ individual CCHS
cycles** (2001-2018):

``` r
# Load DemPoRT metadata
variables <- read.csv(
  system.file("extdata/demport/variables_DemPoRT.csv", package = "MockData"),
  header = TRUE,
  check.names = FALSE,
  na.strings = c("", "NA", "N/A"),
  stringsAsFactors = FALSE
)

variable_details <- read.csv(
  system.file("extdata/demport/variable_details_DemPoRT.csv", package = "MockData"),
  header = TRUE,
  check.names = FALSE,
  na.strings = c("", "NA", "N/A"),
  stringsAsFactors = FALSE
)
```

The DemPoRT metadata includes 74 variables with 669 detail rows. First 5
variables: ADL_01, ADL_02, ADL_03, ADL_04, ADL_05.

**Variable types in the metadata:**

- **Categorical**: Sex, education, marital status, immigration status
- **Continuous**: Age, BMI, alcohol consumption
- **Date**: Birth date, interview date (baseline), death date (outcome)
- **Derived**: Age groups, BMI categories (calculated from raw
  variables)

**Important**: The metadata describes **harmonized target variables**,
not raw source data. MockData uses this metadata to generate mock data
that mimics **raw source databases** before harmonization.

**Multi-cycle structure**: Each variable’s metadata includes a
`databaseStart` column listing which cycles contain that variable (e.g.,
“cchs2001_p, cchs2003_p, cchs2005_p”).

## Generate mock data

The simplest way to generate DemPoRT mock data is using
[`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md).
This function reads the metadata files and generates all variables at
once.

``` r
# Generate mock data for all DemPoRT raw variables
# Derived variables are automatically excluded
mock_demport <- create_mock_data(
  config_path = system.file("extdata/demport/variables_DemPoRT.csv", package = "MockData"),
  details_path = system.file("extdata/demport/variable_details_DemPoRT.csv", package = "MockData"),
  n = 100,
  seed = 123
)

# View structure
dim(mock_demport)
# [1] 100  69

# First few columns
names(mock_demport)[1:5]
# [1] "ADL_01" "ADL_02" "ADL_03" "ADL_04" "ADL_05"

# Show sample of first 3 rows, first 5 columns
head(mock_demport[, 1:5], 3)
#   ADL_01         ADL_02         ADL_03    ADL_04    ADL_05
# 1 No difficulty  No difficulty  No help   No help   No help
# 2 Some difficulty No difficulty  No help   No help   Some help
# 3 No difficulty  No difficulty  No help   No help   No help
```

**Important: Derived variables are NOT generated**

MockData automatically excludes derived variables during generation.
Derived variables (e.g., `ADL_der`, `HWTGBMI_der`, `pack_years_der`) are
calculated from raw variables and should NOT be generated as mock data.

**How it works:**

1.  Variables with `role = "derived,enabled"` are automatically filtered
    out
2.  Only raw variables (e.g., `ADL_01`, `HWTGHTM`, `HWTGWTK`) are
    generated. This includes raw variables required to calculate derived
    variables.
3.  You calculate derived variables using your analysis pipeline after
    generation.

**Why this matters:**

- **Consistency**: Derived variables use the same calculation logic as
  your real analysis
- **Testing**: Test your derived variable calculations on mock data
- **Correctness**: Prevents generating fake derived values that don’t
  match raw inputs

## Understanding multi-cycle data

DemPoRT harmonizes and pools data from multiple CCHS cycles. The
harmonization metadata specifies which cycles contain each variable via
the `databaseStart` column.

**Key concept**: MockData generates individual cycle datasets (e.g.,
mock CCHS 2001, mock CCHS 2003). The analyst then:

1.  Harmonizes each cycle separately using recodeflow/cchsflow
2.  Binds the harmonized cycles together
3.  Calculates derived variables on the pooled dataset

### Extract cycle information

DemPoRT harmonizes 26 CCHS cycles ranging from 2001 to 2017-2018. The
cycles are: cchs2001_i, cchs2001_p, cchs20013_2014_i, cchs2003_i,
cchs2003_p, cchs2005_i, cchs2005_p, cchs2007_2008_i, cchs2007_2008_p,
cchs2009_2010_i, cchs2009_2010_p, cchs2009_s, cchs2010_p, cchs2010_s,
cchs2011_2012_i, cchs2011_2012_p, cchs2012_p, cchs2012_s,
cchs2013_2014_i, cchs2013_2014_p, cchs2014_p, cchs2015_2016_i,
cchs2015_2016_p, cchs2017_2018, cchs2017_2018_i, cchs2017_2018_p.

**Interpretation:**

- Each variable may appear in **different subsets** of cycles
- Example: `EDU_04` (education) appears in cycles 2001-2014, but not
  2015-2018

### Check variable coverage by cycle

The EDU_04 (education) variable is available in 0 cycles. First 3: .

**Why this matters for MockData:**

- Generate separate mock datasets for each cycle you want to test
- Each cycle will have different variables based on `databaseStart`
  metadata
- Test your harmonization pipeline on individual cycles before pooling
- Missing data patterns may differ by cycle

## Validate metadata consistency

Before generating mock data, it’s good practice to check that your
config and details files are aligned.

The metadata includes 74 variables in config and 80 variables in
details. Warning: 6 variables missing details. Warning: 12 extra
variables in details.

**Common issues this catches:**

- Typos in variable names
- Variables defined in config but missing implementation details
- Orphaned details rows from deleted variables
- Helpful for troubleshooting
  [`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md)
  errors

## Classify variables by type

Understanding variable types helps organize analysis and identify which
variables need special handling.

**Variable type summary:**

- Derived: 7
- Categorical: 47
- Continuous: 20
- Total: 74

Classification accounts for all variables.

**About derived variables:**

- Examples: `age_cat` (age groups), `bmi_cat` (BMI categories)
- These are **calculated** from raw variables (age, BMI) after
  harmonization
- Should **not** be generated as raw mock data
- In real workflows, you’d calculate them using recodeflow after
  generating raw variables

## Examine data quality for individual cycles

After generating mock data for an individual cycle, check variable
completeness and data types.

**Remember**: You’re examining **one cycle’s raw data** here, not pooled
data. Each cycle may have different variables and different data
patterns.

``` r
# Example: Check mock data for CCHS 2001
# (Replace mock_demport with your cycle-specific dataset, e.g., mock_2001)

# Check for date variables
date_vars <- names(mock_demport)[sapply(mock_demport, inherits, "Date")]

cat("Date variables in this cycle:\n")
if (length(date_vars) > 0) {
  for (var in date_vars) {
    date_range <- range(mock_demport[[var]], na.rm = TRUE)
    n_missing <- sum(is.na(mock_demport[[var]]))

    cat(sprintf("  %s: %s to %s (%d missing)\n",
                var,
                as.character(date_range[1]),
                as.character(date_range[2]),
                n_missing))
  }
} else {
  cat("  (No date variables in this cycle)\n")
}

# Check for factor variables
factor_vars <- names(mock_demport)[sapply(mock_demport, is.factor)]

cat("\nFactor variables:", length(factor_vars), "\n")
if (length(factor_vars) > 0) {
  cat("  First 3:", paste(head(factor_vars, 3), collapse = ", "), "\n")

  # Show levels for first factor
  cat(sprintf("  %s levels: %s\n",
              factor_vars[1],
              paste(levels(mock_demport[[factor_vars[1]]]), collapse = ", ")))
}

# Example output:
# Factor variables: 8
#   First 3: DHH_SEX, EDU_04, SMK_202
#   DHH_SEX levels: Male, Female

# Check for numeric variables
numeric_vars <- names(mock_demport)[sapply(mock_demport, is.numeric)]

cat("\nNumeric variables:", length(numeric_vars), "\n")
if (length(numeric_vars) > 0) {
  cat("  First 3:", paste(head(numeric_vars, 3), collapse = ", "), "\n")
}

# Example output:
# Numeric variables: 12
#   First 3: ADL_01, ADL_02, HWTDHTM
```

## Practical workflow: Generate individual cycle datasets

MockData generates **separate datasets for individual cycles**. You do
NOT bind them together in MockData - that’s the analyst’s job to test
harmonization.

**Recommended workflow:**

### Step 1: Filter metadata for each cycle

``` r
# Example: Create cycle-specific metadata files
# Filter variables and details by databaseStart column

# CCHS 2001
vars_2001 <- variables %>%
  filter(str_detect(databaseStart, "cchs2001"))

details_2001 <- variable_details %>%
  filter(variable %in% vars_2001$variable)

# Save cycle-specific metadata
write.csv(vars_2001, "demport_variables_2001.csv", row.names = FALSE)
write.csv(details_2001, "demport_details_2001.csv", row.names = FALSE)

# Repeat for other cycles...
```

### Step 2: Generate mock data for each cycle

``` r
# Generate separate mock dataset for CCHS 2001
mock_2001 <- create_mock_data(
  config_path = "demport_variables_2001.csv",
  details_path = "demport_details_2001.csv",
  n = 1000,
  seed = 2001  # Cycle-specific seed for reproducibility
)

# Generate separate mock dataset for CCHS 2003
mock_2003 <- create_mock_data(
  config_path = "demport_variables_2003.csv",
  details_path = "demport_details_2003.csv",
  n = 1000,
  seed = 2003
)

# MockData STOPS here - hand off to analyst
```

### Step 3: Test harmonization (analyst’s job)

After generating individual cycle datasets, you’ll harmonize them using
your harmonization pipeline (e.g., recodeflow/cchsflow), bind the
harmonized cycles together, and calculate derived variables. Good luck!

**Key principles:**

1.  **MockData generates**: Individual raw cycle datasets (separate
    files/objects)
2.  **Analyst harmonizes**: Each cycle using recodeflow/cchsflow
3.  **Analyst binds**: Harmonized cycles together for analysis
4.  **Analyst calculates**: Derived variables on pooled data

**Why separate cycles matter:**

- Tests harmonization logic on realistic raw data structure
- Allows cycle-specific sample sizes (CCHS 2001 = 130K, CCHS 2017 =
  110K)
- Enables testing cycle-specific missing patterns
- Matches real workflow: harmonize first, then pool

## Survival analysis dates

DemPoRT is a survival model predicting time to dementia diagnosis. This
section demonstrates how to generate realistic survival dates with
proper temporal ordering and competing risks.

### Date variables for survival analysis

The table below shows the date variables in temporal order. The survival
analysis focuses on the three key dates: **interview** (cohort entry),
**dementia onset** (primary outcome), and **death** (competing risk).
Birth date is included in the metadata for age calculation but is not
required for the survival analysis itself.

| Variable              | Role in analysis                                | Date range | Temporal constraint            |
|-----------------------|-------------------------------------------------|------------|--------------------------------|
| `birth_date`          | Age calculation (not used in survival analysis) | 1920-1987  | birth \< interview             |
| `interview_date`      | **Cohort entry (t=0)**                          | 2001-2005  | Baseline for all follow-up     |
| `dementia_onset_date` | **Primary outcome**                             | 2001-2017  | interview \< dementia \< death |
| `death_date`          | **Competing risk**                              | 2001-2017  | interview \< death             |

**Administrative censoring:** End of follow-up is 2017-03-31.
Individuals alive at this date are censored.

### Step 1: Generate survival dates with temporal ordering

The
[`create_survival_dates()`](https://big-life-lab.github.io/MockData/reference/create_survival_dates.md)
function generates paired entry and event dates with guaranteed temporal
ordering. This must be called separately from
[`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md)
because it processes TWO variables together.

``` r
# Extract metadata for interview (cohort entry) and death (competing risk)
interview_details <- variable_details %>%
  filter(variable == "interview_date")

death_details <- variable_details %>%
  filter(variable == "death_date")

interview_row <- variables %>%
  filter(variable == "interview_date")

death_row <- variables %>%
  filter(variable == "death_date")

# Generate 1000 individuals with guaranteed temporal ordering
survival_dates <- create_survival_dates(
  entry_var_row = interview_row,
  entry_details_subset = interview_details,
  event_var_row = death_row,
  event_details_subset = death_details,
  n = 1000,
  seed = 456,
  df_mock = data.frame()
)
```

**Verify temporal ordering and date ranges:**

| Variable       | Min        | Max        | Expected  | Temporal ordering            |
|:---------------|:-----------|:-----------|:----------|:-----------------------------|
| interview_date | 2001-01-09 | 2005-12-31 | 2001-2005 | Baseline (t=0)               |
| death_date     | 2002-07-07 | 2015-10-26 | 2001-2017 | ✓ All \>= interview (n=1000) |

Generated date ranges and temporal ordering verification

### Step 2: Add competing risks (dementia onset)

Real survival studies track multiple outcomes. In DemPoRT, two mutually
exclusive events can occur:

1.  **Dementia diagnosis** (primary outcome)
2.  **Death without dementia** (competing risk)

We’ll simulate dementia occurring between interview and death for 10% of
the cohort:

``` r
# Simulate dementia incidence (10% develop dementia)
set.seed(789)
survival_dates$dementia_occurred <- rbinom(
  n = nrow(survival_dates),
  size = 1,
  prob = 0.10
)

# For those with dementia, set dementia_onset_date between interview and death
survival_dates$dementia_onset_date <- ifelse(
  survival_dates$dementia_occurred == 1,
  survival_dates$interview_date +
    runif(nrow(survival_dates)) *
    (survival_dates$death_date - survival_dates$interview_date),
  NA
)

# Convert back to Date class
survival_dates$dementia_onset_date <- as.Date(
  survival_dates$dementia_onset_date,
  origin = "1970-01-01"
)
```

### Step 3: Add administrative censoring

Not everyone is followed to death in real cohort studies. We apply
administrative censoring at 2017-03-31 (end of follow-up):

``` r
# Apply censoring: individuals alive after 2017-03-31 are censored
censor_date <- as.Date("2017-03-31")
survival_dates$censored <- survival_dates$death_date > censor_date

# Set observed death date (censored individuals get censor_date)
survival_dates$death_date_observed <- ifelse(
  survival_dates$censored,
  censor_date,
  survival_dates$death_date
)

survival_dates$death_date_observed <- as.Date(
  survival_dates$death_date_observed,
  origin = "1970-01-01"
)
```

### Step 4: Calculate time-to-event and final outcomes

``` r
# Calculate follow-up time to first event (years)
survival_dates$time_to_event <- pmin(
  as.numeric(difftime(survival_dates$dementia_onset_date,
                     survival_dates$interview_date,
                     units = "days")) / 365.25,
  as.numeric(difftime(survival_dates$death_date_observed,
                     survival_dates$interview_date,
                     units = "days")) / 365.25,
  na.rm = TRUE
)

# Event type: 0=censored, 1=dementia, 2=death without dementia
survival_dates$event_type <- ifelse(
  !is.na(survival_dates$dementia_onset_date), 1,
  ifelse(!survival_dates$censored, 2, 0)
)
```

### Summary: Cohort characteristics

| Outcome  | Event code |   N | Percent | Mean follow-up (years) | Temporal ordering verified                   |
|:---------|:-----------|----:|:--------|:-----------------------|:---------------------------------------------|
| Censored | 0          |   0 | 0.0%    | —                      | ✓ All interview \< censor (n=0)              |
| Dementia | 1          | 102 | 10.2%   | 3.0                    | ✓ All interview \< dementia \< death (n=102) |
| Death    | 2          | 898 | 89.8%   | 5.6                    | ✓ All interview \< death (n=898)             |

Final cohort summary: Events, follow-up time, and temporal ordering
verification

The simulated cohort demonstrates realistic survival analysis patterns:

- **Temporal ordering:** All dates satisfy the constraint interview \<
  event \< death
- **Competing risks:** Individuals experience either dementia or death,
  not both
- **Censoring:** Individuals alive at study end (2017-03-31) are
  censored
- **Follow-up time:** Varies by outcome, with censored individuals
  having longest follow-up

### Prepare for Cox regression or competing risks analysis

The dataset is now ready for survival analysis:

``` r
# Example: Cox proportional hazards for dementia
# library(survival)
#
# model_dementia <- coxph(
#   Surv(time_to_event, event_type == 1) ~ age + sex + education,
#   data = survival_dates
# )
#
# # Example: Competing risks analysis
# library(cmprsk)
#
# cr_fit <- cuminc(
#   ftime = survival_dates$time_to_event,
#   fstatus = survival_dates$event_type,
#   cencode = 0
# )
```

**Key takeaways:**

1.  [`create_survival_dates()`](https://big-life-lab.github.io/MockData/reference/create_survival_dates.md)
    generates entry and event dates with guaranteed temporal ordering
2.  Competing risks (dementia vs death) require additional simulation
    between entry and event
3.  Administrative censoring is applied based on study design (end date)
4.  All temporal constraints are verified before analysis
5.  The dataset is ready for Cox regression or competing risks models

**See also:** [Date variables
tutorial](https://big-life-lab.github.io/MockData/articles/dates.md) for
more on date generation and temporal constraints.

## Visualize mock data (optional)

After generating mock data, you can visualize distributions to verify
data quality. For example, create histograms for continuous variables
(height, weight) or bar charts for categorical variables (sex,
education).

``` r
# Example: Check a continuous variable distribution
hist(mock_demport$HWTDHTM,  # Height in cm
     breaks = 20,
     main = "Height Distribution",
     xlab = "Height (cm)",
     col = "lightblue")

# Example: Check a categorical variable distribution
barplot(table(mock_demport$DHH_SEX),
        main = "Sex Distribution",
        col = "lightgreen")
```

These visualizations help you verify that generated values fall within
expected ranges and categories match your metadata specifications.

## Export mock data

Save your generated mock data for use in testing your analysis pipeline.
You can export to CSV for broad compatibility or RDS to preserve
R-specific data types (Date objects, factor levels).

``` r
# Save to CSV (compatible with most tools)
write.csv(
  mock_demport,
  "demport_mock_data.csv",
  row.names = FALSE
)

# Save to RDS (preserves R data types like Date, factor levels)
saveRDS(
  mock_demport,
  "demport_mock_data.rds"
)
```

After running these commands, you’ll have two files saved to your
working directory: `demport_mock_data.csv` and `demport_mock_data.rds`.

## What you learned

This vignette demonstrated:

1.  **Batch generation** with
    [`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md)
    for complex multi-variable datasets
2.  **Multi-cycle data** concepts and why they matter for survey
    harmonization
3.  **Metadata validation** to catch inconsistencies before generation
4.  **Variable classification** to distinguish raw vs. derived variables
5.  **Data quality checks** to verify generated data meets expectations
6.  **Survival analysis setup** including date variables and event
    indicators

## Next steps

**Core concepts:**

- [Getting
  started](https://big-life-lab.github.io/MockData/articles/getting-started.md) -
  If you haven’t read this yet
- [Configuration
  files](https://big-life-lab.github.io/MockData/articles/tutorial-config-files.md) -
  Deep dive on metadata format
- [Date
  variables](https://big-life-lab.github.io/MockData/articles/dates.md) -
  Advanced temporal data and survival workflows

**Real-world examples:**

- [CCHS
  example](https://big-life-lab.github.io/MockData/articles/cchs-example.md) -
  Canadian Community Health Survey
- [CHMS
  example](https://big-life-lab.github.io/MockData/articles/chms-example.md) -
  Canadian Health Measures Survey

**Advanced topics:**

- [Configuration
  reference](https://big-life-lab.github.io/MockData/articles/reference-config.md) -
  Complete metadata specification
- [Advanced
  topics](https://big-life-lab.github.io/MockData/articles/advanced-topics.md) -
  Performance optimization and integration

**For DemPoRT users:**

- Apply mock data in analysis pipelines
- Test harmonization code before accessing real data
- Validate survival model implementation
- Generate sample datasets for method development
