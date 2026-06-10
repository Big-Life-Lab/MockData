# ADR: v0.4 Hybrid Backend Architecture

**Status**: accepted and implemented in PR #28
**Date**: 2026-05-18
**Decision owner**: MockData maintainers

## Context

MockData began as an experiment for generating mock testing data from
recodeflow-style metadata. It now supports categorical, continuous, date,
garbage-data, and survival-style examples. People are using it, and it is
becoming part of the recodeflow/cchsflow/chmsflow adoption path.

The v0.3 architecture grew organically. The current generators filter metadata,
parse ranges, infer generation parameters, generate values, apply missing codes,
inject garbage, coerce types, and return columns. That made early development
fast, but it makes cross-variable structure, validation, diagnostics, and
backend selection harder to reason about.

The v0.4 spike tested whether MockData can normalize user inputs into a
`mock_spec`, generate through either a native backend or `simstudy`, and keep
MockData-specific semantics as post-processing. Three review rounds converged on
the same conclusion: the hybrid architecture is ready for production refactor
planning.

The production refactor was implemented in PR #28 and merged to `dev` for
sibling-package testing before a v0.4.0 tag.

## Decision

MockData v0.4 will move toward a hybrid backend architecture:

- `mock_spec` is the normalized internal representation.
- Native MockData generation is the default backend and must work without
  `simstudy`.
- `simstudy` is an optional advanced backend for features where it clearly helps,
  including formula dependencies, correlations, survival durations, and mature
  simulation mechanics.
- MockData remains responsible for recodeflow semantics, simple direct APIs,
  validation, explicit missing-code conventions, garbage/invalid data,
  diagnostics, date/source-format conversion, and calendar anchoring.
- `mock_spec` carries `spec_version`, `provenance`, and `model_hint` to preserve
  adapter agnosticism.

## License And Dependency Posture

MockData remains MIT. `simstudy` is GPL-3, so it will initially be kept optional
in `Suggests` and accessed through `requireNamespace()`.

Importing `simstudy` as a required dependency would require a conscious future
governance decision.

## API And Deprecation

Current public functions remain available in v0.4.0:

- `create_mock_data()`
- `create_cat_var()`
- `create_con_var()`
- `create_date_var()`
- `create_wide_survival_data()`

These functions should become wrappers around the new layered internals where
possible. They should not be removed in v0.4.0.

Deprecation policy:

- No removal before v0.5.0.
- Lifecycle deprecation warnings may be added during v0.4.x only after sibling
  package maintainers have had a migration path.
- `NEWS.md` must include v0.4.0 migration notes and any deprecation timeline.

## Non-Goals

MockData will not market itself as synthetic data for inference, privacy release,
or population-valid statistical analysis. It generates mock data for code
development, QA, documentation, examples, and training.

## Consequences

Positive:

- Recodeflow support remains central.
- Simple users can use direct APIs without learning `simstudy`.
- Advanced users can benefit from a mature simulation backend.
- Missing codes, garbage data, dates, and diagnostics stay MockData-owned.
- Native generation keeps the package usable where optional dependencies are not
  installed.

Tradeoffs:

- The package needs a real internal spec model.
- Backends must be tested for parity where both support the same feature.
- Some spike contracts need production design: diagnostics, date offsets,
  formula syntax, custom distribution registry, and correlation merging.
- Maintaining wrappers will add short-term complexity.

## Implementation Status

The production refactor proceeded in layers:

1. `mock_spec` constructors and validators.
2. Direct and recodeflow input adapters.
3. Native backend.
4. Post-processing layer and diagnostics.
5. Promotion of spike assertions to `testthat`.
6. Optional `simstudy` backend.
7. Current API wrappers.
8. Divio documentation sprint and Phase C maintainer communication.

Formula/dependency evaluation, multi-group correlations, Table 1 adapters, and
schema-first integration remain deferred roadmap items rather than v0.4.0
commitments.

## Open Follow-Up Decisions

- Multi-group correlation merge strategy.
- Diagnostics object shape.
- Whether `mock_spec` is internal-only or partially user-facing in v0.4.0.
- How formula/dependency syntax enters from recodeflow or direct APIs.
- How Table 1 / summary specifications become a future adapter.
- How the legacy `var_row` shim used by v0.3 garbage helpers is replaced with
  typed v0.4 post-processing specs.
- Empty, `NULL`, `n = 0`, and single-row input behavior across adapters and
  backends.
- Seed discipline across native generation, post-processing, and the optional
  `simstudy` backend.
