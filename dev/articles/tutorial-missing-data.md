# Missing data in health surveys

**About this vignette:** This tutorial teaches you how to generate
realistic missing data in mock health survey datasets. You’ll learn why
different types of missing data codes matter for statistical analysis
and how to handle them correctly in your research.

## Understanding missing data in health surveys

Health surveys use structured missing data codes to distinguish between
different types of non-response. Unlike general R data where `NA`
represents any missing value, survey data differentiates between several
categories of missingness. This distinction is crucial for accurate
statistical analysis.

Consider a simple example: calculating smoking prevalence from survey
data. If you treat all missing values the same way, you’ll get biased
estimates. Let’s see why.

``` r
# Generate smoking data with two approaches
set.seed(123)

# Wrong approach: treating all missing as NA
smoking_wrong <- data.frame(
  smoker = sample(c("Yes", "No", NA), 1000,
                  replace = TRUE,
                  prob = c(0.20, 0.70, 0.10))
)

# Correct approach: using survey missing codes
smoking_correct <- data.frame(
  smoker = sample(c("1", "2", "6", "7", "9"), 1000,
                  replace = TRUE,
                  prob = c(0.20, 0.70, 0.05, 0.03, 0.02))
)
```

Now let’s calculate prevalence both ways:

``` r
# Wrong calculation (naive approach)
wrong_prevalence <- mean(smoking_wrong$smoker == "Yes", na.rm = TRUE)

# Correct calculation (excluding valid skip, including DK/RF/NS in denominator)
valid_responses <- smoking_correct$smoker %in% c("1", "2", "7", "9")
correct_prevalence <- sum(smoking_correct$smoker == "1") / sum(valid_responses)
```

The naive approach gives us a prevalence of 22.4%, while the correct
approach gives 22%. This difference matters when making population-level
estimates or comparing across surveys.

### Why missing data codes matter

In health surveys, not all missing values mean the same thing. The
Canadian Community Health Survey (CCHS) and Canadian Health Measures
Survey (CHMS) use a standardized system of missing data codes:

- **Valid skip (996)**: The question was not asked because skip logic
  determined it wasn’t applicable
- **Don’t know (997)**: The question was asked but the respondent didn’t
  know the answer
- **Refusal (998)**: The question was asked but the respondent refused
  to answer
- **Not stated (999)**: The question was asked but no response was
  recorded

Each type has different statistical implications. Valid skips should be
excluded from your denominator (they weren’t part of the eligible
population for that question). But don’t know, refusal, and not stated
should be included in the denominator when calculating response rates,
even though they’re excluded from the numerator when calculating
prevalence.

Let’s generate some realistic data to see this in action:

``` r
# Load metadata for examples
variable_details <- read.csv(
  system.file("extdata/cchs/variable_details_cchsflow_sample.csv",
              package = "MockData"),
  stringsAsFactors = FALSE
)

variables <- read.csv(
  system.file("extdata/cchs/variables_cchsflow_sample.csv",
              package = "MockData"),
  stringsAsFactors = FALSE
)

# Create smoking data with realistic proportions using MockData
df_mock <- data.frame()
smoking_data <- create_cat_var(
  var_raw = "SMK_01",
  cycle = "cchs2015_2016_p",
  variable_details = variable_details,
  variables = variables,
  length = 1000,
  df_mock = df_mock,
  proportions = list(
    "1" = 0.18,  # Current smoker
    "2" = 0.65,  # Never smoked
    "3" = 0.12,  # Former smoker
    "6" = 0.01,  # Valid skip
    "7" = 0.02,  # Don't know
    "9" = 0.02   # Not stated
  ),
  seed = 456
)

# Show distribution
table(smoking_data$SMK_01)
```

    < table of extent 0 >

### The three types of missing data codes

Health surveys categorize missing data into three main types, each
requiring different statistical treatment.

**Valid skip (code 996)**

A valid skip occurs when skip logic determines a question should not be
asked. For example, if someone reports they’ve never smoked, they won’t
be asked “How many cigarettes per day do you smoke?” This isn’t truly
missing data—it’s a logical consequence of their previous answer.

Statistical treatment: Exclude from both the numerator and denominator.
These respondents weren’t eligible for the question.

**Don’t know / Refusal / Not stated (codes 997, 998, 999)**

These codes represent questions that were asked but didn’t receive valid
responses:

- **997 (Don’t know)**: Respondent was uncertain about the answer
- **998 (Refusal)**: Respondent declined to answer
- **999 (Not stated)**: Question was asked but no response was recorded

Statistical treatment: Include in the denominator when calculating
response rates (they were eligible and asked), but exclude from the
numerator when calculating prevalence (we don’t know their true status).

**Not applicable (code 996, sometimes labeled NA::a)**

This is similar to valid skip—the question doesn’t apply to the
respondent’s situation. The statistical treatment is the same as valid
skip.

Let’s demonstrate the difference with a worked example:

``` r
# Calculate response rate (includes DK/RF/NS in denominator)
asked <- smoking_data$SMK_01 %in% c("1", "2", "3", "7", "9")
valid_response <- smoking_data$SMK_01 %in% c("1", "2", "3")
response_rate <- sum(valid_response) / sum(asked)

# Calculate prevalence (excludes valid skip from denominator, excludes DK/NS from numerator)
current_smoker <- smoking_data$SMK_01 == "1"
asked_not_skip <- smoking_data$SMK_01 %in% c("1", "2", "3", "7", "9")
prevalence <- sum(current_smoker) / sum(asked_not_skip)
```

In this dataset:

- **Sample size**: respondents
- **Valid skip**: 0 (not asked due to skip logic)
- **Asked**: 0 (eligible for the question)
- **Response rate**: NaN% (valid responses ÷ asked)
- **Smoking prevalence**: NaN% (current smokers ÷ asked excluding DK/NS)

Notice how valid skip (6) doesn’t factor into either calculation—those
respondents were never part of the eligible population for this
question.

### Real-world example from CCHS

Let’s use actual CCHS metadata to generate realistic missing data
patterns. The CCHS uses these same coding schemes across hundreds of
variables.

``` r
# Load CCHS metadata
variable_details <- read.csv(
  system.file("extdata/cchs/variable_details_cchsflow_sample.csv",
              package = "MockData"),
  stringsAsFactors = FALSE
)

# Look at alcohol consumption variable
alc_details <- variable_details[variable_details$variable == "ALC_15", ]
head(alc_details[, c("variable", "recEnd", "catLabel", "catLabelLong")], 10)
```

    [1] variable     recEnd       catLabel     catLabelLong
    <0 rows> (or 0-length row.names)

This shows how missing codes appear in actual survey metadata. The
`recEnd` column contains the category values, including both substantive
responses (1-4 for frequency categories) and missing data codes (6, 7,
9, 96, 97, 99).

We can use this metadata to generate mock data with realistic
proportions:

``` r
# Generate alcohol consumption data using CCHS patterns
df_mock_alc <- data.frame()
alcohol_data <- create_cat_var(
  var_raw = "ALC_15",
  cycle = "cchs2015_2016_p",
  variable_details = variable_details,
  variables = variables,
  length = 2000,
  df_mock = df_mock_alc,
  proportions = list(
    "1" = 0.15,   # Regular drinker
    "2" = 0.35,   # Occasional drinker
    "3" = 0.28,   # Infrequent drinker
    "4" = 0.15,   # Non-drinker
    "6" = 0.01,   # Valid skip
    "7" = 0.03,   # Don't know
    "9" = 0.03    # Not stated
  ),
  seed = 789
)

# Calculate response rate and prevalence of regular drinking
asked_alc <- alcohol_data$ALC_15 %in% c("1", "2", "3", "4", "7", "9")
valid_alc <- alcohol_data$ALC_15 %in% c("1", "2", "3", "4")
response_rate_alc <- sum(valid_alc) / sum(asked_alc)

regular_drinker <- alcohol_data$ALC_15 == "1"
prevalence_alc <- sum(regular_drinker) / sum(asked_alc)
```

For this alcohol consumption variable:

- **Response rate**: NaN% (0 valid responses ÷ 0 asked)
- **Regular drinking prevalence**: NaN% (0 regular drinkers ÷ 0 asked)
- **Don’t know responses**: 0 (NaN% of those asked)
- **Not stated**: 0 (NaN% of those asked)

This demonstrates how real CCHS data includes measurable proportions of
missing data codes, and why distinguishing between them matters for
accurate statistical reporting.
