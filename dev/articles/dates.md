# Date variables and temporal data

**About this vignette:** This reference document provides comprehensive
technical specifications for date variable generation. For step-by-step
tutorials, see [Working with date
variables](https://big-life-lab.github.io/MockData/articles/tutorial-dates.md).

## Overview

MockData supports generating date variables for temporal analysis,
including survival analysis and longitudinal studies. This vignette
covers:

- Creating date variables from metadata
- Distribution options for realistic temporal patterns
- Simulating different source formats (CSV, SAS) for harmonization
  testing
- Generating invalid dates for testing validation pipelines
- Best practices for temporal mock data

## Basic date generation

The
[`create_date_var()`](https://big-life-lab.github.io/MockData/reference/create_date_var.md)
function generates date variables from SAS date format specifications in
your metadata.

### Metadata format

Date ranges are specified in SAS date format in the `recStart` column:

    variable,recStart,recEnd,catLabel
    death_date,"[01JAN2001, 31MAR2017]","[2001-01-01, 2017-03-31]",Death date
    death_date,else,NA::b,Missing

The function parses the SAS format and generates R `Date` objects within
the specified range.

### Example: Basic date variable

``` r
# Load package
library(MockData)

# Load DemPoRT metadata (has date variables)
variable_details <- read.csv(
  system.file("extdata/demport/variable_details_DemPoRT.csv", package = "MockData"),
  stringsAsFactors = FALSE
)

# Generate death dates
death_dates <- create_date_var(
  var_raw = "death_date",
  cycle = "ices",
  variable_details = variable_details,
  length = 1000,
  df_mock = data.frame(),
  seed = 100
)

# View sample
head(death_dates)
```

      death_date
    1 2016-11-17
    2 2009-06-18
    3 2008-06-25
    4 2001-04-02
    5 2007-05-18
    6 2016-01-06

**Date range:** Minimum: 2001-01-01, Maximum: 2017-03-09, Sample size:
1000

## Distribution options

Date variables support three distribution types to create realistic
temporal patterns.

### Uniform distribution (default)

Equal probability across all dates in the range. Suitable for calendar
dates with no temporal bias.

``` r
dates_uniform <- create_date_var(
  var_raw = "study_entry_date",
  cycle = "ices",
  variable_details = variable_details,
  length = 1000,
  df_mock = data.frame(),
  distribution = "uniform",  # Default
  seed = 100
)
```

**Use cases:**

- Study recruitment dates
- Random calendar events
- Administrative dates

### Gompertz distribution

Events concentrate near the end of the range, following a Gompertz
survival distribution. Useful for modeling mortality and age-related
events.

``` r
dates_gompertz <- create_date_var(
  var_raw = "death_date",
  cycle = "ices",
  variable_details = variable_details,
  length = 1000,
  df_mock = data.frame(),
  distribution = "gompertz",
  seed = 100
)
```

**Use cases:**

- Death dates (mortality increases with time)
- Disease progression events
- Age-related outcomes

**Technical details:**

- Shape parameter (η) = 0.1
- Rate parameter (b) = 0.01
- Events cluster toward end of range

### Exponential distribution

Events concentrate near the start of the range. Useful for time-to-event
data where early events are more common.

``` r
dates_exponential <- create_date_var(
  var_raw = "first_hospitalization",
  cycle = "ices",
  variable_details = variable_details,
  length = 1000,
  df_mock = data.frame(),
  distribution = "exponential",
  seed = 100
)
```

**Use cases:**

- First event occurrence
- Early disease diagnosis
- Initial treatment dates

**Technical details:**

- Rate = 1 / (range / 3)
- Mean event time at 1/3 of range
- Events decay exponentially

### Choosing a distribution

| Distribution | Pattern              | Best for                        |
|--------------|----------------------|---------------------------------|
| Uniform      | Flat across range    | Calendar dates, random events   |
| Gompertz     | Increases toward end | Mortality, age-related outcomes |
| Exponential  | Decreases from start | First events, early diagnoses   |

### Comparing distributions

``` r
# Generate dates with each distribution
dates_uniform <- create_date_var(
  var_raw = "death_date", cycle = "demport",
  variable_details = variable_details,
  length = 1000, df_mock = data.frame(),
  distribution = "uniform", seed = 100
)

dates_gompertz <- create_date_var(
  var_raw = "death_date", cycle = "demport",
  variable_details = variable_details,
  length = 1000, df_mock = data.frame(),
  distribution = "gompertz", seed = 101
)

dates_exponential <- create_date_var(
  var_raw = "death_date", cycle = "demport",
  variable_details = variable_details,
  length = 1000, df_mock = data.frame(),
  distribution = "exponential", seed = 102
)

# Calculate medians
median_uniform <- format(median(dates_uniform$death_date), "%Y-%m-%d")
median_gompertz <- format(median(dates_gompertz$death_date), "%Y-%m-%d")
median_exponential <- format(median(dates_exponential$death_date), "%Y-%m-%d")
```

**Median dates by distribution:**

- Uniform: NULL
- Gompertz: NULL
- Exponential: NULL

Notice how:

- **Uniform**: Median near middle of range (2009)
- **Gompertz**: Median shifted toward end (2013) - realistic for
  mortality
- **Exponential**: Median shifted toward start (2005) - realistic for
  early events

## Missing data

Use `prop_NA` to introduce missing dates:

``` r
dates_with_na <- create_date_var(
  var_raw = "death_date",
  cycle = "ices",
  variable_details = variable_details,
  length = 1000,
  df_mock = data.frame(),
  prop_NA = 0.05,  # 5% missing
  seed = 100
)

# Check missing proportion
sum(is.na(dates_with_na$death_date)) / 1000  # ~0.05
```

**Note**: Date variables use R `NA` values rather than numeric codes,
even if NA codes are specified in the metadata.

## Source format: simulating raw data imports

By default, MockData generates dates as R `Date` objects (analysis-ready
format). However, real survey data comes in different formats depending
on the source. The `source_format` parameter simulates how dates appear
after importing from different file types.

### Available formats

**analysis (default)**: R Date objects

``` r
# Default behavior - analysis-ready dates
mock <- create_mock_data(
  config_path = "variables.csv",
  details_path = "variable_details.csv",
  n = 100,
  source_format = "analysis"  # Default
)

class(mock$interview_date)
# [1] "Date"
```

**csv**: Character strings (ISO format)

``` r
# Simulate dates as they appear after read.csv()
mock_csv <- create_mock_data(
  config_path = "variables.csv",
  details_path = "variable_details.csv",
  n = 100,
  source_format = "csv"
)

class(mock_csv$interview_date)
# [1] "character"

mock_csv$interview_date[1:3]
# [1] "2001-01-15" "2001-02-22" "2001-03-30"
```

**sas**: Numeric values (days since 1960-01-01)

``` r
# Simulate dates as they appear after haven::read_sas()
mock_sas <- create_mock_data(
  config_path = "variables.csv",
  details_path = "variable_details.csv",
  n = 100,
  source_format = "sas"
)

class(mock_sas$interview_date)
# [1] "numeric"

mock_sas$interview_date[1:3]
# [1] 15050 15087 15123  # Days since 1960-01-01
```

### Use case: testing harmonization pipelines

The `source_format` parameter is particularly useful for testing date
parsing and harmonization code:

``` r
# Generate CSV-format mock data
mock_csv <- create_mock_data(
  config_path = "cchs_variables.csv",
  details_path = "cchs_variable_details.csv",
  n = 1000,
  source_format = "csv"
)

# Test your harmonization logic
harmonized <- mock_csv %>%
  mutate(
    # Parse character dates
    interview_date = as.Date(interview_date, format = "%Y-%m-%d"),

    # Calculate age at baseline
    age_at_baseline = as.numeric(interview_date - birth_date) / 365.25
  )

# Verify harmonization succeeded
stopifnot(inherits(harmonized$interview_date, "Date"))
stopifnot(all(harmonized$age_at_baseline >= 0, na.rm = TRUE))
```

### Why this matters

Real survey data doesn’t arrive as clean R Date objects:

- **CSV files**: Dates are character strings that need parsing
- **SAS files**: Dates may be numeric (if haven doesn’t auto-convert)
- **SPSS/Stata files**: Various numeric formats with different epochs

Using `source_format` lets you test your entire harmonization pipeline,
not just the analysis code.

### Converting between formats

All formats represent the same underlying dates:

``` r
# Generate in all three formats (same seed = same dates)
mock_analysis <- create_mock_data(..., source_format = "analysis", seed = 123)
mock_csv <- create_mock_data(..., source_format = "csv", seed = 123)
mock_sas <- create_mock_data(..., source_format = "sas", seed = 123)

# Convert back to Date for comparison
dates_from_csv <- as.Date(mock_csv$interview_date)
dates_from_sas <- as.Date(mock_sas$interview_date, origin = "1960-01-01")

# Verify all represent same dates
all(mock_analysis$interview_date == dates_from_csv)  # TRUE
all(mock_analysis$interview_date == dates_from_sas)  # TRUE
```

## Invalid dates for testing

The `prop_invalid` parameter generates out-of-period dates to test
validation pipelines.

### Basic usage

``` r
dates_dirty <- create_date_var(
  var_raw = "death_date",
  cycle = "ices",
  variable_details = variable_details,
  length = 1000,
  df_mock = data.frame(),
  prop_invalid = 0.03,  # 3% invalid
  seed = 100
)

# Check for dates outside valid range
valid_start <- as.Date("2001-01-01")
valid_end <- as.Date("2017-03-31")

n_too_early <- sum(dates_dirty$death_date < valid_start, na.rm = TRUE)
n_too_late <- sum(dates_dirty$death_date > valid_end, na.rm = TRUE)
total_invalid <- n_too_early + n_too_late
pct_invalid <- sprintf("%.1f%%", 100 * total_invalid / nrow(dates_dirty))
```

**Invalid date summary:**

- Dates before range: 15
- Dates after range: 0
- Total invalid: 15 out of 1000 (1.5%)

**Sample invalid dates:**

- Too early: 2000-12-31, 2000-12-31, 2000-12-31
- Too late:

### Invalid date characteristics

- **Range**: 1-5 years before start or after end
- **Distribution**: Split evenly between too-early and too-late
- **Realism**: Mimics common data entry errors

### Combining NA and invalid

``` r
dates_complex <- create_date_var(
  var_raw = "death_date",
  cycle = "ices",
  variable_details = variable_details,
  length = 1000,
  df_mock = data.frame(),
  prop_NA = 0.02,        # 2% missing
  prop_invalid = 0.03,   # 3% invalid
  seed = 100
)

# Validation check
stopifnot(prop_NA + prop_invalid <= 1.0)  # Must sum to ≤ 1
```

## Configuration-driven workflow

For complex studies with multiple events and data quality parameters,
use configuration files to manage settings. This approach improves
reproducibility and makes it easy to share study specifications.

### Using configuration files

Configuration files are CSV files with four columns: parameter, value,
type, and description. They specify study design, time windows, event
parameters, and data quality settings.

``` r
# Load configuration
config <- read_study_config(system.file("extdata/study_config_example.csv", package = "MockData"))

# Validate configuration
validate_study_config(config)

# Generate survival data using config parameters
survival_data <- create_survival_dates(
  entry_var = "index_date",
  event_var = "death_date",
  entry_start = config$accrual_start,
  entry_end = config$accrual_end,
  followup_min = config$followup_min,
  followup_max = config$followup_max,
  length = config$sample_size,
  df_mock = data.frame(),
  event_distribution = config$death_distribution,
  prop_censored = config$prop_censored,
  seed = config$seed
)
```

**Benefits:**

- All study parameters in one file
- Easy to version control and share
- Validates parameters before generation
- Documents study design decisions
- Supports both open cohort and fixed follow-up designs

See `inst/extdata/study_config_example.csv` for a complete example
configuration.

## Survival analysis workflows

### Basic cohort study

Use
[`create_survival_dates()`](https://big-life-lab.github.io/MockData/reference/create_survival_dates.md)
to generate paired entry and event dates with guaranteed temporal
ordering:

``` r
# Mortality study with 5-year recruitment, up to 10-year follow-up
surv_data <- create_survival_dates(
  entry_var = "cohort_entry",
  event_var = "death_date",
  entry_start = as.Date("2000-01-01"),
  entry_end = as.Date("2004-12-31"),
  followup_min = 365,       # Min 1 year follow-up
  followup_max = 3650,      # Max 10 years
  length = 1000,
  df_mock = data.frame(),
  event_distribution = "gompertz",  # Realistic mortality pattern
  seed = 100
)

# View sample
head(surv_data, 5)
```

      cohort_entry death_date
    1   2004-10-03 2014-10-01
    2   2001-05-17 2011-05-15
    3   2003-10-13 2013-10-10
    4   2004-07-05 2014-07-03
    5   2002-09-11 2012-09-08

**Key features:**

- Entry dates uniformly distributed across recruitment period
- Event dates follow Gompertz distribution (mortality increases with
  time)
- Guaranteed: `death_date > cohort_entry` for all records

**Follow-up time summary (days):**

- Median: 3650
- Range: 3650 - 3650
- Mean: 3650

### Censoring

Add censoring to simulate incomplete follow-up:

``` r
surv_censored <- create_survival_dates(
  entry_var = "entry",
  event_var = "event",
  entry_start = as.Date("2010-01-01"),
  entry_end = as.Date("2015-12-31"),
  followup_min = 30,
  followup_max = 1825,  # 5 years
  length = 1000,
  df_mock = data.frame(),
  event_distribution = "exponential",
  prop_censored = 0.3,  # 30% censored
  seed = 200
)

# View structure
head(surv_censored, 5)
```

           entry      event event_status
    1 2013-10-25 2018-05-28            1
    2 2014-11-10 2015-02-13            1
    3 2010-08-20 2012-12-22            1
    4 2014-10-22 2017-12-27            1
    5 2014-04-29 2015-09-08            1

The `event_status` column indicates:

- **1** = event observed (death occurred)
- **0** = censored (lost to follow-up, end of study)

**Censoring summary:**

- Events: 700 (70.0%)
- Censored: 300 (30.0%)

### Distribution comparison for survival data

Different distributions create different event patterns:

``` r
# Uniform: constant hazard
surv_uniform <- create_survival_dates(
  entry_var = "entry", event_var = "event",
  entry_start = as.Date("2015-01-01"),
  entry_end = as.Date("2015-12-31"),
  followup_min = 100, followup_max = 1000,
  length = 1000, df_mock = data.frame(),
  event_distribution = "uniform", seed = 301
)

# Gompertz: increasing hazard (aging population)
surv_gompertz <- create_survival_dates(
  entry_var = "entry", event_var = "event",
  entry_start = as.Date("2015-01-01"),
  entry_end = as.Date("2015-12-31"),
  followup_min = 100, followup_max = 1000,
  length = 1000, df_mock = data.frame(),
  event_distribution = "gompertz", seed = 302
)

# Exponential: early events (diagnosis, treatment failure)
surv_exponential <- create_survival_dates(
  entry_var = "entry", event_var = "event",
  entry_start = as.Date("2015-01-01"),
  entry_end = as.Date("2015-12-31"),
  followup_min = 100, followup_max = 1000,
  length = 1000, df_mock = data.frame(),
  event_distribution = "exponential", seed = 303
)

# Compare median survival times
followup_uniform <- as.numeric(surv_uniform$event - surv_uniform$entry)
followup_gompertz <- as.numeric(surv_gompertz$event - surv_gompertz$entry)
followup_exponential <- as.numeric(surv_exponential$event - surv_exponential$entry)

median_uniform_tte <- median(followup_uniform)
median_gompertz_tte <- median(followup_gompertz)
median_exponential_tte <- median(followup_exponential)
```

**Median time-to-event (days):**

- Uniform: 565.5
- Gompertz: 1000
- Exponential: 302.5

**Pattern interpretation:**

- **Uniform**: Events spread evenly across follow-up
- **Gompertz**: More events later (realistic for age-related mortality)
- **Exponential**: More events early (realistic for disease progression)

### Longitudinal studies

Generate visit dates across a study period:

``` r
# Baseline visit (uniform across recruitment period)
baseline <- create_date_var(
  var_raw = "visit_baseline",
  cycle = "cohort",
  variable_details = variable_details,
  length = 500,
  df_mock = data.frame(),
  distribution = "uniform",
  seed = 200
)

# Follow-up visits would be generated relative to baseline
# (Currently manual - see planned temporal constraints in parking-lot.md)
```

### Testing data validation

Generate realistic errors for pipeline testing:

``` r
# Create test data with multiple error types
test_dates <- create_date_var(
  var_raw = "death_date",
  cycle = "ices",
  variable_details = variable_details,
  length = 10000,
  df_mock = data.frame(),
  prop_NA = 0.02,
  prop_invalid = 0.01,
  seed = 300
)

# Test your validation function
validate_dates <- function(dates, min_date, max_date) {
  errors <- list()

  # Check for missing
  if (any(is.na(dates))) {
    errors$missing <- sum(is.na(dates))
  }

  # Check for out-of-range
  valid_dates <- dates[!is.na(dates)]
  if (any(valid_dates < min_date | valid_dates > max_date)) {
    errors$out_of_range <- sum(
      valid_dates < min_date | valid_dates > max_date
    )
  }

  return(errors)
}

# Run validation
errors <- validate_dates(
  test_dates$death_date,
  min_date = as.Date("2001-01-01"),
  max_date = as.Date("2017-03-31")
)

# The errors list will contain any validation issues found
```

## Best practices

### Seed management

Use different seeds for different date variables to ensure independence:

``` r
birth_dates <- create_date_var(..., seed = 100)
death_dates <- create_date_var(..., seed = 101)
diagnosis_dates <- create_date_var(..., seed = 102)
```

### Distribution selection

1.  **Start with uniform** for calendar dates without known patterns
2.  **Use Gompertz** for mortality and age-related outcomes
3.  **Use exponential** for first-event or early-diagnosis scenarios
4.  **Validate** against real data distributions when possible

### Temporal constraints

**Current limitation**: MockData v0.2.0 does not enforce temporal
relationships between dates (e.g., birth \< death).

**Workarounds**:

- Generate dates independently and post-process
- Use appropriate distributions to minimize violations
- Document assumptions in your code

**Future**: See
[parking-lot.md](https://big-life-lab.github.io/MockData/parking-lot.md)
for planned `after`/`before` parameters in v0.3.0.

### Testing strategies

1.  **Test both valid and invalid data**:

    ``` r
    # Valid data for algorithm testing
    clean_dates <- create_date_var(..., prop_invalid = 0)

    # Dirty data for validation testing
    dirty_dates <- create_date_var(..., prop_invalid = 0.05)
    ```

2.  **Use realistic error proportions**:

    - Real surveys: 1-5% invalid
    - Administrative data: 0.1-1% invalid
    - Manual entry: 5-10% invalid

3.  **Document your assumptions**:

    ``` r
    # Generate dates with 3% invalid to match historical error rate
    # from 2015-2017 data linkage (see docs/data-quality-report.pdf)
    test_dates <- create_date_var(..., prop_invalid = 0.03)
    ```

## Limitations and future enhancements

### Current limitations

- No automatic temporal constraints between dates
- Limited distribution options (3 types)
- No support for recurrent events
- No time-varying covariates

### Planned features

See
[parking-lot.md](https://big-life-lab.github.io/MockData/parking-lot.md)
for:

- **Temporal constraints** (v0.3.0): `after`, `before` parameters
- **Survival helpers** (v0.3.0): `create_survival_vars()`
- **Recurrent events** (v0.4.0): Multiple events per subject
- **Time-varying covariates** (v0.5.0): Variables that change over time

## Next steps

- [User
  guide](https://big-life-lab.github.io/MockData/articles/user-guide.md) -
  Comprehensive feature documentation
- [DemPoRT
  example](https://big-life-lab.github.io/MockData/articles/demport-example.md) -
  Applied survival analysis workflow
- [Advanced
  topics](https://big-life-lab.github.io/MockData/articles/advanced-topics.md) -
  Custom distributions and workflows
- [`?create_date_var`](https://big-life-lab.github.io/MockData/reference/create_date_var.md) -
  Function reference
