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
- `simstudy` can preserve categorical codes via categorical labels.
- Truncated normal age generation can be handled with a `simstudy` custom
  distribution while MockData still owns range parsing and rType coercion.
- MockData-style explicit missing codes and garbage values can remain
  post-processing after baseline valid-value generation.
- Correlated height/weight generation is straightforward through
  `simstudy::genCorData()` when correlation is declared in `mock_spec`.
- Survival durations can be generated through `simstudy::defSurv()` /
  `simstudy::genSurv()` and then anchored back to MockData-owned calendar
  dates.
- The same `mock_spec` can drive a native MockData-style generation path when
  `simstudy` is absent.
- Missing-code collisions are detectable if post-processing preserves assignment
  diagnostics. This matters when a valid drawn value can equal an explicit
  missing code.
- Seed reproducibility can be asserted across native and `simstudy` paths.

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

## Review Gaps Addressed After First PR Review

- Added `spec_version`, `provenance`, and `model_hint` fields.
- Added a fail-loud `from_linkml()` placeholder to keep a future third adapter
  visible without pretending it is implemented.
- Added native backend generation from the same `mock_spec`.
- Added a missing-code collision case where `97` can be both a valid generated
  value and an assigned missing code.
- Moved the height/weight correlation example into a `mock_spec` declaration.
- Added seed reproducibility assertions.
