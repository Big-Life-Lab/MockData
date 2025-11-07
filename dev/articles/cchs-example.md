# CCHS example

**About this vignette:** All numeric values shown in this vignette are
computed from the actual CCHS sample metadata files. Code is hidden by
default for readability, but you can view the source `.qmd` file to see
how values are calculated.

## Overview

This example demonstrates generating mock Canadian Community Health
Survey (CCHS) data using cchsflow metadata. The generated mock data can
be used to test harmonization workflows before accessing real CCHS data.

``` r
library(MockData)
library(dplyr)
library(stringr)
```

## Load metadata

Load the CCHS harmonization metadata files that define variables and
their details across cycles.

``` r
# CCHS sample variables
variables <- read.csv(
  system.file("extdata/cchs/variables_cchsflow_sample.csv", package = "MockData"),
  header = TRUE,
  check.names = FALSE,
  na.strings = c("", "NA", "N/A"),
  stringsAsFactors = FALSE
)

# CCHS sample variable details
variable_details <- read.csv(
  system.file("extdata/cchs/variable_details_cchsflow_sample.csv", package = "MockData"),
  header = TRUE,
  check.names = FALSE,
  na.strings = c("", "NA", "N/A"),
  stringsAsFactors = FALSE
)
```

The CCHS sample metadata includes 20 harmonized variables with 126
detail rows.

## Extract available cycles

The sample metadata includes 8 CCHS cycles: cchs2003_p, cchs2005_p,
cchs2007_2008_p, cchs2009_2010_p, cchs2011_2012_p, cchs2013_2014_p,
cchs2001_p, cchs2003_p.

## Understanding the metadata

The sample metadata includes 20 harmonized variables. For cchs2003_p,
there are 20 harmonized variables available:

| variable | variable_raw | variableType | label                       |
|:---------|:-------------|:-------------|:----------------------------|
| ADL_01   | RACC_6A      | Categorical  | Help preparing meals        |
| ADL_02   | RACC_6B1     | Categorical  | Help appointments/errands   |
| ADL_03   | RACC_6C      | Categorical  | Help housework              |
| ADL_04   | RACC_6E      | Categorical  | Help personal care          |
| ADL_05   | RACC_6F      | Categorical  | Help move inside house      |
| ADL_06   | RACC_6G      | Categorical  | Help personal finances      |
| ADL_07   | RACC_6D      | Categorical  | Help heavy household chores |
| ADLF6R   | RACCF6R      | Categorical  | Help tasks                  |
| ADL_der  | NA           | Categorical  | Help tasks                  |
| ADM_RNO  | ADMC_RNO     | Continuous   | Sequential record number    |

## Get raw variables to generate

For mock data generation, we need to create the **raw source variables**
(before harmonization), not the harmonized variables.

``` r
# Get unique raw variables needed for this cycle (excludes derived variables)
raw_vars <- get_raw_variables(example_cycle, variables, variable_details,
                               include_derived = FALSE)
```

This cycle requires 19 unique raw variables: 11 categorical and 8
continuous.

| variable_raw | variableType | harmonized_vars | n_harmonized |
|:-------------|:-------------|:----------------|-------------:|
| ADMC_RNO     | Continuous   | ADM_RNO         |            1 |
| ALCC_1       | Categorical  | ALC_1           |            1 |
| ALCC_5       | Categorical  | ALW_1           |            1 |
| ALCC_5A1     | Continuous   | ALW_2A1         |            1 |
| ALCC_5A2     | Continuous   | ALW_2A2         |            1 |
| ALCC_5A3     | Continuous   | ALW_2A3         |            1 |
| ALCC_5A4     | Continuous   | ALW_2A4         |            1 |
| ALCC_5A5     | Continuous   | ALW_2A5         |            1 |
| ALCC_5A6     | Continuous   | ALW_2A6         |            1 |
| ALCC_5A7     | Continuous   | ALW_2A7         |            1 |
| ALCCDTYP     | Categorical  | ALCDTTM         |            1 |
| RACC_6A      | Categorical  | ADL_01          |            1 |
| RACC_6B1     | Categorical  | ADL_02          |            1 |
| RACC_6C      | Categorical  | ADL_03          |            1 |
| RACC_6D      | Categorical  | ADL_07          |            1 |
| RACC_6E      | Categorical  | ADL_04          |            1 |
| RACC_6F      | Categorical  | ADL_05          |            1 |
| RACC_6G      | Categorical  | ADL_06          |            1 |
| RACCF6R      | Categorical  | ADLF6R          |            1 |

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

We’ll generate 100 mock records for cchs2003_p.

### Generate categorical variables

Generated 11 categorical variables. Data frame now has 12 columns.

### Generate continuous variables

Generated 8 continuous variables. Final data frame has 20 columns.

### Examine the result

**Mock data structure:**

    'data.frame':   100 obs. of  20 variables:
     $ id      : int  1 2 3 4 5 6 7 8 9 10 ...
     $ ALCC_1  : chr  "2" "2" "2" "1" ...
     $ ALCC_5  : chr  "31" "27" "18" "35" ...
     $ ALCCDTYP: chr  "2" "3" "3" "2" ...
     $ RACC_6A : chr  "2" "2" "2" "1" ...
     $ RACC_6B1: chr  "1" "2" "2" "1" ...
     $ RACC_6C : chr  "1" "1" "1" "1" ...
     $ RACC_6D : chr  "1" "2" "1" "1" ...
     $ RACC_6E : chr  "2" "2" "2" "1" ...
     $ RACC_6F : chr  "2" "1" "1" "1" ...
     $ RACC_6G : chr  "2" "2" "2" "2" ...
     $ RACCF6R : chr  "2" "2" "1" "1" ...
     $ ADMC_RNO: num  660337 104974 913583 245862 928899 ...
     $ ALCC_5A1: num  15.7 12.3 27.5 34.1 22.9 ...
     $ ALCC_5A2: num  12.99 41.72 2.23 16.19 41.72 ...
     $ ALCC_5A3: num  14.21 15.41 35.32 8.22 3.53 ...
     $ ALCC_5A4: num  32.52 17.32 6.43 35.39 19.99 ...
     $ ALCC_5A5: num  42.96 14.85 8.18 11.72 6.64 ...
     $ ALCC_5A6: num  35.2 20.7 16.4 42.4 11.7 ...
     $ ALCC_5A7: num  46.1 20.1 10.1 32.9 22.5 ...

**First 5 rows:**

|  id | ALCC_1 | ALCC_5 | ALCCDTYP | RACC_6A | RACC_6B1 | RACC_6C | RACC_6D | RACC_6E | RACC_6F | RACC_6G | RACCF6R | ADMC_RNO | ALCC_5A1 | ALCC_5A2 |  ALCC_5A3 |  ALCC_5A4 |  ALCC_5A5 | ALCC_5A6 | ALCC_5A7 |
|----:|:-------|:-------|:---------|:--------|:---------|:--------|:--------|:--------|:--------|:--------|:--------|---------:|---------:|---------:|----------:|----------:|----------:|---------:|---------:|
|   1 | 2      | 31     | 2        | 2       | 1        | 1       | 1       | 2       | 2       | 2       | 2       | 660337.5 | 15.72437 | 12.99133 | 14.208899 | 32.515844 | 42.962386 | 35.19427 | 46.13716 |
|   2 | 2      | 27     | 3        | 2       | 2        | 1       | 2       | 2       | 1       | 2       | 2       | 104973.9 | 12.28077 | 41.71837 | 15.410777 | 17.316266 | 14.849557 | 20.70368 | 20.08061 |
|   3 | 2      | 18     | 3        | 2       | 2        | 1       | 1       | 2       | 1       | 2       | 1       | 913582.7 | 27.53722 |  2.23390 | 35.316357 |  6.431974 |  8.183292 | 16.37728 | 10.13340 |
|   4 | 1      | 35     | 2        | 1       | 1        | 1       | 1       | 1       | 1       | 2       | 1       | 245862.2 | 34.09194 | 16.19133 |  8.218619 | 35.393032 | 11.720900 | 42.36451 | 32.92027 |
|   5 | 2      | 26     | 3        | 1       | 1        | 1       | 1       | 1       | 2       | 2       | 2       | 928898.9 | 22.91900 | 41.71608 |  3.526694 | 19.988267 |  6.644390 | 11.69989 | 22.53624 |

**Missing values:** No missing values

## Summary

This example demonstrated generating mock CCHS data for testing cchsflow
harmonization workflows. The generated data:

- Respects category ranges from variable_details
- Includes appropriate missing values
- Uses reproducible seeds
- Can be used to test harmonization functions before accessing real CCHS
  data

## Next steps

- Test your cchsflow harmonization pipeline on this mock data
- Generate mock data for additional cycles as needed
- Calculate derived variables after harmonization (not during mock data
  generation)
