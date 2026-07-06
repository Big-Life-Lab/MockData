# ADR: v0.5 Seed and RNG-Stream Contract

**Status**: ACCEPTED 2026-07-06 — full-bundle contract, co-released with #39 in v0.5. Implementation is a separate ADR-gated plan (not yet written). Any individual decision below remains open to maintainer revision before implementation begins.
**Date**: drafted 2026-07-03; accepted 2026-07-06
**Decision owner**: MockData maintainers
**Issue**: #38 (fulfils #22; resolves #33 item 11)

## Decision summary

| # | Question | Decision |
|---|---|---|
| D1 | Stream-derivation scheme | **(b)** L'Ecuyer-CMRG stage sub-streams via `parallel::nextRNGStream()` |
| D2 | Isolation across paths | **(a)** Unify all three paths on save/restore (no path perturbs the caller's RNG) |
| D3 | Guarantee scope | Ratified as stated: same seed + spec + **version** ⇒ identical output; not across minor versions |
| D4 | Fallback stream-switch announcement | **(a)** Always-on, once-per-call message |
| Timing | Release | **Co-release with #39** in v0.5 — one break, one NEWS note (maintainer-selected) |

Rationale for the bundle: #39 (formula evaluator) reorders draws and so forces a
seeded-output break in v0.5 independent of this ADR. Given that break is already
budgeted and being spent, adopting the full principled contract in the same
release is near-zero marginal cost, and it means #42 (correlations) later needs
**no** further break. The minimal alternative would spend the #39 break without
buying the contract, then require a second break for #42.

## Context

MockData accepts a single public `seed` argument and promises reproducible mock
data. Today that promise is kept by three different mechanisms that do not agree
on either *how the seed is consumed* or *whether generation perturbs the
caller's random state*. Before v0.5 adds features that necessarily change seeded
output — the formula evaluator (#39) reorders draws by dependency, correlated
variables (#42) add a third RNG consumer — the contract must be defined once, so
those features land as a single, well-documented reproducibility break rather
than a series of silent ones.

### The three regimes today

Verified against `dev` at merge commit `6099176` (2026-07-03).

**1. v0.4 native path** — `.create_mock_data_v04()` (`R/create_mock_data.R:98-103`):

```r
baseline <- generate_mock_data_native(spec, n = n, seed = seed)
postprocess_seed <- if (is.null(seed)) NULL else seed + 1L
postprocess_mock_data(baseline, spec, seed = postprocess_seed)
```

Both stages run inside `.with_mock_seed()` (`R/mock_spec_native.R:8-34`), which
**saves `.Random.seed`, calls `set.seed()`, and restores the caller's
`.Random.seed` on exit** — generation is reproducible *and* non-invasive to the
user's RNG stream. Baseline uses `seed`; post-processing uses `seed + 1L`. The
`seed + 1L` split is explicitly a pragmatic choice (its own code comment calls it
that), giving baseline and post-processing "independent" streams by using
adjacent Mersenne-Twister seeds.

**2. Legacy path** — `create_mock_data()` main body (`R/create_mock_data.R:349-352`):

```r
if (!is.null(seed)) {
  if (verbose) message("Setting random seed: ", seed)
  set.seed(seed)
}
```

A bare `set.seed(seed)` with **no save/restore** — this *clobbers the caller's
global RNG stream*. Generators are then invoked with `seed = NULL`
(`R/create_mock_data.R:424`, "Global seed already set") and draw sequentially
from that one stream. The legacy per-variable helpers
(`sample_with_proportions()`, `make_garbage()`, `apply_garbage()` in
`R/mockdata_helpers.R`) each *can* self-seed, but on this path receive `NULL`.

**3. simstudy backend** — `generate_mock_data_simstudy()`
(`R/mock_spec_simstudy.R:223-231`): uses `.with_mock_seed(seed, ...)` — same
save/restore as the native path, but a single `seed` (no `+ 1L` split).

### What actually differs (and why it matters)

Two independent axes are conflated in the current design:

| Axis | Native (v0.4) | simstudy | Legacy |
|---|---|---|---|
| **Isolation** — does generation perturb the caller's RNG? | No (save/restore) | No (save/restore) | **Yes (clobbers)** |
| **Stream derivation** — how sub-stages get distinct streams | `seed`, `seed+1L` | single `seed` | one shared stream, sequential draws |
| **RNG kind** | ambient `RNGkind()` | ambient `RNGkind()` | ambient `RNGkind()` |

Three consequences:

1. **Isolation is inconsistent.** `create_mock_data(..., validate = TRUE)` leaves
   the user's `.Random.seed` untouched; `create_mock_data(..., validate = FALSE)`
   silently resets it. A user who seeds their own analysis, calls MockData on the
   legacy path, then draws more random numbers gets *different* downstream results
   than if they had used the v0.4 path — a surprising, undocumented side effect.

2. **Stream derivation is unprincipled.** `seed` and `seed + 1L` produce
   well-separated Mersenne-Twister states in practice (R's seeding scrambles the
   integer through a linear congruential step), so overlap is not a *practical*
   risk today. But there is no theoretical guarantee, and the scheme does not
   generalize: #39 and #42 will need a third and fourth stream, and "`seed + 2L`,
   `seed + 3L`" is not a contract anyone should have to reason about.

3. **RNG kind is unpinned.** All paths call `set.seed(seed)` under whatever
   `RNGkind()` the session happens to have. A user who has set a non-default
   generator gets different mock data for the same `seed` — reproducibility is
   silently conditional on ambient session state the contract never mentions.

### Constraints

- **One break, budgeted.** The post-v0.4.0 plan allocates exactly one
  seeded-output break for v0.5, covered by one NEWS migration note. This ADR's
  implementation must land in the same release as #39 (formula evaluator), which
  independently reorders draws — see Migration.
- **Dependency ethos.** MockData is MIT and `Imports: stats` only. `parallel` is
  a base R package (present in every R installation, no new external
  dependency), so it is available for RNG-stream work at zero dependency cost.
  A non-base dependency such as `withr` would need explicit justification.
- **Downstream.** cchsflow/chmsflow (CRAN) consume the recodeflow adapter, not
  the RNG internals, so this change does not touch shared metadata semantics —
  but their test suites may pin MockData output, so the break must be announced.
- **R floor** ≥ 4.2.0; `parallel::nextRNGStream()` and `"L'Ecuyer-CMRG"` have
  been available far longer, so no floor concern.

## Decision points

Each is a decision the maintainer must make. Recommendations are given but not
enacted — no code is written until this ADR is accepted.

### D1 — Stream-derivation scheme

How do distinct generation stages (baseline, post-processing, and future formula
/ correlation stages) get non-overlapping, reproducible streams from one public
`seed`?

- **(a) Document the status quo.** Keep `seed` / `seed + 1L`; write down that
  adjacent seeds are treated as independent. Cheapest; no output break for the
  native path. But it does not generalize to more stages and never becomes
  *principled*.
- **(b) L'Ecuyer-CMRG sub-streams via `parallel::nextRNGStream()`.** Seed once
  from the public `seed` under `RNGkind("L'Ecuyer-CMRG")`, then advance one
  guaranteed-independent sub-stream per stage. Theoretically sound, base-R only,
  extends to any number of stages. Cost: changes the RNG kind, so **all seeded
  output changes** (this is the budgeted break).
- **(c) Hash-derived per-stage seeds.** Derive each stage's integer seed by
  hashing `(seed, stage_name)`. Generalizes and reads clearly, but still relies
  on Mersenne-Twister seed-scrambling for independence (same theoretical gap as
  (a), just tidier) and adds a hashing helper.

**Recommendation: (b), at stage granularity.** It is the only option that makes
"independent streams" a guarantee rather than an empirical accident, costs no new
dependency, and scales to the #39/#40/#42 stages without inventing new arithmetic
each time. Per-*variable* sub-streams are explicitly **out of scope** (YAGNI
until parallel generation exists); stages, not variables, are the unit.

### D2 — Isolation: unify the three paths

Should all paths adopt the native path's save/restore behaviour, so no
`create_mock_data()` call ever perturbs the caller's RNG stream?

- **(a) Unify on save/restore.** Route the legacy path's seeding through the same
  wrapper as native/simstudy. Removes the surprising side effect; makes isolation
  a uniform guarantee. Changes legacy-path seeded output (already inside the
  budgeted break) and touches a stable code path.
- **(b) Freeze legacy as-is.** Document that the legacy (`validate = FALSE`) path
  clobbers the RNG stream and leave it; only the v0.4 path gets the new contract.
  Smaller blast radius, but the contract then has an asterisk and the legacy path
  keeps a genuine footgun.

**Recommendation: (a).** Isolation should be a property of *MockData*, not of
which internal path a call happens to take. Extend `.with_mock_seed()` to also
save/restore `RNGkind` (needed for D1 (b) regardless), set L'Ecuyer-CMRG within
scope, and have every path — native, simstudy, and legacy — generate inside it.
This unifies all three regimes under one mechanism and confines the non-default
RNG kind to the generation scope so the user's session generator is untouched.

### D3 — Guarantee scope (what `seed` promises)

**Recommendation** (a statement to ratify, not options):

> Given identical `seed`, identical resolved `mock_spec`, and identical MockData
> **package version**, `create_mock_data()` returns identical output — regardless
> of backend path, ambient `RNGkind()`, or the caller's prior RNG state, and
> without altering that prior state. Reproducibility is **not** guaranteed across
> MockData minor versions; each break is announced in NEWS. Nothing about the
> *statistical* properties of the values (independence across variables,
> distributional fidelity) is promised — see the design-philosophy scope
> boundary.

Pinning RNG kind inside the generation scope (D1 (b) / D2 (a)) is what makes the
"regardless of ambient `RNGkind()`" clause true.

### D4 — Fallback stream-switch announcement (resolves #33 item 11)

When the v0.4 path falls back to the legacy engine for an unsupported feature, it
switches RNG regimes for the same `seed` (different output), today announced only
under `verbose = TRUE`. Under the new contract the two regimes differ by RNG kind
as well, widening the gap.

- **(a) Always-on, once-per-call message** when a fallback switches streams.
- **(b) Keep it `verbose`-gated.**

**Recommendation: (a).** A silent change in what `seed` produces is exactly the
class of surprise this ADR exists to remove. One `message()` per call (not per
variable) is proportionate.

## Consequences

**If accepted as recommended (D1(b), D2(a), D3, D4(a)):**

- One seeded-output break for every path, in v0.5, co-released with #39.
- `.with_mock_seed()` becomes the single seeding primitive: save/restore
  `.Random.seed` **and** `RNGkind`, set L'Ecuyer-CMRG, expose a per-stage
  sub-stream helper. Native, simstudy, and legacy paths all route through it.
- The `seed + 1L` arithmetic in `.create_mock_data_v04()` is replaced by named
  stage sub-streams (`"baseline"`, `"postprocess"`, later `"formula"`,
  `"correlate"`).
- `create_mock_data()` no longer perturbs the caller's RNG on any path.
- Reproducibility becomes independent of the user's ambient `RNGkind()`.

**Costs / risks:**

- Every existing test that pins a specific generated value breaks once and must
  be re-baselined in the same PR. This is the budgeted break, but it is real work
  and must be done deliberately (regenerate expected values, eyeball a sample for
  sanity, not blind-accept).
- Touching the stable legacy path (D2 (a)) carries regression risk; mitigated by
  the characterization tests merged in #35 and the new pinned-value suite below.

## Test strategy (fulfils #22)

A new `tests/testthat/test-seed-contract.R` pinning the ratified contract:

1. **Determinism** — same `seed` + same spec ⇒ `identical()` output, across the
   native path, the simstudy path (skip if `simstudy` absent), and the legacy
   (`validate = FALSE`) path.
2. **Isolation** — capture `.Random.seed` before and after a seeded
   `create_mock_data()` call on *every* path; assert unchanged. This is the
   regression pin for D2.
3. **RNG-kind independence** — same `seed` under two different ambient
   `RNGkind()` settings ⇒ `identical()` output (pins D1(b)/D3).
4. **Stage independence** — baseline and post-processing draws are not trivially
   correlated (e.g. differ where a naïve shared stream would coincide).
5. **Pinned values** — a small `expect_equal` against committed reference output
   for one canonical spec, so the *next* accidental break is caught loudly. These
   are the values re-baselined when this ADR's implementation lands.

## Migration

- Implementation is written only after this ADR is accepted, as its own plan
  (`development/plans/YYYY-MM-DD-seed-contract.md`) per the post-v0.4.0 plan's
  ADR-gate rule.
- **Co-release with #39.** The formula evaluator reorders draws by dependency and
  so changes seeded output on its own; batching both into one v0.5 release means
  one NEWS migration note, not two. #40 (survival pairs) may ride the same release
  (no independent seed impact). #42 (correlations) must not begin until this lands
  — it is the fourth RNG consumer and needs the stage-substream mechanism.
- **NEWS migration note** states plainly: seeded output changes once in v0.5;
  same-version reproducibility is unaffected; pin your own expected values against
  the version you use. Precedent: the v0.3→v0.4 divergence already documented in
  NEWS.

## Resolved / carried to implementation

1. D1 (b), D2 (a), D3 (ratified), D4 (a) — see Decision summary. ✅
2. Co-release of #38 + #39 in v0.5 — confirmed. ✅
3. **Carried to the implementation plan:** where the pinned reference values (test
   strategy item 5) live — inline in the test file vs. a committed fixture under
   `tests/testthat/_snaps/` or `inst/`. Low-stakes; decide when writing the plan.
