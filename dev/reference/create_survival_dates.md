# Create paired survival dates for cohort studies

Generates entry and event dates with guaranteed temporal ordering (entry
\< event). Useful for survival analysis, cohort studies, and
time-to-event modeling.

## Usage

``` r
create_survival_dates(
  entry_var_row = NULL,
  entry_details_subset = NULL,
  event_var_row = NULL,
  event_details_subset = NULL,
  n = NULL,
  seed = NULL,
  df_mock = NULL,
  entry_var = NULL,
  event_var = NULL,
  entry_start = NULL,
  entry_end = NULL,
  followup_min = NULL,
  followup_max = NULL,
  length = NULL,
  event_distribution = "uniform",
  prop_censored = 0,
  prop_NA = NULL,
  prop_invalid = NULL
)
```

## Arguments

- entry_var_row:

  data.frame. Single row from mock_data_config for entry date variable

- entry_details_subset:

  data.frame. Rows from mock_data_config_details for entry date

- event_var_row:

  data.frame. Single row from mock_data_config for event date variable

- event_details_subset:

  data.frame. Rows from mock_data_config_details for event date

- n:

  integer. Number of observations to generate

- seed:

  integer. Random seed for reproducibility. If NULL, uses global seed.

- df_mock:

  data.frame. The current mock data (to check if variables already
  exist)

  **Configuration v0.1 format (LEGACY):**

- entry_var:

  character. Name for entry date variable

- event_var:

  character. Name for event date variable

- entry_start:

  Date. Start of entry period

- entry_end:

  Date. End of entry period

- followup_min:

  integer. Minimum follow-up days

- followup_max:

  integer. Maximum follow-up days

- length:

  integer. Number of records to generate

- event_distribution:

  character. Distribution for time-to-event: "uniform", "gompertz",
  "exponential"

- prop_censored:

  numeric. Proportion of records to censor (0-1)

- prop_NA:

  numeric. Proportion of missing values (0-1)

- prop_invalid:

  numeric. Optional. Proportion of temporal violations (entry \> event)
  (0 to 1). If NULL, no invalid dates generated.

## Value

data.frame with entry_date, event_date, and optionally event_status
columns, or NULL if:

- Variables already exist in df_mock

- Missing required configuration

## Details

**Configuration v0.2 format (NEW):**

**v0.2 format (NEW):**

- Extracts date ranges from entry_details_subset and
  event_details_subset

- Generates entry dates uniformly distributed

- Calculates event dates to ensure entry \< event

- Supports garbage data via `catLabel::garbage` in event_details_subset

- Supports fallback mode: reasonable defaults when details_subset is
  NULL

**v0.1 format (LEGACY):**

- Accepts explicit date ranges and follow-up parameters

- Supports multiple event distributions (uniform, gompertz, exponential)

- Handles censoring, missing values, and temporal violations via
  parameters

The function auto-detects which format based on parameter names.

This function generates realistic survival data by:

1.  Creating entry dates uniformly distributed across entry period

2.  Generating follow-up times using specified distribution

3.  Calculating event dates (entry + follow-up)

4.  Optionally censoring events (event_status = 0)

5.  Ensuring entry_date \< event_date for all records

**Event distributions:**

- "uniform": Constant hazard over follow-up period

- "gompertz": Increasing hazard (mortality increases with time)

- "exponential": Decreasing hazard (early events more common)

**Censoring:** When prop_censored \> 0, generates event_status column:

- 1 = event observed

- 0 = censored (event_date becomes censoring date)

## See also

Other generators:
[`create_cat_var()`](https://big-life-lab.github.io/MockData/reference/create_cat_var.md),
[`create_con_var()`](https://big-life-lab.github.io/MockData/reference/create_con_var.md),
[`create_date_var()`](https://big-life-lab.github.io/MockData/reference/create_date_var.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# v0.2 format - called by create_mock_data()
config <- read_mock_data_config("mock_data_config.csv")
details <- read_mock_data_config_details("mock_data_config_details.csv")
entry_row <- config[config$variable == "study_entry", ]
entry_details <- get_variable_details(details, variable_name = "study_entry")
event_row <- config[config$variable == "death_date", ]
event_details <- get_variable_details(details, variable_name = "death_date")
surv_data <- create_survival_dates(
  entry_var_row = entry_row,
  entry_details_subset = entry_details,
  event_var_row = event_row,
  event_details_subset = event_details,
  n = 1000,
  seed = 123
)

# v0.2 with garbage (catLabel::garbage in config_details)
# In mock_data_config_details.csv:
# variable,recEnd,catLabel,proportion
# death_date,followup_min,,
# death_date,followup_max,,
# death_date,garbage,garbage,0.03
event_details_with_garbage <- get_variable_details(details, variable_name = "death_date")
surv_data_garbage <- create_survival_dates(
  entry_var_row = entry_row,
  entry_details_subset = entry_details,
  event_var_row = event_row,
  event_details_subset = event_details_with_garbage,
  n = 1000,
  seed = 123
)

# v0.1 format (legacy) - Basic mortality study
surv_data <- create_survival_dates(
  entry_var = "study_entry",
  event_var = "death_date",
  entry_start = as.Date("2000-01-01"),
  entry_end = as.Date("2005-12-31"),
  followup_min = 365,
  followup_max = 3650,
  length = 1000,
  df_mock = data.frame(),
  event_distribution = "gompertz"
)

# v0.1 with censoring
surv_data <- create_survival_dates(
  entry_var = "cohort_entry",
  event_var = "event_date",
  entry_start = as.Date("2010-01-01"),
  entry_end = as.Date("2015-12-31"),
  followup_min = 30,
  followup_max = 1825,
  length = 500,
  df_mock = data.frame(),
  event_distribution = "exponential",
  prop_censored = 0.3
)

# v0.1 with temporal violations for validation testing
surv_data <- create_survival_dates(
  entry_var = "interview_date",
  event_var = "death_date",
  entry_start = as.Date("2015-01-01"),
  entry_end = as.Date("2016-12-31"),
  followup_min = 30,
  followup_max = 3650,
  length = 1000,
  df_mock = data.frame(),
  prop_invalid = 0.03  # 3% temporal violations
)
} # }
```
