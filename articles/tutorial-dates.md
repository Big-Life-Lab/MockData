# Working with date variables

**About this vignette:** This tutorial teaches you how to generate date
variables with realistic temporal patterns. You’ll learn interval
notation, distribution options, source format simulation, and data
quality testing. All code examples run during vignette build to ensure
accuracy.

## Overview

This tutorial teaches temporal data generation in MockData. You’ll learn
how to create date variables for:

- **Cohort entry dates** (index dates, baseline dates)
- **Event dates** (death, diagnosis, hospital admission)
- **Administrative dates** (censoring dates, data freeze dates)
- **Temporal data quality testing** (out-of-period dates for validation)

Date variables use interval notation to specify ranges and support three
distributions (uniform, Gompertz, exponential) for realistic temporal
patterns.

## Basic date variable setup

### Configuration structure

Date variables use the same two-file structure as other variables, with
**interval notation** for date ranges:

**variables.csv:**

| uid      | variable       | role    | variableType | variableLabel  | position |
|----------|----------------|---------|--------------|----------------|----------|
| ices_v01 | interview_date | enabled | Date         | Interview date | 1        |

**variable_details.csv:**

| uid | uid_detail | variable | recStart | catLabel |
|----|----|----|----|----|
| ices_v01 | ices_d001 | interview_date | \[2001-01-01,2005-12-31\] | Interview date range |

**Key points:**

- Use **interval notation** in `recStart`: `[start_date,end_date]`
  (square brackets, comma-separated, ISO format)
- Dates use ISO format: YYYY-MM-DD
- Single row per date variable (not separate rows for start/end)
- All date variables from minimal-example use `ices_v*` namespace

### Generating date variables

``` r

# Load minimal-example metadata
variables <- read.csv(
  system.file("extdata/minimal-example/variables.csv", package = "MockData"),
  stringsAsFactors = FALSE
)

variable_details <- read.csv(
  system.file("extdata/minimal-example/variable_details.csv", package = "MockData"),
  stringsAsFactors = FALSE
)

# Generate interview dates
interview_data <- create_mock_data(
  databaseStart = "minimal-example",
  variables = variables,
  variable_details = variable_details,
  n = 100,
  seed = 123
)

# View interview date distribution
head(interview_data$interview_date)
```

    [1] "2005-07-01" "2005-09-11" "2003-09-25" "2005-08-09" "2004-07-13"
    [6] "2002-12-14"

``` r

summary(as.Date(interview_data$interview_date))
```

            Min.      1st Qu.       Median         Mean      3rd Qu.         Max.
    "2001-01-09" "2002-01-16" "2003-03-01" "2003-04-25" "2004-07-16" "2005-10-24" 

**Result:** 100 interview dates uniformly distributed between 2001-01-01
and 2005-12-31 (matching the minimal-example metadata).

**Note:** The interval notation in `recStart` specifies the complete
date range in a single row.

## Generating single date variables

For interactive development or testing, use
[`create_date_var()`](https://big-life-lab.github.io/MockData/reference/create_date_var.md)
to generate a single date variable without creating an entire dataset:

``` r

# Generate just the interview_date variable
interview_dates_only <- create_date_var(
  var = "interview_date",
  databaseStart = "minimal-example",
  variables = variables,
  variable_details = variable_details,
  n = 100,
  seed = 456
)

# View the result (single-column data frame)
head(interview_dates_only)
```

      interview_date
    1     2005-11-08
    2     2005-02-17
    3     2003-07-20
    4     2002-07-04
    5     2002-04-14
    6     2004-06-29

``` r

summary(as.Date(interview_dates_only$interview_date))
```

            Min.      1st Qu.       Median         Mean      3rd Qu.         Max.
    "2001-01-31" "2002-02-25" "2003-06-25" "2003-06-28" "2004-07-30" "2005-12-31" 

**Use cases for create_date_var():**

- Testing date specifications interactively
- Generating single variables for specific tests
- Exploring distribution patterns
- Quick prototyping before batch generation

**For complete datasets:** Use
[`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md)
to generate all variables at once (as shown in the previous section).

## Date ranges and distributions

### Distribution options

MockData supports three distributions for date generation:

**Uniform (default):** All dates equally likely across the range

- Use for: Cohort accrual with constant enrollment, administrative dates
- Example: `distribution = "uniform"`

**Gompertz:** Useful for survival/event times with higher events near
end of range

- Use for: Typical survival patterns
- Example: `distribution = "gompertz"`

**Exponential:** More events near start of range

- Use for: Time-to-event with early concentration
- Example: `distribution = "exponential"`

**Note:** Distribution types are specified in the `distribution` column
of variables.csv. For interactive generation (single variable
functions), you can override the metadata distribution.

### Comparing distributions

Different distributions create different temporal patterns. Here’s how
they compare using the same date range:

``` r

# Generate dates with uniform distribution (default)
uniform_dates <- create_date_var(
  var = "interview_date",
  databaseStart = "minimal-example",
  variables = variables,
  variable_details = variable_details,
  n = 1000,
  seed = 100
)

# Calculate median date
median_uniform <- median(as.Date(uniform_dates$interview_date))

# View median
median_uniform
```

    [1] "2003-09-10"

The uniform distribution produces a median date near the middle of the
range (2001-01-01 to 2005-12-31), as expected for evenly distributed
dates.

**Distribution patterns:**

| Distribution | Median location | Best for |
|----|----|----|
| **Uniform** | Middle of range (~2003) | Calendar dates, recruitment periods, random events |
| **Gompertz** | Shifted toward end (~2004-2005) | Mortality data, age-related events |
| **Exponential** | Shifted toward start (~2001-2002) | First diagnosis, early treatment, rapid events |

**Choosing a distribution:**

1.  **Start with uniform** for calendar dates without known temporal
    patterns
2.  **Use Gompertz** for mortality and age-related outcomes
3.  **Use exponential** for first-event or early-diagnosis scenarios

The distribution is read from the `distribution` column in
variables.csv, making it easy to specify different patterns for
different date variables.

## Event proportions for survival data

When generating event dates (death, diagnosis, hospitalization), not all
individuals experience the event during follow-up. The `event_prop`
parameter controls what proportion of individuals experience the event
versus being censored (no event observed).

### Basic event_prop example

Let’s generate death dates where only 30% of individuals die during the
study period:

``` r

# Create simple death date configuration
death_vars <- data.frame(
  uid = "death_v1",
  variable = "death_date",
  role = "enabled",
  variableType = "Date",
  rType = "date",
  position = 1,
  distribution = "gompertz",
  rate = 1e-04,
  shape = 0.1,
  followup_min = 0,
  followup_max = 3650,
  event_prop = 0.3,  # 30% experience death
  sourceFormat = "analysis",
  stringsAsFactors = FALSE
)

death_details <- data.frame(
  uid = "death_v1",
  uid_detail = "death_v1_d1",
  variable = "death_date",
  recStart = "[2001-01-01,2005-12-31]",
  recEnd = "copy",
  catLabel = "Death dates",
  stringsAsFactors = FALSE
)

# Generate death dates (requires anchor_date for survival variables)
anchor_dates <- as.Date("2001-01-01") + sample(0:1826, 100, replace = TRUE)
df_mock <- data.frame(anchor_date = anchor_dates)

death_data <- create_date_var(
  var = "death_date",
  databaseStart = "tutorial",
  variables = death_vars,
  variable_details = death_details,
  df_mock = df_mock,
  n = 100,
  seed = 456
)

# Check event proportion
n_deaths <- sum(!is.na(death_data$death_date))
n_censored <- sum(is.na(death_data$death_date))
observed_prop <- n_deaths / nrow(death_data)
```

**Results:**

- Deaths observed: 30 out of 100 (30%)
- Censored (no death): 70 (70%)
- Expected: 30% deaths (from `event_prop = 0.3`)

**Sample of first 10 observations (showing NA for censored cases):**

``` r

# Display first 10 rows to show mixture of dates and NA values
head(death_data, 10)
```

       death_date
    1        <NA>
    2        <NA>
    3        <NA>
    4  2003-12-30
    5  2004-04-19
    6        <NA>
    7        <NA>
    8        <NA>
    9        <NA>
    10       <NA>

**Key concepts:**

- **event_prop = 0.3**: 30% of individuals experience the event (get a
  date)
- **Censored observations**: The remaining 70% have `NA` for death_date
  (event not observed)
- **Survival analysis use**: `event_prop` simulates realistic cohort
  data where not everyone experiences the outcome

**When to use event_prop:**

- Death dates in cohort studies
- Disease incidence dates
- Hospital admission dates
- Any time-to-event outcome where censoring occurs

For complete survival data examples with competing risks and multiple
event types, see the [Survival data
tutorial](https://big-life-lab.github.io/MockData/articles/tutorial-survival-data.md).

## Source data format: simulating raw data imports

By default, MockData generates dates as R `Date` objects (analysis-ready
format). However, real survey data comes in different formats depending
on the source. The `sourceFormat` column in variables.csv controls how
dates are generated to simulate different raw data formats.

### Available sourceFormat values

MockData supports three sourceFormat formats specified in the
variables.csv metadata:

**analysis (default)**: R Date objects ready for analysis

**csv**: Character strings in ISO format (YYYY-MM-DD), simulating dates
from CSV files

**sas**: Numeric values (days since 1960-01-01), simulating SAS date
format

### Demonstrating sourceFormat formats

The `sourceFormat` column in variables.csv controls the output format.
Let’s generate the same date variable in all three formats by modifying
the metadata:

``` r

# Format 1: analysis (R Date objects) - DEFAULT
# Variables already has sourceFormat = "analysis" by default
dates_analysis <- create_date_var(
  var = "interview_date",
  databaseStart = "minimal-example",
  variables = variables,
  variable_details = variable_details,
  n = 5,
  seed = 100
)

# Check the class and values
class(dates_analysis$interview_date)
```

    [1] "Date"

``` r

head(dates_analysis$interview_date, 3)
```

    [1] "2005-10-04" "2002-05-18" "2004-10-13"

``` r

# Format 2: csv (character strings)
vars_csv <- variables
vars_csv$sourceFormat <- "csv"

dates_csv <- create_date_var(
  var = "interview_date",
  databaseStart = "minimal-example",
  variables = vars_csv,
  variable_details = variable_details,
  n = 5,
  seed = 100  # Same seed = same underlying dates
)

# Check the class and values
class(dates_csv$interview_date)
```

    [1] "character"

``` r

head(dates_csv$interview_date, 3)
```

    [1] "2005-10-04" "2002-05-18" "2004-10-13"

``` r

# Format 3: sas (numeric days since 1960-01-01)
vars_sas <- variables
vars_sas$sourceFormat <- "sas"

dates_sas <- create_date_var(
  var = "interview_date",
  databaseStart = "minimal-example",
  variables = vars_sas,
  variable_details = variable_details,
  n = 5,
  seed = 100  # Same seed = same underlying dates
)

# Check the class and values
class(dates_sas$interview_date)
```

    [1] "numeric"

``` r

head(dates_sas$interview_date, 3)
```

    [1] 16713 15478 16357

**Key insight:** The same underlying dates are represented in three
different formats. Using the same seed (100) ensures all three formats
contain the same dates, just stored differently.

### Converting between formats

All three formats represent identical dates. You can convert between
them:

``` r

# Convert CSV format (character) to Date
csv_to_date <- as.Date(dates_csv$interview_date)

# Convert SAS format (numeric) to Date
sas_to_date <- as.Date(dates_sas$interview_date, origin = "1960-01-01")

# Verify all represent the same dates
all(csv_to_date == dates_analysis$interview_date)
```

    [1] TRUE

``` r

all(sas_to_date == dates_analysis$interview_date)
```

    [1] TRUE

### Use case: testing harmonization pipelines

The `sourceFormat` metadata column is particularly useful for testing
date parsing and harmonization code. Generate mock data in the format
matching your raw source files:

``` r

# Example: Testing harmonization from CSV source
vars_csv_source <- variables
vars_csv_source$sourceFormat <- "csv"

# Generate mock data in CSV format
mock_csv <- create_mock_data(
  databaseStart = "minimal-example",
  variables = vars_csv_source,
  variable_details = variable_details,
  n = 1000
)

# Test your harmonization logic
library(dplyr)
harmonized <- mock_csv %>%
  mutate(
    # Parse character dates (your harmonization code)
    interview_date = as.Date(interview_date, format = "%Y-%m-%d"),

    # Calculate derived variables
    days_from_start = as.numeric(interview_date - as.Date("2001-01-01"))
  )

# Verify harmonization succeeded
stopifnot(inherits(harmonized$interview_date, "Date"))
stopifnot(all(harmonized$days_from_start >= 0, na.rm = TRUE))
```

### Why this matters

Real survey data doesn’t arrive as clean R Date objects:

- **CSV files**: Dates are character strings that need parsing
- **SAS files**: Dates may be numeric (if haven doesn’t auto-convert)
- **SPSS/Stata files**: Various numeric formats with different epochs

Setting `sourceFormat` in variables.csv lets you generate mock data that
matches your actual raw data format, allowing you to test your entire
harmonization pipeline.

## Data quality for dates

### Future dates

Simulate data entry errors where dates are in the future using
**garbage_high** parameters in variables.csv:

``` r

# Create configuration with future date garbage
birth_config <- data.frame(
  uid = "birth_date_v1",
  variable = "birth_date",
  role = "enabled",
  variableType = "Date",
  rType = "date",
  position = 1,
  garbage_high_prop = 0.02,
  garbage_high_range = "[2026-01-01,2030-12-31]",
  stringsAsFactors = FALSE
)

birth_details <- data.frame(
  uid = "birth_date_v1",
  uid_detail = "birth_date_v1_d1",
  variable = "birth_date",
  recStart = "[1950-01-01,2010-12-31]",
  catLabel = "Valid birth dates",
  stringsAsFactors = FALSE
)

# Write to temporary files
temp_dir <- tempdir()
birth_config_path <- file.path(temp_dir, "birth_config.csv")
birth_details_path <- file.path(temp_dir, "birth_details.csv")
write.csv(birth_config, birth_config_path, row.names = FALSE)
write.csv(birth_details, birth_details_path, row.names = FALSE)

# Generate birth dates with future date garbage
birth_data <- create_mock_data(
  databaseStart = "tutorial",
  variables = birth_config_path,
  variable_details = birth_details_path,
  n = 1000,
  seed = 789
)

# Check for future dates (after 2025)
future_threshold <- as.Date("2025-12-31")
n_future <- sum(birth_data$birth_date > future_threshold, na.rm = TRUE)
prop_future <- n_future / nrow(birth_data)
future_dates_sample <- head(sort(birth_data$birth_date[birth_data$birth_date > future_threshold]), 5)
```

**Result:** 20 birth dates (2%) are in the future (after 2025-12-31),
which is impossible for current data. Sample of future dates:
2026-01-12, 2026-04-06, 2026-05-14, 2026-05-14, 2026-06-01.

**Key insight:** Garbage data is now specified at the **variable level**
in variables.csv, not in variable_details.csv.

### Past dates (temporal violations)

Simulate impossibly old dates using **garbage_low** parameters:

``` r

# Create configuration with old date garbage
diag_config <- data.frame(
  uid = "diagnosis_date_v1",
  variable = "diagnosis_date",
  role = "enabled",
  variableType = "Date",
  rType = "date",
  position = 1,
  garbage_low_prop = 0.03,
  garbage_low_range = "[1850-01-01,1900-12-31]",
  stringsAsFactors = FALSE
)

diag_details <- data.frame(
  uid = "diagnosis_date_v1",
  uid_detail = "diagnosis_date_v1_d1",
  variable = "diagnosis_date",
  recStart = "[2000-01-01,2020-12-31]",
  catLabel = "Valid diagnosis dates",
  stringsAsFactors = FALSE
)

# Write to temporary files
temp_dir <- tempdir()
diag_config_path <- file.path(temp_dir, "diag_config.csv")
diag_details_path <- file.path(temp_dir, "diag_details.csv")
write.csv(diag_config, diag_config_path, row.names = FALSE)
write.csv(diag_details, diag_details_path, row.names = FALSE)

# Generate diagnosis dates with old date garbage
diag_data <- create_mock_data(
  databaseStart = "tutorial",
  variables = diag_config_path,
  variable_details = diag_details_path,
  n = 1000,
  seed = 456
)

# Check for impossibly old dates (before 1950)
old_threshold <- as.Date("1950-01-01")
n_old <- sum(diag_data$diagnosis_date < old_threshold, na.rm = TRUE)
prop_old <- n_old / nrow(diag_data)
old_dates_sample <- head(sort(diag_data$diagnosis_date[diag_data$diagnosis_date < old_threshold]), 5)
```

**Result:** 30 diagnosis dates (3%) are from before 1950-01-01
(1850-1900 range), which is unrealistic for modern medical data. Sample
of old dates: 1850-05-18, 1853-03-07, 1854-09-07, 1855-05-01,
1860-06-13.

### Use cases for garbage dates

- **Testing validation pipelines:** Ensure your code catches impossible
  dates
- **Training analysts:** Show examples of real-world data quality issues
- **Data cleaning scripts:** Test date range checks and filtering logic

**Note:** For complete examples of garbage date generation integrated
into metadata files, see the [minimal-example configuration
files](https://github.com/Big-Life-Lab/mockData/tree/main/inst/extdata/minimal-example).

## Checking generated dates

After generating dates, validate the results:

``` r

# Check interview date range
interview_dates <- as.Date(interview_data$interview_date)

# Calculate summary statistics
date_min <- min(interview_dates, na.rm = TRUE)
date_max <- max(interview_dates, na.rm = TRUE)
n_missing <- sum(is.na(interview_dates))

# Validate dates are within expected range (from metadata)
expected_min <- as.Date("2001-01-01")
expected_max <- as.Date("2005-12-31")
all_valid <- all(interview_dates >= expected_min &
                 interview_dates <= expected_max,
                 na.rm = TRUE)
```

**Validation results:**

- Date range: 2001-01-09 to 2005-10-24
- Missing dates: 0
- All dates within expected range (2001-01-01 to 2005-12-31): TRUE

This validation confirms the generated dates match the metadata
specifications.

## Key concepts summary

| Concept | Implementation | Details |
|----|----|----|
| **Date ranges** | Interval notation in `recStart` | `[2001-01-01,2005-12-31]` format (ISO dates) |
| **Distributions** | Uniform, Gompertz, Exponential | Specified in `distribution` column of variables.csv |
| **Event proportions** | `event_prop` column in variables.csv | Controls % experiencing event vs. censored (NA) |
| **Garbage dates** | `garbage_low_prop/range`, `garbage_high_prop/range` | Specified in variables.csv for data quality testing |
| **Validation** | Check ranges and distributions | Use [`summary()`](https://rdrr.io/r/base/summary.html), [`min()`](https://rdrr.io/r/base/Extremes.html), [`max()`](https://rdrr.io/r/base/Extremes.html) after generation |
| **Source formats** | `sourceFormat` column in variables.csv | Values: “csv” (character), “sas” (numeric), “analysis” (Date) |

## What you learned

In this tutorial, you learned:

- **Date configuration basics:** How to specify date ranges using
  interval notation in variable_details.csv
- **Single variable generation:** Using
  [`create_date_var()`](https://big-life-lab.github.io/MockData/reference/create_date_var.md)
  for interactive development and testing
- **Distribution options:** Uniform, Gompertz, and exponential
  distributions for realistic temporal patterns
- **Distribution selection:** When to use each distribution type for
  different use cases
- **Event proportions:** Using `event_prop` to control the proportion of
  individuals experiencing events versus being censored
- **Source data formats:** Using the `sourceFormat` metadata column to
  simulate different raw data formats (csv, sas, analysis)
- **Format conversion:** How the same dates can be represented in
  different formats for harmonization testing
- **Data quality testing:** Generating corrupt future/past dates using
  `garbage_low` and `garbage_high` parameters for validation pipeline
  testing
- **Validation:** Checking generated dates are within expected ranges
  and match metadata specifications

## Next steps

**Tutorials:**

- [Missing
  data](https://big-life-lab.github.io/MockData/articles/tutorial-missing-data.md) -
  Survey missing data codes and patterns
- [Garbage
  data](https://big-life-lab.github.io/MockData/articles/tutorial-garbage-data.md) -
  Comprehensive data quality testing
- [Getting
  started](https://big-life-lab.github.io/MockData/articles/getting-started.md) -
  Review MockData fundamentals

**Reference:**

- [Configuration
  reference](https://big-life-lab.github.io/MockData/articles/reference-config.md) -
  Complete metadata schema specification
- [Advanced
  topics](https://big-life-lab.github.io/MockData/articles/advanced-topics.md) -
  Technical details on distributions and workflows
