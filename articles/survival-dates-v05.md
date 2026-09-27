# Add survival dates to your metadata

**About this guide:** How to describe survival dates in `variables.csv`,
move from
[`create_wide_survival_data()`](https://big-life-lab.github.io/MockData/reference/create_wide_survival_data.md)
to
[`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md),
derive status and follow-up time, and keep the uncontaminated data.
Every example runs when the vignette is built, and hidden checks stop
the build if MockData stops behaving as this page describes.

## Mark dates as survival dates

A survival date is a date variable whose `variables.csv` row names its
entry date in the `anchor` column. It also needs a follow-up window
(`followup_min`, `followup_max`, in days after the anchor) and
`event_prop`, the share of people who have the event. An optional
`censored_by` names a competing survival date that removes this one
where it comes first.

This cohort has an entry date, a primary event that death can pre-empt,
death, loss to follow-up, and administrative censoring:

``` r

variables <- data.frame(
  variable = c("entry_date", "event_date", "death_date", "ltfu_date", "admin_censor_date"),
  variableType = "Date",
  rType = "date",
  role = "enabled",
  distribution = "uniform",
  anchor = c("", "entry_date", "entry_date", "entry_date", "entry_date"),
  censored_by = c("", "death_date", "", "", ""),
  followup_min = c(NA, 0, 0, 0, 1825),
  followup_max = c(NA, 3650, 3650, 3650, 3650),
  event_prop = c(NA, 0.4, 0.3, 0.1, 1),
  sourceFormat = "analysis",
  stringsAsFactors = FALSE
)

variable_details <- data.frame(
  variable = variables$variable,
  recStart = c("[2001-01-01,2005-12-31]", rep("[2001-01-01,2040-12-31]", 4)),
  recEnd = "copy",
  proportion = 1,
  stringsAsFactors = FALSE
)

cohort <- create_mock_data(
  databaseStart = "study",
  variables = variables,
  variable_details = variable_details,
  n = 1000,
  seed = 1
)
head(cohort)
```

      entry_date death_date ltfu_date admin_censor_date event_date
    1 2004-10-26       <NA>      <NA>        2010-01-03       <NA>
    2 2004-10-14       <NA>      <NA>        2013-07-15 2007-09-29
    3 2001-09-28       <NA>      <NA>        2008-01-12       <NA>
    4 2004-04-09       <NA>      <NA>        2014-03-07       <NA>
    5 2003-04-21       <NA>      <NA>        2008-12-26       <NA>
    6 2004-12-21 2014-09-28      <NA>        2010-06-13       <NA>

300 of 1,000 people have a death date, exactly `floor(n * event_prop)`,
and 0 events fall after a death. The `recStart` ranges on the survival
dates’ `variable_details` rows are not used; the follow-up window
decides when events happen.

## Move from create_wide_survival_data()

Before MockData 0.5, survival dates were generated separately. The same
metadata, without `anchor` and `censored_by`, went to
[`create_wide_survival_data()`](https://big-life-lab.github.io/MockData/reference/create_wide_survival_data.md):

``` r

legacy_variables <- variables[, setdiff(names(variables), c("anchor", "censored_by"))]

legacy <- create_wide_survival_data(
  var_entry_date = "entry_date",
  var_event_date = "event_date",
  var_death_date = "death_date",
  var_ltfu = "ltfu_date",
  var_admin_censor = "admin_censor_date",
  databaseStart = "study",
  variables = legacy_variables,
  variable_details = variable_details,
  n = 1000,
  seed = 1
)
```

To migrate, add `anchor` to every survival date’s row, and `censored_by`
where a competing risk applies (the legacy function always let death
censor the primary event). Then call
[`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md),
as in the first section.

Both paths produce the same five columns and the same number of deaths
(300), and both remove events that follow a death. The seeded values
differ, because MockData 0.5 draws from its own random-number streams;
regenerate any expected values you pinned against the old function.
[`create_wide_survival_data()`](https://big-life-lab.github.io/MockData/reference/create_wide_survival_data.md)
still works, but warns once per session that it is deprecated.

## Derive observed status and follow-up time

A death date existing is not the same as a death being observed.
Observation ends at the earliest of death, loss to follow-up and
administrative censoring, and a death after that point was not observed.
Status and follow-up time must therefore come from the same observation
window.

Formula variables compute both during generation. Each gets a
`mockFormula` in `variable_details`; a formula cannot return a date, so
the end of observation is written out in each:

``` r

end_of_observation <- "pmin(death_date, ltfu_date, admin_censor_date, na.rm = TRUE)"

derived_variables <- rbind(variables, data.frame(
  variable = c("death_status", "followup_days"),
  variableType = "Continuous",
  rType = c("integer", "double"),
  role = "enabled",
  distribution = NA,
  anchor = "",
  censored_by = "",
  followup_min = NA,
  followup_max = NA,
  event_prop = NA,
  sourceFormat = "analysis",
  stringsAsFactors = FALSE
))

derived_details <- rbind(
  transform(variable_details, mockFormula = ""),
  data.frame(
    variable = c("death_status", "followup_days"),
    recStart = "DerivedVar::[death_date, ltfu_date, admin_censor_date]",
    recEnd = c("Func::death_status", "Func::followup_days"),
    proportion = NA,
    mockFormula = c(
      paste0("as.integer(!is.na(death_date) & death_date == ", end_of_observation, ")"),
      paste0("as.numeric(", end_of_observation, " - entry_date)")
    ),
    stringsAsFactors = FALSE
  )
)

derived <- create_mock_data(
  databaseStart = "study",
  variables = derived_variables,
  variable_details = derived_details,
  n = 1000,
  seed = 1
)
head(derived[, c("death_date", "ltfu_date", "admin_censor_date",
                 "death_status", "followup_days")])
```

      death_date ltfu_date admin_censor_date death_status followup_days
    1       <NA>      <NA>        2010-01-03            0          1895
    2       <NA>      <NA>        2013-07-15            0          3196
    3       <NA>      <NA>        2008-01-12            0          2297
    4       <NA>      <NA>        2014-03-07            0          3619
    5       <NA>      <NA>        2008-12-26            0          2076
    6 2014-09-28      <NA>        2010-06-13            0          2000

The same quantities can be computed in R after generation, which is how
an analysis would compute them from observed data:

``` r

end_date <- do.call(
  pmin,
  c(derived[c("death_date", "ltfu_date", "admin_censor_date")], na.rm = TRUE)
)
r_status <- as.integer(!is.na(derived$death_date) & derived$death_date == end_date)
r_days <- as.numeric(end_date - derived$entry_date)
```

The formula columns and the R calculation agree on every row. 83 of the
300 death dates fall after loss to follow-up or administrative
censoring, so their status is 0: counting `!is.na(death_date)` alone
would have called them deaths. A death on the censoring date counts as
observed.

The two approaches agree here because this metadata adds no missing
codes or garbage. When it does, formula columns keep describing the
generated values while the date columns are contaminated; see
[`vignette("survival-design-v05")`](https://big-life-lab.github.io/MockData/articles/survival-design-v05.md).

## Keep the uncontaminated data

[`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md)
returns data after missing codes and garbage are applied. To keep the
generated values as well, run the stages yourself and hold on to the
data before
[`postprocess_mock_data()`](https://big-life-lab.github.io/MockData/reference/postprocess_mock_data.md):

``` r

garbage_variables <- add_garbage(
  variables, "death_date",
  garbage_high_prop = 0.1,
  garbage_high_range = "[2090-01-01;2090-12-31]"
)
spec <- mock_spec_from_recodeflow(garbage_variables, variable_details)

clean <- generate_survival_dates(
  generate_mock_data_native(spec, n = 1000, seed = 3),
  spec, seed = 3
)
observed <- postprocess_mock_data(clean, spec, seed = 3)
```

`clean` holds the generated dates; `observed` is what
[`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md)
would return. They differ in 30 rows, exactly the rows the
`mockdata_diagnostics` attribute records as garbage.

## Common errors

A date with survival parameters but no `anchor` stops generation with a
message that names the fix:

``` r

no_anchor_message <- tryCatch(
  create_mock_data("study", legacy_variables, variable_details, n = 10, seed = 1),
  error = conditionMessage
)
cat(no_anchor_message)
```

    Date variable 'event_date' has survival parameter(s) followup_min, followup_max, event_prop but no anchor. Add anchor = "<entry-date variable>" to its variables row to generate it as a survival date, or remove the survival parameters.
    Metadata validation failed while building the v0.4 specification. Fix the metadata as the message above describes. Survival dates are generated only by the v0.4 pipeline, so validate = FALSE is not a workaround for survival dates.

`validate = FALSE` is not a workaround: survival dates are generated
only by the v0.4 pipeline, and the legacy generator stops on metadata
that sets `anchor`. Survival dates and their anchors also need
`sourceFormat = "analysis"` in this version.

## See also

- [`vignette("tutorial-survival-data")`](https://big-life-lab.github.io/MockData/articles/tutorial-survival-data.md)
  for a first walk through survival data
- [`vignette("survival-design-v05")`](https://big-life-lab.github.io/MockData/articles/survival-design-v05.md)
  for how the stage works and why
- [`vignette("reference-config")`](https://big-life-lab.github.io/MockData/articles/reference-config.md)
  for every survival column
