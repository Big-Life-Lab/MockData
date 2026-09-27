# Create a survival date variable specification

`mock_spec_survival()` describes a date generated relative to an anchor
(entry) date: `floor(n * event_prop)` rows receive a date a follow-up
time after the anchor, drawn within `[followup_min, followup_max]` days,
and the rest are `NA` (censored). Survival variables are computed after
baseline generation by
[`generate_survival_dates()`](https://big-life-lab.github.io/MockData/reference/generate_survival_dates.md),
so the anchor must be another variable in the same
[`mock_spec()`](https://big-life-lab.github.io/MockData/reference/mock_spec.md).

## Usage

``` r
mock_spec_survival(
  name,
  anchor,
  followup_min,
  followup_max,
  event_prop,
  distribution = "uniform",
  censored_by = NULL,
  shape = NULL,
  rate = NULL,
  source_format = "analysis",
  missing_codes = character(0),
  missing_proportions = numeric(0),
  garbage_rules = list(),
  provenance = "direct",
  model_hint = "native-postprocess"
)
```

## Arguments

- name:

  Variable name.

- anchor:

  Name of the date variable this date is generated relative to.

- followup_min, followup_max:

  Follow-up window in days after the anchor.

- event_prop:

  Share of rows that receive an event, in `[0, 1]`.

- distribution:

  Follow-up time distribution: `"uniform"`, `"exponential"`, or
  `"gompertz"`.

- censored_by:

  Optional name of a competing survival variable with the same anchor.
  Where that date is earlier than this one, this one becomes `NA`.

- shape, rate:

  Optional Gompertz parameters (defaults 0.1 and 0.0001). The
  exponential distribution derives its rate from the follow-up window.

- source_format:

  Output format. Only `"analysis"` (R `Date`) is supported for survival
  dates.

- missing_codes, missing_proportions, garbage_rules, provenance,
  model_hint:

  As for other variable specifications; applied by post-processing after
  the survival rules.

## Value

A `mock_spec_variable` object of type `"survival"`.

## See also

[`generate_survival_dates()`](https://big-life-lab.github.io/MockData/reference/generate_survival_dates.md),
[`mock_spec_date()`](https://big-life-lab.github.io/MockData/reference/mock_spec_date.md)

Other mock specification APIs:
[`mock_spec()`](https://big-life-lab.github.io/MockData/reference/mock_spec.md),
[`mock_spec_categorical()`](https://big-life-lab.github.io/MockData/reference/mock_spec_categorical.md),
[`mock_spec_continuous()`](https://big-life-lab.github.io/MockData/reference/mock_spec_continuous.md),
[`mock_spec_date()`](https://big-life-lab.github.io/MockData/reference/mock_spec_date.md),
[`mock_spec_formula()`](https://big-life-lab.github.io/MockData/reference/mock_spec_formula.md),
[`mock_spec_from_recodeflow()`](https://big-life-lab.github.io/MockData/reference/mock_spec_from_recodeflow.md)

## Examples

``` r
spec <- mock_spec(
  mock_spec_date("entry", range = as.Date(c("2001-01-01", "2005-12-31"))),
  mock_spec_survival("death", anchor = "entry",
    followup_min = 365, followup_max = 7300, event_prop = 0.2),
  mock_spec_survival("event", anchor = "entry",
    followup_min = 0, followup_max = 5475, event_prop = 0.3,
    censored_by = "death")
)
validate_mock_spec(spec)
#> MockData mock_spec validation result: valid
```
