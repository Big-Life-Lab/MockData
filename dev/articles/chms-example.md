# CHMS example

**About this vignette:** All numeric values shown in this vignette are
computed from the actual CHMS sample metadata files. Code is hidden by
default for readability, but you can view the source `.qmd` file to see
how values are calculated.

## Overview

The Canadian Health Measures Survey (CHMS) data exists only in secure
data environments. This example demonstrates how to generate mock CHMS
data using chmsflow metadata for testing harmonization workflows before
accessing real data.

``` r
library(MockData)
library(dplyr)
library(stringr)
```

## Load metadata

Load the CHMS harmonization metadata files that define variables and
their details across cycles.

``` r
# CHMS sample variables
variables <- read.csv(
  system.file("extdata/chms/variables_chmsflow_sample.csv", package = "MockData"),
  header = TRUE,
  check.names = FALSE,
  na.strings = c("", "NA", "N/A"),
  stringsAsFactors = FALSE
)

# CHMS sample variable details
variable_details <- read.csv(
  system.file("extdata/chms/variable_details_chmsflow_sample.csv", package = "MockData"),
  header = TRUE,
  check.names = FALSE,
  na.strings = c("", "NA", "N/A"),
  stringsAsFactors = FALSE
)
```

The CHMS sample metadata includes 18 harmonized variables with 73 detail
rows.

## Extract available cycles

The sample metadata includes 8 CHMS cycles: cycle2, cycle2_meds, cycle3,
cycle4, cycle5, cycle6, cycle1, cycle1_meds.

## Understanding the metadata

The sample metadata includes 20 harmonized variables. For cycle2, there
are 15 harmonized variables available:

| variable | variable_raw | variableType | label                                             |
|:---------|:-------------|:-------------|:--------------------------------------------------|
| alc_11   | alc_11       | Categorical  | Drank in past year                                |
| alc_17   | alc_17       | Categorical  | Ever drank alcohol                                |
| alc_18   | alc_18       | Categorical  | Drank alcohol regularly                           |
| alcdwky  | alcdwky      | Continuous   | Drinks in week                                    |
| ammdmva1 | ammdmva1     | Continuous   | Minutes of exercise per day (accelerometer Day 1) |
| ammdmva2 | ammdmva2     | Continuous   | Minutes of exercise per day (accelerometer Day 2) |
| ammdmva3 | ammdmva3     | Continuous   | Minutes of exercise per day (accelerometer Day 3) |
| ammdmva4 | ammdmva4     | Continuous   | Minutes of exercise per day (accelerometer Day 4) |
| ammdmva5 | ammdmva5     | Continuous   | Minutes of exercise per day (accelerometer Day 5) |
| ammdmva6 | ammdmva6     | Continuous   | Minutes of exercise per day (accelerometer Day 6) |

## Get raw variables to generate

For mock data generation, we need to create the **raw source variables**
(before harmonization), not the harmonized variables.

``` r
# Get unique raw variables needed for this cycle (excludes derived variables)
raw_vars <- get_raw_variables(example_cycle, variables, variable_details,
                               include_derived = FALSE)
```

This cycle requires 15 unique raw variables: 4 categorical and 11
continuous.

| variable_raw | variableType | harmonized_vars | n_harmonized |
|:-------------|:-------------|:----------------|-------------:|
| alc_11       | Categorical  | alc_11          |            1 |
| alc_17       | Categorical  | alc_17          |            1 |
| alc_18       | Categorical  | alc_18          |            1 |
| alcdwky      | Continuous   | alcdwky         |            1 |
| ammdmva1     | Continuous   | ammdmva1        |            1 |
| ammdmva2     | Continuous   | ammdmva2        |            1 |
| ammdmva3     | Continuous   | ammdmva3        |            1 |
| ammdmva4     | Continuous   | ammdmva4        |            1 |
| ammdmva5     | Continuous   | ammdmva5        |            1 |
| ammdmva6     | Continuous   | ammdmva6        |            1 |
| ammdmva7     | Continuous   | ammdmva7        |            1 |
| bpmdpbpd     | Continuous   | bpmdpbpd        |            1 |
| bpmdpbps     | Continuous   | bpmdpbps        |            1 |
| clc_age      | Continuous   | clc_age         |            1 |
| clc_sex      | Categorical  | clc_sex         |            1 |

## Generate mock data for one cycle

Now let’s generate mock data for a single cycle.

``` r
# Configuration
n_records <- 100
target_cycle <- example_cycle
seed <- 12345

# Initialize data frame
df_mock <- data.frame(id = 1:n_records)
```

We’ll generate 100 mock records for cycle2.

### Generate categorical variables

Generated 4 categorical variables. Data frame now has 5 columns.

### Generate continuous variables

Generated 11 continuous variables. Final data frame has 16 columns.

### Examine the result

**Mock data structure:**

    'data.frame':   100 obs. of  16 variables:
     $ id      : int  1 2 3 4 5 6 7 8 9 10 ...
     $ alc_11  : chr  "2" "2" "2" "1" ...
     $ alc_17  : chr  "1" "1" "2" "1" ...
     $ alc_18  : chr  "2" "2" "2" "2" ...
     $ clc_sex : chr  "2" "2" "2" "1" ...
     $ alcdwky : num  55.47 8.82 76.74 20.65 78.03 ...
     $ ammdmva1: num  127.1 99.2 222.5 275.5 185.2 ...
     $ ammdmva2: num  105 337 18 131 337 ...
     $ ammdmva3: num  114.8 124.5 285.4 66.4 28.5 ...
     $ ammdmva4: num  263 140 52 286 162 ...
     $ ammdmva5: num  347.1 120 66.1 94.7 53.7 ...
     $ ammdmva6: num  284.4 167.3 132.3 342.3 94.5 ...
     $ ammdmva7: num  372.8 162.3 81.9 266 182.1 ...
     $ bpmdpbpd: num  95.4 83.3 54.6 94.7 71.1 ...
     $ bpmdpbps: num  110.8 143.9 149.6 89.7 138.8 ...
     $ clc_age : num  74.9 45.8 61.5 53.2 45.8 ...

**First 5 rows:**

|  id | alc_11 | alc_17 | alc_18 | clc_sex |   alcdwky | ammdmva1 |  ammdmva2 |  ammdmva3 |  ammdmva4 |  ammdmva5 | ammdmva6 |  ammdmva7 | bpmdpbpd |  bpmdpbps |  clc_age |
|----:|:-------|:-------|:-------|:--------|----------:|---------:|----------:|----------:|----------:|----------:|---------:|----------:|---------:|----------:|---------:|
|   1 | 2      | 1      | 2      | 2       | 55.468431 | 127.0529 | 104.96991 | 114.80790 | 262.72802 | 347.13607 | 284.3697 | 372.78829 | 95.41136 | 110.78141 | 74.85507 |
|   2 | 2      | 1      | 2      | 2       |  8.817749 |  99.2286 | 337.08440 | 124.51908 | 139.91543 | 119.98442 | 167.2858 | 162.25131 | 83.33644 | 143.93198 | 45.84278 |
|   3 | 2      | 2      | 2      | 2       | 76.741093 | 222.5007 |  18.04991 | 285.35616 |  51.97035 |  66.12100 | 132.3284 |  81.87789 | 54.62073 | 149.60858 | 61.48123 |
|   4 | 1      | 1      | 2      | 1       | 20.652405 | 275.4628 | 130.82593 |  66.40645 | 285.97570 |  94.70487 | 342.3053 | 265.99578 | 94.74711 |  89.69766 | 53.21518 |
|   5 | 2      | 2      | 2      | 1       | 78.027656 | 185.1855 | 337.06596 |  28.49568 | 161.50520 |  53.68667 |  94.5351 | 182.09282 | 71.11196 | 138.83499 | 45.78124 |

**Missing values:** No missing values

## Summary

This example demonstrated generating mock CHMS data for testing chmsflow
harmonization workflows. The generated data:

- Respects category ranges from variable_details
- Includes appropriate missing values
- Uses reproducible seeds
- Can be used to test harmonization functions before accessing real CHMS
  data

## Next steps

- Test your chmsflow harmonization pipeline on this mock data
- Generate mock data for additional cycles as needed
- Calculate derived variables after harmonization (not during mock data
  generation)
