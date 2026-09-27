# Getting started with MockData

**About this vignette:** This tutorial teaches MockData through
progressive examples, starting with single variables and building to
complete datasets. All code runs during vignette build to ensure
accuracy.

## Overview

MockData generates fake data from variable specifications, such as what
is published in a “*Table 1 - Description of study data*”. This tutorial
shows three approaches, from simplest to most powerful. All approaches
build from the recodeflow approach of using two “worksheets” to describe
variables used in your project: `variables.csv` (or data frame) and
`variable_details.csv`:

1.  Generate a single variable using the worksheets and manually
    defining the mock data specifications
2.  Generate the same variable using mock data configuration added to
    the worksheets
3.  Generate a complete dataset from configuration files

## Approach 1: Single variable with inline specifications

Let’s generate a smoking status variable with three categories:

``` r

# Create variables data frame with variable-level metadata
variables <- data.frame(
  variable = "smoking",
  label = "Smoking status",
  variableType = "Categorical",
  role = "enabled",  # Required: tells MockData to generate this variable
  stringsAsFactors = FALSE
)

# Create variable_details data frame with category definitions
variable_details <- data.frame(
  variable = c("smoking", "smoking", "smoking"),
  recStart = c("1", "2", "3"),
  catLabel = c("Never", "Former", "Current"),
  proportion = c(0.5, 0.3, 0.2), ### make mock data with these proportions! ###
  stringsAsFactors = FALSE
)

# Generate smoking variable
smoking_data <- create_cat_var(
  var = "smoking",
  databaseStart = "tutorial",
  variables = variables,
  variable_details = variable_details,
  df_mock = data.frame(),
  n = 100, # how many rows
  seed = 123 # to ensure the mock data is reproducible
)

# View results
head(smoking_data)
```

      smoking
    1       1
    2       2
    3       1
    4       3
    5       3
    6       1

``` r

table(smoking_data$smoking)
```


     1  2  3
    53 29 18 

**What happened:**

- We started with standard `recodeflow` worksheets, but we added
  `proportion`
- Called
  [`create_cat_var()`](https://big-life-lab.github.io/MockData/reference/create_cat_var.md)
  to generate 100 random smoking values
- Values are distributed according to specified proportions (50%, 30%,
  20%)
- Used a seed for reproducibility

**Limitations of this approach:**

- “proportions” are hardcoded in your script
- Difficult to maintain for multiple variables
- Better to add mock data configurations to `variables` and
  `variable_details` for anything beyond simple examples

## Approach 2: Same variable using metadata files

Instead of hardcoding metadata, we can read it from CSV files. This
makes it easier to specify proportions and maintain consistency:

> **About example data paths**
>
> These examples use
> [`system.file()`](https://rdrr.io/r/base/system.file.html) to load
> example metadata included with the MockData package. In your own
> projects, you’ll use regular file paths:
>
> ``` r
>
> # Package examples use:
> variables <- read.csv(
>   system.file("extdata/minimal-example/variables.csv", package = "MockData"),
>   stringsAsFactors = FALSE, check.names = FALSE
> )
>
> # Your code will use:
> variables <- read.csv(
>   "path/to/your/variables.csv",
>   stringsAsFactors = FALSE, check.names = FALSE
> )
> ```

``` r

# Read metadata from files
config_path <- system.file("extdata/minimal-example/variables.csv", package = "MockData")
details_path <- system.file("extdata/minimal-example/variable_details.csv", package = "MockData")

# Load the metadata
variables_from_file <- read.csv(config_path, stringsAsFactors = FALSE, check.names = FALSE)
details_from_file <- read.csv(details_path, stringsAsFactors = FALSE, check.names = FALSE)

# View the smoking variable specification
smoking_details <- details_from_file[details_from_file$variable == "smoking",
                                      c("uid_detail", "variable", "recStart", "catLabel", "proportion")]
print(smoking_details, row.names = FALSE)
```

          uid_detail variable recStart       catLabel proportion
     cchsflow_d00005  smoking        1   Never smoker       0.50
     cchsflow_d00006  smoking        2  Former smoker       0.30
     cchsflow_d00007  smoking        3 Current smoker       0.17
     cchsflow_d00008  smoking        7     Don't know       0.03

Notice how the metadata file includes proportions:

- Never smoker (code 1): 50%
- Former smoker (code 2): 30%
- Current smoker (code 3): 17%
- Don’t know (code 7): 3%

``` r

# Generate using metadata files (pass full data frames)
smoking_data_v2 <- create_cat_var(
  var = "smoking",
  databaseStart = "tutorial",
  variables = variables_from_file,
  variable_details = details_from_file,
  df_mock = data.frame(),
  n = 1000,
  seed = 456
)

# View distribution
table(smoking_data_v2$smoking)
```


      1   2   3   7
    466 309 195  30 

``` r

# View proportions
round(prop.table(table(smoking_data_v2$smoking)), 2)
```


       1    2    3    7
    0.47 0.31 0.20 0.03 

**What improved:**

- Metadata lives in CSV files (easy to edit, version control)
- Proportions specified in metadata (50%, 30%, 17%, 3%)
- Same function call, but reads specifications from files
- Generated distribution matches specified proportions

## Approach 3: Complete dataset from metadata

The most powerful approach: generate multiple variables in a single call
using
[`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md):

``` r

# Generate complete dataset
mock_data <- create_mock_data(
  databaseStart = "minimal-example",
  variables = system.file("extdata/minimal-example/variables.csv", package = "MockData"),
  variable_details = system.file("extdata/minimal-example/variable_details.csv", package = "MockData"),
  n = 100,
  seed = 789
)

# View dataset structure
str(mock_data)
```

    'data.frame':   100 obs. of  10 variables:
     $ age               : int  53 49 55 54 27 35 48 38 57 33 ...
     $ smoking           : Factor w/ 4 levels "1","2","3","7": 1 1 2 1 3 1 1 1 1 1 ...
     $ BMI               : num  37.3 26.8 998 31.9 996 ...
     $ height            : num  1.69 1.82 1.83 1.72 1.79 ...
     $ weight            : num  65.9 83.2 93.9 69.4 73.4 ...
     $ interview_date    : Date, format: "2005-12-22" "2004-03-09" ...
     $ death_date        : Date, format: "2006-12-22" NA ...
     $ ltfu_date         : Date, format: NA NA ...
     $ admin_censor_date : Date, format: "2007-01-27" "2014-02-10" ...
     $ primary_event_date: Date, format: "2006-03-08" NA ...
     - attr(*, "mockdata_diagnostics")=List of 2
      ..$ spec_version: chr "0.4.0"
      ..$ variables   :List of 10
      .. ..$ age               :List of 6
      .. .. ..$ n                               : int 100
      .. .. ..$ preexisting_missing_code_indices: int(0)
      .. .. ..$ assigned_missing_indices        : int [1:10] 38 33 87 57 96 36 27 50 41 19
      .. .. ..$ assigned_missing_codes          : chr [1:10] "997" "997" "997" "997" ...
      .. .. ..$ assigned_garbage_indices        : Named list()
      .. .. ..$ assigned_garbage_values         : Named list()
      .. ..$ smoking           :List of 6
      .. .. ..$ n                               : int 100
      .. .. ..$ preexisting_missing_code_indices: int(0)
      .. .. ..$ assigned_missing_indices        : int [1:3] 16 72 78
      .. .. ..$ assigned_missing_codes          : chr [1:3] "7" "7" "7"
      .. .. ..$ assigned_garbage_indices        : Named list()
      .. .. ..$ assigned_garbage_values         : Named list()
      .. ..$ BMI               :List of 6
      .. .. ..$ n                               : int 100
      .. .. ..$ preexisting_missing_code_indices: int(0)
      .. .. ..$ assigned_missing_indices        : int [1:39] 5 91 57 54 88 76 65 67 49 90 ...
      .. .. ..$ assigned_missing_codes          : chr [1:39] "996" "996" "996" "996" ...
      .. .. ..$ assigned_garbage_indices        :List of 2
      .. .. .. ..$ low : int 39
      .. .. .. ..$ high: int 32
      .. .. ..$ assigned_garbage_values         :List of 2
      .. .. .. ..$ low : num 12
      .. .. .. ..$ high: num 114
      .. ..$ height            :List of 6
      .. .. ..$ n                               : int 100
      .. .. ..$ preexisting_missing_code_indices: int(0)
      .. .. ..$ assigned_missing_indices        : int(0)
      .. .. ..$ assigned_missing_codes          : chr(0)
      .. .. ..$ assigned_garbage_indices        :List of 2
      .. .. .. ..$ low : int 93
      .. .. .. ..$ high: int 6
      .. .. ..$ assigned_garbage_values         :List of 2
      .. .. .. ..$ low : num 0.643
      .. .. .. ..$ high: num 2.42
      .. ..$ weight            :List of 6
      .. .. ..$ n                               : int 100
      .. .. ..$ preexisting_missing_code_indices: int(0)
      .. .. ..$ assigned_missing_indices        : int(0)
      .. .. ..$ assigned_missing_codes          : chr(0)
      .. .. ..$ assigned_garbage_indices        : Named list()
      .. .. ..$ assigned_garbage_values         : Named list()
      .. ..$ interview_date    :List of 6
      .. .. ..$ n                               : int 100
      .. .. ..$ preexisting_missing_code_indices: int(0)
      .. .. ..$ assigned_missing_indices        : int(0)
      .. .. ..$ assigned_missing_codes          : chr(0)
      .. .. ..$ assigned_garbage_indices        : Named list()
      .. .. ..$ assigned_garbage_values         : Named list()
      .. ..$ primary_event_date:List of 11
      .. .. ..$ n                               : int 100
      .. .. ..$ preexisting_missing_code_indices: int(0)
      .. .. ..$ assigned_missing_indices        : int(0)
      .. .. ..$ assigned_missing_codes          : chr(0)
      .. .. ..$ assigned_garbage_indices        :List of 1
      .. .. .. ..$ high: int 71
      .. .. ..$ assigned_garbage_values         :List of 1
      .. .. .. ..$ high: Date[1:1], format: "2095-12-02"
      .. .. ..$ derived                         : logi TRUE
      .. .. ..$ anchor                          : chr "interview_date"
      .. .. ..$ censored_by                     : chr "death_date"
      .. .. ..$ depends_on                      : chr [1:2] "interview_date" "death_date"
      .. .. ..$ n_events                        : int 30
      .. ..$ death_date        :List of 10
      .. .. ..$ n                               : int 100
      .. .. ..$ preexisting_missing_code_indices: int(0)
      .. .. ..$ assigned_missing_indices        : int(0)
      .. .. ..$ assigned_missing_codes          : chr(0)
      .. .. ..$ assigned_garbage_indices        :List of 1
      .. .. .. ..$ high: int 81
      .. .. ..$ assigned_garbage_values         :List of 1
      .. .. .. ..$ high: Date[1:1], format: "2094-03-14"
      .. .. ..$ derived                         : logi TRUE
      .. .. ..$ anchor                          : chr "interview_date"
      .. .. ..$ depends_on                      : chr "interview_date"
      .. .. ..$ n_events                        : int 20
      .. ..$ ltfu_date         :List of 10
      .. .. ..$ n                               : int 100
      .. .. ..$ preexisting_missing_code_indices: int(0)
      .. .. ..$ assigned_missing_indices        : int(0)
      .. .. ..$ assigned_missing_codes          : chr(0)
      .. .. ..$ assigned_garbage_indices        :List of 1
      .. .. .. ..$ high: int(0)
      .. .. ..$ assigned_garbage_values         :List of 1
      .. .. .. ..$ high: chr(0)
      .. .. ..$ derived                         : logi TRUE
      .. .. ..$ anchor                          : chr "interview_date"
      .. .. ..$ depends_on                      : chr "interview_date"
      .. .. ..$ n_events                        : int 10
      .. ..$ admin_censor_date :List of 10
      .. .. ..$ n                               : int 100
      .. .. ..$ preexisting_missing_code_indices: int(0)
      .. .. ..$ assigned_missing_indices        : int(0)
      .. .. ..$ assigned_missing_codes          : chr(0)
      .. .. ..$ assigned_garbage_indices        : Named list()
      .. .. ..$ assigned_garbage_values         : Named list()
      .. .. ..$ derived                         : logi TRUE
      .. .. ..$ anchor                          : chr "interview_date"
      .. .. ..$ depends_on                      : chr "interview_date"
      .. .. ..$ n_events                        : int 100

**What’s garbage data?**

MockData is designed to test your *realistic* workflow — including data
cleaning and QA processes. Notice the `garbage_*` columns in the
metadata below? These add intentional invalid values (like negative ages
or impossible dates) so you can test your validation code before using
real data. Move through the tutorials to learn about this advanced
feature: [Garbage data
tutorial](https://big-life-lab.github.io/MockData/articles/tutorial-garbage-data.md).

**What’s in this dataset:**

Age distribution:

       Min. 1st Qu.  Median    Mean 3rd Qu.    Max.
      21.00   45.00   53.00  145.69   62.25  999.00 

Smoking status distribution:


     1  2  3  7
    50 27 20  3 

Interview date range:

        Earliest       Latest
    "2001-01-01" "2005-12-22" 

**Why this approach is best:**

1.  **One function call** generates all variables
2.  **Metadata-driven** - specifications live in CSV files
3.  **Reproducible** - same metadata always produces same structure
4.  **Maintainable** - update CSV files, not R code
5.  **Testable** - version control metadata files

## What’s in those metadata files?

Let’s look at the minimal example metadata:

**variables.csv** (7 variables):

| variable | variableType | distribution | mean | sd | garbage_low_prop | garbage_low_range | garbage_high_prop | garbage_high_range |
|:---|:---|:---|---:|---:|---:|:---|---:|:---|
| age | Continuous | normal | 50.0 | 15.0 | NA | \[;\] | NA | \[;\] |
| smoking | Categorical |  | NA | NA | NA |  | NA |  |
| BMI | Continuous | normal | 27.5 | 5.2 | 0.02 | \[-10;15\] | 0.01 | \[60;150\] |
| height | Continuous | normal | 1.7 | 0.1 | 0.01 | \[0;1.4) | 0.01 | (2.1;2.5\] |
| weight | Continuous | normal | 75.0 | 15.0 | NA | \[;\] | NA | \[;\] |
| BMI_derived | Continuous |  | NA | NA | NA | \[;\] | NA | \[;\] |
| interview_date | Continuous | uniform | NA | NA | 0.00 | \[;\] | 0.00 | \[;\] |
| primary_event_date | Continuous | gompertz | NA | NA | 0.00 | \[;\] | 0.03 | \[2021-01-01;2099-12-31\] |
| death_date | Continuous | gompertz | NA | NA | 0.00 | \[;\] | 0.03 | \[2025-01-01;2099-12-31\] |
| ltfu_date | Continuous | uniform | NA | NA | 0.00 | \[;\] | 0.03 | \[2025-01-01;2099-12-31\] |
| admin_censor_date | Continuous |  | NA | NA | 0.00 | \[;\] | 0.00 | \[;\] |

**variable_details.csv** (10 detail rows):

| variable | recStart | catLabel | proportion |
|:---|:---|:---|---:|
| age | \[18,100\] | Valid age range | 0.90 |
| age | 997 | Don’t know | 0.05 |
| age | 998 | Refusal | 0.03 |
| age | 999 | Not stated | 0.02 |
| smoking | 1 | Never smoker | 0.50 |
| smoking | 2 | Former smoker | 0.30 |
| smoking | 3 | Current smoker | 0.17 |
| smoking | 7 | Don’t know | 0.03 |
| BMI | \[15,50\] | Valid BMI range | NA |
| BMI | 996 | Not applicable | 0.30 |
| BMI | \[997,999\] | Don’t know, refusal, not stated | 0.10 |
| height | \[1.4,2.1\] | Valid height range (meters) | NA |
| height | else | Missing height | 0.02 |
| weight | \[35,150\] | Valid weight range (kg) | NA |
| weight | else | Missing weight | 0.03 |
| BMI_derived | DerivedVar::\[height, weight\] | BMI calculated from height and weight | NA |
| interview_date | \[2001-01-01,2005-12-31\] | Interview date range | 1.00 |
| interview_date | else | Missing interview date | 0.00 |
| primary_event_date | \[2002-01-01,2021-01-01\] | Primary event date range | 0.10 |
| primary_event_date | else | Missing event date | 0.00 |
| death_date | \[2002-01-01,2024-12-31\] | Death date range | 0.20 |
| death_date | else | Missing death date | 0.05 |
| ltfu_date | \[2002-01-01,2024-12-31\] | Loss to follow-up date range | 0.05 |
| ltfu_date | else | Missing ltfu date | NA |
| admin_censor_date | 2024-12-31 | Administrative censor date | 1.00 |
| admin_censor_date | else | Missing administrative censor date | 0.00 |

**Key columns in variables.csv:**

- `variable`: Name of the variable in the generated dataset
- `variableType`: Categorical, Continuous, or Date
- `distribution`: Distribution type (normal, uniform, gompertz)
- `mean`, `sd`: Parameters for normal distribution (continuous
  variables)
- `garbage_*`: Advanced feature for adding invalid values (see tutorial)

**Key columns in variable_details.csv:**

- `variable`: Links to variable name in variables.csv
- `recStart`: Category code (categorical) or range `[min,max]`
  (continuous/date)
- `catLabel`: Category label or range description
- `proportion`: Probability of each category (categorical variables
  only)

See
[inst/extdata/minimal-example/](https://github.com/Big-Life-Lab/MockData/tree/main/inst/extdata/minimal-example)
for the complete files and v0.2.1 schema documentation.

## Working with the generated data

Once you have mock data, you can use it to test your analysis pipeline:

``` r

library(dplyr)

# Test data manipulation
mock_data %>%
  mutate(
    age_group = cut(age, breaks = c(0, 40, 60, 100), labels = c("18-39", "40-59", "60+")),
    smoking_binary = ifelse(smoking == 1, "Never", "Ever")
  ) %>%
  select(age, age_group, smoking, smoking_binary, interview_date) %>%
  head(10)
```

       age age_group smoking smoking_binary interview_date
    1   53     40-59       1          Never     2005-12-22
    2   49     40-59       1          Never     2004-03-09
    3   55     40-59       2           Ever     2003-01-28
    4   54     40-59       1          Never     2004-08-16
    5   27     18-39       3           Ever     2003-01-01
    6   35     18-39       1          Never     2001-04-22
    7   48     40-59       1          Never     2002-11-21
    8   38     18-39       1          Never     2003-09-23
    9   57     40-59       1          Never     2005-09-09
    10  33     18-39       1          Never     2005-08-06

**Common use cases:**

- Test harmonisation workflows (cchsflow, chmsflow)
- Develop analysis scripts before accessing real data
- Create reproducible examples for documentation
- Train new team members on survey data structure

**Limitations:**

- No real-world statistical relationships between variables
- Joint distributions may differ from actual survey data
- **Never use for research, modelling, or population inference**

## Next steps

**Tutorials:**

- [Configuration
  files](https://big-life-lab.github.io/MockData/articles/tutorial-config-files.md) -
  Detailed guide to creating metadata files
- [Date
  variables](https://big-life-lab.github.io/MockData/articles/tutorial-dates.md) -
  Working with survival data and time-to-event distributions
- [Garbage
  data](https://big-life-lab.github.io/MockData/articles/tutorial-garbage-data.md) -
  Adding invalid values and garbage data for QA testing
- [Missing
  data](https://big-life-lab.github.io/MockData/articles/tutorial-missing-data.md) -
  Controlling missing value patterns

**Reference:**

- [Configuration
  reference](https://big-life-lab.github.io/MockData/articles/reference-config.md) -
  Complete v0.2.1 schema specification
- [Advanced
  topics](https://big-life-lab.github.io/MockData/articles/advanced-topics.md) -
  Data quality testing, distributions, validation
