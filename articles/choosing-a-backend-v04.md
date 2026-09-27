# Choose a MockData v0.4 backend

**About this vignette:** This how-to explains when to use the default
native backend and when to try the optional `simstudy` backend. The
`simstudy` examples run when `simstudy >= 0.8.1` is installed and
otherwise render a clear message.

## The short version

Use the native backend by default.

``` r

spec <- mock_spec(
  mock_spec_continuous("age", range = c(18, 85), rtype = "integer"),
  mock_spec_categorical(
    "smoking",
    levels = c("never", "former", "current"),
    proportions = c(0.5, 0.3, 0.2),
    rtype = "character"
  )
)

native_data <- generate_mock_data_native(spec, n = 100, seed = 101)
head(native_data)
```

      age smoking
    1  84 current
    2  79   never
    3  36   never
    4  56  former
    5  58   never
    6  57   never

The native backend is always available, stays within MockData’s
MIT-licensed code, and is the backend used by
[`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md)
for supported v0.4 metadata.

Use the optional `simstudy` backend when you want to exercise that
engine path or when future MockData features need simulation mechanics
that `simstudy` already provides.

## Check whether simstudy is available

MockData keeps `simstudy` optional. It is listed in `Suggests`, not
`Imports`, so installing MockData does not require installing
`simstudy`.

``` r

simstudy_available <- requireNamespace("simstudy", quietly = TRUE) &&
  utils::packageVersion("simstudy") >= numeric_version("0.8.1")

simstudy_available
```

    [1] TRUE

If `simstudy` is unavailable, use
[`generate_mock_data_native()`](https://big-life-lab.github.io/MockData/reference/generate_mock_data_native.md).

``` r

if (!simstudy_available) {
  message(
    "The optional simstudy backend is not available in this R environment; ",
    "using generate_mock_data_native() is the recommended path."
  )
}
```

## Run the same spec through both backends

For categorical variables and uniform continuous variables, both
backends can generate the baseline data.

``` r

native_large <- generate_mock_data_native(spec, n = 2000, seed = 202)

if (simstudy_available) {
  simstudy_large <- generate_mock_data_simstudy(spec, n = 2000, seed = 202)
  head(simstudy_large)
} else {
  simstudy_large <- NULL
}
```

      age smoking
    1  26  former
    2  84  former
    3  49   never
    4  66   never
    5  59   never
    6  41 current

When `simstudy` is installed, compare broad properties rather than
expecting row-for-row equality. The engines use different internals.

``` r

if (simstudy_available) {
  c(
    native_mean_age = mean(native_large$age),
    simstudy_mean_age = mean(simstudy_large$age)
  )
}
```

      native_mean_age simstudy_mean_age
              51.7055           51.7055 

``` r

if (simstudy_available) {
  rbind(
    native = prop.table(table(factor(
      native_large$smoking,
      levels = c("never", "former", "current")
    ))),
    simstudy = prop.table(table(factor(
      simstudy_large$smoking,
      levels = c("never", "former", "current")
    )))
  )
}
```

             never former current
    native   0.504 0.2920  0.2040
    simstudy 0.487 0.2985  0.2145

## Mixed specs are allowed

The optional backend uses `simstudy` only for pieces it can currently
generate safely. Other variables route through MockData’s native backend
inside the same call.

``` r

mixed_spec <- mock_spec(
  mock_spec_categorical(
    "smoking",
    levels = c("never", "former", "current"),
    proportions = c(0.5, 0.3, 0.2),
    rtype = "character"
  ),
  mock_spec_continuous(
    "bmi",
    range = c(15, 50),
    distribution = "normal",
    mean = 27,
    sd = 5,
    rtype = "double"
  ),
  mock_spec_date(
    "interview_date",
    range = as.Date(c("2020-01-01", "2020-12-31"))
  )
)

mixed_native <- generate_mock_data_native(mixed_spec, n = 100, seed = 303)
head(mixed_native)
```

      smoking      bmi interview_date
    1   never 26.91380     2020-09-06
    2   never 24.94866     2020-02-12
    3  former 28.24664     2020-08-21
    4 current 26.31296     2020-01-20
    5  former 26.70605     2020-06-26
    6   never 32.25927     2020-08-06

``` r

if (simstudy_available) {
  mixed_simstudy <- generate_mock_data_simstudy(mixed_spec, n = 100, seed = 303)
  head(mixed_simstudy)
}
```

      smoking      bmi interview_date
    1  former 29.44966     2020-02-17
    2   never 27.36393     2020-08-22
    3   never 32.97241     2020-12-29
    4   never 27.23012     2020-05-10
    5  former 16.88193     2020-07-19
    6  former 23.62353     2020-04-14

In this example, `smoking` can be generated through `simstudy`; `bmi`
and `interview_date` stay native because MockData owns the truncated
normal and calendar-date contracts in v0.4.

## Post-processing stays MockData-owned

Missing codes, garbage values, and diagnostics are applied after
baseline generation. That is true for both backends.

``` r

post_spec <- mock_categorical(
  "response",
  levels = c("1", "97"),
  proportions = c(0.6, 0.4),
  rtype = "character",
  missing_codes = "97",
  missing_proportions = 0.2,
  garbage_rules = list(low = list(proportion = 0.1, range = "[-2, 0]"))
)

native_baseline <- generate_mock_data_native(post_spec, n = 100, seed = 404)
native_processed <- postprocess_mock_data(native_baseline, post_spec, seed = 405)

names(attr(native_processed, "mockdata_diagnostics")$variables$response)
```

    [1] "n"                                "preexisting_missing_code_indices"
    [3] "assigned_missing_indices"         "assigned_missing_codes"
    [5] "assigned_garbage_indices"         "assigned_garbage_values"         

``` r

if (simstudy_available) {
  simstudy_baseline <- generate_mock_data_simstudy(post_spec, n = 100, seed = 404)
  simstudy_processed <- postprocess_mock_data(simstudy_baseline, post_spec, seed = 405)

  names(attr(simstudy_processed, "mockdata_diagnostics")$variables$response)
}
```

    [1] "n"                                "preexisting_missing_code_indices"
    [3] "assigned_missing_indices"         "assigned_missing_codes"
    [5] "assigned_garbage_indices"         "assigned_garbage_values"         

The diagnostics shape is the same because post-processing is not
delegated to `simstudy`.

## License and dependency posture

MockData is MIT licensed. `simstudy` is GPL-3 licensed. Keeping
`simstudy` optional lets MockData keep the core package MIT while still
allowing users to try the advanced backend when that dependency is
acceptable in their project.

If your workflow needs no optional dependency, use:

``` r

generate_mock_data_native(spec, n = 10, seed = 1)
```

       age smoking
    1   63 current
    2   47 current
    3   79   never
    4   82  former
    5   74   never
    6   41   never
    7   42   never
    8   47  former
    9   48 current
    10  45  former

If your workflow explicitly wants to test the optional backend and
`simstudy` is installed, use:

``` r

if (simstudy_available) {
  generate_mock_data_simstudy(spec, n = 10, seed = 1)
}
```

       age smoking
    1   63   never
    2   47   never
    3   79 current
    4   82  former
    5   74 current
    6   41   never
    7   42   never
    8   47   never
    9   48  former
    10  45   never

## Decision guide

Choose the native backend when:

- you want the default v0.4 behavior;
- you need MockData to work without optional dependencies;
- you are generating categorical, continuous, date, missing-code, or
  garbage examples covered by the native pipeline;
- you want the simplest path for package tests and vignettes.

Try the optional `simstudy` backend when:

- `simstudy >= 0.8.1` is already acceptable in your project;
- you want to exercise the optional engine path;
- you are preparing for future features where `simstudy` provides mature
  simulation mechanics;
- you still want MockData to own missing-code, garbage-value, and
  diagnostics semantics after generation.
