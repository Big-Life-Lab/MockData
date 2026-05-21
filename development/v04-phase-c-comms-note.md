# MockData v0.4 Phase C Maintainer Communication Note

**Audience**: cchsflow, chmsflow, recodeflow, and MockData maintainers
**Status**: draft for maintainer review
**Branch for testing**: `dev`

## Short Version

MockData v0.4 is now available on the `dev` branch for maintainer testing. The
main change is architectural: MockData now normalizes inputs into a `mock_spec`,
then generates data through a native backend, an optional `simstudy` backend, and
a MockData-owned post-processing layer for missing codes, garbage values, and
diagnostics.

The goal is to make MockData more reliable for recodeflow-style metadata while
preserving the existing public API. No sibling package needs to migrate
immediately for v0.4.0.

## What Changed

- `mock_spec` is the normalized internal representation for mock-data
  specifications.
- New direct helper APIs exist for simple use cases:
  `mock_continuous()`, `mock_categorical()`, and `mock_date()`.
- `mock_spec_from_recodeflow()` converts recodeflow-style `variables.csv` and
  `variable_details.csv` metadata into a `mock_spec`.
- `generate_mock_data_native()` generates data from `mock_spec` without optional
  dependencies.
- `postprocess_mock_data()` applies MockData-owned missing-code and garbage-data
  semantics and attaches a `mockdata_diagnostics` attribute.
- `generate_mock_data_simstudy()` is available for supported advanced cases when
  `simstudy >= 0.8.1` is installed.
- `create_mock_data()` now routes supported metadata through the v0.4 pipeline
  and falls back to the legacy path for unsupported or explicitly lenient cases.

## What Did Not Change

- Existing v0.3 public functions remain available in v0.4.0.
- `create_mock_data()` keeps its existing signature.
- MockData remains focused on mock data for package development, QA,
  documentation, examples, and training.
- MockData is not positioning v0.4 as synthetic data for privacy release,
  inference, or population-valid analysis.
- MockData remains MIT licensed. `simstudy` is GPL-3 and optional through
  `Suggests`, not a required dependency.
- No public function removals are planned before v0.5.0.

## Compatibility Notes

- `validate = TRUE` is the default strict path. It uses the v0.4 pipeline when
  the requested metadata is supported.
- `validate = FALSE` deliberately uses the legacy, more permissive path.
- `variable_details = NULL` also uses the legacy fallback path.
- The v0.4 path returns a regular data frame with an optional
  `mockdata_diagnostics` attribute. Legacy fallback output does not include this
  attribute.
- Seeded output may differ from v0.3 even when the same seed is supplied.
  v0.4 uses the requested seed for baseline generation and `seed + 1L` for
  post-processing so missing-code and garbage injection are reproducible without
  sharing the same RNG stream as baseline generation.
- Formula-derived variables, multi-group correlations, and advanced survival
  models are intentionally deferred. Unsupported cases should either fail loudly
  or route through the legacy path, depending on the public entry point.

## What We Need Maintainers To Test

Please test against representative metadata from cchsflow, chmsflow, and
recodeflow projects, especially files that include:

- categorical variables with `recEnd` missing-code semantics;
- continuous variables with ranges or distribution parameters;
- date variables;
- garbage or invalid-value rules;
- role and `databaseStart` filtering;
- any variables that sibling packages expect MockData to generate today.

Suggested smoke test:

```r
devtools::load_all()

vars <- read.csv("path/to/variables.csv")
details <- read.csv("path/to/variable_details.csv")

mock <- create_mock_data(
  variables = vars,
  variable_details = details,
  databaseStart = "cycle1",
  n = 100,
  seed = 123,
  validate = TRUE,
  verbose = TRUE
)

str(mock)
attr(mock, "mockdata_diagnostics")
```

Also useful:

```r
spec <- mock_spec_from_recodeflow(
  variables = vars,
  variable_details = details,
  databaseStart = "cycle1"
)

validate_mock_spec(spec, strict = TRUE)
```

## What To Report

Please report:

- metadata files or patterns that unexpectedly fall back to the legacy path;
- variables that generated correctly in v0.3 but fail in v0.4;
- variables that generate but have surprising values, types, or missing-code
  behavior;
- diagnostics that are hard to interpret;
- any cchsflow/chmsflow/recodeflow assumptions about MockData output that v0.4
  appears to change;
- API ergonomics issues that make the new path hard to explain in documentation.

## Proposed Timeline

- v0.4 sits on `dev` while sibling maintainers test representative metadata.
- Documentation sprint work continues on a separate branch and PR.
- After checks, documentation, and maintainer smoke tests are complete, v0.4.0
  can be tagged and merged forward to `main`.
- Any lifecycle deprecation warnings for older APIs should wait until v0.4.x and
  only after sibling package maintainers have a clear migration path.

## Message Template

Subject: MockData v0.4 available on `dev` for sibling-package testing

MockData v0.4 is now on the `dev` branch for maintainer testing. It keeps the
existing `create_mock_data()` API, but internally routes supported metadata
through a new `mock_spec` pipeline with native generation and MockData-owned
post-processing diagnostics.

No immediate migration is required for cchsflow/chmsflow/recodeflow, and no
public function removals are planned before v0.5.0. The main ask is to try
representative `variables.csv` and `variable_details.csv` files against
`create_mock_data(validate = TRUE, verbose = TRUE)` and report any unexpected
fallbacks, failures, or output changes.

The key user-visible differences are that v0.4 output may include a
`mockdata_diagnostics` attribute, seeded output can differ from v0.3 because
post-processing uses `seed + 1L`, and optional `simstudy` support remains in
`Suggests` rather than becoming a required dependency.
