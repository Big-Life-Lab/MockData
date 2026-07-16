# Seed & RNG-Stream Contract Implementation Plan (#38)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make one public `seed` reproduce identical MockData output across every generation path, independent of the caller's ambient `RNGkind()` and without perturbing the caller's RNG state — via L'Ecuyer-CMRG per-stage sub-streams — landing the single budgeted seeded-output break for v0.5.

**Architecture:** One seeding primitive, `.with_mock_seed(seed, expr, stage)`, owns all randomness. It saves/restores both `.Random.seed` and `RNGkind`, seeds one `L'Ecuyer-CMRG` stream from the public seed, advances to the named stage's guaranteed-independent sub-stream via `parallel::nextRNGStream()`, and runs the generation expression under it. The native, simstudy, and legacy paths all route through it; stage indices are frozen so future stages (#39 formula, #42 correlate) add without renumbering.

**Tech Stack:** R (≥ 4.2.0), base `parallel` (new Import — ships with every R install, no external dependency), testthat edition 3, roxygen2, renv.

**Decision source:** [development/adr/v05-seed-contract.md](../adr/v05-seed-contract.md) (ACCEPTED 2026-07-06). This plan implements D1(b), D2(a), D3, D4(a).

## Global Constraints

Inherited from `development/post-v040-development-plan.md` Global Constraints (R floor, `en_US.UTF-8` CI, `roxygenize()` before pkgdown, no committing check artefacts, plain-imperative commits with no AI credit, review before push, fixtures via `system.file()` + skip guards). Plus, specific to this workstream:

- **This is the budgeted break.** Seeded output changes once, here. Every value-pinning test breaks and is re-baselined *deliberately* (regenerate → sanity-check → paste), never blind-accepted. A test asserting a *property* (range, type, count, error message) that breaks is a real regression — stop, do not edit it green.
- **`parallel` is base R.** Add it to `DESCRIPTION` `Imports` and use `parallel::nextRNGStream()`. Run `renv::snapshot()` after (base packages usually don't alter `renv.lock`; commit it only if it changes).
- **Stage indices are frozen** at `baseline = 0, postprocess = 1, formula = 2, correlate = 3`. Reserve `formula`/`correlate` now though unused, so #39/#42 don't renumber existing streams and re-break output.
- **Co-releases with #39** in v0.5 — do not tag until both land. This plan is #38 only.
- **Downstream:** cchsflow/chmsflow may pin MockData output; the NEWS migration note is mandatory.

## The mechanism (read before Task 1)

R's default Mersenne-Twister has no guaranteed stream-splitting. `L'Ecuyer-CMRG` does: `parallel::nextRNGStream(state)` returns a state advanced 2^127 steps — provably non-overlapping. Pattern:

```r
set.seed(seed, kind = "L'Ecuyer-CMRG")   # sets kind AND seeds in one call
stream <- .Random.seed                    # sub-stream 0 (baseline)
stream <- parallel::nextRNGStream(stream) # sub-stream 1 (postprocess)
assign(".Random.seed", stream, envir = .GlobalEnv)  # install; draws now use it
```

Because the kind is pinned inside the scope and `.Random.seed`/`RNGkind` are saved and restored around it, output is independent of ambient `RNGkind()` and the caller's stream is untouched. Lazy evaluation makes wrapping work: `.with_mock_seed(seed, { df[[v]] <- ... })` forces the `{...}` promise in the *caller's* frame, so assignments inside it persist — this is how the native path already operates and how the legacy loop will be wrapped.

## File structure

- `R/mock_spec_native.R` — `.MOCK_STAGES` (new), `.with_mock_seed()` (extend), `generate_mock_data_native()` call site.
- `R/mock_spec_postprocess.R` — `postprocess_mock_data()` call site → stage `"postprocess"`.
- `R/mock_spec_simstudy.R` — `generate_mock_data_simstudy()` call site → stage `"baseline"`.
- `R/create_mock_data.R` — `.create_mock_data_v04()` drop `seed + 1L`; legacy loop wrap; always-on fallback message; roxygen `@details` seed paragraph.
- `DESCRIPTION` — add `parallel` to `Imports`.
- `tests/testthat/test-seed-contract.R` — new contract suite.
- `NEWS.md` — migration note.
- Re-baselined value-pin tests across `tests/testthat/` (discovered during execution).

---

### Task 1: RNG primitive + native/spec-layer wiring

**Files:**
- Modify: `R/mock_spec_native.R` (add `.MOCK_STAGES`; rewrite `.with_mock_seed()` at :8-34; `generate_mock_data_native()` call at :349)
- Modify: `R/mock_spec_postprocess.R:373` (call site)
- Modify: `R/mock_spec_simstudy.R:231` (call site)
- Modify: `R/create_mock_data.R` (`.create_mock_data_v04()` :98-103; `@details` seed paragraph :164-166)
- Modify: `DESCRIPTION` (Imports)
- Test: `tests/testthat/test-seed-contract.R` (new)

**Interfaces:**
- Produces: `.with_mock_seed(seed, expr, stage = "baseline")` — save/restore `.Random.seed` + `RNGkind`; L'Ecuyer sub-stream per stage; returns `force(expr)`. `.MOCK_STAGES` named int vector. Consumed by Task 2 (legacy path).

- [ ] **Step 1: Write the failing contract tests (primitive + native level)**

```r
# tests/testthat/test-seed-contract.R
# Contract pinned by ADR development/adr/v05-seed-contract.md (#38).

test_that("distinct stages yield distinct, reproducible streams from one seed", {
  draw <- function(stage) MockData:::.with_mock_seed(1L, runif(5), stage = stage)
  expect_false(identical(draw("baseline"), draw("postprocess")))
  expect_identical(draw("baseline"), draw("baseline"))
})

test_that("seeded generation leaves the caller's RNG state and kind untouched", {
  set.seed(999)
  before_state <- .Random.seed
  before_kind <- RNGkind()
  spec <- mock_continuous("age", range = c(18, 80))
  generate_mock_data_native(spec, n = 50, seed = 42)
  expect_identical(.Random.seed, before_state)
  expect_identical(RNGkind(), before_kind)
})

test_that("same seed and spec give identical native output", {
  spec <- mock_continuous("age", range = c(18, 80))
  expect_identical(
    generate_mock_data_native(spec, n = 100, seed = 7),
    generate_mock_data_native(spec, n = 100, seed = 7)
  )
})

test_that("native output is independent of the caller's ambient RNGkind", {
  spec <- mock_continuous("age", range = c(18, 80))
  old <- RNGkind()
  on.exit(RNGkind(kind = old[1], normal.kind = old[2], sample.kind = old[3]), add = TRUE)
  RNGkind("Mersenne-Twister")
  a <- generate_mock_data_native(spec, n = 100, seed = 7)
  RNGkind("Marsaglia-Multicarry")
  b <- generate_mock_data_native(spec, n = 100, seed = 7)
  expect_identical(a, b)
})
```

- [ ] **Step 2: Run — verify failure**

Run: `Rscript -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-seed-contract.R")'`
Expected: FAIL — `.with_mock_seed()` has no `stage` argument yet (unused-argument error), and RNGkind-independence fails because current code uses ambient MT.

- [ ] **Step 3: Add `.MOCK_STAGES` and rewrite `.with_mock_seed()`**

In `R/mock_spec_native.R`, replace the existing `.with_mock_seed` (:8-34) with:

```r
# Named generation stages -> fixed L'Ecuyer-CMRG sub-stream indices. Indices
# are FROZEN: adding a future stage must not renumber baseline/postprocess, or
# seeded output for existing features would shift. formula (#39) and correlate
# (#42) are reserved now though unused in this release.
.MOCK_STAGES <- c(
  baseline    = 0L,
  postprocess = 1L,
  formula     = 2L,
  correlate   = 3L
)

#' @noRd
.with_mock_seed <- function(seed, expr, stage = "baseline") {
  if (is.null(seed)) {
    return(force(expr))
  }

  if (!is.numeric(seed) || length(seed) != 1 || is.na(seed) || seed != floor(seed)) {
    stop("seed must be a single whole number.", call. = FALSE)
  }
  if (!stage %in% names(.MOCK_STAGES)) {
    stop("Unknown generation stage: '", stage, "'.", call. = FALSE)
  }

  # Save the caller's RNG state AND kind so generation never perturbs them.
  old_kind <- RNGkind()
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) {
    old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  }
  on.exit({
    RNGkind(kind = old_kind[1], normal.kind = old_kind[2], sample.kind = old_kind[3])
    if (had_seed) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)

  # One L'Ecuyer-CMRG stream from the public seed, advanced to this stage's
  # provably-independent sub-stream. Pinning the kind makes output independent
  # of the caller's ambient RNGkind().
  set.seed(seed, kind = "L'Ecuyer-CMRG")
  stream <- .Random.seed
  for (i in seq_len(.MOCK_STAGES[[stage]])) {
    stream <- parallel::nextRNGStream(stream)
  }
  assign(".Random.seed", stream, envir = .GlobalEnv)

  force(expr)
}
```

- [ ] **Step 4: Point the three spec-layer call sites at their stages**

`R/mock_spec_native.R:349` — `generate_mock_data_native()`: change `.with_mock_seed(seed, {` to `.with_mock_seed(seed, stage = "baseline", {` (or add `stage = "baseline"` after the `expr` — since `expr` is positional and `{...}` is large, pass `stage` as the named 3rd arg *after* the block: keep `.with_mock_seed(seed, { ... })` and append `, stage = "baseline")` — baseline is the default, so this call may be left unchanged; make it explicit for clarity).

`R/mock_spec_postprocess.R:373` — `postprocess_mock_data()`: the `.with_mock_seed(seed, { ... })` must pass `stage = "postprocess"`. Add the named argument.

`R/mock_spec_simstudy.R:231` — `generate_mock_data_simstudy()`: it is an alternative *baseline* backend; pass `stage = "baseline"` (explicit).

(Because `stage` is a named argument with default `"baseline"`, add it after the closing brace of the block, e.g. `.with_mock_seed(seed, stage = "postprocess", { ... })` — verify the call parses.)

- [ ] **Step 5: Drop the `seed + 1L` split in the orchestrator**

`R/create_mock_data.R:98-103` — replace:

```r
  baseline <- generate_mock_data_native(spec, n = n, seed = seed)
  # The wrapper uses a second deterministic stream for post-processing so
  # baseline generation and missing/garbage assignment can be reproduced
  # independently from the single public seed.
  postprocess_seed <- if (is.null(seed)) NULL else seed + 1L
  postprocess_mock_data(baseline, spec, seed = postprocess_seed)
```

with:

```r
  baseline <- generate_mock_data_native(spec, n = n, seed = seed)
  # Baseline and post-processing use distinct L'Ecuyer-CMRG sub-streams derived
  # from the single public seed (see .with_mock_seed / ADR v05-seed-contract),
  # so both stages pass the same seed and select their own stage internally.
  postprocess_mock_data(baseline, spec, seed = seed)
```

Then fix the now-stale `@details` seed paragraph at `R/create_mock_data.R:164-166` ("seed + 1 is used for post-processing…") to describe the sub-stream contract, e.g.: "In the v0.4 path, baseline generation and post-processing draw from distinct, independent sub-streams derived from a single `seed`; output is reproducible for a given seed and package version but changed in v0.5 (see NEWS)."

- [ ] **Step 6: Add `parallel` to Imports**

`DESCRIPTION` — under `Imports:`, add `parallel` beside `stats`:

```
Imports:
    parallel,
    stats
```

- [ ] **Step 7: Document, then run the contract tests**

Run: `Rscript -e 'devtools::document()'` (no roxygen surface change expected beyond the edited `@details`; confirm clean).
Run: `Rscript -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-seed-contract.R")'`
Expected: all four PASS.

- [ ] **Step 8: Re-baseline the value-pin tests broken by the MT→L'Ecuyer switch**

Run: `Rscript -e 'devtools::test()' 2>&1 | tee /private/tmp/claude-502/-Users-dmanuel-github-mock-data/20beff35-3d8d-499a-b425-4bfa03cd3bb1/scratchpad/seed-break-t1.log`

Triage every failure:
- **Exact-value assertion** (`expect_equal`/`expect_identical` against a hard-coded number or vector produced under a seed): expected re-baseline. Read the new actual value from the failure output and VERIFY before pasting: value(s) within the variable's declared range; correct type/class/length; for a distribution, mean/spread in the right ballpark (draw a quick `summary()` if unsure). Then replace the literal. Never blind-copy the failure's "actual".
- **Property assertion** (range, count, NA-proportion within tolerance, type, error message, `expect_error`): if this broke, it is a REAL regression — STOP and report BLOCKED with the test and output. Do not edit it to pass.

Re-run `devtools::test()` until green (0 FAIL; pre-existing 10 skips OK; WARN not above the pre-existing baseline of 35).

- [ ] **Step 9: Commit**

```bash
git add R/mock_spec_native.R R/mock_spec_postprocess.R R/mock_spec_simstudy.R \
        R/create_mock_data.R DESCRIPTION tests/testthat/test-seed-contract.R \
        man/ NEWS.md
# (NEWS.md only if you added the note here; otherwise defer to Task 3)
git commit -m "Adopt L'Ecuyer-CMRG per-stage seed sub-streams (#38)

Replace the seed/seed+1L split with named, provably-independent
sub-streams (baseline, postprocess) derived from one public seed via
parallel::nextRNGStream(). .with_mock_seed() now pins RNGkind within
scope and restores it, so output no longer depends on the caller's
ambient RNGkind(). Native, postprocess, and simstudy paths route
through it. Re-baselines value-pinning tests for the RNG change."
```

---

### Task 2: Unify legacy-path isolation + always-on fallback message

**Files:**
- Modify: `R/create_mock_data.R` (legacy seed block :347-352; generation loop wrap; fallback message after :296-298)
- Test: `tests/testthat/test-seed-contract.R` (append)

**Interfaces:**
- Consumes: `.with_mock_seed()` and `.MOCK_STAGES` from Task 1.
- Produces: legacy path no longer clobbers the caller's RNG; a once-per-call `message()` when the v0.4 path silently falls back to legacy.

- [ ] **Step 1: Write the failing tests**

Append to `tests/testthat/test-seed-contract.R`:

```r
test_that("legacy path (validate = FALSE) leaves the caller's RNG untouched", {
  vars <- system.file("extdata", "minimal-example", "variables.csv", package = "MockData")
  dets <- system.file("extdata", "minimal-example", "variable_details.csv", package = "MockData")
  if (!nzchar(vars) || !nzchar(dets)) skip("minimal-example fixtures not installed")
  variables <- read.csv(vars, stringsAsFactors = FALSE, check.names = FALSE)
  variable_details <- read.csv(dets, stringsAsFactors = FALSE, check.names = FALSE)

  set.seed(123)
  before <- .Random.seed
  suppressWarnings(suppressMessages(
    create_mock_data("minimal-example", variables, variable_details,
                     n = 20, seed = 42, validate = FALSE)
  ))
  expect_identical(.Random.seed, before)
})

test_that("legacy path is reproducible for a given seed", {
  vars <- system.file("extdata", "minimal-example", "variables.csv", package = "MockData")
  dets <- system.file("extdata", "minimal-example", "variable_details.csv", package = "MockData")
  if (!nzchar(vars) || !nzchar(dets)) skip("minimal-example fixtures not installed")
  variables <- read.csv(vars, stringsAsFactors = FALSE, check.names = FALSE)
  variable_details <- read.csv(dets, stringsAsFactors = FALSE, check.names = FALSE)
  a <- suppressWarnings(suppressMessages(
    create_mock_data("minimal-example", variables, variable_details, n = 20, seed = 42, validate = FALSE)))
  b <- suppressWarnings(suppressMessages(
    create_mock_data("minimal-example", variables, variable_details, n = 20, seed = 42, validate = FALSE)))
  expect_identical(a, b)
})
```

- [ ] **Step 2: Run — verify the isolation test fails**

Run: `Rscript -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-seed-contract.R")'`
Expected: "legacy path … leaves the caller's RNG untouched" FAILS (current bare `set.seed()` clobbers `.Random.seed`). The reproducibility test may pass already.

- [ ] **Step 3: Replace the bare `set.seed` and wrap the generation loop**

`R/create_mock_data.R` — remove the SET GLOBAL SEED block (:347-352):

```r
  # ========== SET GLOBAL SEED ==========

  if (!is.null(seed)) {
    if (verbose) message("Setting random seed: ", seed)
    set.seed(seed)
  }
```

Wrap the variable-generation loop (the `for (i in seq_len(nrow(enabled_vars)))` block, currently ~:374 onward through its closing brace) in `.with_mock_seed(seed, stage = "baseline", { ... })`. Because the promise is forced in this frame, in-loop assignments (`df_mock[[var_name]] <- …`, `skipped_vars <- …`) persist. Concretely, change:

```r
  for (i in seq_len(nrow(enabled_vars))) {
    ...
  }
```

to:

```r
  .with_mock_seed(seed, stage = "baseline", {
    for (i in seq_len(nrow(enabled_vars))) {
      ...
    }
  })
```

Do not alter the loop body or the post-loop assembly. If `verbose`, keep a seed message inside the wrapper: `if (!is.null(seed) && verbose) message("Setting random seed: ", seed)` as the first line inside the block.

- [ ] **Step 4: Add the always-on fallback message (D4)**

`R/create_mock_data.R:286-298` — the `else` branch attempts v0.4 and falls through when `v04_result` is NULL. Add an always-on message on that silent-fallback edge only:

```r
  } else {
    v04_result <- .create_mock_data_v04(
      databaseStart = databaseStart,
      variables = variables,
      variable_details = variable_details,
      n = n,
      seed = seed,
      verbose = verbose
    )

    if (!is.null(v04_result)) {
      return(v04_result)
    }

    message(
      "Falling back to the legacy generator for an unsupported v0.4 feature; ",
      "for a given seed this produces different values than the v0.4 pipeline."
    )
  }
```

(Do not add it to the `validate = FALSE` or `variable_details = NULL` branches — those are explicit user choices already messaged under `verbose`.)

- [ ] **Step 5: Run the contract tests, then re-baseline legacy value-pins**

Run the seed-contract file: expected all PASS (isolation now holds).
Run: `Rscript -e 'devtools::test()' 2>&1 | tee /private/tmp/claude-502/-Users-dmanuel-github-mock-data/20beff35-3d8d-499a-b425-4bfa03cd3bb1/scratchpad/seed-break-t2.log`
Apply the same triage as Task 1 Step 8 to any newly-broken value-pin tests on the legacy path (they switched MT→L'Ecuyer). Property regressions → STOP. A new fallback `message()` may surface in tests that call the fallback edge without `suppressMessages()` — wrap those calls, do not silence the message globally.

- [ ] **Step 6: Commit**

```bash
git add R/create_mock_data.R tests/testthat/
git commit -m "Unify legacy path on the seed contract and announce fallbacks (#38)

Route the legacy generation loop through .with_mock_seed() so it no
longer clobbers the caller's RNG stream, matching the native path.
Emit an always-on message when the v0.4 path silently falls back to
the legacy generator for an unsupported feature (resolves #33 item 11).
Re-baselines affected legacy value-pin tests."
```

---

### Task 3: Contract test suite completion, docs, NEWS

**Files:**
- Modify: `tests/testthat/test-seed-contract.R` (cross-path + pinned reference values)
- Modify: `R/mock_spec_native.R`, `R/mock_spec_postprocess.R`, `R/mock_spec_simstudy.R` (`@param seed` consistency)
- Modify: `NEWS.md`
- Modify: `man/` (regenerated)

**Interfaces:** consumes everything above; no new production code.

- [ ] **Step 1: Add cross-path determinism and pinned-reference tests**

Append to `tests/testthat/test-seed-contract.R`:

```r
test_that("full orchestrated pipeline is reproducible for a given seed", {
  vars <- system.file("extdata", "minimal-example", "variables.csv", package = "MockData")
  dets <- system.file("extdata", "minimal-example", "variable_details.csv", package = "MockData")
  if (!nzchar(vars) || !nzchar(dets)) skip("minimal-example fixtures not installed")
  variables <- read.csv(vars, stringsAsFactors = FALSE, check.names = FALSE)
  variable_details <- read.csv(dets, stringsAsFactors = FALSE, check.names = FALSE)
  a <- suppressWarnings(suppressMessages(
    create_mock_data("minimal-example", variables, variable_details, n = 50, seed = 1)))
  b <- suppressWarnings(suppressMessages(
    create_mock_data("minimal-example", variables, variable_details, n = 50, seed = 1)))
  expect_identical(a, b)
})

test_that("pinned reference values catch the next accidental RNG change", {
  spec <- mock_continuous("x", range = c(0, 1))
  got <- generate_mock_data_native(spec, n = 3, seed = 20260706)$x
  # Reference values captured under the v0.5 L'Ecuyer-CMRG contract. If this
  # breaks, seeded output changed — treat as a deliberate, NEWS-documented break,
  # not a silent one.
  expect_equal(got, c(<FILL FROM FIRST GREEN RUN>), tolerance = 1e-8)
})
```

For the pinned test: run it once, read the three actual values, sanity-check they lie in `[0, 1]`, and paste them into `<FILL FROM FIRST GREEN RUN>`. This is the golden baseline; capturing it is the point.

- [ ] **Step 2: Harmonize `@param seed` docs**

In `generate_mock_data_native()`, `postprocess_mock_data()`, and `generate_mock_data_simstudy()`, make each `@param seed` state the shared contract, e.g.: "Optional whole-number seed. Generation uses an isolated L'Ecuyer-CMRG sub-stream and restores the caller's RNG state and kind on exit, so output is reproducible for a given seed and package version without perturbing the caller's RNG." Run `Rscript -e 'devtools::document()'`.

- [ ] **Step 3: NEWS migration note**

Under `# MockData (development version)` in `NEWS.md`:

```markdown
## Reproducibility (breaking change)

- Seeded output changed once in this release. MockData now derives all
  randomness from independent L'Ecuyer-CMRG sub-streams (one per generation
  stage) seeded from the single public `seed`, replacing the previous
  Mersenne-Twister `seed` / `seed + 1` scheme. For a given seed **and package
  version** output is reproducible and independent of the session's ambient
  `RNGkind()`; it is not comparable across the v0.4 → v0.5 boundary. Pin your
  own expected values against the version you use. Generation no longer alters
  the caller's RNG state on any path (previously the legacy `validate = FALSE`
  path reset it).
```

- [ ] **Step 4: Full verification**

Run: `Rscript -e 'devtools::test()'` — 0 FAIL, ≤10 skips, ≤35 WARN.
Run: `Rscript -e 'devtools::check()'` — no new ERRORs/WARNINGs/NOTEs attributable to this work (a `parallel` Import NOTE, if any, is expected and acceptable).
Run: `Rscript -e 'renv::snapshot()'` — commit `renv.lock` only if it changed.

- [ ] **Step 5: Commit**

```bash
git add tests/testthat/test-seed-contract.R NEWS.md man/ R/ renv.lock
git commit -m "Complete seed-contract tests and docs (#38)

Add cross-path determinism and pinned-reference tests, harmonize the
seed @param docs across the three generators, and document the v0.5
reproducibility break in NEWS. Fulfils #22."
```

---

## Self-review (performed at plan date)

- **ADR coverage:** D1(b) sub-streams — Task 1 Step 3; D2(a) unify isolation — Task 1 (native/simstudy/postprocess already save/restore; Task 2 legacy); D3 guarantee — pinned + RNGkind-independence tests; D4(a) always-on fallback — Task 2 Step 4. Test strategy items 1–5 map to Task 1 Steps 1, Task 2 Step 1, Task 3 Step 1.
- **Placeholder scan:** the only intentional fill-in is the pinned reference vector (Task 3 Step 1), which cannot exist until the mechanism runs; the step specifies exactly how to capture and sanity-check it. Re-baselining (Task 1 Step 8, Task 2 Step 5) is genuine golden-value regeneration with explicit triage criteria, not hand-waving.
- **Type consistency:** `.with_mock_seed(seed, expr, stage = "baseline")` signature and `.MOCK_STAGES` names (`baseline`/`postprocess`/`formula`/`correlate`) are used identically at every call site; `stage` passed as a named argument everywhere because `expr` is a large positional block.
- **Sequencing risk:** Task 1 changes RNG output → its own tests re-baseline within the task, so each task ends green. Legacy wrap (Task 2) is the highest-risk edit; its isolation test is written red-first to prove the fix.
- **Open item carried from ADR:** pinned-reference storage location — chosen here as inline in the test file (simplest; a fixture under `_snaps/` is unnecessary for three scalars).
