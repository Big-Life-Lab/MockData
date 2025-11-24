# MockData for recodeflow users

**About this vignette:** This tutorial is for users who already have
recodeflow metadata files (`variables.csv` and `variable_details.csv`).
If you’re new to MockData, start with [Getting
started](https://big-life-lab.github.io/MockData/articles/getting-started.md)
instead.

## Quick start

If you already have recodeflow metadata files, you’re one function call
away from generating mock data:

``` r
library(MockData)

# Point MockData at your existing metadata files
mock_data <- create_mock_data(
  databaseStart = "cchs2001",  # Your database identifier
  variables = "path/to/variables.csv",
  variable_details = "path/to/variable_details.csv",
  n = 1000,
  seed = 123
)

head(mock_data)
```

That’s it. MockData reads your existing metadata and generates mock data
that matches your variable specifications.

## What MockData reads from your files

MockData uses the same metadata files as cchsflow and chmsflow. No
duplicate specifications needed.

### From variables.csv

MockData reads:

- `variable`: Variable name in the generated dataset
- `rType`: R data type (factor, character, integer, double, date)
- `role`: Filters for enabled variables only
- `distribution`: Distribution type (uniform, normal, exponential,
  gompertz) for continuous/date variables
- `mean`, `sd`, `rate`, `shape`: Distribution parameters
- `event_prop`, `followup_min`, `followup_max`: Survival data parameters
- `prop_garbage`, `garbage_low_prop`, `garbage_high_prop`: Data quality
  testing parameters

**Example:**

| variable | rType   | role                     | distribution |
|:---------|:--------|:-------------------------|:-------------|
| age      | integer | enabled,predictor,table1 | normal       |
| smoking  | factor  | enabled,predictor,table1 |              |
| BMI      | double  | enabled,outcome,table1   | normal       |
| height   | double  | enabled,predictor        | normal       |
| weight   | double  | enabled,predictor        | normal       |

### From variable_details.csv

MockData reads:

- `recStart`: Category codes or value ranges using interval notation
  (e.g., `[18,100]` for continuous, `[2001-01-01,2005-12-31]` for dates)
- `recEnd`: Classification (`copy`, `NA::a`, `NA::b`)
- `catLabel`: Category labels
- `proportion`: Category proportions (optional)

**Example:**

|     | variable | recStart | recEnd | catLabel       | proportion |
|:----|:---------|:---------|:-------|:---------------|-----------:|
| 5   | smoking  | 1        | 1      | Never smoker   |       0.50 |
| 6   | smoking  | 2        | 2      | Former smoker  |       0.30 |
| 7   | smoking  | 3        | 3      | Current smoker |       0.17 |
| 8   | smoking  | 7        | NA::b  | Don’t know     |       0.03 |

## The databaseStart parameter

The `databaseStart` parameter tells MockData which database/cycle to
generate data for. This is the same identifier you use in recodeflow
workflows.

``` r
# Generate data for CCHS 2001
mock_cchs2001 <- create_mock_data(
  databaseStart = "cchs2001_p",  # Match your database identifier
  variables = "variables.csv",
  variable_details = "variable_details.csv",
  n = 1000
)

# Generate data for CHMS Cycle 1
mock_chms1 <- create_mock_data(
  databaseStart = "cycle1",  # Match your database identifier
  variables = "variables.csv",
  variable_details = "variable_details.csv",
  n = 1000
)
```

MockData filters `variable_details.csv` to only generate variables where
the `databaseStart` column matches your specified database.

## Working example with minimal-example metadata

Let’s generate mock data using the minimal-example metadata included
with MockData:

``` r
# Load recodeflow-compatible metadata
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

# Generate mock data
mock_data <- create_mock_data(
  databaseStart = "minimal-example",
  variables = variables,
  variable_details = variable_details,
  n = 100,
  seed = 456
)

# View structure
cat("Generated", nrow(mock_data), "observations across", ncol(mock_data), "variables\n\n")
```

    Generated 100 observations across 5 variables

**View sample data:**

      age smoking    height    weight interview_date
    1  30       1 0.5259396  52.05418     2004-08-20
    2  59       1 1.2789355 104.37787     2001-12-09
    3  62       2 0.2535377  87.96214     2003-07-30
    4  29       1 0.3669026  65.09685     2002-03-22
    5  39       2 0.6075947  89.62049     2004-03-26
    6  45       1 1.2702433  88.92887     2005-07-24

## Common workflows

### Testing harmonisation code

Use mock data to test cchsflow or chmsflow harmonisation before
accessing real data:

``` r
library(cchsflow)

# 1. Generate mock raw data
mock_raw <- create_mock_data(
  databaseStart = "cchs2001_p",
  variables = "variables.csv",
  variable_details = "variable_details.csv",
  n = 1000
)

# 2. Apply harmonisation
mock_harmonised <- rec_with_table(
  data = mock_raw,
  variables = variables,
  variable_details = variable_details,
  databaseStart = "cchs2001_p"
)

# 3. Test your analysis code
mock_harmonised %>%
  filter(age_der >= 65) %>%
  summarise(prevalence_bmi_obesity = mean(bmi_der_cat == "Obese", na.rm = TRUE))
```

### Developing analysis scripts

Write and debug analysis scripts before data access:

``` r
library(dplyr)

# Generate mock data
mock_data <- create_mock_data(
  databaseStart = "cchs2001_p",
  variables = "variables.csv",
  variable_details = "variable_details.csv",
  n = 5000,
  seed = 789
)

# Develop analysis pipeline
results <- mock_data %>%
  filter(!is.na(age), !is.na(smoking)) %>%
  group_by(smoking) %>%
  summarise(
    n = n(),
    mean_age = mean(age),
    sd_age = sd(age)
  )

# Test visualisations
ggplot(mock_data, aes(x = age, fill = smoking)) +
  geom_density(alpha = 0.5) +
  labs(title = "Age distribution by smoking status (MOCK DATA)")
```

### Training new team members

Generate safe, non-sensitive data for training:

``` r
# Generate training dataset
training_data <- create_mock_data(
  databaseStart = "cchs2001_p",
  variables = "variables.csv",
  variable_details = "variable_details.csv",
  n = 500,
  seed = 111
)

# Save for training exercises
write.csv(training_data, "training_cchs_mock.csv", row.names = FALSE)
```

## Advanced features

### Specifying category proportions

Add a `proportion` column to `variable_details.csv` to control category
distributions:

``` csv
variable,recStart,recEnd,catLabel,proportion
smoking,1,1,Never,0.50
smoking,2,2,Former,0.30
smoking,3,3,Current,0.20
```

Without proportions, MockData generates equal probabilities for all
categories.

### Survival data and custom distributions

Advanced features are specified directly in `variables.csv` using
additional columns:

**Survival data parameters:**

- `event_prop`: Probability event occurs (0-1)
- `followup_min`, `followup_max`: Follow-up time range in days
- `distribution`: Distribution type (uniform, gompertz, exponential)
- `rate`, `shape`: Distribution parameters

**Example:**

``` csv
uid,variable,rType,role,distribution,rate,shape,event_prop,followup_min,followup_max
ices_v02,primary_event_date,date,enabled,gompertz,0.0001,0.1,0.10,0,5475
ices_v03,death_date,date,enabled,gompertz,0.0001,0.1,0.20,365,7300
```

See [Generating survival data with competing
risks](https://big-life-lab.github.io/MockData/articles/tutorial-survival-data.md)
for details.

### Data quality testing

Add garbage data for testing validation pipelines using these
`variables.csv` columns:

- `prop_garbage`: Simple auto-generated garbage proportion
- `garbage_low_prop`, `garbage_low_range`: Below-range invalid values
- `garbage_high_prop`, `garbage_high_range`: Above-range invalid values

See [Testing data quality and
validation](https://big-life-lab.github.io/MockData/articles/tutorial-garbage-data.md)
for details.

## Differences from real data

**Important limitations:**

MockData generates data that matches your metadata specifications but
**does not preserve real-world statistical relationships**:

- Variables are generated independently
- No correlations between variables (e.g., age and health status)
- Joint distributions may differ from actual survey data
- Temporal patterns are simplified

**Never use mock data for:**

- Research publications
- Population inference
- Predictive modelling
- Algorithm training

**Safe uses:**

- Testing harmonisation workflows
- Developing analysis scripts
- Training team members
- Creating documentation examples

## Next steps

**Tutorials:**

- [Getting
  started](https://big-life-lab.github.io/MockData/articles/getting-started.md) -
  Learn MockData basics
- [Generating survival data with competing
  risks](https://big-life-lab.github.io/MockData/articles/tutorial-survival-data.md) -
  Time-to-event data with custom distributions
- [Working with date
  variables](https://big-life-lab.github.io/MockData/articles/tutorial-dates.md) -
  Date generation and interval notation
- [Testing data quality and
  validation](https://big-life-lab.github.io/MockData/articles/tutorial-garbage-data.md) -
  Generating garbage data for QA
- [Handling missing
  data](https://big-life-lab.github.io/MockData/articles/tutorial-missing-data.md) -
  Missing codes and proportions

**Reference:**

- [Configuration
  reference](https://big-life-lab.github.io/MockData/articles/reference-config.md) -
  Complete metadata schema documentation
- [Advanced
  topics](https://big-life-lab.github.io/MockData/articles/advanced-topics.md) -
  Derived variables, UIDs, multi-database workflows
