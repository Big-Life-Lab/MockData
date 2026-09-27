# Generating survival data with competing risks

**About this vignette:** A first walk through survival data for cohort
studies: an entry date, event dates, a competing risk (death) and
censoring. You will see how survival dates are described in
`variables.csv`, generate them with
[`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md),
and check the rules MockData applies. All code runs during the vignette
build, and hidden checks stop the build if MockData stops behaving as
this page describes.

## Overview

Survival analysis needs several date variables that respect each other:

- **Cohort entry date** (baseline, index date)
- **Event dates** (disease incidence, outcomes of interest)
- **Competing risks** (death prevents observation of the primary event)
- **Censoring** (loss to follow-up, administrative censoring)

[`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md)
generates all of these from metadata. A survival date is a date variable
whose row in `variables.csv` names, in the `anchor` column, the entry
date it is generated from.

## Survival dates in the metadata

The packaged minimal example has an entry date and four survival dates:

``` r

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

survival_columns <- c("variable", "anchor", "censored_by", "distribution",
                      "followup_min", "followup_max", "event_prop")
date_rows <- variables$rType == "date"
variables[date_rows, survival_columns]
```

                 variable         anchor censored_by distribution followup_min
    7      interview_date                                 uniform           NA
    8  primary_event_date interview_date  death_date     gompertz            0
    9          death_date interview_date                 gompertz          365
    10          ltfu_date interview_date                  uniform          365
    11  admin_censor_date interview_date                                   365
       followup_max event_prop
    7            NA         NA
    8          5475        0.3
    9          7300        0.2
    10         7300        0.1
    11         7300        1.0

Each survival date has:

- `anchor`: the entry-date variable it is generated from
  (`interview_date`)
- `followup_min`, `followup_max`: the follow-up window, in days after
  the anchor
- `event_prop`: the share of people who have the event; the rest are
  `NA` (censored)
- `distribution`: how follow-up times spread across the window
  (`uniform`, `exponential` or `gompertz`)
- `censored_by` (optional): a competing survival date. Where it comes
  first, this date is set to `NA`. Here `death_date` censors
  `primary_event_date`.

## Generating survival data

The minimal example also adds future-date garbage to its survival dates,
for data-quality testing. This section removes it to show clean data;
the last section puts it back.

``` r

clean_variables <- variables
clean_variables$garbage_high_prop[date_rows] <- 0

mock <- create_mock_data(
  databaseStart = "minimal-example",
  variables = clean_variables,
  variable_details = variable_details,
  n = 2000,
  seed = 123
)

surv <- mock[, c("interview_date", "primary_event_date", "death_date",
                 "ltfu_date", "admin_censor_date")]
head(surv)
```

      interview_date primary_event_date death_date ltfu_date admin_censor_date
    1     2004-10-23         2004-12-24       <NA>      <NA>        2020-12-03
    2     2004-01-10         2004-03-20 2005-01-09      <NA>        2011-05-25
    3     2004-01-15         2004-04-02       <NA>      <NA>        2020-06-02
    4     2005-06-02         2005-08-07       <NA>      <NA>        2022-11-28
    5     2003-10-19         2003-12-30       <NA>      <NA>        2008-06-14
    6     2005-03-24               <NA>       <NA>      <NA>        2008-08-26

Each row has an interview date (cohort entry). Survival dates that did
not occur are `NA`. `death_date` has `event_prop = 0.2`, and 400 of 2000
people have a death date: exactly `floor(n * event_prop)`, because
MockData assigns a fixed number of events and shuffles who receives
them.

## Competing risks and temporal rules

MockData applies two rules to each survival date:

1.  **Entry is the baseline.** A date earlier than its anchor is set to
    `NA`.
2.  **Competing risks.** If a date has `censored_by`, it is set to `NA`
    wherever the censoring date is earlier: death before a primary event
    means the event cannot be observed.

``` r

events_after_entry <- all(surv$primary_event_date >= surv$interview_date, na.rm = TRUE)
deaths_after_entry <- all(surv$death_date >= surv$interview_date, na.rm = TRUE)
events_after_death <- sum(surv$death_date < surv$primary_event_date, na.rm = TRUE)
```

- All events on or after entry: TRUE
- All deaths on or after entry: TRUE
- Events recorded after a death: 0

In the minimal example no death comes before an event, so the
competing-risk rule never applies. Its Gompertz parameters put every
death exactly 365 days after entry and every primary event within 88
days ([\#54](https://github.com/Big-Life-Lab/MockData/issues/54)). This
small specification shows the rule at work, with follow-up times that
overlap:

``` r

spec <- mock_spec(
  mock_spec_date("entry", range = as.Date(c("2001-01-01", "2005-12-31"))),
  mock_spec_survival("death", anchor = "entry",
    followup_min = 0, followup_max = 3650, event_prop = 0.5),
  mock_spec_survival("event", anchor = "entry",
    followup_min = 1825, followup_max = 1825, event_prop = 1,
    censored_by = "death")
)
baseline <- generate_mock_data_native(spec, n = 1000, seed = 1)
demo <- generate_survival_dates(baseline, spec, seed = 1)
n_censored <- sum(is.na(demo$event))
```

Everyone would have the event (`event_prop = 1`) exactly five years
after entry, but 246 of 1,000 events are removed because death came
first.

One caveat about the example: `admin_censor_date` is a survival date
with `event_prop = 1`, so each person gets a random date, 1751 distinct
dates in all, rather than one study end date
([\#55](https://github.com/Big-Life-Lab/MockData/issues/55)).

## Temporal violations for QA testing

With its garbage settings back, the minimal example adds future dates to
its survival dates. MockData applies garbage after the temporal rules,
so the violations stay in the output for your validation pipeline to
find:

``` r

mock_qa <- create_mock_data(
  databaseStart = "minimal-example",
  variables = variables,
  variable_details = variable_details,
  n = 1000,
  seed = 999
)
future_threshold <- as.Date("2025-01-01")
n_future_events <- sum(mock_qa$primary_event_date > future_threshold, na.rm = TRUE)
n_future_deaths <- sum(mock_qa$death_date > future_threshold, na.rm = TRUE)
```

- Future primary events: 8
- Future deaths: 6

The [Garbage data
tutorial](https://big-life-lab.github.io/MockData/articles/tutorial-garbage-data.html#survival-data-garbage)
covers survival garbage in more detail.

## Next steps

- [`vignette("survival-dates-v05")`](https://big-life-lab.github.io/MockData/articles/survival-dates-v05.md):
  add survival dates to your own metadata, move from
  [`create_wide_survival_data()`](https://big-life-lab.github.io/MockData/reference/create_wide_survival_data.md),
  and derive observed status and follow-up time
- [`vignette("survival-design-v05")`](https://big-life-lab.github.io/MockData/articles/survival-design-v05.md):
  how the survival stage works, the three layers of data, and what
  version 0.5 does not yet do
- [`vignette("reference-config")`](https://big-life-lab.github.io/MockData/articles/reference-config.md):
  every survival column
