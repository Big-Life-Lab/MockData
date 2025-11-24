# Generating survival data with competing risks

**About this vignette:** This tutorial teaches survival data generation
for cohort studies. You’ll learn how to create time-to-event data with
competing risks (death, disease incidence, loss-to-follow-up), apply
temporal ordering constraints, and generate survival indicators for
analysis. All code examples run during vignette build to ensure
accuracy.

## Overview

Survival analysis requires careful coordination of multiple date
variables with strict temporal ordering:

- **Cohort entry date** (baseline, index date)
- **Event dates** (disease incidence, outcomes of interest)
- **Competing risks** (death prevents observation of primary event)
- **Censoring events** (loss to follow-up, administrative censoring)

MockData’s
[`create_wide_survival_data()`](https://big-life-lab.github.io/MockData/reference/create_wide_survival_data.md)
generates these dates with proper temporal constraints and realistic
distributions.

> **About this tutorial: Clean survival data with correct temporal
> ordering**
>
> This tutorial teaches how to create **meaningful, analysis-ready
> survival data** with correct temporal ordering. All dates follow
> proper survival analysis constraints (entry ≤ event, death as
> competing risk, etc.).
>
> **For data quality testing:** If you need to generate **raw data with
> temporal violations** (e.g., death before entry, impossible dates) for
> testing data cleaning pipelines, see the [Garbage data
> tutorial](https://big-life-lab.github.io/MockData/articles/tutorial-garbage-data.html#survival-data-garbage)
> which covers survival-specific garbage patterns.

## Basic survival data generation

### Minimal example: entry + event

The simplest survival data has two dates: cohort entry and a single
event.

``` r
# Load minimal-example metadata
variables <- read.csv(
  system.file("extdata/minimal-example/variables.csv", package = "MockData"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

variable_details <- read.csv(
  system.file("extdata/minimal-example/variable_details.csv", package = "MockData"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

# Generate entry + event dates
surv_basic <- create_wide_survival_data(
  var_entry_date = "interview_date",
  var_event_date = "primary_event_date", # disease incidence or similar
  var_death_date = NULL,
  var_ltfu = NULL,  # Loss to follow-up
  var_admin_censor = NULL, # i.e. End of study follow-up
  databaseStart = "minimal-example",
  variables = variables,
  variable_details = variable_details,
  n = 1000,
  seed = 123
)

# View first few rows
head(surv_basic)
```

      interview_date primary_event_date
    1     2002-02-19               <NA>
    2     2002-04-08         2002-05-23
    3     2001-06-28               <NA>
    4     2002-06-10               <NA>
    5     2001-07-14               <NA>
    6     2003-07-27               <NA>

**Result:** Each row has an interview date (cohort entry) and primary
event date. Some event dates are `NA` (censored - event did not occur
during follow-up).

### Event proportions

Not all individuals experience the primary event. The `event_prop`
parameter in variables.csv controls event occurrence rate:

**Configuration:** The primary_event_date variable has
`event_prop = 0.3` in variables.csv, meaning 30% of individuals
experience the event.

**Observed:** 300 out of 1000 individuals (30%) experienced the primary
event.

## Competing risks: adding death

Death is a competing risk - individuals who die cannot experience the
primary event. MockData handles this temporal logic automatically.

``` r
# Generate entry + event + death
surv_compete <- create_wide_survival_data(
  var_entry_date = "interview_date",
  var_event_date = "primary_event_date",
  var_death_date = "death_date",
  var_ltfu = NULL,
  var_admin_censor = NULL,
  databaseStart = "minimal-example",
  variables = variables,
  variable_details = variable_details,
  n = 1000,
  seed = 456
)

# Check temporal ordering
head(surv_compete[, c("interview_date", "primary_event_date", "death_date")])
```

      interview_date primary_event_date death_date
    1     2005-11-08         2006-01-17       <NA>
    2     2005-02-17               <NA>       <NA>
    3     2003-07-20               <NA>       <NA>
    4     2002-07-04               <NA>       <NA>
    5     2002-04-14         2002-06-07       <NA>
    6     2004-06-29         2004-09-13       <NA>

### Competing risk logic

MockData applies these rules:

1.  **Entry date is baseline**: All other dates occur after entry
2.  **Death prevents events**: If death \< event, set event to NA
    (cannot observe event after death)
3.  **Temporal ordering**: interview_date ≤ event_date, interview_date ≤
    death_date

``` r
# Verify temporal ordering
# Note: Dates are already R Date objects (sourceFormat = "analysis" in variables.csv)
interview_dates <- surv_compete$interview_date
event_dates <- surv_compete$primary_event_date
death_dates <- surv_compete$death_date

# Check: All events occur after entry
all_events_after_entry <- all(
  event_dates[!is.na(event_dates)] >= interview_dates[!is.na(event_dates)],
  na.rm = TRUE
)

# Check: All deaths occur after entry
all_deaths_after_entry <- all(
  death_dates[!is.na(death_dates)] >= interview_dates[!is.na(death_dates)],
  na.rm = TRUE
)
```

**Temporal ordering validation:**

- All events occur after entry: TRUE
- All deaths occur after entry: TRUE

This confirms MockData correctly enforces temporal constraints.

## Complete survival data: entry + event + death + censoring

Real cohort studies have multiple censoring mechanisms:

- **Loss to follow-up**: Participants drop out
- **Administrative censoring**: Study ends on specific date

``` r
# Generate complete survival data (all 5 date variables)
surv_complete <- create_wide_survival_data(
  var_entry_date = "interview_date",
  var_event_date = "primary_event_date",
  var_death_date = "death_date",
  var_ltfu = "ltfu_date",
  var_admin_censor = "admin_censor_date",
  databaseStart = "minimal-example",
  variables = variables,
  variable_details = variable_details,
  n = 2000,
  seed = 789
)

# View structure
head(surv_complete)
```

      interview_date primary_event_date death_date  ltfu_date admin_censor_date
    1     2003-03-24               <NA>       <NA>       <NA>        2020-04-12
    2     2003-02-19               <NA>       <NA> 2020-02-15        2010-05-26
    3     2005-03-14         2005-05-16 2006-03-14       <NA>        2024-11-15
    4     2004-08-14               <NA>       <NA>       <NA>        2018-07-07
    5     2002-10-28         2003-01-16       <NA>       <NA>        2017-10-07
    6     2002-09-16               <NA>       <NA>       <NA>        2017-10-29

## Creating survival indicators

Survival analysis requires deriving time-to-event and event indicators
from the date variables.

### Calculate observation end date

Observation ends at the earliest of: primary event, death, loss to
follow-up, or administrative censoring.

``` r
# Dates are already R Date objects (sourceFormat = "analysis")
# Calculate end date (earliest of all outcomes)
# Build list of existing date columns
date_cols <- c("primary_event_date", "death_date", "ltfu_date", "admin_censor_date")
existing_cols <- date_cols[date_cols %in% names(surv_complete)]

# Calculate minimum date across existing columns
if (length(existing_cols) > 0) {
  # Use row-wise minimum to avoid pmin Inf issues with all-NA rows
  surv_complete$t_end <- as.Date(
    apply(surv_complete[, existing_cols, drop = FALSE], 1, function(row_dates) {
      valid_dates <- row_dates[!is.na(row_dates)]
      if (length(valid_dates) == 0) return(NA_real_)
      min(valid_dates)
    }),
    origin = "1970-01-01"
  )
} else {
  surv_complete$t_end <- as.Date(NA)
}

# Calculate follow-up time in days
# Date subtraction returns difftime object; convert to numeric days
surv_complete$followup_days <- as.numeric(difftime(surv_complete$t_end, surv_complete$interview_date, units = "days"))

head(surv_complete[, c("interview_date", "t_end", "followup_days")])
```

      interview_date      t_end followup_days
    1     2003-03-24 2020-04-12          6229
    2     2003-02-19 2010-05-26          2653
    3     2005-03-14 2005-05-16            63
    4     2004-08-14 2018-07-07          5075
    5     2002-10-28 2003-01-16            80
    6     2002-09-16 2017-10-29          5522

### Create event indicator

Event indicator identifies why observation ended:

- **0**: Censored (loss to follow-up or administrative censoring)
- **1**: Primary event occurred
- **2**: Death occurred (competing risk)

``` r
# Create event indicator
surv_complete$event_indicator <- ifelse(
  !is.na(surv_complete$primary_event_date) & surv_complete$primary_event_date == surv_complete$t_end, 1,  # Event
  ifelse(!is.na(surv_complete$death_date) & surv_complete$death_date == surv_complete$t_end, 2,  # Death
  0)  # Censored
)

# Tabulate outcomes
table(surv_complete$event_indicator)
```

       0    1    2
    1132  582  286 

**Result:**

- **Censored (0)**: 1132 (56.6%) - lost to follow-up or administratively
  censored
- **Primary event (1)**: 582 (29.1%) - experienced primary event
- **Death (2)**: 286 (14.3%) - died before primary event

## Distributions for survival data

Survival dates use realistic distributions to match real-world patterns:

**Uniform**: Constant hazard (administrative censoring, loss to
follow-up)

``` r
distribution = "uniform"
```

**Gompertz**: Age-dependent hazard (death, chronic disease)

``` r
distribution = "gompertz"
rate = 0.0001
shape = 0.1
```

**Exponential**: Constant hazard with early concentration

``` r
distribution = "exponential"
rate = 0.001
```

Distribution parameters are specified in variables.csv and used
automatically by
[`create_wide_survival_data()`](https://big-life-lab.github.io/MockData/reference/create_wide_survival_data.md).

## Date output formats: sourceFormat column

By default, survival dates are generated as R Date objects
(`sourceFormat = "analysis"`). However, you can simulate different raw
data formats using the `sourceFormat` column in variables.csv:

**Available sourceFormat values:**

- **analysis** (default): R Date objects ready for analysis
- **csv**: Character strings in ISO format (YYYY-MM-DD), simulating CSV
  file imports
- **sas**: Numeric values (days since 1960-01-01), simulating SAS date
  format

**Why this matters:**

Real cohort data doesn’t arrive as clean R Date objects:

- CSV files from survey instruments contain character dates requiring
  parsing
- SAS files may have numeric dates that need conversion
- Different data sources require different harmonization approaches

**Example: Testing different source formats**

The `sourceFormat` value in variables.csv controls the output format.
Let’s generate interview_date in SAS numeric format while keeping other
dates in analysis format:

``` r
# Modify only interview_date to use SAS format
vars_sas <- variables
vars_sas$sourceFormat[vars_sas$variable == "interview_date"] <- "sas"

surv_sas <- create_wide_survival_data(
  var_entry_date = "interview_date",
  var_event_date = "primary_event_date",
  var_death_date = NULL,
  var_ltfu = NULL,
  var_admin_censor = NULL,
  databaseStart = "minimal-example",
  variables = vars_sas,  # Modified to use SAS format for interview_date
  variable_details = variable_details,
  n = 100,
  seed = 123
)

# Check the format: interview_date is numeric (SAS), others are Date
head(surv_sas)
```

      interview_date primary_event_date
    1          15390         2012-05-06
    2          15438               <NA>
    3          15154         2011-09-15
    4          15501               <NA>
    5          15170               <NA>
    6          15913               <NA>

**Result:** The `interview_date` column is numeric (days since
1960-01-01), while `primary_event_date` remains a Date object. This
simulates mixed-format raw data that requires harmonization.

To convert SAS dates to R Date format:

``` r
# Convert SAS numeric dates to R Date
interview_converted <- as.Date(surv_sas$interview_date, origin = "1960-01-01")
head(interview_converted)
```

    [1] "2002-02-19" "2002-04-08" "2001-06-28" "2002-06-10" "2001-07-14"
    [6] "2003-07-27"

## Temporal violations for QA testing

The minimal-example metadata includes temporal violations through the
`garbage_high_prop` and `garbage_high_range` parameters. These generate
future dates that violate temporal constraints for testing validation
pipelines:

``` r
# Generate survival data with configured garbage dates
surv_qa <- create_wide_survival_data(
  var_entry_date = "interview_date",
  var_event_date = "primary_event_date",
  var_death_date = "death_date",
  var_ltfu = NULL,
  var_admin_censor = NULL,
  databaseStart = "minimal-example",
  variables = variables,
  variable_details = variable_details,
  n = 1000,
  seed = 999
)

# Check for temporal violations
# Look for events that occur after impossibly far in the future (2025+)
future_threshold <- as.Date("2025-01-01")

# Count future dates in primary_event_date
n_future_events <- sum(surv_qa$primary_event_date > future_threshold, na.rm = TRUE)

# Count future dates in death_date
n_future_deaths <- sum(surv_qa$death_date > future_threshold, na.rm = TRUE)

# Total violations
n_violations <- n_future_events + n_future_deaths
prop_violations <- round(100 * n_violations / nrow(surv_qa), 1)
```

**Validation detects:** 14 temporal violations out of 1000 observations
(1.4%). These future dates (\> 2025-01-01) represent data quality issues
that your validation pipeline should flag.

**Breakdown:**

- Future primary events: 8
- Future deaths: 6

This demonstrates how MockData’s garbage parameters help test validation
logic by generating realistic data quality issues.

## Key concepts summary

| Concept               | Implementation                    | Details                                              |
|-----------------------|-----------------------------------|------------------------------------------------------|
| **Competing risks**   | Death prevents primary event      | If death \< event, set event to NA                   |
| **Event proportions** | `event_prop` in variables.csv     | Controls % experiencing each outcome                 |
| **Temporal ordering** | Automatic constraint enforcement  | All dates ≥ entry date                               |
| **Distributions**     | Gompertz, uniform, exponential    | Specified in variables.csv                           |
| **End date**          | `pmin(event, death, ltfu, admin)` | Earliest outcome defines observation end             |
| **Event indicator**   | Derived from date comparison      | 0=censored, 1=event, 2=death                         |
| **QA testing**        | `prop_garbage` parameter          | Generates temporal violations for validation testing |

## What you learned

In this tutorial, you learned:

- **Basic survival generation**: Entry date + event date with event
  proportions
- **Competing risks**: Death as a competing event that prevents primary
  event observation
- **Temporal constraints**: How MockData enforces proper date ordering
- **Complete cohort data**: Entry + event + death + loss-to-follow-up +
  administrative censoring
- **Derived variables**: Creating follow-up time and event indicators
  from raw dates
- **Distributions**: Using Gompertz, uniform, and exponential for
  realistic temporal patterns
- **QA testing**: Generating temporal violations to validate data
  quality pipelines

## Next steps

**Tutorials:**

- [Date
  variables](https://big-life-lab.github.io/MockData/articles/tutorial-dates.md) -
  Learn interval notation and date distributions
- [Garbage
  data](https://big-life-lab.github.io/MockData/articles/tutorial-garbage-data.md) -
  Testing validation pipelines
- [Getting
  started](https://big-life-lab.github.io/MockData/articles/getting-started.md) -
  Review MockData fundamentals

**Reference:**

- [Configuration
  reference](https://big-life-lab.github.io/MockData/articles/reference-config.md) -
  Complete metadata schema
- [Advanced
  topics](https://big-life-lab.github.io/MockData/articles/advanced-topics.md) -
  Technical implementation details
