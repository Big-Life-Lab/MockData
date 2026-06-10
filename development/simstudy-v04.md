# MockData v0.4 Production Refactor Plan

**Status**: implemented in PR #28 and superseded by the v0.4 documentation
sprint. This document is retained as the production-refactor plan and should be
read as historical implementation context rather than an active task list.

## 1. Write The ADR First

Write a short architecture decision record before production code changes.

**Status**: complete. See `development/adr/v04-hybrid-backend.md`.

The ADR should lock these decisions:

- **Decision**: MockData adopts a hybrid backend architecture.
- **Core abstraction**: `mock_spec` is the normalized internal specification.
- **Forward compatibility**: `mock_spec` carries `spec_version`, `provenance`,
  and `model_hint` so direct APIs, recodeflow adapters, and future adapters can
  share one internal representation.
- **Default backend**: native MockData generation remains the default and must
  work without `simstudy`.
- **Optional backend**: `simstudy` is an advanced backend, initially in
  `Suggests`, gated with `requireNamespace()`.
- **License posture**: keep MockData MIT by keeping `simstudy` optional unless a
  future governance decision changes that.
- **Version target**: v0.4.0.
- **NEWS commitment**: `NEWS.md` gets a v0.4.0 section with breaking changes,
  the new spec model, migration notes, and deprecated functions.
- **Current API timeline**: existing public functions remain as wrappers through
  v0.4.0. They may be marked lifecycle-deprecated in v0.4.x after sibling
  packages have migrated, and removed no earlier than v0.5.0.
- **Non-goal**: MockData remains mock data for code development, QA, and
  documentation. It is not marketed as synthetic data for inference or privacy
  release.

## 2. Implement In Layers

Each layer should have focused tests before the next layer starts.

**Status**: complete for the v0.4.0 scope. Formula/dependency evaluation,
multi-group correlation, and Table 1 input remain deferred roadmap items.

1. **`mock_spec` core**
   - Constructors and validators.
   - Stable fields for names, types, ranges, levels, proportions, missing codes,
     garbage rules, formulas, dates, and backend hints.
   - Explicit handling for empty specs, `NULL` metadata, single-row specs, and
     `n = 0`.

2. **Input adapters**
   - Direct function-argument APIs to `mock_spec`.
   - Recodeflow `variables` + `variable_details` adapter to `mock_spec`.
   - Preserve recodeflow semantics as first-class behavior.

3. **Formula/dependency evaluator**
   - Promote the spike pattern to core: formula referent validation, topological
     ordering, cycle detection, and sandboxed evaluation in a generated-data
     environment.

4. **Native backend**
   - Generate valid baseline values from `mock_spec`.
   - Keep native support for the simple/core path without `simstudy`.
   - Add multi-group correlation strategy, including merge behavior with
     ordinary variables.

5. **Post-processing layer**
   - Missing codes.
   - Garbage values.
   - `rType` coercion.
   - Date/source-format conversion.
   - Diagnostics contract.
   - Replace the legacy `var_row` garbage shim with typed garbage specs.

6. **Spike assertion promotion**
   - Promote the strongest spike assertions into `testthat`, especially:
     categorical code/label preservation, missing-code collision diagnostics,
     seed reproducibility, censor/event date invariants, recEnd-driven
     missingness, formula dependency validation, and correlation contracts.

7. **Optional `simstudy` backend**
   - Translate supported `mock_spec` pieces to `simstudy` definitions.
   - Keep `simstudy` optional with clear errors when unavailable.
   - Test native/simstudy parity for column names, types, reproducibility, and
     expected statistical contracts.

8. **Orchestrator wrappers**
   - Gradually replace current dispatch internals.
   - Keep `create_mock_data()`, `create_cat_var()`, `create_con_var()`, and
     `create_date_var()` alive as wrappers during transition.

## 3. Keep The Current API Alive

**Status**: complete. The v0.3 public functions remain available, and
`create_mock_data()` now routes supported metadata through the v0.4 pipeline
while preserving legacy fallback paths.

Existing public functions should remain available in v0.4.0:

- `create_mock_data()`
- `create_cat_var()`
- `create_con_var()`
- `create_date_var()`
- `create_wide_survival_data()`

These should call the new layered internals where possible. Migration should be
incremental so cchsflow, chmsflow, and recodeflow users do not need a
synchronized release.

## 4. Carry-Forward Design Issues

**Status**: partly resolved. The diagnostics shape, seed discipline, native vs
`simstudy` parity tests, and optional `simstudy` posture were settled for v0.4.0.
The remaining items below should be treated as v0.5+ roadmap candidates or issue
backlog material.

Settle in the ADR or the first design note:

- Multi-group correlation merge strategy.
- Whether `mock_spec` is internal-only in v0.4.0 or partially user-facing.
- Diagnostics object shape and stability.
- `simstudy` dependency posture after governance review.
- Deprecation schedule for current public wrappers.

Track as implementation issues:

- Empty / `NULL` / single-row input behavior.
- Date `__offset` convention and whether it remains internal.
- Garbage `var_row` shim replacement.
- Distribution registry for custom backend functions.
- Seed discipline between baseline generation and post-processing.
- Native vs `simstudy` backend equivalence tests.
- Event/censoring rate tests with two-sided bounds.
- Table 1 / summary-spec source as a future adapter.

## 5. Communication

**Status**: complete as a draft communication artifact. See
`development/v04-phase-c-comms-note.md`.

Before v0.4.0 lands, write a short communication note for cchsflow, chmsflow,
and recodeflow maintainers:

- What changes.
- What does not change.
- Which functions remain available.
- What migration is optional in v0.4.0.
- When deprecation warnings may begin.
- How the mock-data framing remains distinct from synthetic-data release.
