# Create wide survival data for cohort studies

Generates wide-format survival data (one row per individual) with up to
5 date variables (entry, event, death, loss-to-follow-up, administrative
censoring). Applies temporal ordering constraints and supports garbage
data generation for QA testing.

## Usage

``` r
create_wide_survival_data(
  var_entry_date,
  var_event_date = NULL,
  var_death_date = NULL,
  var_ltfu = NULL,
  var_admin_censor = NULL,
  databaseStart,
  variables,
  variable_details,
  df_mock = NULL,
  n,
  seed = NULL,
  prop_garbage = NULL
)
```

## Arguments

- var_entry_date:

  character. Required. Variable name for entry date (baseline).

- var_event_date:

  character. Optional. Variable name for primary event date (e.g.,
  "dementia_incid_date"). Set to NULL to skip.

- var_death_date:

  character. Optional. Variable name for death date (competing risk).
  Set to NULL to skip.

- var_ltfu:

  character. Optional. Variable name for loss-to-follow-up date. Set to
  NULL to skip.

- var_admin_censor:

  character. Optional. Variable name for administrative censoring date.
  Set to NULL to skip.

- databaseStart:

  character. Required. Database identifier for filtering metadata (used
  with databaseStart column in variable_details).

- variables:

  data.frame. Required. Full variables metadata (not pre-filtered). Must
  contain columns: variable, variableType.

- variable_details:

  data.frame. Required. Full variable details metadata (not
  pre-filtered). Will be filtered internally using databaseStart column.

- df_mock:

  data.frame. Optional. The current mock data to check if variables
  already exist and to use as anchor_date source. Default: NULL.

- n:

  integer. Required. Number of observations to generate.

- seed:

  integer. Optional. Random seed for reproducibility. Default: NULL.

- prop_garbage:

  numeric. **DEPRECATED in v0.3.1**. This parameter is no longer
  supported. To generate temporal violations for QA testing, use the
  `garbage_high_prop` and `garbage_high_range` parameters in
  variables.csv for individual date variables. See Details section for
  migration guidance. Default: NULL.

## Value

data.frame with 1-5 date columns (depending on which variables are
specified), or NULL if variables already exist in df_mock.

## Details

This function implements v0.3.0 "recodeflow pattern" API:

- Accepts full metadata data frames (not pre-filtered subsets)

- Accepts variable names (not variable rows)

- Filters metadata internally using databaseStart column

**Implementation strategy:**

1.  Call create_date_var() once for each non-NULL date variable

2.  Each variable configured separately in variables.csv with own
    event_prop, distribution, followup_min, followup_max, etc.

3.  Combine results into single data frame

4.  Apply temporal ordering constraints

**Temporal ordering constraints (normal mode):**

- Entry date is always baseline (earliest)

- All other dates must be \>= entry_date

- Death can occur before any event

- If death \< event, set event to NA (censored, not missing)

- Observation ends at min(event, death, ltfu, admin_censor)

**Temporal violations for QA testing (v0.3.1+):** This function creates
clean, temporally-ordered survival data. To generate temporal violations
for testing data quality pipelines:

- Add `garbage_high_prop` and `garbage_high_range` to individual date
  variables in variables.csv (e.g., future death dates beyond 2025)

- Use
  [`create_date_var()`](https://big-life-lab.github.io/MockData/reference/create_date_var.md)
  to generate date variables with garbage

- Test your temporal validation logic separately

- This approach separates concerns: date-level garbage vs. survival data
  generation

**Migration from prop_garbage (deprecated in v0.3.1):**

    # OLD (v0.3.0):
    surv <- create_wide_survival_data(..., prop_garbage = 0.03)

    # NEW (v0.3.1+):
    # Add garbage to date variables in metadata
    variables$garbage_high_prop[variables$variable == "death_date"] <- 0.03
    variables$garbage_high_range[variables$variable == "death_date"] <-
      "[2025-01-01, 2099-12-31]"
    # create_date_var() will apply garbage automatically
    surv <- create_wide_survival_data(..., variables = variables)

**Configuration in metadata:** Each date variable must be defined in
variables.csv and variable_details.csv:

variables.csv:

    variable,variableType,role
    interview_date,Date,enabled
    dementia_incid_date,Date,enabled
    death_date,Date,enabled

variable_details.csv:

    variable,recStart,recEnd,value,proportion
    interview_date,[2001-01-01,2005-12-31],copy,NA,NA
    dementia_incid_date,[2002-01-01,2021-01-01],followup_min,365,NA
    dementia_incid_date,NA,followup_max,7300,NA
    dementia_incid_date,NA,event_prop,0.15,NA
    death_date,[2002-01-01,2026-01-01],followup_min,365,NA
    death_date,NA,followup_max,9125,NA
    death_date,NA,event_prop,0.40,NA

## See also

Other generators:
[`create_cat_var()`](https://big-life-lab.github.io/MockData/reference/create_cat_var.md),
[`create_con_var()`](https://big-life-lab.github.io/MockData/reference/create_con_var.md),
[`create_date_var()`](https://big-life-lab.github.io/MockData/reference/create_date_var.md),
[`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md),
[`create_survival_dates()`](https://big-life-lab.github.io/MockData/reference/create_survival_dates.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Read metadata
variables <- read.csv("inst/extdata/survival/variables.csv")
variable_details <- read.csv("inst/extdata/survival/variable_details.csv")

# Generate 5-variable survival data
surv_data <- create_wide_survival_data(
  var_entry_date = "interview_date",
  var_event_date = "dementia_incid_date",
  var_death_date = "death_date",
  var_ltfu = "ltfu_date",
  var_admin_censor = "admin_censor_date",
  databaseStart = "demport",
  variables = variables,
  variable_details = variable_details,
  n = 1000,
  seed = 123
)

# Generate minimal survival data (entry + event only)
surv_data <- create_wide_survival_data(
  var_entry_date = "cohort_entry",
  var_event_date = "primary_event_date",
  var_death_date = NULL,
  var_ltfu = NULL,
  var_admin_censor = NULL,
  database = "study",
  variables = variables,
  variable_details = variable_details,
  n = 500,
  seed = 456
)

# Generate with garbage data for QA testing (v0.3.1+)
# Add garbage to death_date in metadata
vars_with_garbage <- add_garbage(variables, "death_date",
  high_prop = 0.05, high_range = "[2025-01-01, 2099-12-31]")

surv_data <- create_wide_survival_data(
  var_entry_date = "interview_date",
  var_event_date = "dementia_incid_date",
  var_death_date = "death_date",
  var_ltfu = NULL,
  var_admin_censor = NULL,
  databaseStart = "demport",
  variables = vars_with_garbage,  # Use modified metadata
  variable_details = variable_details,
  n = 1000,
  seed = 789
)
} # }
```
