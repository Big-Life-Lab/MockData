# Inspect diagnostics and garbage rules in MockData v0.4

**About this vignette:** This how-to shows how to inspect the
`mockdata_diagnostics` attribute added by the v0.4 post-processing
layer. The examples focus on audit trails for missing-code collisions
and garbage-value rules.

## Why diagnostics matter

Mock data often needs two kinds of unusual values:

- missing codes, such as `97` or `999`
- garbage values, such as impossible ages used to test validation code

Sometimes a value can be both meaningful and suspicious. For example,
code `97` could be a valid category in one source file and also a
declared missing code in another. MockData records diagnostics so you
can tell whether a value was drawn naturally by the baseline generator
or assigned later by post-processing.

## Create a collision case

Start with a categorical variable where `97` is both a valid level and a
declared missing code. This is deliberately awkward; it is the case
diagnostics are designed to make auditable.

``` r

response_spec <- mock_categorical(
  "response",
  levels = c("1", "97"),
  proportions = c(0.65, 0.35),
  rtype = "character",
  missing_codes = "97",
  missing_proportions = 0.20
)

baseline <- generate_mock_data_native(response_spec, n = 200, seed = 11)
table(baseline$response)
```


      1  97
    142  58 

The baseline already contains some `97` values because `97` is a valid
level. Now apply post-processing.

``` r

processed <- postprocess_mock_data(baseline, response_spec, seed = 12)
table(processed$response)
```


      1  97
    102  98 

## Read the diagnostics

Diagnostics live in a data-frame attribute.

``` r

diagnostics <- attr(processed, "mockdata_diagnostics")
names(diagnostics$variables)
```

    [1] "response"

For a variable, two fields are especially important:

- `preexisting_missing_code_indices`: rows whose baseline value already
  matched a declared missing code
- `assigned_missing_indices`: rows changed by post-processing to a
  missing code

``` r

response_diag <- diagnostics$variables$response

length(response_diag$preexisting_missing_code_indices)
```

    [1] 58

``` r

length(response_diag$assigned_missing_indices)
```

    [1] 40

These two sets should be distinct.

``` r

intersect(
  response_diag$preexisting_missing_code_indices,
  response_diag$assigned_missing_indices
)
```

    integer(0)

Both groups contain `97` in the final data, but they mean different
things.

``` r

head(processed$response[response_diag$preexisting_missing_code_indices])
```

    [1] "97" "97" "97" "97" "97" "97"

``` r

head(processed$response[response_diag$assigned_missing_indices])
```

    [1] "97" "97" "97" "97" "97" "97"

Use the diagnostics when your tests need to distinguish a naturally
drawn collision from a missing code assigned by MockData.

## Add garbage rules

Garbage rules deliberately inject invalid or out-of-range values. Here
`age` has one missing code and two garbage rules:

- `low`: values below the valid age range
- `high`: values above the valid age range

``` r

age_spec <- mock_continuous(
  "age",
  range = c(18, 85),
  distribution = "normal",
  mean = 50,
  sd = 12,
  rtype = "integer",
  missing_codes = 999,
  missing_proportions = 0.05,
  garbage_rules = list(
    high = list(proportion = 0.03, range = "[120, 150]"),
    low = list(proportion = 0.04, range = "[0, 17]")
  )
)

age_baseline <- generate_mock_data_native(age_spec, n = 200, seed = 21)
age_processed <- postprocess_mock_data(age_baseline, age_spec, seed = 22)
```

MockData applies garbage rules in canonical order: `low`, then `high`,
then any other named rules in caller order. The diagnostics use the same
order.

``` r

age_diag <- attr(age_processed, "mockdata_diagnostics")$variables$age
names(age_diag$assigned_garbage_indices)
```

    [1] "low"  "high"

Inspect the assigned rows.

``` r

low_idx <- age_diag$assigned_garbage_indices$low
high_idx <- age_diag$assigned_garbage_indices$high

length(low_idx)
```

    [1] 8

``` r

range(age_processed$age[low_idx])
```

    [1]  0 16

``` r

length(high_idx)
```

    [1] 6

``` r

range(age_processed$age[high_idx])
```

    [1] 127 148

Missing-code rows are protected from garbage assignment.

``` r

intersect(age_diag$assigned_missing_indices, low_idx)
```

    integer(0)

``` r

intersect(age_diag$assigned_missing_indices, high_idx)
```

    integer(0)

## Combine variables in one pipeline

Most workflows generate several variables together. The same diagnostics
shape is used for every variable in the spec.

``` r

spec <- mock_spec(
  response_spec$variables$response,
  age_spec$variables$age
)

combined_baseline <- generate_mock_data_native(spec, n = 200, seed = 31)
combined_processed <- postprocess_mock_data(combined_baseline, spec, seed = 32)

combined_diag <- attr(combined_processed, "mockdata_diagnostics")
names(combined_diag$variables)
```

    [1] "response" "age"     

A compact audit summary can be built from the diagnostics.

``` r

data.frame(
  variable = names(combined_diag$variables),
  preexisting_missing = vapply(
    combined_diag$variables,
    function(x) length(x$preexisting_missing_code_indices),
    integer(1)
  ),
  assigned_missing = vapply(
    combined_diag$variables,
    function(x) length(x$assigned_missing_indices),
    integer(1)
  ),
  assigned_garbage = vapply(
    combined_diag$variables,
    function(x) sum(lengths(x$assigned_garbage_indices)),
    integer(1)
  )
)
```

             variable preexisting_missing assigned_missing assigned_garbage
    response response                  73               40                0
    age           age                   0               10               14

## Preserve diagnostics before reshaping

Diagnostics are stored as an attribute on the returned data frame. Some
downstream operations keep attributes and others drop them. If
diagnostics are part of your QA workflow, save them before heavy
reshaping or joins.

``` r

saved_diagnostics <- attr(combined_processed, "mockdata_diagnostics")

subset_data <- combined_processed[1:5, ]
is.null(attr(subset_data, "mockdata_diagnostics"))
```

    [1] FALSE

``` r

names(saved_diagnostics$variables)
```

    [1] "response" "age"     

## Re-running post-processing

[`postprocess_mock_data()`](https://big-life-lab.github.io/MockData/reference/postprocess_mock_data.md)
is intentionally not idempotent. Running it again on a data frame that
already has `mockdata_diagnostics` would double-contaminate the data, so
MockData stops loudly.

``` r

postprocess_mock_data(combined_processed, spec, seed = 33)
```

    Error:
    ! postprocess_mock_data() appears to have already run on this data. Start from baseline generated data to avoid double post-processing.

Start again from baseline data when you want a fresh post-processing
draw.
