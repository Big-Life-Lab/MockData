# MockData v0.4 simstudy Spike

This directory contains a disposable architecture spike for MockData v0.4.
It is intentionally outside the package build and is excluded by
`.Rbuildignore`.

The working thesis:

> MockData remains the recodeflow-native, MIT-licensed interface for practical
> mock data. `simstudy` is evaluated as an optional advanced engine for cases
> where it clearly improves robustness, performance, or modeling capability.

## Run

Install `simstudy` into a temporary library, then run:

```r
lib <- "/private/tmp/mockdata-simstudy-lib"
dir.create(lib, recursive = TRUE, showWarnings = FALSE)
install.packages("simstudy", lib = lib, repos = "https://cloud.r-project.org")

source("development/v04-simstudy-spike/prototype.R")
```

The prototype expects that temporary library path by default. It does not
modify `DESCRIPTION`, `renv.lock`, or the package library.

To exercise the native fallback path without `simstudy`, point the temporary
library variable at an empty path:

```sh
MOCKDATA_SIMSTUDY_LIB=/private/tmp/no-simstudy-lib \
  Rscript --vanilla development/v04-simstudy-spike/prototype.R
```

## What This Prototype Tests

- Recodeflow-style metadata can normalize into a small internal `mock_spec`.
- The same `mock_spec` can translate to `simstudy::defData()` definitions for
  age, smoking, interview date offsets, and one formula dependency.
- `simstudy` can preserve recodeflow categorical codes via categorical levels,
  and both backends can also generate non-numeric categorical labels such as
  `"never"`, `"former"`, and `"current"`.
- Truncated normal age generation can be handled with a `simstudy` custom
  distribution while MockData still owns range parsing and rType coercion.
- MockData-style explicit missing codes and garbage values can remain
  post-processing after baseline valid-value generation.
- Correlated height/weight generation is straightforward through
  `simstudy::genCorData()` when correlation parameters are declared in
  `mock_spec` and translated through the backend definition layer.
- Survival durations can be generated through `simstudy::defSurv()` /
  `simstudy::genSurv()` and then anchored back to MockData-owned calendar
  dates.
- The same `mock_spec` can drive a native MockData-style generation path when
  `simstudy` is absent.
- Missing-code collisions are detectable if post-processing preserves assignment
  diagnostics. This matters when a valid drawn value can equal an explicit
  missing code.
- Seed reproducibility can be asserted across native and `simstudy` paths.
- Formula dependencies can be validated for missing referents and sorted so
  formula variables are generated after their inputs.
- Truncated-normal boundary collapse now fails loudly instead of returning
  `NaN`.

## Early Read

This first pass supports the hybrid design:

- `simstudy` looks strong as a generation engine.
- MockData should still own recodeflow semantics, direct simple APIs, validation,
  missing-code conventions, garbage data, source formats, and calendar anchoring.
- The normalized `mock_spec` abstraction is useful enough to keep testing.

Open questions remain around dependency/license posture, error wrapping,
structural constraints, and whether ordinary simple variables should use native
MockData generation or route through `simstudy`.

## License and Dependency Posture

`simstudy` is GPL-3. MockData is currently MIT. This spike treats `simstudy` as
an optional advanced backend rather than a required package dependency. A future
architecture decision needs to explicitly decide whether:

- MockData keeps `simstudy` in `Suggests` with a soft `requireNamespace()` gate.
- MockData imports `simstudy` and accepts the license/governance implications.
- MockData keeps a native engine and only borrows design ideas from `simstudy`.

The current prototype supports the first option technically: the native fallback
path runs without loading `simstudy`.

## Prototype Contracts Surfaced

- `model_hint` is currently a small enum in the prototype rather than an
  unrestricted string.
- `provenance` is stored as structured metadata and displayed compactly in the
  printed spec table.
- `mockdata_diagnostics` is the prototype mechanism for preserving assignment
  state after post-processing. This is what lets MockData distinguish a value
  that was drawn as valid from the same value assigned as an explicit missing
  code.
- Survival date columns use mutually exclusive `event_date` and `censor_date`
  values. Event rows do not also receive a censoring date.

## Review Gaps Addressed After First PR Review

- Added `spec_version`, `provenance`, and `model_hint` fields.
- Added a fail-loud `from_linkml()` placeholder to keep a future third adapter
  visible without pretending it is implemented.
- Added native backend generation from the same `mock_spec`.
- Added a missing-code collision case where `97` can be both a valid generated
  value and an assigned missing code.
- Moved the height/weight correlation example into a `mock_spec` declaration.
- Added seed reproducibility assertions.

## Review Gaps Addressed After Second PR Review

- Fixed the survival censoring semantic bug where event rows also had
  `censor_date` populated.
- Routed correlation parameters through `mock_spec` and the backend definition
  layer, with both `simstudy` and native Cholesky-based generation paths.
- Added formula referent validation and dependency ordering.
- Added statistical-contract assertions for truncated normal moments,
  categorical proportions, garbage rates, and correlation marginals.
- Added non-numeric categorical label coverage.

## Remaining Questions Before Production Refactor

- Whether `mockdata_diagnostics` should become a formal internal contract or a
  different diagnostics object.
- How much of the prototype `mock_spec` should become user-facing for advanced
  users.
- Whether formula/dependency syntax should come from recodeflow metadata,
  direct MockData arguments, or a future third adapter.
- Whether `simstudy` remains a `Suggests` backend long term or becomes a
  stronger package dependency after governance review.

## Internal Contracts Not Yet Generalized

The prototype deliberately encodes a few implementation contracts that are
useful evidence, but not production-ready API decisions:

- Date variables use hidden `__offset` companion columns during generation, then
  convert those offsets to calendar dates in post-processing.
- Custom `simstudy` distributions are resolved by global function name, as with
  `mockdata_rtrunc_norm`; production code likely needs an explicit distribution
  registry.
- Formula variables are added directly to `mock_spec` in the spike rather than
  parsed from recodeflow metadata.
- Garbage post-processing still rebuilds a row-shaped `var_row` object to reuse
  the v0.3 `apply_garbage()` helper.
- The prototype uses `seed + 1` for post-processing so baseline generation and
  missing/garbage assignment are reproducible but distinct.
- Correlated variables currently use a separate backend path from ordinary
  `defData()` generation; production code needs a merge strategy for multiple
  correlation groups and ordinary variables.
