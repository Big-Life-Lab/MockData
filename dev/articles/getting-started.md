# Getting started with MockData

> **About this vignette**
>
> This introductory tutorial teaches core MockData concepts through
> progressive examples. All code runs during vignette build to ensure
> accuracy. The generated data are for testing and development only—not
> for modelling or analysis.

## What is MockData?

MockData generates metadata-driven mock datasets for testing and
developing harmonisation workflows. Mock data are created solely from
variable specifications and contain **no real person-level data** or
identifiable information.

### Key purposes

- **Testing harmonisation code** (cchsflow, chmsflow) without access to
  real survey data
- **Developing data pipelines** with realistic variable structures
  before data access
- **Training and education** with representative but non-sensitive data
- **Validating data processing** workflows with controlled test inputs

### What mock data are (and are not)

MockData reads recodeflow metadata files (`variables.csv`,
`variable-details.csv`) to generate data that mimics the variable
structure of health survey datasets like CCHS and CHMS. The data have
appropriate types, value ranges, and category labels—but **no real-world
statistical relationships**.

**Limitations**: While variable types and ranges match the metadata,
joint distributions and correlations may differ significantly from
real-world data. Mock data should never be used for population
inference, epidemiological modelling, or research publication.

## Your first mock dataset

This tutorial walks you through generating a simple mock dataset with
both categorical and continuous variables.

### Setup

``` r
library(dplyr)
```

### Step 1: Prepare metadata

MockData uses two metadata tables:

1.  **variables**: defines which variables exist in each database cycle
2.  **variable_details**: defines categories, ranges, and recode rules

For this tutorial, we’ll use a simple example with two variables:
smoking status (categorical) and age (continuous) .

``` r
# Define variables table
variables <- data.frame(
  variable = c("smoking", "smoking", "age", "age"),
  variableStart = c("SMK_01", "SMK_01", "AGE_01", "AGE_01"),
  databaseStart = c("cycle1", "cycle2", "cycle1", "cycle2"),
  databaseEnd = c("cycle1", "cycle2", "cycle1", "cycle2"),
  variableType = c("categorical", "categorical", "continuous", "continuous")
)

# Define variable details (categories and ranges)
variable_details <- data.frame(
  variable = c("smoking", "smoking", "smoking",
               "smoking", "smoking", "smoking", "smoking",
               "age", "age", "age"),
  recStart = c("1", "2", "3", "996", "997", "998", "999",
               "[18, 100]", "996", "[997, 999]"),
  recEnd = c("1", "2", "3", "996", "997", "998", "999",
             "copy", "NA::a", "NA::b"),
  catLabel = c("Daily smoker", "Occasional smoker", "Never smoked",
               "Not applicable", "Don't know", "Refusal", "Not stated",
               "Age in years", "Not applicable", "Missing"),
  variableStart = c("SMK_01", "SMK_01", "SMK_01", "SMK_01", "SMK_01", "SMK_01", "SMK_01",
                    "AGE_01", "AGE_01", "AGE_01"),
  databaseStart = c("cycle1", "cycle1", "cycle1", "cycle1", "cycle1", "cycle1", "cycle1",
                    "cycle1", "cycle1", "cycle1"),
  rType = c("factor", "factor", "factor", "factor", "factor", "factor", "factor",
            "integer", "integer", "integer")
)
```

**Variables table** (4 rows):

| variable | variableStart | databaseStart | databaseEnd | variableType |
|:---------|:--------------|:--------------|:------------|:-------------|
| smoking  | SMK_01        | cycle1        | cycle1      | categorical  |
| smoking  | SMK_01        | cycle2        | cycle2      | categorical  |
| age      | AGE_01        | cycle1        | cycle1      | continuous   |
| age      | AGE_01        | cycle2        | cycle2      | continuous   |

**Variable details table** (10 rows):

| variable | recStart     | recEnd | catLabel          | variableStart | databaseStart | rType   |
|:---------|:-------------|:-------|:------------------|:--------------|:--------------|:--------|
| smoking  | 1            | 1      | Daily smoker      | SMK_01        | cycle1        | factor  |
| smoking  | 2            | 2      | Occasional smoker | SMK_01        | cycle1        | factor  |
| smoking  | 3            | 3      | Never smoked      | SMK_01        | cycle1        | factor  |
| smoking  | 996          | 996    | Not applicable    | SMK_01        | cycle1        | factor  |
| smoking  | 997          | 997    | Don’t know        | SMK_01        | cycle1        | factor  |
| smoking  | 998          | 998    | Refusal           | SMK_01        | cycle1        | factor  |
| smoking  | 999          | 999    | Not stated        | SMK_01        | cycle1        | factor  |
| age      | \[18, 100\]  | copy   | Age in years      | AGE_01        | cycle1        | integer |
| age      | 996          | NA::a  | Not applicable    | AGE_01        | cycle1        | integer |
| age      | \[997, 999\] | NA::b  | Missing           | AGE_01        | cycle1        | integer |

### Step 2: Generate a categorical variable with custom proportions

Real survey data has different types of missing values. Use the
`proportions` parameter to explicitly specify the distribution for all
categories, including missing codes:

``` r
# Create mock data frame
df_mock <- data.frame(id = 1:1000)

# Generate smoking variable with explicit proportions for ALL categories
smoking_col <- create_cat_var(
  var_raw = "SMK_01",
  cycle = "cycle1",
  variable_details = variable_details,
  variables = variables,
  length = 1000,
  df_mock = df_mock,
  proportions = list(
    "1" = 0.30,   # Daily smoker
    "2" = 0.50,   # Occasional smoker
    "3" = 0.15,   # Never smoked
    "996" = 0.01, # Not applicable (valid skip)
    "997" = 0.01, # Don't know
    "998" = 0.02, # Refusal
    "999" = 0.01  # Not stated
  )
)

# Add to data frame
df_mock <- cbind(df_mock, smoking_col)

# View distribution
table(df_mock$SMK_01)
```

      1   2   3 996 997 998 999
    312 472 156   7  13  32   8 

**What happened:**

- MockData extracted all 7 categories from variable_details (1, 2, 3,
  996, 997, 998, 999)
- Generated 1000 random values distributed according to the specified
  proportions
- The `proportions` parameter gives you full control over the
  distribution, including missing data codes
- Categories 1-3 are valid responses, while 996-999 are different types
  of missing data

For further discussion on making mock missing data see [Missing data in
health
surveys](https://big-life-lab.github.io/MockData/articles/missing-data.md).

### Step 3: Generate continuous variable

Use
[`create_con_var()`](https://big-life-lab.github.io/MockData/reference/create_con_var.md)
to generate continuous variables like age.

``` r
# Generate age variable
age_col <- create_con_var(
  var_raw = "AGE_01",
  cycle = "cycle1",
  variable_details = variable_details,
  variables = variables,
  length = 100,
  df_mock = df_mock,
  distribution = "uniform"  # Uniform distribution within range [18, 100]
)

# Add to data frame
df_mock <- cbind(df_mock, age_col)

# View results
head(df_mock, 10)
```

       id SMK_01 AGE_01
    1   1      3     38
    2   2      1     77
    3   3      2     52
    4   4      2     40
    5   5      2     94
    6   6      1     38
    7   7      1     59
    8   8      3     59
    9   9      2     70
    10 10      2     69

``` r
summary(df_mock$AGE_01)
```

       Min. 1st Qu.  Median    Mean 3rd Qu.    Max.
      18.00   40.00   63.50   60.93   79.25   99.00 

**What happened:**

- MockData extracted the range from variable_details \[18, 100\]
- Generated 100 random ages uniformly distributed between 18 and 100
- Returned a single-column data frame that we added to df_mock

### Step 4: Working with configuration files

For larger projects, MockData supports batch generation using
configuration CSV files instead of inline data frames. This makes it
easier to generate many variables at once.

``` r
# Read configuration files (not run in this tutorial)
config <- read_mock_data_config("mock_data_config.csv")
details <- read_mock_data_config_details("mock_data_config_details.csv")

# Generate all variables in one call
mock_data <- create_mock_data(
  config = config,
  details = details,
  n = 1000,
  seed = 123
)
```

**Why use config files:**

- Generate dozens of variables in a single call
- Easier to maintain and version control metadata
- Consistent with recodeflow harmonization workflows
- Supports advanced features like derived variables and garbage data

See [CCHS
example](https://big-life-lab.github.io/MockData/articles/cchs-example.md),
[CHMS
example](https://big-life-lab.github.io/MockData/articles/chms-example.md),
and [DemPoRT
example](https://big-life-lab.github.io/MockData/articles/demport-example.md)
for real-world configuration file usage.

### Step 5: Control reproducibility with seeds

Use seeds to generate the same mock data every time.

``` r
# Set seed for reproducibility
set.seed(12345)

df_mock <- data.frame(id = 1:100)

result1 <- create_cat_var(
  var_raw = "SMK_01",
  cycle = "cycle1",
  variable_details = variable_details,
  variables = variables,
  length = 100,
  df_mock = df_mock
)

# Reset seed
set.seed(12345)

df_mock <- data.frame(id = 1:100)

result2 <- create_cat_var(
  var_raw = "SMK_01",
  cycle = "cycle1",
  variable_details = variable_details,
  variables = variables,
  length = 100,
  df_mock = df_mock
)

# Verify identical
identical(result1$SMK_01, result2$SMK_01)
```

    [1] TRUE

**Result:** TRUE - same seed produces identical mock data

### Step 6: Working with derived variables

MockData generates **raw variables** (direct survey measurements).
Derived variables should be calculated from the generated data using
harmonization workflows.

**Conceptual workflow:**

``` r
# 1. Generate mock raw variables
mock_data <- create_mock_data(
  config = config,        # Includes height_raw, weight_raw
  details = details,
  n = 1000
)

# 2. Apply harmonization to create derived variables
# (Requires cchsflow or recodeflow package)
# library(cchsflow)
# mock_data <- rec_with_table(
#   data = mock_data,
#   variables = variables,
#   variable_details = variable_details,
#   database_name = "cchs2001"
# )
# Now mock_data includes derived variables like BMI_der, age categories, etc.
```

**Why this approach:**

- Mirrors real data processing (derived variables computed during
  harmonization)
- Allows testing harmonization logic with mock data
- Keeps raw and derived variables separate
- Tests the complete workflow: generate → harmonize → analyze

**Common derived variables:**

- BMI categories from height and weight
- Age categories from continuous age
- Income quintiles from income
- Health risk scores from multiple indicators

See [CCHS
example](https://big-life-lab.github.io/MockData/articles/cchs-example.md)
and [DemPoRT
example](https://big-life-lab.github.io/MockData/articles/demport-example.md)
for complete workflows with derived variables.

## What you learned

In this tutorial, you learned:

- How to prepare metadata (variables and variable_details tables)
- How to specify custom proportions for all categories including missing
  codes
- The critical difference between valid skip (996) and other missing
  codes (997-999)
- How to calculate prevalence correctly by handling missing codes
  appropriately
- How to generate continuous variables with
  [`create_con_var()`](https://big-life-lab.github.io/MockData/reference/create_con_var.md)
- How configuration files enable batch generation for larger projects
- How to ensure reproducibility with seeds
- How to work with derived variables through harmonization workflows

## Next steps

**Core topics:**

- [Missing
  data](https://big-life-lab.github.io/MockData/articles/missing-data.md) -
  Realistic missing data patterns in health surveys
- [Date
  variables](https://big-life-lab.github.io/MockData/articles/dates.md) -
  Working with dates and survival times
- [Configuration
  files](https://big-life-lab.github.io/MockData/articles/cchs-example.html#configuration-format) -
  Batch generation approach

**Database-specific examples:**

- [CCHS
  example](https://big-life-lab.github.io/MockData/articles/cchs-example.md) -
  Canadian Community Health Survey
- [CHMS
  example](https://big-life-lab.github.io/MockData/articles/chms-example.md) -
  Canadian Health Measures Survey
- [DemPoRT
  example](https://big-life-lab.github.io/MockData/articles/demport-example.md) -
  Dementia Population Risk Tool

**Advanced topics:**

- [Garbage
  data](https://big-life-lab.github.io/MockData/articles/cchs-example.html#garbage-data) -
  Simulating data quality issues
- [Advanced
  topics](https://big-life-lab.github.io/MockData/articles/advanced-topics.md) -
  Technical details and performance
