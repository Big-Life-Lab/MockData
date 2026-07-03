# Post-v0.4.0 Development Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement Phase 1 task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Phase 2 and 3 tasks are **design-first**: their deliverable is an ADR, and implementation is gated on maintainer approval of that ADR — do not write feature code for a Phase 2/3 workstream until its ADR is merged.

**Goal:** Sequence and specify all post-v0.4.0 work — tactical hardening now, the v0.5 feature train (formulas, seed contract, survival pairs) next, the Table 1 adapter after — so any capable model or developer can execute it without re-deriving context.

**Architecture:** MockData v0.4 is a layered pipeline: input adapters (direct API, recodeflow metadata) → normalized `mock_spec` → backends (native, optional simstudy) → post-processing (missing codes, garbage, coercion) with a `mockdata_diagnostics` attribute. Phase 1 hardens the orchestrator entry layer without touching output semantics. Phase 2 lands the two output-changing features plus the seed contract in a single coordinated minor release. Phase 3 adds a third input adapter.

**Tech Stack:** R (>= 4.2.0), testthat (edition 3), roxygen2, renv, Quarto vignettes via pkgdown, GitHub Actions CI.

**Plan date:** 2026-07-03. **Baseline:** `dev` branch at v0.4.0 + CRAN-readiness prep (`cran-comments.md`; no near-term submission planned).

## Global Constraints

Every task's requirements implicitly include this section.

- R version floor **>= 4.2.0**; renv lockfile baseline 4.4.2.
- After any `DESCRIPTION` dependency change: `renv::snapshot()` and commit `renv.lock`. Snapshot type is `"all"` — do not change it.
- CI locale is `en_US.UTF-8`, never `en_CA` (Ubuntu runners lack it; silently breaks date parsing — see `.claude/AI.md`).
- Always `roxygen2::roxygenize()` before `pkgdown::build_site()`. Quarto vignettes require `minimal: true`; callouts unsupported.
- Never commit `*.Rcheck/`, `MockData_*.tar.gz`, `.tmp/`.
- Commit messages: plain imperative sentences matching repo history (e.g. "Add native exponential distribution"); **no** conventional-commit prefixes; **no** AI credit; review commits with the maintainer before pushing.
- **Release-stability constraint (Phase 1):** CRAN submission is not imminent — `cran-comments.md` was prepared as a readiness assessment, not an active submission. v0.4.x patches nonetheless stay additive: no public API surface changes, no seeded-output changes, error-relaxations allowed, each with a NEWS entry. This keeps a CRAN submission possible at any time and protects downstream consumers.
- **Downstream constraint:** cchsflow and chmsflow (CRAN-published) consume the recodeflow metadata schema. Any change to shared-column semantics requires coordination — MockData-extension columns are the safe channel.
- **Seed policy:** exactly one seeded-output break is budgeted, in v0.5, covered by one NEWS migration note (precedent: v0.3→v0.4 divergence). No other task may alter seeded output.
- TDD throughout: failing test → minimal code → green → commit. Run `devtools::test()` (full) or `testthat::test_file("tests/testthat/<file>")` (single) each cycle.
- Test fixtures: always `system.file(...)` + skip guard, never source-tree-relative paths (issue #33 item 7 lesson).

## How to Use This Plan (two tiers)

- **Phase 1 (Tasks 1–4)** is execution-ready: complete code in every step, verified against the tree at plan date. Execute directly.
- **Phase 2 (Tasks 5–8) and Phase 3 (Task 9)** are design-first: the deliverable is an ADR whose decision points are enumerated below with evidence and a recommendation. After the maintainer approves an ADR, write a fresh implementation plan for that workstream (superpowers:writing-plans; save to `development/plans/YYYY-MM-DD-<workstream>.md`) and execute it. Do not skip the ADR gate.

## Evidence Base

Verified 2026-07-03 by direct probe (`devtools::load_all()` + minimal-example fixtures) and code reading.

### Edge-case probe results

| Call | Behaviour at plan date | Verdict |
|---|---|---|
| `generate_mock_data_native(mock_spec(), n = 10)` | 10 × 0 data frame | correct — pin (Task 1) |
| `generate_mock_data_native(mock_spec(), n = 0)` | 0 × 0 data frame | correct — pin |
| `generate_mock_data_native(<1-var spec>, n = 0)` | 0 × 1, typed column | correct — pin |
| native, `n = -1` / `1.5` / `NA` | error "n must be a non-negative whole number." | correct — pin |
| `postprocess_mock_data(<0-row baseline>, spec)` | 0-row, schema preserved | correct — pin |
| `create_mock_data(db, vars, dets, n = 0)` | error "n must be at least 1" | **inconsistent** — fix (Task 2) |
| `create_mock_data(db, vars, dets, n = 1.5)` | accepted (guard is `n < 1`) | **bug** — fix (Task 2) |
| `create_mock_data()` without `databaseStart` | raw R missing-argument error | **UX gap** — fix (Task 3) |
| `create_mock_data(db, vars[0, ], dets, n = 5)` | error "No variables matched the requested role/database filters." | correct — pin |
| `create_mock_data(db, vars[1, ], dets, n = 5)` | 5 × 1 | correct — pin |
| `create_mock_data(db, vars, NULL, n = 5)` | 5 × **11** (vs 5 × **6** with details) | discrepancy — record on #14, do **not** fix in Phase 1 |
| native `distribution = "exponential"` | error "Native backend does not yet support..." | parity gap — fix (Task 4) |

### Key code locations

- `n < 1` guard: `R/create_mock_data.R:240-242`.
- v0.4 seed split (`seed`, `seed + 1L`): `R/create_mock_data.R:85-90`. Legacy global `set.seed`: `:325-327`.
- Native continuous dispatch (uniform/normal only, else stop): `R/mock_spec_native.R:189-211`. Truncated normal helper: `:75`.
- Legacy exponential support: `R/create_con_var.R:279-281` (`rexp`, unbounded).
- Adapter already stores `rate`/`shape`/`followup_min`/`followup_max`/`event_prop` on spec variables: `R/mock_spec_recodeflow.R:365-369`.
- Spec variable constructor already has unused `formula` and `depends_on` fields plus `...` passthrough: `R/mock_spec.R:94-145`.
- Validator normal-distribution block (pattern for exponential rule): `R/mock_spec.R:790-799`.
- Formula-evaluator spike (referent validation, `str2lang` dependency extraction, topological ordering, cycle detection): recover with `git show f4f9b41:development/v04-simstudy-spike/prototype.R` (merged PR #27, later removed from tree).

### Issue map

| Issue | Workstream | Phase |
|---|---|---|
| [#35](https://github.com/Big-Life-Lab/MockData/issues/35) | Edge-case contract tests | 1 / Task 1 |
| [#36](https://github.com/Big-Life-Lab/MockData/issues/36) | Entry-validation alignment | 1 / Tasks 2–3 |
| [#37](https://github.com/Big-Life-Lab/MockData/issues/37) | Native exponential parity | 1 / Task 4 |
| [#38](https://github.com/Big-Life-Lab/MockData/issues/38) | Seed-contract ADR | 2 / Task 5 |
| [#39](https://github.com/Big-Life-Lab/MockData/issues/39) | Formula-derived variables | 2 / Task 6 |
| [#40](https://github.com/Big-Life-Lab/MockData/issues/40) | Survival pairs in batch | 2 / Task 7 |
| [#41](https://github.com/Big-Life-Lab/MockData/issues/41) | Table 1 adapter | 3 / Task 9 |
| [#42](https://github.com/Big-Life-Lab/MockData/issues/42) | Correlations (deferred) | register |
| [#43](https://github.com/Big-Life-Lab/MockData/issues/43) | LinkML (deferred, ecosystem) | register |

Related pre-existing: #13 (umbrella reassessment — outcome is this plan), #14 (fallback semantics — evidence recorded by Task 1), #17, #22 (fulfilled by #38), #23 (direction fulfilled by #40), #24 (enabled by #37), #33 (tactical debt, complementary to Phase 1), #25 (spike — suggest close).

### Execution order

```
Phase 1 (v0.4.x, now):   Task 1 → Task 2 → Task 3 → Task 4
Phase 2 (v0.5):          Task 5 (ADR) ─┬→ Task 8 (release train)
                         Task 6 (ADR) ─┤   [Tasks 5+6 land together: one seed break]
                         Task 7 (ADR) ─┘   [Task 7 may land same release; no seed impact]
Phase 3 (v0.6):          Task 9 (ADR → adapter)
Register (triggered):    #42 after Task 5 lands + concrete need; #43 on ecosystem demand
```

---

## Phase 1 — v0.4.x hardening (execution-ready)

No public API surface changes; no seeded-output changes. Each task is one PR-sized unit.

### Task 1: Edge-case contract tests (#35)

**Files:**
- Create: `tests/testthat/test-edge-case-contract.R`

**Interfaces:**
- Consumes: exported `mock_spec()`, `mock_continuous()`, `generate_mock_data_native()`, `postprocess_mock_data()`, `create_mock_data()`; fixture `inst/extdata/minimal-example/`.
- Produces: nothing for later tasks — pure characterization. Tasks 2–3 extend this same file.

- [ ] **Step 1: Write the contract tests** (all should pass immediately — they pin verified current behaviour)

```r
# tests/testthat/test-edge-case-contract.R
# Characterization tests pinning the edge-case input contract (issue #35).
# Probe evidence: development/post-v040-development-plan.md, Evidence Base.

minimal_example <- function() {
  vars <- system.file("extdata", "minimal-example", "variables.csv",
                      package = "MockData")
  dets <- system.file("extdata", "minimal-example", "variable_details.csv",
                      package = "MockData")
  if (!nzchar(vars) || !nzchar(dets)) {
    skip("minimal-example fixtures not installed")
  }
  list(
    variables = read.csv(vars, stringsAsFactors = FALSE, check.names = FALSE),
    variable_details = read.csv(dets, stringsAsFactors = FALSE, check.names = FALSE)
  )
}

test_that("native backend returns typed zero-row output for n = 0", {
  spec <- mock_continuous("age", range = c(18, 80))
  result <- generate_mock_data_native(spec, n = 0)
  expect_s3_class(result, "data.frame")
  expect_identical(nrow(result), 0L)
  expect_named(result, "age")
  expect_type(result$age, "double")
})

test_that("native backend returns n rows and zero columns for an empty spec", {
  expect_identical(dim(generate_mock_data_native(mock_spec(), n = 10)), c(10L, 0L))
  expect_identical(dim(generate_mock_data_native(mock_spec(), n = 0)), c(0L, 0L))
})

test_that("native backend rejects invalid n with a clear message", {
  spec <- mock_continuous("age", range = c(18, 80))
  expect_error(generate_mock_data_native(spec, n = -1),
               "non-negative whole number")
  expect_error(generate_mock_data_native(spec, n = 1.5),
               "non-negative whole number")
  expect_error(generate_mock_data_native(spec, n = NA),
               "non-negative whole number")
})

test_that("postprocess_mock_data preserves zero-row shape and names", {
  spec <- mock_continuous("age", range = c(18, 80))
  baseline <- generate_mock_data_native(spec, n = 0)
  result <- postprocess_mock_data(baseline, spec)
  expect_identical(nrow(result), 0L)
  expect_named(result, "age")
})

test_that("create_mock_data fails loudly when no variables match filters", {
  fx <- minimal_example()
  expect_error(
    suppressMessages(create_mock_data(
      "minimal-example", fx$variables[0, ], fx$variable_details, n = 5
    )),
    "No variables matched"
  )
})

test_that("create_mock_data handles single-row variables metadata", {
  fx <- minimal_example()
  result <- suppressMessages(create_mock_data(
    "minimal-example", fx$variables[1, ], fx$variable_details, n = 5
  ))
  expect_identical(nrow(result), 5L)
  expect_identical(ncol(result), 1L)
})

test_that("create_mock_data generates the minimal example (sanity anchor)", {
  fx <- minimal_example()
  result <- suppressMessages(create_mock_data(
    "minimal-example", fx$variables, fx$variable_details, n = 20, seed = 1
  ))
  expect_identical(nrow(result), 20L)
  expect_true(all(c("age", "smoking") %in% names(result)))
  expect_true(all(names(result) %in% fx$variables$variable))
})
```

- [ ] **Step 2: Run the file**

Run: `Rscript -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-edge-case-contract.R")'`
Expected: all PASS, 0 failures. If any cell fails, current behaviour has drifted from the plan-date probe — stop and re-verify against the Evidence Base before changing either test or code.

- [ ] **Step 3: Record the fallback discrepancy on issue #14** (evidence, not a fix)

Run: `gh issue comment 14 --repo Big-Life-Lab/MockData --body "Concrete evidence (2026-07-03 probe, plan Task 1): create_mock_data(\"minimal-example\", vars, dets, n = 5) returns 6 columns; the same call with variable_details = NULL returns 11 columns via the legacy fallback. Fallback filtering semantics differ from the details path."`

- [ ] **Step 4: Full suite, then commit**

Run: `Rscript -e 'devtools::test()'` — expected: green, no new skips.

```bash
git add tests/testthat/test-edge-case-contract.R
git commit -m "Pin edge-case input contract with characterization tests

Closes #35. Evidence recorded on #14."
```

### Task 2: Allow n = 0 and validate n properly in create_mock_data() (#36)

**Files:**
- Modify: `R/create_mock_data.R:240-242`
- Modify: `tests/testthat/test-edge-case-contract.R` (extend)
- Modify: `NEWS.md` (add "MockData (development version)" heading if absent)

**Interfaces:**
- Consumes: guard block at `R/create_mock_data.R:240-242` exactly as shown in Evidence Base.
- Produces: unified n-validation message `"n must be a non-negative whole number."` — Task 3 appends to the same test file; the message string is relied on by tests.

- [ ] **Step 1: Write the failing tests**

Append to `tests/testthat/test-edge-case-contract.R`:

```r
test_that("create_mock_data accepts n = 0 and returns a full-schema empty frame", {
  fx <- minimal_example()
  result <- suppressMessages(create_mock_data(
    "minimal-example", fx$variables, fx$variable_details, n = 0
  ))
  expect_identical(nrow(result), 0L)
  expect_true(all(c("age", "smoking") %in% names(result)))
})

test_that("create_mock_data rejects fractional, negative, and NA n clearly", {
  fx <- minimal_example()
  for (bad_n in list(1.5, -1, NA)) {
    expect_error(
      suppressMessages(create_mock_data(
        "minimal-example", fx$variables, fx$variable_details, n = bad_n
      )),
      "non-negative whole number"
    )
  }
})
```

- [ ] **Step 2: Run to verify failure**

Run: `Rscript -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-edge-case-contract.R")'`
Expected: FAIL — n = 0 errors "n must be at least 1"; n = 1.5 does not error.

- [ ] **Step 3: Replace the guard**

In `R/create_mock_data.R`, replace exactly:

```r
  if (n < 1) {
    stop("n must be at least 1")
  }
```

with:

```r
  if (!is.numeric(n) || length(n) != 1 || is.na(n) ||
      n < 0 || n != trunc(n)) {
    stop("n must be a non-negative whole number.", call. = FALSE)
  }
```

- [ ] **Step 4: Run the tests again**

Expected: the two new tests pass. **Bounded contingency:** if the n = 0 test now fails *deeper* in the pipeline, the spec-layer contract (verified: 0-row generation works) means the failure is orchestrator glue — fix the failing helper to propagate a zero-row frame, keeping the fix minimal. If the failure is on the **legacy** path only (`validate = FALSE`), instead add after the new guard:

```r
  if (n == 0 && !validate) {
    stop("n = 0 requires validate = TRUE (v0.4 pipeline).", call. = FALSE)
  }
```

and pin that with:

```r
test_that("legacy path states its n = 0 limitation clearly", {
  fx <- minimal_example()
  expect_error(
    suppressMessages(create_mock_data(
      "minimal-example", fx$variables, fx$variable_details, n = 0, validate = FALSE
    )),
    "requires validate = TRUE"
  )
})
```

- [ ] **Step 5: NEWS entry**

Under a `# MockData (development version)` heading at the top of `NEWS.md`:

```markdown
- `create_mock_data()` now accepts `n = 0`, returning a zero-row data frame
  with the full generated schema (useful for schema tests), and rejects
  fractional, negative, and `NA` values of `n` with a clear message. The
  validation now matches `generate_mock_data_native()`.
```

- [ ] **Step 6: Full suite, roxygenize (no roxygen changes expected, cheap safety), commit**

Run: `Rscript -e 'devtools::test()'` — expected green.

```bash
git add R/create_mock_data.R tests/testthat/test-edge-case-contract.R NEWS.md
git commit -m "Allow n = 0 in create_mock_data() and align n validation with the spec layer

Relates to #36."
```

### Task 3: Friendly upfront databaseStart check (#36)

**Files:**
- Modify: `R/create_mock_data.R` (top of function body, before `.load_metadata_df()` calls)
- Modify: `tests/testthat/test-edge-case-contract.R` (extend)

**Interfaces:**
- Consumes: `create_mock_data()` signature — `databaseStart` is the first positional parameter with no default.
- Produces: error message beginning `"databaseStart is required"`.

- [ ] **Step 1: Write the failing test**

```r
test_that("missing databaseStart produces a named, friendly error", {
  fx <- minimal_example()
  expect_error(
    create_mock_data(variables = fx$variables,
                     variable_details = fx$variable_details, n = 5),
    "databaseStart is required"
  )
})
```

- [ ] **Step 2: Run to verify failure**

Expected: FAIL — current error is R's raw `argument "databaseStart" is missing, with no default`.

- [ ] **Step 3: Add the check**

At the top of the `create_mock_data()` function body (immediately after the opening brace, before `# ========== LOAD METADATA ==========`):

```r
  if (missing(databaseStart)) {
    stop(
      "databaseStart is required. Pass the database or cycle name that ",
      "matches your metadata's databaseStart values (e.g. \"cycle1\").",
      call. = FALSE
    )
  }
```

- [ ] **Step 4: Run tests — expected PASS. Full suite — expected green.**

- [ ] **Step 5: NEWS + commit**

Append to the development-version NEWS block:

```markdown
- Calling `create_mock_data()` without `databaseStart` now fails upfront with
  a message naming the argument, instead of a raw missing-argument error.
```

```bash
git add R/create_mock_data.R tests/testthat/test-edge-case-contract.R NEWS.md
git commit -m "Check databaseStart upfront in create_mock_data()

Closes #36."
```

### Task 4: Native exponential distribution (#37)

**Files:**
- Modify: `R/mock_spec.R` (`mock_continuous()` at :287, `mock_spec_continuous()` at :480, validator continuous block at :790-799)
- Modify: `R/mock_spec_native.R` (`.generate_native_continuous()` at :189; new helper next to `.native_truncated_normal()` at :75)
- Create: `tests/testthat/test-native-exponential.R`
- Modify: `NEWS.md`

**Interfaces:**
- Consumes: `.new_mock_spec_variable()` `...` passthrough (extra named fields land on the variable list — this is how `rate` becomes `variable$rate`); validator pattern of the normal block; `.native_truncated_normal()` as the structural template.
- Produces: `mock_continuous(..., rate =)`, `mock_spec_continuous(..., rate =)`, `.native_truncated_exponential(n, rate, range, variable_name)`; validator error string `"exponential distribution requires rate > 0"`.

- [ ] **Step 1: Write the failing tests**

```r
# tests/testthat/test-native-exponential.R
test_that("native exponential generates within the declared range", {
  spec <- mock_continuous("wait", range = c(0, 100),
                          distribution = "exponential", rate = 0.1)
  result <- generate_mock_data_native(spec, n = 500, seed = 42)
  expect_true(all(result$wait >= 0 & result$wait <= 100))
  expect_type(result$wait, "double")
})

test_that("native exponential is seed-reproducible", {
  spec <- mock_continuous("wait", range = c(0, 100),
                          distribution = "exponential", rate = 0.1)
  expect_identical(
    generate_mock_data_native(spec, n = 50, seed = 7),
    generate_mock_data_native(spec, n = 50, seed = 7)
  )
})

test_that("exponential without a positive rate is rejected", {
  # Constructors document that they return a validated mock_spec; expect the
  # error at construction. If construction is lazy in this version, assert on
  # validate_mock_spec(spec, strict = FALSE)$errors instead.
  expect_error(
    mock_continuous("wait", range = c(0, 100), distribution = "exponential"),
    "exponential distribution requires rate > 0"
  )
})

test_that("recodeflow-sourced rate flows to the native generator", {
  spec <- mock_continuous("wait", range = c(0, 50),
                          distribution = "exponential", rate = 0.5)
  result <- generate_mock_data_native(spec, n = 200, seed = 11)
  # rate = 0.5 on [0, 50]: truncated mean ~ 2; loose two-sided sanity bound
  expect_gt(mean(result$wait), 0.5)
  expect_lt(mean(result$wait), 6)
})
```

- [ ] **Step 2: Run to verify failure**

Run: `Rscript -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-native-exponential.R")'`
Expected: FAIL — `unused argument (rate = 0.1)` from `mock_continuous()`.

- [ ] **Step 3: Add `rate` to both constructors**

In `mock_continuous()` (`R/mock_spec.R:287`), add the parameter after `sd = NA_real_`:

```r
                            sd = NA_real_,
                            rate = NA_real_,
```

and forward it inside the `mock_spec_continuous(...)` call:

```r
      mean = mean,
      sd = sd,
      rate = rate,
```

In `mock_spec_continuous()` (`R/mock_spec.R:480`), same pattern — parameter after `sd = NA_real_`, and forward inside `.new_mock_spec_variable(...)`:

```r
    mean = mean,
    sd = sd,
    rate = rate,
```

(`.new_mock_spec_variable()` accepts `...`, so `rate` lands on the variable list as `variable$rate`.)

Add roxygen `@param rate Rate parameter; required when `distribution = "exponential"`.` to both constructors' documentation blocks.

- [ ] **Step 4: Add the validator rule**

In `.validate_mock_spec_variable()` (`R/mock_spec.R`), directly after the closing brace of the `if (identical(variable$distribution, "normal")) {...}` block (:792-799):

```r
    if (identical(variable$distribution, "exponential")) {
      if (is.null(variable$rate) || length(variable$rate) != 1 ||
          is.na(variable$rate) || variable$rate <= 0) {
        errors <- c(errors, paste0(
          "Variable '", variable$name,
          "' exponential distribution requires rate > 0."
        ))
      }
    }
```

- [ ] **Step 5: Add the generator branch and helper**

In `.generate_native_continuous()` (`R/mock_spec_native.R:189`), insert before the final `else { stop(...) }`:

```r
  } else if (distribution == "exponential") {
    values <- .native_truncated_exponential(
      n,
      variable$rate,
      variable$range,
      variable$name
    )
```

New helper, placed immediately after `.native_truncated_normal()`:

```r
#' @noRd
.native_truncated_exponential <- function(n, rate, range, variable_name) {
  lower <- range[[1]]
  upper <- range[[2]]
  p_lower <- stats::pexp(lower, rate = rate)
  p_upper <- stats::pexp(upper, rate = rate)
  if (!is.finite(p_lower) || !is.finite(p_upper) || p_upper <= p_lower) {
    stop(
      "Variable '", variable_name,
      "' exponential distribution has no probability mass inside range [",
      lower, ", ", upper, "].",
      call. = FALSE
    )
  }
  stats::qexp(stats::runif(n, p_lower, p_upper), rate = rate)
}
```

- [ ] **Step 6: Run the test file — expected PASS. Then `Rscript -e 'devtools::document()'` and full suite — expected green.**

- [ ] **Step 7: NEWS + commit**

```markdown
- The native backend now supports `distribution = "exponential"` (parity with
  the legacy generator), removing a forced legacy-fallback for exponential
  metadata. Unlike the legacy `rexp()`, native exponential values are
  truncated to the declared `range`, consistent with the native normal
  distribution.
```

```bash
git add R/mock_spec.R R/mock_spec_native.R tests/testthat/test-native-exponential.R NEWS.md man/
git commit -m "Add exponential distribution to the native backend

Closes #37. Enables the exponential half of #24 on the native path."
```

---

## Phase 2 — v0.5 feature train (design-first; ADR gate before implementation)

Tasks 5 and 6 **must land in the same minor release**: both change seeded output, and the budget is one break with one NEWS migration note. Task 7 has no seed impact and may ride along.

### Task 5: Seed-contract ADR (#38)

**Deliverable:** `development/adr/v05-seed-contract.md`, approved by the maintainer.

- [ ] **Step 1: Draft the ADR** with these sections and decision points:
  - **Context:** three regimes (legacy global `set.seed` at `R/create_mock_data.R:325-327`; v0.4 `seed`/`seed + 1L` at `:85-90`; simstudy backend's own handling); fallback stream-switch is verbose-gated (#33 item 11).
  - **Options:** (a) document the status quo; (b) L'Ecuyer-CMRG sub-streams via `parallel::nextRNGStream()`, one stream per stage; (c) hash-derived per-stage (or per-variable) integer seeds. **Recommendation: (b) at stage granularity** — principled, base-R only, and per-variable granularity is YAGNI until parallel generation is on the table.
  - **Guarantee scope:** same seed + same spec + same package version ⇒ identical output; stability across minor versions explicitly *not* guaranteed when NEWS declares a break.
  - **Migration:** single break, coordinated with Task 6; pinned-value regression tests (fulfils #22); decide whether the fallback stream-switch message becomes always-on (#33 item 11).
- [ ] **Step 2: Maintainer review — STOP until approved.**
- [ ] **Step 3: Write the implementation plan** (superpowers:writing-plans → `development/plans/`) and execute.

### Task 6: Formula-evaluator ADR + implementation (#39)

**Deliverable:** `development/adr/v05-formula-evaluator.md`, approved; then phased implementation.

- [ ] **Step 1: Recover the spike:** `git show f4f9b41:development/v04-simstudy-spike/prototype.R > /tmp/spike-prototype.R` and read it. It contains `formula_dependencies()` (`all.vars(str2lang(...))`), topological ordering with cycle detection ("Formula dependency cycle or unresolved ordering among: ..."), and `validate_formula_referents()`.
- [ ] **Step 2: Draft the ADR** with these decision points:
  - **Syntax entry:** (a) new MockData-extension column (e.g. `mockFormula`) vs (b) reuse `variableStart` `DerivedVar::`/`Func::`. **Recommendation: (a)** — cchsflow/chmsflow are CRAN downstreams; do not overload shared recodeflow semantics. `identify_derived_vars()` continues to detect-and-skip `DerivedVar::` entries that carry no `mockFormula`.
  - **Evaluation environment:** restricted env containing only generated columns + an enumerated whitelist of base math/logic functions (`+ - * / ^ %% < <= > >= == != & | ! ifelse pmin pmax log exp sqrt abs round`); no filesystem, network, or global lookup. List the exact whitelist in the ADR.
  - **Phasing:** Phase A — algebraic formulas over generated columns (spec fields `formula`/`depends_on` already exist, `R/mock_spec.R:94-145`). Phase B — `Func::` dispatch to the consuming package's namespace (define lookup order and failure semantics).
  - **Diagnostics:** derived columns get a `derived = TRUE` entry in `mockdata_diagnostics` with their dependency list.
- [ ] **Step 3: Maintainer review — STOP until approved.**
- [ ] **Step 4: Implementation plan + execution.** Required tests: referent validation errors, cycle detection message, deterministic ordering, seed reproducibility under the Task 5 contract.

### Task 7: Survival pairs in batch generation (#40)

**Deliverable:** short design note (may be a section in the implementation plan rather than a full ADR), then implementation.

- [ ] **Step 1: Decide the pairing convention** — recommendation: an explicit `anchor` extension column on the event variable's metadata row naming its entry-date variable. Metadata fields `followup_min`/`followup_max`/`event_prop` already flow (`R/mock_spec_recodeflow.R:367-369`).
- [ ] **Step 2: Define the multi-column generator contract** — a spec variable of type `survival` returns a 2-column data frame; the assembly loop accepts multi-column returns; `validate_mock_spec()` checks the anchor exists, is a date variable, and ordering constraints hold.
- [ ] **Step 3: Implementation plan + execution.** Required tests: event/censoring proportions with two-sided bounds (#23's direction); diagnostics attribute both columns to one spec entry; NEWS removes the standing known-issue entry.

### Task 8: v0.5 release assembly

- [ ] Tasks 5 + 6 merged together; one NEWS migration section covering the seeded-output break with before/after guidance.
- [ ] Pinned-value seed regression tests in place (#22 closed).
- [ ] `devtools::check()` clean; `roxygen2::roxygenize()` then `pkgdown::build_site()` clean; `renv::snapshot()` if dependencies moved.
- [ ] Version bump to 0.5.0; downstream heads-up to cchsflow/chmsflow maintainers if any metadata-extension columns were added.

---

## Phase 3 — v0.6

### Task 9: Table 1 bootstrap adapter (#41)

**Deliverable:** `development/adr/v06-table1-adapter.md` (short), then `mock_spec_from_table1()`.

Strict-schema v1 only — tidy input data frame (`variable`, `type`, `level`, `prop`, `mean`, `sd`, `min`, `max`) → validated `mock_spec`. Explicit v1 exclusions (in the issue and the ADR): no median/IQR conversion, no stratified panels, no document/PDF parsing, and a vignette-level scope statement that outputs match *marginals* for testing and teaching — not synthetic data for inference or release (the `cran-comments.md` boundary). Design can begin any time; implementation targets v0.6.

## Deferred register (do not schedule; activate on trigger)

- **Correlated variables (#42):** trigger = seed ADR (#38) landed **and** a concrete derived-variable test that cannot get coverage from independent marginals. simstudy-backend-only; plausibility-not-fidelity documentation mandatory.
- **LinkML / schema-first (#43):** trigger = a second ecosystem consumer needs formal schema validation. First step is an org-level ADR in a recodeflow ecosystem repo — not MockData code.
- **Distribution registry:** no issue filed — YAGNI. The path, should demand appear, is more native built-ins (Task 4 pattern), not a public registration API.

## Self-review (performed at plan date)

- **Coverage:** all eight assessed improvement areas map to a task or register entry; issues #35–#43 cross-linked; pre-existing #13/#14/#22/#23/#24/#25/#33 reconciled.
- **Placeholder scan:** Phase 1 steps contain complete code verified against the tree; the two bounded contingencies (Task 2 Step 4, Task 4 Step 1's construction-vs-lazy validation note) provide exact code for both branches rather than deferring the decision.
- **Type consistency:** `rate` flows constructor → `...` → `variable$rate` → validator → `.native_truncated_exponential()`; message strings quoted in tests match the code that raises them.
