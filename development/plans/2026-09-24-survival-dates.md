# Metadata-Driven Survival Dates Implementation Plan (#40)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `create_mock_data()` generates entry, event, death, loss-to-follow-up and administrative-censoring dates from metadata alone, by computing `type = "survival"` variables from their anchor dates in a post-baseline stage.

**Architecture:** A new spec type `survival` (rtype `date`). Both backends skip derived types (formula, survival) in baseline generation. A new exported `generate_survival_dates(data, spec, seed)` processes survival variables one at a time in dependency order (draw, then the before-anchor and `censored_by` rules) under `.with_mock_seed(stage = "survival")`. `create_mock_data()` runs baseline → survival → formulas → postprocess. The recodeflow adapter builds survival variables from `variables.csv` rows that set `anchor`. The legacy engine is unchanged apart from a deprecation warning, and the legacy dispatcher stops on anchored metadata.

**Tech stack:** base R (no new dependency), testthat 3e (3.2.3), roxygen2.

**Spec:** [development/adr/v05-survival-dates.md](../adr/v05-survival-dates.md) (ACCEPTED 2026-09-24, D1–D10; amended the same day after an external design review: chained censoring rejected, D8's status/time example corrected, data layers named). Issues: #40; concerns #54, #55, #56, #57 and #15; prerequisite #58 (PR #59).

**Base:** branch `v05-survival-dates` at `2548b51`: `v05-formula-evaluator` (#52, which carries #51) + the ADR commits + PR #59 (#58 range missing codes and minimal-example fixture corrections) merged in. Do not start until `git log --oneline -1` shows `2548b51` or a descendant.

**Prototype evidence (2026-09-24):** the Task 1 characterization tests were run against the legacy engine and pass; the Task 3 draw routine, rules and ordering were prototyped and pass 11 parity checks (competing risk both directions, exact event count, whole days inside the window, Gompertz #54 parity, exponential bounds, `n = 0`, flooring to zero events, `NA` anchors, draw order, cycle error). The Task 3 pinned values were computed independently by emulating `.with_mock_seed()` for stage index 4, not captured from the implementation.

## Global Constraints

- **Zero seeded-output change for specs without survival variables.** The #48 pins in `tests/testthat/test-seed-contract.R` (postprocess stage pin, pinned reference values) must pass untouched. If one fails, the code is wrong: fix the code, never the pin. The only permitted edit to that file's existing tests is extending the frozen-stage vector (Task 3) and dropping anchored rows in the two legacy-path tests (Task 4).
- **Survival draws use only `.MOCK_STAGES["survival"]`**, appended as `4L`. Never renumber indices 0–3.
- **Exact port (ADR D4).** The statistics and rules in Task 3 Step 3 come from `R/create_date_var.R:295-346` and `R/create_wide_survival_data.R:347,363`. Do not fix anything the ADR lists under Concerns (#54, #55, #56, #15), even where it looks wrong. Tests that pin those behaviours say so in a comment.
- **recodeflow semantics untouched.** `anchor` and `censored_by` are MockData extension columns on `variables.csv`.
- **CSV fixtures change only through R data-frame operations** (`read.csv`/`write.csv(row.names = FALSE, na = "")`), never sed, awk or hand edits (user CLAUDE.md). `write.csv` reproduces the minimal example byte for byte (verified).
- **No backward-compatibility obligation (0.x)**, but every new error names the fix, and every new error message is asserted by a test with a regex on a distinctive phrase.
- **Commits:** imperative subject in the repo's style with a `(#40)` suffix, wrapped body; no AI attribution (user CLAUDE.md overrides). Commit locally; do not push.
- **Test counts:** report all testthat columns, including `error`. Summing only `failed` hid #50. Use the snippet in Task 1 Step 1.
- **Environment:** the renv library lives under `~/Library/Caches` and macOS purges it. If `library(devtools)` fails, run `SDKROOT=$(xcrun --sdk macosx --show-sdk-path) Rscript -e 'renv::restore(prompt = FALSE)'` first. `devtools::check()` fails on this Mac's toolchain; use `R CMD build` then `R CMD check --as-cran --no-manual` on the tarball (Task 7).
- **Style for prose (NEWS, vignettes, roxygen):** Canadian Press spelling with -ize, sentence-case headings, "per cent" in running prose, no Unicode dashes in source (`~/github/ai-infrastructure/context/global_style.md`).

## Review Focus

1. **Legacy route with anchored metadata** (`validate = FALSE`, or another variable forcing the fallback): expect an error that names the survival variables. Test: Task 4, `legacy generator stops on anchored metadata instead of dropping survival dates`.
2. **Anchor not enabled** (role filtering drops the entry date but keeps its survival dates): expect a validation error naming the anchor, surfaced by `create_mock_data()`. Test: Task 4, `an anchor that is not enabled fails with a message naming it`.
3. **Character anchor column in standalone use** (a user reads dates from CSV and calls `generate_survival_dates()` directly): expect an error naming the column and its class. Test: Task 3, `generate_survival_dates rejects a non-Date anchor column`.
4. **Small n with a small event_prop** (n = 3, event_prop = 0.2, so `floor()` gives zero events): expect an all-`NA` `Date` column and `n_events = 0` in diagnostics, with no error or warning. Test: Task 3, `zero events from flooring is an all-NA column, not an error`.
5. **Mutual `censored_by`** (A censored by B, B censored by A): expect a dependency-cycle error at validation. Test: Task 2, `mutual censored_by is reported as a dependency cycle`.

---

### Task 1: Characterize the legacy survival engine

Pins what the port must reproduce, before any code changes. These tests describe current legacy behaviour and stay green throughout; the legacy engine is not changed (Task 6 adds a warning, which the Task 6 test helper pre-empts).

**Files:**
- Create: `tests/testthat/test-survival-characterization.R`

**Interfaces:**
- Consumes: `create_wide_survival_data()` (unchanged)
- Produces: nothing used by later tasks; the scenarios are mirrored against the new stage in Task 3.

- [x] **Step 1: Record the baseline**

```bash
cd /Users/dmanuel/github/mock-data && Rscript -e '
df <- as.data.frame(devtools::test(reporter = "silent", stop_on_failure = FALSE))
cat(sprintf("FAIL %d | ERROR %d | WARN %d | SKIP %d | PASS %d\n",
  sum(df$failed), sum(df$error), sum(df$warning), sum(df$skipped), sum(df$passed)))
bad <- df[df$failed > 0 | df$error, c("file", "test")]; if (nrow(bad)) print(bad)'
```

Expected at `2548b51` with simstudy installed: `FAIL 0 | ERROR 0 | WARN 35 | SKIP 3 | PASS 811`. Record the actual line; every later task compares against it.

- [x] **Step 2: Write the characterization tests**

```r
# tests/testthat/test-survival-characterization.R
# Characterization of the legacy survival engine (create_wide_survival_data()),
# pinned before the #40 port. ADR: development/adr/v05-survival-dates.md (D4).
# These describe current behaviour, including behaviour filed as concerns
# (#54, #56); they are the reference the metadata-driven stage must match.

legacy_fixture <- function(event_window, death_window,
                           event_prop = 1, death_prop = 1) {
  list(
    variables = data.frame(
      variable = c("entry", "event", "death"),
      variableType = c("Date", "Date", "Date"),
      rType = c("date", "date", "date"),
      role = c("enabled", "enabled", "enabled"),
      distribution = c("uniform", "uniform", "uniform"),
      followup_min = c(NA, event_window[1], death_window[1]),
      followup_max = c(NA, event_window[2], death_window[2]),
      event_prop = c(NA, event_prop, death_prop),
      sourceFormat = c("analysis", "analysis", "analysis"),
      stringsAsFactors = FALSE
    ),
    variable_details = data.frame(
      variable = c("entry", "event", "death"),
      recStart = c("[2001-01-01,2001-12-31]",
                   "[2001-01-01,2040-12-31]",
                   "[2001-01-01,2040-12-31]"),
      recEnd = c("copy", "copy", "copy"),
      proportion = c(1, 1, 1),
      stringsAsFactors = FALSE
    )
  )
}

run_legacy <- function(fx, n = 200, seed = 1) {
  suppressWarnings(create_wide_survival_data(
    var_entry_date = "entry",
    var_event_date = "event",
    var_death_date = "death",
    databaseStart = "test",
    variables = fx$variables,
    variable_details = fx$variable_details,
    n = n,
    seed = seed
  ))
}

days_from_entry <- function(result, column) {
  as.numeric(result[[column]] - result$entry)
}

test_that("legacy: an event later than death is set to NA (competing risk)", {
  result <- run_legacy(legacy_fixture(c(1000, 2000), c(0, 500)))
  expect_true(all(is.na(result$event)))
  expect_false(any(is.na(result$death)))
})

test_that("legacy: an event earlier than death is kept", {
  result <- run_legacy(legacy_fixture(c(0, 500), c(1000, 2000)))
  expect_false(any(is.na(result$event)))
})

test_that("legacy: exactly floor(n * event_prop) rows receive an event", {
  result <- run_legacy(legacy_fixture(c(100, 200), c(100, 200),
                                      event_prop = 0.3, death_prop = 0),
                       n = 200)
  expect_identical(sum(!is.na(result$event)), 60L)
  expect_true(all(is.na(result$death)))
})

test_that("legacy: follow-up days are whole days inside the window", {
  result <- run_legacy(legacy_fixture(c(100, 200), c(5000, 6000)))
  days <- days_from_entry(result, "event")
  days <- days[!is.na(days)]
  expect_true(all(days == floor(days)))
  expect_true(all(days >= 100 & days <= 200))
})

test_that("legacy: on the minimal example no date precedes the entry date", {
  vars <- system.file("extdata", "minimal-example", "variables.csv", package = "MockData")
  dets <- system.file("extdata", "minimal-example", "variable_details.csv", package = "MockData")
  if (!nzchar(vars) || !nzchar(dets)) skip("minimal-example fixtures not installed")
  variables <- read.csv(vars, stringsAsFactors = FALSE, check.names = FALSE)
  variable_details <- read.csv(dets, stringsAsFactors = FALSE, check.names = FALSE)
  result <- suppressWarnings(create_wide_survival_data(
    var_entry_date = "interview_date",
    var_event_date = "primary_event_date",
    var_death_date = "death_date",
    var_ltfu = "ltfu_date",
    var_admin_censor = "admin_censor_date",
    databaseStart = "minimal-example",
    variables = variables,
    variable_details = variable_details,
    n = 2000,
    seed = 1
  ))
  for (column in c("primary_event_date", "death_date", "ltfu_date", "admin_censor_date")) {
    ok <- !is.na(result[[column]])
    expect_true(all(result[[column]][ok] >= result$interview_date[ok]), info = column)
  }
  # #54: with the packaged Gompertz parameters every non-garbage death lands
  # exactly at followup_min (365 days). Garbage deaths are 2025 or later.
  # Update this expectation deliberately when #54 is resolved.
  days <- as.numeric(result$death_date - result$interview_date)
  clean <- !is.na(days) & result$death_date < as.Date("2025-01-01")
  expect_true(any(clean))
  expect_true(all(days[clean] == 365))
})
```

- [x] **Step 3: Run them — expected PASS (characterization)**

Run: `Rscript -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-survival-characterization.R")'`
Expected: 5 tests, 13 expectations, all PASS. If any fails, stop: the legacy engine differs from what the plan assumes; report rather than editing the test.

- [x] **Step 4: Commit**

```bash
git add tests/testthat/test-survival-characterization.R
git commit -m "Characterize the legacy survival engine before the port (#40)" -m "Pins the create_wide_survival_data() behaviour the metadata-driven stage
must reproduce: the death-censors-event rule in both directions, the exact
floor(n * event_prop) event count, whole-day follow-up inside the window,
no date before entry on the minimal example, and the #54 Gompertz clamp."
```

---

### Task 2: Survival spec layer

**Files:**
- Create: `R/mock_spec_survival.R`
- Modify: `R/mock_spec_formula.R:87-126` (generalize ordering)
- Modify: `R/mock_spec.R` (constructor after `mock_spec_formula()`, which ends near line 746; validator branch before the unsupported-type `else` near line 992; spec-level checks in `validate_mock_spec()` after the formula block near line 1046)
- Test: `tests/testthat/test-survival-vars.R` (new)

**Interfaces:**
- Consumes: `.new_mock_spec_variable()`, `.is_formula_variable()`, `.formula_dependencies()`, `.is_blank()` (defined in `R/mock_spec_recodeflow.R:34`), `` `%||%` `` (`R/mock_spec.R:45`)
- Produces:
  - `mock_spec_survival(name, anchor, followup_min, followup_max, event_prop, distribution = "uniform", censored_by = NULL, shape = NULL, rate = NULL, source_format = "analysis", missing_codes = character(0), missing_proportions = numeric(0), garbage_rules = list(), provenance = "direct", model_hint = "native-postprocess")` → `mock_spec_variable` with `type = "survival"`, `rtype = "date"`, fields `anchor`, `censored_by`, `followup_min`, `followup_max`, `event_prop`, `shape`, `rate`, `depends_on = c(anchor, censored_by)`
  - `.is_survival_variable(variable)` → logical; `.is_derived_variable(variable)` → TRUE for `formula` or `survival`
  - `.survival_dependencies(variable)` → character
  - `.validate_survival_variable(variable)` → character vector of errors
  - `.validate_survival_referents(spec)` → character vector of errors (includes the chained-censoring rejection)
  - `.order_dependent_variables(names_in_scope, dependencies, label)` → character (stops with `"<label> dependency cycle or unresolved ordering among: ..."`)
  - `.order_survival_variables(spec)` → character; `.order_formula_variables(spec)` keeps its behaviour and message

- [x] **Step 1: Write the failing tests**

```r
# tests/testthat/test-survival-vars.R
# Metadata-driven survival dates (#40). ADR: development/adr/v05-survival-dates.md

survival_spec <- function(...) {
  mock_spec(
    mock_spec_date("entry", range = as.Date(c("2001-01-01", "2001-12-31"))),
    ...
  )
}

test_that("mock_spec_survival constructs a validated survival variable", {
  spec <- survival_spec(
    mock_spec_survival("death", anchor = "entry", followup_min = 365,
                       followup_max = 7300, event_prop = 0.2),
    mock_spec_survival("event", anchor = "entry", followup_min = 0,
                       followup_max = 5475, event_prop = 0.3,
                       distribution = "gompertz", shape = 0.1, rate = 1e-4,
                       censored_by = "death")
  )
  expect_true(validate_mock_spec(spec)$valid)
  event <- spec$variables$event
  expect_identical(event$type, "survival")
  expect_identical(event$rtype, "date")
  expect_identical(event$anchor, "entry")
  expect_identical(event$censored_by, "death")
  expect_identical(event$distribution, "gompertz")
  expect_equal(event$followup_max, 5475)
  expect_equal(event$event_prop, 0.3)
  expect_identical(event$depends_on, c("entry", "death"))
  expect_identical(spec$variables$death$depends_on, "entry")
  expect_null(spec$variables$death$censored_by)
})

test_that("an anchor that is not in the spec fails validation", {
  expect_error(
    mock_spec(mock_spec_survival("death", anchor = "entry", followup_min = 0,
                                 followup_max = 10, event_prop = 1)),
    "anchor 'entry', which is not a variable in the spec"
  )
})

test_that("an anchor must be a date variable", {
  expect_error(
    mock_spec(
      mock_spec_continuous("age", range = c(18, 80)),
      mock_spec_survival("death", anchor = "age", followup_min = 0,
                         followup_max = 10, event_prop = 1)
    ),
    "an anchor must be a date variable"
  )
})

test_that("a survival variable cannot anchor another (no chained anchors in v0.5)", {
  expect_error(
    survival_spec(
      mock_spec_survival("a", anchor = "entry", followup_min = 0,
                         followup_max = 10, event_prop = 1),
      mock_spec_survival("b", anchor = "a", followup_min = 0,
                         followup_max = 10, event_prop = 1)
    ),
    "of type 'survival'; an anchor must be a date variable"
  )
})

test_that("censored_by must name a survival variable with the same anchor", {
  expect_error(
    survival_spec(
      mock_spec_survival("event", anchor = "entry", followup_min = 0,
                         followup_max = 10, event_prop = 1, censored_by = "entry")
    ),
    "censored_by 'entry' must be a survival variable"
  )
  expect_error(
    mock_spec(
      mock_spec_date("entry", range = as.Date(c("2001-01-01", "2001-12-31"))),
      mock_spec_date("entry2", range = as.Date(c("2001-01-01", "2001-12-31"))),
      mock_spec_survival("death", anchor = "entry2", followup_min = 0,
                         followup_max = 10, event_prop = 1),
      mock_spec_survival("event", anchor = "entry", followup_min = 0,
                         followup_max = 10, event_prop = 1, censored_by = "death")
    ),
    "must share its anchor"
  )
  expect_error(
    survival_spec(
      mock_spec_survival("event", anchor = "entry", followup_min = 0,
                         followup_max = 10, event_prop = 1, censored_by = "nope")
    ),
    "censored_by 'nope', which is not a variable in the spec"
  )
  expect_error(
    survival_spec(
      mock_spec_survival("event", anchor = "entry", followup_min = 0,
                         followup_max = 10, event_prop = 1, censored_by = "event")
    ),
    "cannot be censored by itself"
  )
})

test_that("chained censored_by is rejected with a message naming the fix (ADR D7)", {
  # A (day 30) censored by B (day 20) censored by C (day 10): sequential rules
  # would report A as observed although observation ended on day 10.
  expect_error(
    survival_spec(
      mock_spec_survival("a", anchor = "entry", followup_min = 30,
                         followup_max = 30, event_prop = 1, censored_by = "b"),
      mock_spec_survival("b", anchor = "entry", followup_min = 20,
                         followup_max = 20, event_prop = 1, censored_by = "c"),
      mock_spec_survival("c", anchor = "entry", followup_min = 10,
                         followup_max = 10, event_prop = 1)
    ),
    "which is itself censored by 'c'. Chained censoring is not supported"
  )
})

test_that("mutual censored_by is reported as a dependency cycle", {
  expect_error(
    survival_spec(
      mock_spec_survival("a", anchor = "entry", followup_min = 0,
                         followup_max = 10, event_prop = 1, censored_by = "b"),
      mock_spec_survival("b", anchor = "entry", followup_min = 0,
                         followup_max = 10, event_prop = 1, censored_by = "a")
    ),
    "Survival dependency cycle or unresolved ordering among: a, b"
  )
})

test_that("survival parameters are validated with messages that name the fix", {
  bad <- function(...) {
    args <- utils::modifyList(
      list(name = "event", anchor = "entry", followup_min = 0,
           followup_max = 10, event_prop = 0.5),
      list(...)
    )
    survival_spec(do.call(mock_spec_survival, args))
  }
  expect_error(bad(anchor = ""), "requires an anchor")
  expect_error(bad(followup_min = NA_real_),
               "requires finite numeric followup_min and followup_max")
  expect_error(bad(followup_min = -1), "followup_min must be >= 0")
  expect_error(bad(followup_min = 20, followup_max = 10),
               "followup_min must be <= followup_max")
  expect_error(bad(event_prop = 1.5), "event_prop must be a number in \\[0, 1\\]")
  expect_error(bad(distribution = "weibull"),
               "distribution must be one of: uniform, exponential, gompertz")
  expect_error(bad(shape = -1), "shape must be a positive number when supplied")
  expect_error(bad(rate = 0), "rate must be a positive number when supplied")
  expect_error(bad(source_format = "csv"), "supports sourceFormat 'analysis' only")
})

test_that("survival ordering places a censored_by target before the variable it censors", {
  spec <- survival_spec(
    mock_spec_survival("event", anchor = "entry", followup_min = 0,
                       followup_max = 10, event_prop = 1, censored_by = "death"),
    mock_spec_survival("death", anchor = "entry", followup_min = 0,
                       followup_max = 10, event_prop = 1),
    mock_spec_survival("ltfu", anchor = "entry", followup_min = 0,
                       followup_max = 10, event_prop = 1)
  )
  # Repeated passes in spec order: pass 1 places death and ltfu, pass 2 event.
  expect_identical(MockData:::.order_survival_variables(spec),
                   c("death", "ltfu", "event"))
})

test_that("formula ordering is unchanged by the shared ordering helper", {
  spec <- mock_spec(
    mock_spec_formula("c", formula = "b + 1"),
    mock_spec_formula("b", formula = "a * 2"),
    mock_spec_continuous("a", range = c(0, 1))
  )
  expect_identical(MockData:::.order_formula_variables(spec), c("b", "c"))
})
```

- [x] **Step 2: Run to verify failure**

Run: `Rscript -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-survival-vars.R")'`
Expected: FAIL/ERROR with `could not find function "mock_spec_survival"` (the formula-ordering test passes already).

- [x] **Step 3: Generalize the ordering helper in `R/mock_spec_formula.R`**

Replace the whole of `.order_formula_variables()` (lines 87-126, from `#' @noRd` through its closing `}`) with:

```r
#' @noRd
.order_dependent_variables <- function(names_in_scope, dependencies, label) {
  # Shared by every derived-variable stage (ADR v05-survival-dates D7):
  # repeated passes in spec order, each placing the variables whose in-scope
  # dependencies are already placed. Dependencies outside `names_in_scope`
  # (baseline columns) are available from the start.
  remaining <- names_in_scope
  ordered <- character(0)
  while (length(remaining) > 0) {
    progressed <- FALSE
    for (name in remaining) {
      deps <- intersect(dependencies[[name]], names_in_scope)
      if (all(deps %in% ordered)) {
        ordered <- c(ordered, name)
        remaining <- setdiff(remaining, name)
        progressed <- TRUE
      }
    }
    if (!progressed) {
      stop(
        label, " dependency cycle or unresolved ordering among: ",
        paste(remaining, collapse = ", "),
        call. = FALSE
      )
    }
  }
  ordered
}

#' @noRd
.order_formula_variables <- function(spec) {
  formula_names <- names(spec$variables)[
    vapply(spec$variables, .is_formula_variable, logical(1))
  ]
  # Skip unparseable formulas here too (see .validate_formula_referents()):
  # the per-variable validator already reports the parse error once, and a
  # variable that can't be parsed has no computable dependency set — leaving
  # it in `formula_names` would either duplicate the parse error (via
  # .formula_dependencies()) or permanently block any variable that
  # references it from ever being ordered.
  parseable_names <- Filter(function(name) {
    tryCatch({
      .parse_mock_formula(spec$variables[[name]])
      TRUE
    }, error = function(e) FALSE)
  }, formula_names)

  dependencies <- lapply(spec$variables[parseable_names], .formula_dependencies)
  .order_dependent_variables(parseable_names, dependencies, "Formula")
}
```

- [x] **Step 4: Create `R/mock_spec_survival.R`**

```r
# ==============================================================================
# Metadata-driven survival dates (#40) — spec-side helpers.
# Generation lives in generate_survival_dates() (same file, added in Task 3).
# ADR: development/adr/v05-survival-dates.md
# ==============================================================================

.survival_distributions <- c("uniform", "exponential", "gompertz")

#' @noRd
.is_survival_variable <- function(variable) {
  identical(variable$type, "survival")
}

#' @noRd
.is_derived_variable <- function(variable) {
  # Derived types are computed after baseline generation from already-generated
  # columns, so both backends skip them (ADR v05-survival-dates D1, D7).
  .is_formula_variable(variable) || .is_survival_variable(variable)
}

#' @noRd
.survival_dependencies <- function(variable) {
  if (!.is_survival_variable(variable)) {
    return(character(0))
  }
  deps <- as.character(c(variable$anchor, variable$censored_by))
  unique(deps[!is.na(deps) & nzchar(trimws(deps))])
}

#' @noRd
.validate_survival_variable <- function(variable) {
  errors <- character(0)
  label <- paste0("Survival variable '", variable$name, "'")
  is_number <- function(x) {
    is.numeric(x) && length(x) == 1 && !is.na(x) && is.finite(x)
  }

  if (.is_blank(variable$anchor)) {
    errors <- c(errors, paste0(
      label, " requires an anchor (the name of its entry-date variable)."
    ))
  }

  followup_min <- variable$followup_min
  followup_max <- variable$followup_max
  if (!is_number(followup_min) || !is_number(followup_max)) {
    errors <- c(errors, paste0(
      label, " requires finite numeric followup_min and followup_max (days)."
    ))
  } else {
    if (followup_min < 0) {
      errors <- c(errors, paste0(label, " followup_min must be >= 0."))
    }
    if (followup_min > followup_max) {
      errors <- c(errors, paste0(label, " followup_min must be <= followup_max."))
    }
  }

  event_prop <- variable$event_prop
  if (!is_number(event_prop) || event_prop < 0 || event_prop > 1) {
    errors <- c(errors, paste0(label, " event_prop must be a number in [0, 1]."))
  }

  distribution <- variable$distribution %||% "uniform"
  if (!distribution %in% .survival_distributions) {
    errors <- c(errors, paste0(
      label, " distribution must be one of: ",
      paste(.survival_distributions, collapse = ", "), "."
    ))
  }

  for (param in c("shape", "rate")) {
    value <- variable[[param]]
    supplied <- !is.null(value) && !(length(value) == 1 && is.na(value))
    if (supplied && !(is_number(value) && value > 0)) {
      errors <- c(errors, paste0(
        label, " ", param, " must be a positive number when supplied."
      ))
    }
  }

  if (!identical(variable$rtype, "date")) {
    errors <- c(errors, paste0(label, " must have rType 'date'."))
  }
  if (!identical(variable$source_format %||% "analysis", "analysis")) {
    errors <- c(errors, paste0(
      label, " supports sourceFormat 'analysis' only in this version."
    ))
  }

  errors
}

#' @noRd
.validate_survival_referents <- function(spec) {
  errors <- character(0)
  for (variable in spec$variables) {
    if (!.is_survival_variable(variable)) next
    label <- paste0("Survival variable '", variable$name, "'")

    anchor <- variable$anchor
    if (!.is_blank(anchor)) {
      anchor_variable <- spec$variables[[anchor]]
      if (is.null(anchor_variable)) {
        errors <- c(errors, paste0(
          label, " has anchor '", anchor, "', which is not a variable in the ",
          "spec. Enable the entry-date variable or correct the anchor."
        ))
      } else if (!identical(anchor_variable$type, "date")) {
        errors <- c(errors, paste0(
          label, " has anchor '", anchor, "' of type '", anchor_variable$type,
          "'; an anchor must be a date variable."
        ))
      }
    }

    censor <- variable$censored_by
    if (.is_blank(censor)) next
    censor_variable <- spec$variables[[censor]]
    if (identical(censor, variable$name)) {
      errors <- c(errors, paste0(label, " cannot be censored by itself."))
    } else if (is.null(censor_variable)) {
      errors <- c(errors, paste0(
        label, " has censored_by '", censor,
        "', which is not a variable in the spec."
      ))
    } else if (!.is_survival_variable(censor_variable)) {
      errors <- c(errors, paste0(
        label, " has censored_by '", censor, "'; censored_by '", censor,
        "' must be a survival variable."
      ))
    } else if (!identical(censor_variable$anchor, anchor)) {
      errors <- c(errors, paste0(
        label, " has censored_by '", censor,
        "', which must share its anchor ('", anchor, "')."
      ))
    } else if (!.is_blank(censor_variable$censored_by)) {
      # ADR D7: with a chain (A by B, B by C) the sequential rules report A as
      # observed after observation ended, so chains are rejected in v0.5.
      errors <- c(errors, paste0(
        label, " has censored_by '", censor, "', which is itself censored by '",
        censor_variable$censored_by, "'. Chained censoring is not supported in ",
        "this version; censor '", variable$name, "' by the earliest date ",
        "directly, or derive observed outcomes after generation."
      ))
    }
  }
  errors
}

#' @noRd
.order_survival_variables <- function(spec) {
  survival_names <- names(spec$variables)[
    vapply(spec$variables, .is_survival_variable, logical(1))
  ]
  dependencies <- lapply(spec$variables[survival_names], .survival_dependencies)
  .order_dependent_variables(survival_names, dependencies, "Survival")
}
```

- [x] **Step 5: Add the constructor to `R/mock_spec.R`**

Insert immediately after the closing `}` of `mock_spec_formula()` (the line after `  variable\n}` that ends it, before `#' Check whether an object is a MockData specification`):

```r
#' Create a survival date variable specification
#'
#' `mock_spec_survival()` describes a date generated relative to an anchor
#' (entry) date: `floor(n * event_prop)` rows receive a date a follow-up time
#' after the anchor, drawn within `[followup_min, followup_max]` days, and the
#' rest are `NA` (censored). Survival variables are computed after baseline
#' generation by [generate_survival_dates()], so the anchor must be another
#' variable in the same [mock_spec()].
#'
#' @param name Variable name.
#' @param anchor Name of the date variable this date is generated relative to.
#' @param followup_min,followup_max Follow-up window in days after the anchor.
#' @param event_prop Share of rows that receive an event, in `[0, 1]`.
#' @param distribution Follow-up time distribution: `"uniform"`,
#'   `"exponential"`, or `"gompertz"`.
#' @param censored_by Optional name of a competing survival variable with the
#'   same anchor. Where that date is earlier than this one, this one becomes
#'   `NA`.
#' @param shape,rate Optional Gompertz parameters (defaults 0.1 and 0.0001).
#'   The exponential distribution derives its rate from the follow-up window.
#' @param source_format Output format. Only `"analysis"` (R `Date`) is
#'   supported for survival dates.
#' @param missing_codes,missing_proportions,garbage_rules,provenance,model_hint
#'   As for other variable specifications; applied by post-processing after
#'   the survival rules.
#'
#' @return A `mock_spec_variable` object of type `"survival"`.
#' @family mock specification APIs
#' @seealso [generate_survival_dates()], [mock_spec_date()]
#'
#' @examples
#' spec <- mock_spec(
#'   mock_spec_date("entry", range = as.Date(c("2001-01-01", "2005-12-31"))),
#'   mock_spec_survival("death", anchor = "entry",
#'     followup_min = 365, followup_max = 7300, event_prop = 0.2),
#'   mock_spec_survival("event", anchor = "entry",
#'     followup_min = 0, followup_max = 5475, event_prop = 0.3,
#'     censored_by = "death")
#' )
#' validate_mock_spec(spec)
#'
#' @export
mock_spec_survival <- function(name,
                               anchor,
                               followup_min,
                               followup_max,
                               event_prop,
                               distribution = "uniform",
                               censored_by = NULL,
                               shape = NULL,
                               rate = NULL,
                               source_format = "analysis",
                               missing_codes = character(0),
                               missing_proportions = numeric(0),
                               garbage_rules = list(),
                               provenance = "direct",
                               model_hint = "native-postprocess") {
  variable <- .new_mock_spec_variable(
    name = name,
    type = "survival",
    rtype = "date",
    distribution = distribution,
    source_format = source_format,
    missing_codes = missing_codes,
    missing_proportions = missing_proportions,
    garbage_rules = garbage_rules,
    provenance = provenance,
    model_hint = model_hint,
    anchor = anchor,
    censored_by = censored_by,
    followup_min = followup_min,
    followup_max = followup_max,
    event_prop = event_prop,
    shape = shape,
    rate = rate
  )
  # Computed once at construction, as for mock_spec_formula(); anchor and
  # censored_by feed the shared dependency ordering (ADR D7).
  variable$depends_on <- .survival_dependencies(variable)
  variable
}

```

- [x] **Step 6: Validator branches in `R/mock_spec.R`**

In `.validate_mock_spec_variable()`, replace:

```r
  } else {
    errors <- c(errors, paste0("Variable '", variable$name, "' has unsupported type '", variable$type, "'."))
  }
```

with:

```r
  } else if (variable$type == "survival") {
    errors <- c(errors, .validate_survival_variable(variable))
  } else {
    errors <- c(errors, paste0("Variable '", variable$name, "' has unsupported type '", variable$type, "'."))
  }
```

In `validate_mock_spec()`, replace:

```r
      if (!is.null(formula_error)) {
        errors <- c(errors, formula_error)
      }
```

with:

```r
      if (!is.null(formula_error)) {
        errors <- c(errors, formula_error)
      }

      errors <- c(errors, .validate_survival_referents(spec))
      survival_error <- tryCatch({
        .order_survival_variables(spec)
        NULL
      }, error = function(e) conditionMessage(e))
      if (!is.null(survival_error)) {
        errors <- c(errors, survival_error)
      }
```

- [x] **Step 7: Run the new tests — expected PASS**

Run: `Rscript -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-survival-vars.R")'`
Expected: 10 tests PASS.

- [x] **Step 8: Document, run the full suite, commit**

Run `Rscript -e 'devtools::document()'`, then the Task 1 Step 1 snippet. Expected: FAIL 0 | ERROR 0, WARN and SKIP unchanged from the baseline, PASS up by this task's expectations. The existing formula tests (`test-formula-vars.R`, including `"dependency cycle"`) must pass unchanged.

```bash
git add R/mock_spec_survival.R R/mock_spec_formula.R R/mock_spec.R NAMESPACE tests/testthat/test-survival-vars.R
git commit -m "Add the survival variable type to the mock_spec layer (#40)" -m "mock_spec_survival() builds a type = \"survival\" date with anchor,
censored_by, follow-up window, event_prop and distribution parameters, and
records depends_on = c(anchor, censored_by). validate_mock_spec() checks
each variable's parameters and the spec-level referents (anchor is a date
in the spec; censored_by is an uncensored survival variable with the same
anchor, since chained censoring gives wrong observed outcomes) and reports
mutual censored_by as a dependency cycle.

The #39 formula ordering becomes a shared .order_dependent_variables(),
which formulas and survival dates both use (ADR D7); formula ordering and
its messages are unchanged."
```

---

### Task 3: Survival stage, backend skips, diagnostics and seed

**Files:**
- Modify: `R/mock_spec_survival.R` (append the generation code)
- Modify: `R/mock_spec_native.R:8-17` (`.MOCK_STAGES`), `R/mock_spec_native.R` `generate_mock_data_native()` skip and its `@return`
- Modify: `R/mock_spec_simstudy.R` (`.native_only_variables()` and `generated_variable_names` in `generate_mock_data_simstudy()`)
- Modify: `R/mock_spec_postprocess.R:10` (`.postprocess_empty_diagnostics()`) and its call near line 388
- Modify: `tests/testthat/test-seed-contract.R:99-104` (frozen stages) and append a pinned test
- Test: `tests/testthat/test-survival-vars.R` (append)

**Interfaces:**
- Consumes: everything Task 2 produces; `.with_mock_seed(seed, expr, stage)`; `generate_mock_data_native()`; `postprocess_mock_data()`
- Produces:
  - `generate_survival_dates(data, spec, seed = NULL)` → `data` with one appended `Date` column per survival variable (exported)
  - `.draw_survival_dates(variable, anchor_dates)` → `Date` vector; `.survival_event_days(variable, n_events)` → numeric
  - `.MOCK_STAGES["survival"] == 4L`
  - diagnostics fields for survival variables: `derived`, `anchor`, `censored_by`, `depends_on`, `n_events`

- [x] **Step 1: Write the failing tests (append to `tests/testthat/test-survival-vars.R`)**

```r
run_stage <- function(spec, n = 200, seed = 1) {
  baseline <- generate_mock_data_native(spec, n = n, seed = seed)
  generate_survival_dates(baseline, spec, seed = seed)
}

days_after <- function(data, column, anchor = "entry") {
  as.numeric(data[[column]] - data[[anchor]])
}

test_that("both backends skip survival variables in baseline generation", {
  spec <- survival_spec(
    mock_spec_survival("death", anchor = "entry", followup_min = 0,
                       followup_max = 10, event_prop = 1)
  )
  expect_identical(names(generate_mock_data_native(spec, n = 5, seed = 1)), "entry")
  skip_if_not_installed("simstudy")
  expect_identical(names(generate_mock_data_simstudy(spec, n = 5, seed = 1)), "entry")
})

test_that("the survival stage runs on a simstudy baseline too", {
  skip_if_not_installed("simstudy")
  spec <- survival_spec(
    mock_spec_categorical("smoking", levels = c("never", "former", "current")),
    mock_spec_survival("death", anchor = "entry", followup_min = 0,
                       followup_max = 100, event_prop = 0.5)
  )
  baseline <- generate_mock_data_simstudy(spec, n = 100, seed = 1)
  result <- generate_survival_dates(baseline, spec, seed = 1)
  expect_identical(sum(!is.na(result$death)), 50L)
  expect_true(all(result$death >= result$entry, na.rm = TRUE))
})

test_that("the survival stage reproduces the legacy competing-risk rule", {
  later <- run_stage(survival_spec(
    mock_spec_survival("event", anchor = "entry", followup_min = 1000,
                       followup_max = 2000, event_prop = 1, censored_by = "death"),
    mock_spec_survival("death", anchor = "entry", followup_min = 0,
                       followup_max = 500, event_prop = 1)
  ))
  expect_true(all(is.na(later$event)))
  expect_false(any(is.na(later$death)))

  earlier <- run_stage(survival_spec(
    mock_spec_survival("event", anchor = "entry", followup_min = 0,
                       followup_max = 500, event_prop = 1, censored_by = "death"),
    mock_spec_survival("death", anchor = "entry", followup_min = 1000,
                       followup_max = 2000, event_prop = 1)
  ))
  expect_false(any(is.na(earlier$event)))
})

test_that("censored_by sets NA exactly where the censoring date is earlier", {
  result <- run_stage(survival_spec(
    mock_spec_survival("event", anchor = "entry", followup_min = 0,
                       followup_max = 1000, event_prop = 1, censored_by = "death"),
    mock_spec_survival("death", anchor = "entry", followup_min = 0,
                       followup_max = 1000, event_prop = 0.5)
  ), n = 400)
  both <- !is.na(result$event) & !is.na(result$death)
  expect_false(any(result$death[both] < result$event[both]))
  # event_prop = 1, so the only way an event is NA is censoring by an
  # earlier death.
  expect_true(all(!is.na(result$death[is.na(result$event)])))
  expect_gt(sum(is.na(result$event)), 0)
  expect_gt(sum(both), 0)
})

test_that("exactly floor(n * event_prop) rows receive an event", {
  result <- run_stage(survival_spec(
    mock_spec_survival("event", anchor = "entry", followup_min = 100,
                       followup_max = 200, event_prop = 0.3)
  ), n = 200)
  expect_identical(sum(!is.na(result$event)), 60L)
})

test_that("follow-up days are whole days inside the window for every distribution", {
  for (distribution in c("uniform", "exponential", "gompertz")) {
    result <- run_stage(survival_spec(
      mock_spec_survival("event", anchor = "entry", followup_min = 10,
                         followup_max = 400, event_prop = 1,
                         distribution = distribution)
    ))
    days <- days_after(result, "event")
    expect_false(anyNA(days), info = distribution)
    expect_true(all(days == floor(days)), info = distribution)
    expect_true(all(days >= 10 & days <= 400), info = distribution)
  }
})

test_that("gompertz with the packaged parameters reproduces the legacy clamp (#54)", {
  # Pins behaviour filed as #54; update deliberately when #54 is resolved.
  result <- run_stage(survival_spec(
    mock_spec_survival("death", anchor = "entry", followup_min = 365,
                       followup_max = 7300, event_prop = 1,
                       distribution = "gompertz", shape = 0.1, rate = 1e-4)
  ))
  expect_true(all(days_after(result, "death") == 365))
})

test_that("n = 0 returns a typed zero-row survival column", {
  result <- run_stage(survival_spec(
    mock_spec_survival("event", anchor = "entry", followup_min = 0,
                       followup_max = 10, event_prop = 0.5)
  ), n = 0)
  expect_identical(nrow(result), 0L)
  expect_s3_class(result$event, "Date")
})

test_that("zero events from flooring is an all-NA column, not an error", {
  spec <- survival_spec(
    mock_spec_survival("event", anchor = "entry", followup_min = 0,
                       followup_max = 10, event_prop = 0.2)
  )
  expect_no_warning(result <- run_stage(spec, n = 3))
  expect_true(all(is.na(result$event)))
  expect_s3_class(result$event, "Date")
  diag <- attr(postprocess_mock_data(result, spec, seed = 1), "mockdata_diagnostics")
  expect_identical(diag$variables$event$n_events, 0L)
})

test_that("NA anchors give NA survival dates in those rows only", {
  spec <- survival_spec(
    mock_spec_survival("event", anchor = "entry", followup_min = 1,
                       followup_max = 2, event_prop = 1)
  )
  data <- data.frame(entry = as.Date("2001-01-01") + 0:9)
  data$entry[1:3] <- as.Date(NA)
  result <- generate_survival_dates(data, spec, seed = 1)
  expect_true(all(is.na(result$event[1:3])))
  expect_false(anyNA(result$event[4:10]))
})

test_that("generate_survival_dates rejects a non-Date anchor column", {
  spec <- survival_spec(
    mock_spec_survival("event", anchor = "entry", followup_min = 0,
                       followup_max = 10, event_prop = 1)
  )
  data <- data.frame(entry = c("2001-01-01", "2001-06-01"), stringsAsFactors = FALSE)
  expect_error(
    generate_survival_dates(data, spec, seed = 1),
    "Anchor column 'entry' must be of class Date; got character"
  )
})

test_that("generate_survival_dates fails loudly when an anchor column is missing", {
  spec <- survival_spec(
    mock_spec_survival("event", anchor = "entry", followup_min = 0,
                       followup_max = 10, event_prop = 1)
  )
  expect_error(
    generate_survival_dates(data.frame(other = 1:2), spec, seed = 1),
    "missing anchor column\\(s\\) required by survival variables: entry"
  )
})

test_that("generate_survival_dates is a no-op without survival variables", {
  spec <- mock_spec(mock_spec_continuous("x", range = c(0, 1)))
  data <- generate_mock_data_native(spec, n = 5, seed = 1)
  expect_identical(generate_survival_dates(data, spec, seed = 1), data)
})

test_that("skipping the survival stage makes postprocess fail on the missing column", {
  spec <- survival_spec(
    mock_spec_survival("event", anchor = "entry", followup_min = 0,
                       followup_max = 10, event_prop = 1)
  )
  baseline <- generate_mock_data_native(spec, n = 5, seed = 1)
  expect_error(
    postprocess_mock_data(baseline, spec, seed = 1),
    "missing column\\(s\\) required by spec: event"
  )
})

test_that("the survival stage leaves the caller's RNG untouched and is reproducible", {
  spec <- survival_spec(
    mock_spec_survival("event", anchor = "entry", followup_min = 0,
                       followup_max = 100, event_prop = 0.5)
  )
  baseline <- generate_mock_data_native(spec, n = 50, seed = 3)
  set.seed(99)
  before <- .Random.seed
  a <- generate_survival_dates(baseline, spec, seed = 3)
  expect_identical(.Random.seed, before)
  expect_identical(a, generate_survival_dates(baseline, spec, seed = 3))
})

test_that("postprocess marks survival variables as derived with anchor, dependencies and event count", {
  spec <- survival_spec(
    mock_spec_survival("event", anchor = "entry", followup_min = 0,
                       followup_max = 10, event_prop = 0.5, censored_by = "death"),
    mock_spec_survival("death", anchor = "entry", followup_min = 100,
                       followup_max = 200, event_prop = 0.5)
  )
  staged <- run_stage(spec, n = 100)
  diag <- attr(postprocess_mock_data(staged, spec, seed = 1), "mockdata_diagnostics")$variables
  expect_true(isTRUE(diag$event$derived))
  expect_identical(diag$event$anchor, "entry")
  expect_identical(diag$event$censored_by, "death")
  expect_identical(diag$event$depends_on, c("entry", "death"))
  expect_identical(diag$event$n_events, sum(!is.na(staged$event)))
  expect_null(diag$death$censored_by)
  expect_null(diag$entry$derived)
})

test_that("garbage applied after the rules keeps before-entry violations (D5)", {
  spec <- survival_spec(
    mock_spec_survival("event", anchor = "entry", followup_min = 10,
                       followup_max = 100, event_prop = 1,
                       garbage_rules = list(low = list(
                         proportion = 0.2, range = "[1990-01-01;1990-12-31]"
                       )))
  )
  out <- postprocess_mock_data(run_stage(spec, n = 200), spec, seed = 1)
  before_entry <- which(out$event < out$entry)
  garbage_rows <- attr(out, "mockdata_diagnostics")$variables$event$assigned_garbage_indices$low
  expect_gt(length(before_entry), 0)
  expect_setequal(before_entry, garbage_rows)
})

test_that("the rules use true dates: a censoring death later replaced by garbage still censored (D5)", {
  spec <- survival_spec(
    mock_spec_survival("event", anchor = "entry", followup_min = 1000,
                       followup_max = 2000, event_prop = 1, censored_by = "death"),
    mock_spec_survival("death", anchor = "entry", followup_min = 0,
                       followup_max = 500, event_prop = 1,
                       garbage_rules = list(high = list(
                         proportion = 0.5, range = "[2090-01-01;2090-12-31]"
                       )))
  )
  out <- postprocess_mock_data(run_stage(spec, n = 200), spec, seed = 1)
  # Every death preceded its event before post-processing, so every event is
  # NA; about half the deaths now show a 2090 garbage date.
  expect_true(all(is.na(out$event)))
  expect_true(any(out$death >= as.Date("2090-01-01")))
})
```

- [x] **Step 2: Run to verify failure**

Run: `Rscript -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-survival-vars.R")'`
Expected: the new tests ERROR with `could not find function "generate_survival_dates"` or `Native backend does not support variable type 'survival'`; Task 2's tests still PASS.

- [x] **Step 3: Append the generation code to `R/mock_spec_survival.R`**

```r
#' @noRd
.survival_param <- function(value, default) {
  if (is.null(value) || length(value) != 1 || is.na(value)) default else value
}

#' @noRd
.survival_event_days <- function(variable, n_events) {
  # Exact port of the legacy follow-up-time draws (R/create_date_var.R:305-340,
  # ADR v05-survival-dates D4), including behaviour filed as #54 (Gompertz
  # clamp) and #56 (exponential rate derived from the window, not `rate`).
  followup_min <- variable$followup_min
  followup_max <- variable$followup_max
  distribution <- tolower(variable$distribution %||% "uniform")

  if (distribution == "gompertz") {
    shape <- .survival_param(variable$shape, 0.1)
    rate <- .survival_param(variable$rate, 0.0001)
    u <- stats::runif(n_events)
    days <- (1 / shape) * log(1 - (shape / rate) * log(1 - u))
    return(pmax(followup_min, pmin(followup_max, days)))
  }
  if (distribution == "exponential") {
    rate_exp <- 1 / ((followup_max - followup_min) / 3)
    days <- stats::rexp(n_events, rate = rate_exp) + followup_min
    return(pmin(days, followup_max))
  }
  stats::runif(n_events, min = followup_min, max = followup_max)
}

#' @noRd
.draw_survival_dates <- function(variable, anchor_dates) {
  n <- length(anchor_dates)
  values <- rep(as.Date(NA), n)
  if (n == 0) {
    return(values)
  }
  # Legacy event assignment: a fixed count, shuffled (R/create_date_var.R:295).
  n_events <- floor(n * variable$event_prop)
  is_event <- c(rep(TRUE, n_events), rep(FALSE, n - n_events))
  is_event <- is_event[sample(n)]
  if (n_events > 0) {
    # floor(): legacy output is whole days because create_date_var() converts
    # dates to character and back (R/create_date_var.R:479).
    values[is_event] <- anchor_dates[is_event] +
      floor(.survival_event_days(variable, n_events))
  }
  values
}

#' Generate survival dates from their anchor dates
#'
#' Computes each `type = "survival"` variable in `spec` from its anchor column
#' in `data`: `floor(n * event_prop)` rows receive a date a follow-up time
#' after the anchor (whole days, within `[followup_min, followup_max]`), and
#' the rest are `NA`. Variables are processed in dependency order; each is
#' drawn and then has its rules applied: a date earlier than its anchor
#' becomes `NA`, and, if `censored_by` is set, a date later than the censoring
#' date becomes `NA`. Draws use the isolated `survival` sub-stream of the seed
#' contract.
#'
#' Survival dates describe true values. [postprocess_mock_data()] applies
#' missing codes and garbage afterwards, independently for each column.
#'
#' @param data Data frame of generated baseline values (from
#'   [generate_mock_data_native()] or [generate_mock_data_simstudy()]),
#'   containing each anchor column as class `Date`.
#' @param spec A `mock_spec`. Strict-validated at entry.
#' @param seed Optional whole-number seed. The caller's RNG state and kind are
#'   restored on exit.
#'
#' @return `data` with one appended `Date` column per survival variable.
#'   Returns `data` unchanged if the spec has no survival variables.
#' @family mock generation APIs
#' @seealso [mock_spec_survival()], [evaluate_mock_formulas()],
#'   [postprocess_mock_data()]
#'
#' @examples
#' spec <- mock_spec(
#'   mock_spec_date("entry", range = as.Date(c("2001-01-01", "2005-12-31"))),
#'   mock_spec_survival("death", anchor = "entry",
#'     followup_min = 365, followup_max = 7300, event_prop = 0.2)
#' )
#' baseline <- generate_mock_data_native(spec, n = 10, seed = 1)
#' generate_survival_dates(baseline, spec, seed = 1)
#'
#' @export
generate_survival_dates <- function(data, spec, seed = NULL) {
  if (!is.data.frame(data)) {
    stop("data must be a data frame.", call. = FALSE)
  }
  validate_mock_spec(spec, n = nrow(data), strict = TRUE)

  ordered <- .order_survival_variables(spec)
  if (length(ordered) == 0) {
    return(data)
  }

  anchors <- unique(vapply(spec$variables[ordered], function(variable) {
    variable$anchor
  }, character(1)))
  missing_anchors <- setdiff(anchors, names(data))
  if (length(missing_anchors) > 0) {
    stop(
      "data is missing anchor column(s) required by survival variables: ",
      paste(missing_anchors, collapse = ", "),
      call. = FALSE
    )
  }
  for (anchor in anchors) {
    if (!inherits(data[[anchor]], "Date")) {
      stop(
        "Anchor column '", anchor, "' must be of class Date; got ",
        class(data[[anchor]])[1], ". Convert it with as.Date() first.",
        call. = FALSE
      )
    }
  }

  .with_mock_seed(seed, stage = "survival", {
    for (name in ordered) {
      variable <- spec$variables[[name]]
      anchor_dates <- data[[variable$anchor]]
      values <- .draw_survival_dates(variable, anchor_dates)
      # Legacy rules (R/create_wide_survival_data.R:347,363), applied per
      # variable in dependency order so a censoring date is already final.
      values[!is.na(values) & !is.na(anchor_dates) & values < anchor_dates] <-
        as.Date(NA)
      if (!.is_blank(variable$censored_by)) {
        censor <- data[[variable$censored_by]]
        values[!is.na(values) & !is.na(censor) & censor < values] <- as.Date(NA)
      }
      data[[name]] <- values
    }
    data
  })
}
```

- [x] **Step 4: Append the survival stage in `R/mock_spec_native.R`**

Replace:

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
```

with:

```r
# Named generation stages -> fixed L'Ecuyer-CMRG sub-stream indices. Indices
# are FROZEN: adding a future stage must not renumber baseline/postprocess, or
# seeded output for existing features would shift. correlate (#42) is reserved
# though unused; survival (#40) is appended, never inserted.
.MOCK_STAGES <- c(
  baseline    = 0L,
  postprocess = 1L,
  formula     = 2L,
  correlate   = 3L,
  survival    = 4L
)
```

In `generate_mock_data_native()`, replace:

```r
    generated_variables <- spec$variables[
      !vapply(spec$variables, .is_formula_variable, logical(1))
    ]
```

with:

```r
    generated_variables <- spec$variables[
      !vapply(spec$variables, .is_derived_variable, logical(1))
    ]
```

and in the comment block above it replace `type = "formula" variables have no distribution to sample from; they\n    # are computed post-baseline by evaluate_mock_formulas().` with `Derived variables (type = "formula" or "survival") are computed\n    # post-baseline by evaluate_mock_formulas() and generate_survival_dates().` (keep the rest of the comment). In its roxygen `@return`, replace:

```r
#' @return A data frame with `n` rows and one column per non-formula
#'   `mock_spec` variable (`type = "formula"` variables are appended
#'   afterwards by [evaluate_mock_formulas()]).
```

with:

```r
#' @return A data frame with `n` rows and one column per non-derived
#'   `mock_spec` variable (`type = "survival"` and `type = "formula"`
#'   variables are appended afterwards by [generate_survival_dates()] and
#'   [evaluate_mock_formulas()]).
```

- [x] **Step 5: Mirror the skip in `R/mock_spec_simstudy.R`**

In `.native_only_variables()`, replace `!.is_formula_variable(variable) && !.simstudy_can_generate(variable)` with `!.is_derived_variable(variable) && !.simstudy_can_generate(variable)`. In `generate_mock_data_simstudy()`, replace:

```r
  generated_variable_names <- names(spec$variables)[
    !vapply(spec$variables, .is_formula_variable, logical(1))
  ]
```

with:

```r
  generated_variable_names <- names(spec$variables)[
    !vapply(spec$variables, .is_derived_variable, logical(1))
  ]
```

Update both adjacent comments to say "derived variables (formula and survival)" where they say "type = \"formula\" variables".

- [x] **Step 6: Diagnostics in `R/mock_spec_postprocess.R`**

Change the signature `.postprocess_empty_diagnostics <- function(spec, n) {` to `.postprocess_empty_diagnostics <- function(spec, n, data = NULL) {`. Inside it, directly after the formula block that ends:

```r
    if (.is_formula_variable(variable)) {
      entry$derived <- TRUE
      entry$formula <- variable$formula
      entry$depends_on <- variable$depends_on
    }
```

insert:

```r

    # ADR v05-survival-dates D7: survival dates are derived from their anchor;
    # n_events counts the dates present before post-processing.
    if (.is_survival_variable(variable)) {
      entry$derived <- TRUE
      entry$anchor <- variable$anchor
      entry$censored_by <- variable$censored_by
      entry$depends_on <- variable$depends_on
      entry$n_events <- if (is.null(data)) {
        NA_integer_
      } else {
        sum(!is.na(data[[variable$name]]))
      }
    }
```

In `postprocess_mock_data()`, replace `diag <- .postprocess_empty_diagnostics(spec, nrow(data))` with `diag <- .postprocess_empty_diagnostics(spec, nrow(data), data)`.

- [x] **Step 7: Seed contract (`tests/testthat/test-seed-contract.R`)**

In the test `"stage indices are frozen (renumbering would shift seeded output)"`, replace `c(baseline = 0L, postprocess = 1L, formula = 2L, correlate = 3L)` with `c(baseline = 0L, postprocess = 1L, formula = 2L, correlate = 3L, survival = 4L)`. Append at the end of the file:

```r
test_that("survival stage output is pinned (catches a stage-index shift)", {
  spec <- mock_spec(
    mock_spec_date("entry", range = as.Date(c("2001-01-01", "2001-12-31"))),
    mock_spec_survival("event", anchor = "entry", followup_min = 0,
                       followup_max = 1000, event_prop = 0.5)
  )
  baseline <- generate_mock_data_native(spec, n = 6, seed = 20260924)
  got <- generate_survival_dates(baseline, spec, seed = 20260924)
  # Reference computed independently on 2026-09-24 by emulating
  # .with_mock_seed() for sub-stream index 4, not captured from this code.
  # If this breaks, the survival stream shifted or the port changed: treat as
  # a deliberate, NEWS-documented break, not a silent one.
  expect_identical(
    as.character(baseline$entry),
    c("2001-07-25", "2001-05-26", "2001-09-10", "2001-11-16", "2001-09-06", "2001-09-03")
  )
  expect_identical(
    as.character(got$event),
    c(NA, "2003-12-02", NA, "2002-04-18", NA, "2003-10-29")
  )
})
```

- [x] **Step 8: Run the survival and seed tests — expected PASS**

Run: `Rscript -e 'devtools::load_all(quiet = TRUE); for (f in c("test-survival-vars.R", "test-seed-contract.R")) testthat::test_file(file.path("tests/testthat", f))'`
Expected: all PASS. If the pinned survival test fails but everything else passes, compare the implementation line by line with Step 3 before suspecting the pin: the pin was computed from the same algorithm under the same stream.

- [x] **Step 9: Document, full suite, commit**

`Rscript -e 'devtools::document()'`, then the Task 1 Step 1 snippet. Expected: FAIL 0 | ERROR 0; WARN and SKIP unchanged; every pre-existing pinned value passes untouched.

```bash
git add R/mock_spec_survival.R R/mock_spec_native.R R/mock_spec_simstudy.R R/mock_spec_postprocess.R NAMESPACE tests/testthat/test-survival-vars.R tests/testthat/test-seed-contract.R
git commit -m "Add generate_survival_dates() as a post-baseline stage (#40)" -m "Survival variables are drawn from their anchor dates with the legacy
statistics ported exactly (fixed floor(n * event_prop) event count,
uniform/exponential/Gompertz follow-up in whole days) and processed in
dependency order: each is drawn, then dates before the anchor and dates
after an earlier censored_by date become NA. Draws use a new survival
sub-stream appended to .MOCK_STAGES as index 4, so no existing index or
pinned value moves.

Both backends now skip derived types (formula and survival) in baseline
generation. Postprocess diagnostics mark survival variables as derived with
their anchor, censored_by, depends_on and n_events. Tests pin D5 (garbage
survives the rules; the rules use true dates) and the survival stream."
```

---

### Task 4: Recodeflow adapter, orchestrator and legacy guard

**Files:**
- Modify: `R/mock_spec_recodeflow.R` (`.recodeflow_variable_kind()` near line 117, `.recodeflow_rtype()` near line 140, `.recodeflow_to_spec_variable()` before `source_format <- .row_character(var_row, "sourceFormat", "analysis")` near line 446, the date construction block after it, and the roxygen sentence near line 481)
- Modify: `R/create_mock_data.R` (unsupported check near line 18, orchestrator near line 107, legacy guard before `if (nrow(enabled_vars) == 0) {`, roxygen example comment near line 209)
- Modify: `inst/extdata/minimal-example/variables.csv` (through R only)
- Modify: `tests/testthat/test-seed-contract.R` (the two legacy-path tests)
- Modify: `tests/testthat/test-critical-regressions.R` (the `validate = TRUE` skipped-summary test)
- Test: `tests/testthat/test-survival-vars.R` (append)

**Interfaces:**
- Consumes: `mock_spec_survival()`, `generate_survival_dates()`, `.is_blank()`, `.row_character()`, `.row_numeric()`, `.recodeflow_distribution()`
- Produces: `create_mock_data()` runs baseline → survival → formulas → postprocess; adapter kind `"survival"`; the minimal example carries `anchor` and `censored_by`

- [x] **Step 1: Write the failing tests (append to `tests/testthat/test-survival-vars.R`)**

```r
survival_metadata <- function() {
  list(
    variables = data.frame(
      variable = c("entry", "event", "death"),
      variableType = c("Date", "Date", "Date"),
      rType = c("date", "date", "date"),
      role = c("enabled", "enabled", "enabled"),
      distribution = c("uniform", "uniform", "uniform"),
      anchor = c("", "entry", "entry"),
      censored_by = c("", "death", ""),
      followup_min = c(NA, 0, 0),
      followup_max = c(NA, 1000, 1000),
      event_prop = c(NA, 0.5, 0.4),
      stringsAsFactors = FALSE
    ),
    variable_details = data.frame(
      variable = "entry",
      recStart = "[2001-01-01,2001-12-31]",
      recEnd = "copy",
      proportion = 1,
      stringsAsFactors = FALSE
    )
  )
}

test_that("mock_spec_from_recodeflow builds survival variables from anchor rows", {
  md <- survival_metadata()
  spec <- mock_spec_from_recodeflow(md$variables, md$variable_details)
  expect_identical(spec$variables$entry$type, "date")
  expect_identical(spec$variables$event$type, "survival")
  expect_identical(spec$variables$event$anchor, "entry")
  expect_identical(spec$variables$event$censored_by, "death")
  expect_null(spec$variables$death$censored_by)
  expect_equal(spec$variables$death$event_prop, 0.4)
})

test_that("a date with survival parameters but no anchor fails with a message naming the fix", {
  md <- survival_metadata()
  md$variables$anchor[md$variables$variable == "death"] <- ""
  expect_error(
    mock_spec_from_recodeflow(md$variables, md$variable_details),
    "Date variable 'death' has survival parameter\\(s\\) followup_min, followup_max, event_prop but no anchor"
  )
})

test_that("an anchor without survival parameters fails validation", {
  md <- survival_metadata()
  md$variables$followup_min[md$variables$variable == "death"] <- NA
  expect_error(
    mock_spec_from_recodeflow(md$variables, md$variable_details),
    "requires finite numeric followup_min and followup_max"
  )
})

test_that("create_mock_data generates survival dates from metadata via the v0.4 pipeline", {
  md <- survival_metadata()
  expect_message(
    result <- create_mock_data("study", md$variables, md$variable_details,
                               n = 300, seed = 5, verbose = TRUE),
    "Generating via v0.4 mock_spec pipeline"
  )
  expect_true(all(c("entry", "event", "death") %in% names(result)))
  expect_identical(sum(!is.na(result$death)), 120L)
  both <- !is.na(result$event) & !is.na(result$death)
  expect_false(any(result$death[both] < result$event[both]))
  diag <- attr(result, "mockdata_diagnostics")$variables
  expect_true(isTRUE(diag$event$derived))
})

test_that("an anchor that is not enabled fails with a message naming it", {
  md <- survival_metadata()
  md$variables$role[md$variables$variable == "entry"] <- "disabled"
  expect_error(
    suppressMessages(create_mock_data("study", md$variables, md$variable_details,
                                      n = 10, seed = 1)),
    "has anchor 'entry', which is not a variable in the spec"
  )
})

test_that("legacy generator stops on anchored metadata instead of dropping survival dates", {
  md <- survival_metadata()
  expect_error(
    suppressMessages(create_mock_data("study", md$variables, md$variable_details,
                                      n = 10, seed = 1, validate = FALSE)),
    "Survival date variable\\(s\\) event, death \\(anchor set\\) are generated only by the v0.4 pipeline"
  )
})

test_that("the minimal example generates all five survival dates via the v0.4 pipeline", {
  vars <- system.file("extdata", "minimal-example", "variables.csv", package = "MockData")
  dets <- system.file("extdata", "minimal-example", "variable_details.csv", package = "MockData")
  if (!nzchar(vars) || !nzchar(dets)) skip("minimal-example fixtures not installed")
  variables <- read.csv(vars, stringsAsFactors = FALSE, check.names = FALSE)
  variable_details <- read.csv(dets, stringsAsFactors = FALSE, check.names = FALSE)

  expect_message(
    result <- suppressWarnings(create_mock_data(
      "minimal-example", variables, variable_details,
      n = 500, seed = 1, verbose = TRUE
    )),
    "Generating via v0.4 mock_spec pipeline"
  )
  survival <- c("primary_event_date", "death_date", "ltfu_date", "admin_censor_date")
  expect_true(all(c("interview_date", survival) %in% names(result)))
  for (column in survival) {
    ok <- !is.na(result[[column]])
    expect_true(all(result[[column]][ok] >= result$interview_date[ok]), info = column)
  }
  # Garbage only replaces existing values and the example's date missing
  # codes are ignored (#15), so the event counts are exact.
  expect_identical(sum(!is.na(result$death_date)), 100L)
  expect_identical(sum(!is.na(result$ltfu_date)), 50L)
  expect_identical(sum(!is.na(result$admin_censor_date)), 500L)
  expect_lte(sum(!is.na(result$primary_event_date)), 150L)
})
```

- [x] **Step 2: Run to verify failure**

Run: `Rscript -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-survival-vars.R")'`
Expected: the seven new tests FAIL or ERROR (the adapter builds `event` as a plain date; the minimal example still falls back); Tasks 2 and 3 tests PASS.

- [x] **Step 3: Adapter (`R/mock_spec_recodeflow.R`)**

In `.recodeflow_variable_kind()`, replace:

```r
  if (rtype == "date" || variable_type == "date") {
    return("date")
  }
```

with:

```r
  if (rtype == "date" || variable_type == "date") {
    # A non-blank anchor makes a date a survival date (#40, ADR D3).
    if (!.is_blank(.row_character(var_row, "anchor", ""))) {
      return("survival")
    }
    return("date")
  }
```

In `.recodeflow_rtype()`, replace:

```r
    categorical = "factor",
    date = "date"
  )
```

with:

```r
    categorical = "factor",
    date = "date",
    survival = "date"
  )
```

In `.recodeflow_to_spec_variable()`, replace the line `  source_format <- .row_character(var_row, "sourceFormat", "analysis")` (the one immediately before the date `.new_mock_spec_variable(` call) with:

```r
  if (kind == "survival") {
    return(mock_spec_survival(
      name = variable,
      anchor = .row_character(var_row, "anchor"),
      censored_by = .row_character(var_row, "censored_by", NULL),
      followup_min = .row_numeric(var_row, "followup_min"),
      followup_max = .row_numeric(var_row, "followup_max"),
      event_prop = .row_numeric(var_row, "event_prop"),
      distribution = .recodeflow_distribution(var_row, details),
      shape = .row_numeric(var_row, "shape"),
      rate = .row_numeric(var_row, "rate"),
      source_format = .row_character(var_row, "sourceFormat", "analysis"),
      missing_codes = missing$codes,
      missing_proportions = missing$proportions,
      garbage_rules = garbage_rules,
      provenance = provenance
    ))
  }

  # ADR v05-survival-dates D3: survival parameters without an anchor were
  # silently dropped or generated as a plain calendar date before #40.
  survival_fields <- c("followup_min", "followup_max", "event_prop")
  present <- survival_fields[!vapply(survival_fields, function(field) {
    is.na(.row_numeric(var_row, field))
  }, logical(1))]
  if (length(present) > 0) {
    stop(
      "Date variable '", variable, "' has survival parameter(s) ",
      paste(present, collapse = ", "), " but no anchor. Add anchor = ",
      "\"<entry-date variable>\" to its variables row to generate it as a ",
      "survival date, or remove the survival parameters.",
      call. = FALSE
    )
  }

  source_format <- .row_character(var_row, "sourceFormat", "analysis")
```

In the date construction that follows, replace:

```r
    rate = .row_numeric(var_row, "rate"),
    shape = .row_numeric(var_row, "shape"),
    followup_min = .row_numeric(var_row, "followup_min"),
    followup_max = .row_numeric(var_row, "followup_max"),
    event_prop = .row_numeric(var_row, "event_prop")
  )
```

with:

```r
    rate = .row_numeric(var_row, "rate"),
    shape = .row_numeric(var_row, "shape")
  )
```

In the `mock_spec_from_recodeflow()` roxygen, replace:

```r
#' `garbage_*` settings into `garbage_rules`, and stores survival/date fields
#' such as `rate`, `shape`, `followup_min`, `followup_max`, and `event_prop` on
#' date variables for later backend milestones.
```

with:

```r
#' `garbage_*` settings into `garbage_rules`, and builds a survival date
#' ([mock_spec_survival()]) from any date row that sets `anchor`, reading
#' `censored_by`, `followup_min`, `followup_max`, `event_prop`, `distribution`,
#' `shape` and `rate`. A date row with survival parameters but no `anchor` is
#' an error.
```

- [x] **Step 4: Orchestrator and legacy guard (`R/create_mock_data.R`)**

In `.create_mock_data_v04_unsupported_variables()`, directly after:

```r
    if (variable$type == "formula") {
      return(FALSE)
    }
```

insert:

```r
    # type = "survival" is supported end-to-end (#40): both backends skip it,
    # generate_survival_dates() computes it, postprocess treats it as a date.
    if (variable$type == "survival") {
      return(FALSE)
    }
```

In `.create_mock_data_v04()`, replace:

```r
  baseline <- generate_mock_data_native(spec, n = n, seed = seed)
  staged <- evaluate_mock_formulas(baseline, spec, seed = seed)
  # Baseline generation, formula evaluation, and post-processing use distinct
  # L'Ecuyer-CMRG sub-streams derived from the single public seed (see
  # .with_mock_seed / ADR v05-seed-contract), so all three stages pass the
  # same seed and select their own stage internally.
```

with:

```r
  baseline <- generate_mock_data_native(spec, n = n, seed = seed)
  dated <- generate_survival_dates(baseline, spec, seed = seed)
  staged <- evaluate_mock_formulas(dated, spec, seed = seed)
  # Baseline generation, survival dates, formula evaluation, and
  # post-processing use distinct L'Ecuyer-CMRG sub-streams derived from the
  # single public seed (see .with_mock_seed / ADR v05-seed-contract), so all
  # four stages pass the same seed and select their own stage internally.
  # Survival precedes formulas so a mockFormula can use survival dates
  # (ADR v05-survival-dates D6).
```

In `create_mock_data()`, immediately before:

```r
  if (nrow(enabled_vars) == 0) {
    stop("No enabled non-derived variables found in configuration. ",
```

insert:

```r
  # ADR v05-survival-dates D10: the legacy dispatcher cannot build survival
  # dates from anchors (it would warn and drop them), so stop rather than
  # return plausible-looking partial survival data.
  if ("anchor" %in% names(enabled_vars)) {
    anchor_values <- as.character(enabled_vars$anchor)
    anchored <- enabled_vars$variable[
      !is.na(anchor_values) & trimws(anchor_values) != ""
    ]
    if (length(anchored) > 0) {
      stop(
        "Survival date variable(s) ", paste(anchored, collapse = ", "),
        " (anchor set) are generated only by the v0.4 pipeline, but the ",
        "legacy generator was selected. It is used when validate = FALSE, ",
        "when variable_details is NULL, when only variable_details has a ",
        "databaseStart column, or when another variable uses a feature the ",
        "v0.4 pipeline does not support. Run with verbose = TRUE to see which.",
        call. = FALSE
      )
    }
  }

```

In the `create_mock_data()` roxygen examples, replace:

```r
#' # The packaged minimal example includes deliberately messy metadata
#' # (auto-normalized proportions, survival dates without an anchor): the
#' # warnings it generates are expected and demonstrate MockData's diagnostics.
```

with:

```r
#' # The packaged minimal example covers every variable type, including
#' # survival dates anchored on interview_date. It auto-normalizes some
#' # proportions, so warnings about that are expected.
```

- [x] **Step 5: Add `anchor` and `censored_by` to the minimal example (R only)**

```bash
cd /Users/dmanuel/github/mock-data && Rscript -e '
path <- "inst/extdata/minimal-example/variables.csv"
v <- read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
old <- v
survival_rows <- c("primary_event_date", "death_date", "ltfu_date", "admin_censor_date")
v$anchor <- ifelse(v$variable %in% survival_rows, "interview_date", "")
v$censored_by <- ifelse(v$variable == "primary_event_date", "death_date", "")
cols <- names(v)
at <- match("event_prop", cols)
v <- v[, c(cols[seq_len(at)], "anchor", "censored_by",
           setdiff(cols[-seq_len(at)], c("anchor", "censored_by")))]
write.csv(v, path, row.names = FALSE, na = "")
new <- read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
stopifnot(identical(old, new[, names(old)]))
print(new[new$anchor != "" | new$variable == "interview_date",
          c("variable", "anchor", "censored_by", "followup_min", "followup_max", "event_prop")])'
```

Expected: the `stopifnot` passes (every existing column is unchanged) and the printout shows four survival rows anchored on `interview_date`, with `primary_event_date` censored by `death_date`.

- [x] **Step 6: Re-point the two tests whose vehicles no longer exist**

In `tests/testthat/test-seed-contract.R`, in both `"legacy path (validate = FALSE) leaves the caller's RNG untouched"` and `"legacy path is reproducible for a given seed"`, directly after the line `  variable_details <- read.csv(dets, stringsAsFactors = FALSE, check.names = FALSE)` insert:

```r
  # Survival dates (anchor set) are generated only by the v0.4 pipeline
  # (ADR v05-survival-dates D10); this test exercises the legacy path.
  variables <- variables[variables$anchor == "", ]
```

In `tests/testthat/test-critical-regressions.R`, replace the whole `test_that("create_mock_data reports skipped variables when a generator returns NULL under validate = TRUE", { ... })` block with:

```r
test_that("create_mock_data reports skipped variables when a generator returns NULL under validate = TRUE", {
  # A survival-style date without an anchor makes create_date_var() warn and
  # return NULL on the legacy path. Since #40 the v0.4 adapter rejects that
  # metadata outright, so the legacy path is reached here through
  # detail-level-only databaseStart filtering, which the v0.4 pipeline
  # declines. The end-of-run summary must still report the absent column in
  # strict mode.
  variables <- data.frame(
    variable = c("age", "event_date"),
    variableType = c("Continuous", "Date"),
    rType = c("integer", "date"),
    role = c("enabled", "enabled"),
    distribution = c(NA, "gompertz"),
    followup_min = c(NA, 365),
    followup_max = c(NA, 3650),
    event_prop = c(NA, 0.5),
    stringsAsFactors = FALSE
  )
  details <- data.frame(
    variable = c("age", "event_date"),
    databaseStart = c("study", "study"),
    recStart = c("[18,85]", "[2001-01-01,2005-12-31]"),
    recEnd = c("copy", "copy"),
    proportion = c(1, 1),
    stringsAsFactors = FALSE
  )

  expect_message(
    expect_warning(
      result <- create_mock_data(
        databaseStart = "study",
        variables = variables,
        variable_details = details,
        n = 5,
        seed = 1,
        validate = TRUE
      ),
      "anchor_date"
    ),
    "Skipped variables.*event_date"
  )

  expect_s3_class(result, "data.frame")
  expect_true("age" %in% names(result))
  expect_false("event_date" %in% names(result))
})
```

- [x] **Step 7: Run the affected files — expected PASS**

Run: `Rscript -e 'devtools::load_all(quiet = TRUE); for (f in c("test-survival-vars.R", "test-seed-contract.R", "test-critical-regressions.R", "test-recodeflow-mock-spec.R", "test-edge-case-contract.R")) testthat::test_file(file.path("tests/testthat", f))'`
Expected: all PASS. `test-recodeflow-mock-spec.R`'s `"preserves garbage and survival fields"` passes unchanged: `primary_event_date` is now type `survival` but keeps the fields `distribution`, `event_prop` and `followup_max`. If the re-pointed critical-regressions test fails because the legacy path no longer warns `anchor_date`, stop and report: it means the detail-level route changed, not that the expectation should be loosened.

- [x] **Step 8: Document, full suite, commit**

`Rscript -e 'devtools::document()'`, then the Task 1 Step 1 snippet. Expected: FAIL 0 | ERROR 0; SKIP unchanged. WARN may fall, because the minimal example no longer runs the legacy generator in tests that use it; it must not rise. If any other test fails because the minimal example now routes to v0.4, read the test: if it asserts a *behaviour* the v0.4 path breaks, fix the code; if it pins a legacy-path *value*, re-point it to the legacy path the way Step 6 does, and say so in the commit body.

```bash
git add R/mock_spec_recodeflow.R R/create_mock_data.R inst/extdata/minimal-example/variables.csv tests/testthat/test-survival-vars.R tests/testthat/test-seed-contract.R tests/testthat/test-critical-regressions.R
git commit -m "Generate survival dates from recodeflow metadata in create_mock_data() (#40)" -m "The adapter builds a survival variable from any date row that sets anchor
(reading censored_by and the survival parameters), and rejects a date with
survival parameters but no anchor with a message naming the fix. The
orchestrator runs baseline, survival, formulas, then postprocess, and no
longer treats survival dates as a legacy-fallback trigger. When the legacy
generator is selected on anchored metadata, create_mock_data() stops and
names the survival variables instead of dropping them (ADR D10).

The minimal example gains anchor and censored_by, so it now generates
entirely through the v0.4 pipeline. Two legacy-path seed tests drop its
survival rows, and the validate = TRUE skipped-summary test reaches the
legacy path through detail-level databaseStart instead of an anchor-less
survival date, which the adapter now rejects."
```

---

### Task 5: Derive status and follow-up time with mockFormula (D8)

**Files:**
- Modify: `R/mock_spec_formula.R:7-16` (allow-list)
- Modify: `development/adr/v05-formula-evaluator.md:3` (status line)
- Test: `tests/testthat/test-formula-vars.R` (append), `tests/testthat/test-survival-vars.R` (append)

**Interfaces:**
- Consumes: `generate_survival_dates()`, `evaluate_mock_formulas()`, `postprocess_mock_data()`
- Produces: `"is.na"` in `.formula_allowlist`

- [x] **Step 1: Write the failing tests**

Append to `tests/testthat/test-formula-vars.R`:

```r
test_that("is.na is permitted in mockFormula expressions (survival ADR D8)", {
  spec <- mock_spec(
    mock_spec_continuous("x", range = c(0, 1)),
    mock_spec_formula("flag", formula = "as.integer(is.na(x))", rtype = "integer")
  )
  out <- evaluate_mock_formulas(generate_mock_data_native(spec, n = 5, seed = 1),
                                spec, seed = 1)
  expect_identical(out$flag, rep(0L, 5))
})
```

Append to `tests/testthat/test-survival-vars.R`:

```r
window_status <- "as.integer(!is.na(death) & death == pmin(death, admin, na.rm = TRUE))"
window_days <- "as.numeric(pmin(death, admin, na.rm = TRUE) - entry)"

test_that("mockFormula derives status and follow-up time from one observation window (D8)", {
  # ADR D8: status and time must come from the same window. A death after
  # administrative censoring is not an observed death.
  spec <- survival_spec(
    mock_spec_survival("death", anchor = "entry", followup_min = 0,
                       followup_max = 1000, event_prop = 0.5),
    mock_spec_survival("admin", anchor = "entry", followup_min = 0,
                       followup_max = 1000, event_prop = 1),
    mock_spec_formula("death_status", formula = window_status, rtype = "integer"),
    mock_spec_formula("followup_days", formula = window_days)
  )
  staged <- evaluate_mock_formulas(run_stage(spec, n = 400, seed = 2), spec, seed = 2)
  observed <- !is.na(staged$death) & staged$death <= staged$admin
  expect_identical(staged$death_status, as.integer(observed))
  expect_gt(sum(staged$death_status), 0L)
  # Some deaths fall after administrative censoring and must not count.
  expect_gt(sum(!is.na(staged$death) & staged$death_status == 0L), 0L)
  end <- pmin(staged$death, staged$admin, na.rm = TRUE)
  expect_equal(staged$followup_days, as.numeric(end - staged$entry))
})

test_that("a death on the censoring date counts as observed (ties, D8)", {
  spec <- survival_spec(
    mock_spec_survival("death", anchor = "entry", followup_min = 20,
                       followup_max = 20, event_prop = 1),
    mock_spec_survival("admin", anchor = "entry", followup_min = 20,
                       followup_max = 20, event_prop = 1),
    mock_spec_formula("death_status", formula = window_status, rtype = "integer")
  )
  staged <- evaluate_mock_formulas(run_stage(spec, n = 10), spec, seed = 1)
  expect_true(all(staged$death_status == 1L))
})

test_that("formula columns describe clean truth; a later missing code does not change them (D5, D8)", {
  spec <- survival_spec(
    mock_spec_survival("death", anchor = "entry", followup_min = 100,
                       followup_max = 200, event_prop = 1,
                       missing_codes = "1900-01-01", missing_proportions = 0.3),
    mock_spec_formula("has_death_date", formula = "as.integer(!is.na(death))",
                      rtype = "integer")
  )
  staged <- evaluate_mock_formulas(run_stage(spec, n = 100, seed = 2), spec, seed = 2)
  out <- postprocess_mock_data(staged, spec, seed = 2)
  shown_missing <- out$death == as.Date("1900-01-01")
  expect_gt(sum(shown_missing), 0)
  expect_true(all(out$has_death_date[shown_missing] == 1L))
})
```

- [x] **Step 2: Run to verify failure**

Run: `Rscript -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-formula-vars.R"); testthat::test_file("tests/testthat/test-survival-vars.R")'`
Expected: the four new tests ERROR with `uses function(s) not permitted in mockFormula expressions: is.na`.

- [x] **Step 3: Widen the allow-list**

In `R/mock_spec_formula.R`, replace:

```r
# Base functions/operators a mockFormula may call. Deliberately closed and
# RNG-free: Phase A formulas are deterministic transformations of generated
# columns. Widen only on concrete need (ADR D3).
.formula_allowlist <- c(
  "+", "-", "*", "/", "^", "%%", "%/%", "(",
  "<", "<=", ">", ">=", "==", "!=", "&", "|", "!",
  "ifelse", "pmin", "pmax", "min", "max", "abs", "round", "floor",
  "ceiling", "sqrt", "exp", "log", "log10", "sum", "mean", "cut",
  "as.numeric", "as.integer", "as.factor", "factor", "c"
)
```

with:

```r
# Base functions/operators a mockFormula may call. Deliberately closed and
# RNG-free: Phase A formulas are deterministic transformations of generated
# columns. Widen only on concrete need (ADR D3). is.na was added for deriving
# survival status (ADR v05-survival-dates D8).
.formula_allowlist <- c(
  "+", "-", "*", "/", "^", "%%", "%/%", "(",
  "<", "<=", ">", ">=", "==", "!=", "&", "|", "!",
  "ifelse", "pmin", "pmax", "min", "max", "abs", "round", "floor",
  "ceiling", "sqrt", "exp", "log", "log10", "sum", "mean", "cut",
  "as.numeric", "as.integer", "as.factor", "factor", "c", "is.na"
)
```

In `development/adr/v05-formula-evaluator.md`, on line 3 replace `Implemented on branch v05-formula-evaluator (Phase A).` with `Implemented on branch v05-formula-evaluator (Phase A). Allow-list amended 2026-09-24 by \`v05-survival-dates.md\` D8 (adds \`is.na\`).`

- [x] **Step 4: Run the tests — expected PASS**

Same command as Step 2. Expected: all PASS.

- [x] **Step 5: Full suite, commit**

Task 1 Step 1 snippet. Expected: FAIL 0 | ERROR 0; WARN and SKIP no higher than after Task 4.

```bash
git add R/mock_spec_formula.R development/adr/v05-formula-evaluator.md tests/testthat/test-formula-vars.R tests/testthat/test-survival-vars.R
git commit -m "Allow is.na in mockFormula to derive survival status (#40)" -m "Adds is.na to the formula allow-list (survival ADR D8, amending the #39
ADR's D3). Tests derive status and follow-up time from one observation
window (a death after administrative censoring is not observed; a death on
the censoring date is), and pin that formula columns describe clean truth:
a missing code applied to the date afterwards leaves them unchanged."
```

---

### Task 6: Deprecate `create_wide_survival_data()`

**Files:**
- Modify: `R/create_wide_survival_data.R` (session state at the top of the file; warning at the start of the function body; roxygen)
- Create: `tests/testthat/helper-deprecation.R`
- Test: `tests/testthat/test-survival-vars.R` (append)

**Interfaces:**
- Produces: internal `.mockdata_state` environment with `wide_survival_warned`

- [x] **Step 1: Write the failing test (append to `tests/testthat/test-survival-vars.R`)**

```r
test_that("create_wide_survival_data() warns once per session that it is deprecated", {
  state <- MockData:::.mockdata_state
  previous <- state$wide_survival_warned
  on.exit(assign("wide_survival_warned", previous, envir = state), add = TRUE)
  assign("wide_survival_warned", FALSE, envir = state)

  variables <- data.frame(
    variable = c("entry", "event"), variableType = c("Date", "Date"),
    rType = c("date", "date"), role = c("enabled", "enabled"),
    distribution = c("uniform", "uniform"), followup_min = c(NA, 0),
    followup_max = c(NA, 10), event_prop = c(NA, 1),
    stringsAsFactors = FALSE
  )
  details <- data.frame(
    variable = c("entry", "event"),
    recStart = c("[2001-01-01,2001-12-31]", "[2001-01-01,2040-12-31]"),
    recEnd = c("copy", "copy"), proportion = c(1, 1),
    stringsAsFactors = FALSE
  )
  call_legacy <- function() {
    messages <- character(0)
    withCallingHandlers(
      create_wide_survival_data(
        var_entry_date = "entry", var_event_date = "event",
        databaseStart = "test", variables = variables,
        variable_details = details, n = 5, seed = 1
      ),
      warning = function(w) {
        messages <<- c(messages, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    )
    messages
  }
  expect_true(any(grepl("deprecated as of MockData 0.5.0", call_legacy())))
  expect_false(any(grepl("deprecated as of MockData 0.5.0", call_legacy())))
})
```

- [x] **Step 2: Run to verify failure**

Expected: ERROR `object '.mockdata_state' not found`.

- [x] **Step 3: Implement**

In `R/create_wide_survival_data.R`, insert at the very top of the file, before `#' Create wide survival data for cohort studies`:

```r
# Session state for once-per-session notices (ADR v05-survival-dates D9).
.mockdata_state <- new.env(parent = emptyenv())

```

Replace the roxygen opening:

```r
#' Create wide survival data for cohort studies
#'
#' Generates wide-format survival data (one row per individual) with up to 5 date
```

with:

```r
#' Create wide survival data for cohort studies
#'
#' **Deprecated as of MockData 0.5.0.** Add `anchor` (and `censored_by` for a
#' competing risk) to the survival dates' rows in `variables.csv` and generate
#' them with [create_mock_data()]; see `vignette("tutorial-survival-data")`.
#' The function still works and warns once per session.
#'
#' Generates wide-format survival data (one row per individual) with up to 5 date
```

In the function body, insert directly after the opening line `                                       prop_garbage = NULL) {`:

```r
  if (!isTRUE(.mockdata_state$wide_survival_warned)) {
    .mockdata_state$wide_survival_warned <- TRUE
    warning(
      "create_wide_survival_data() is deprecated as of MockData 0.5.0. Add ",
      "`anchor` (and `censored_by` for competing risks) to the survival ",
      "dates' rows in variables.csv and generate them with create_mock_data(); ",
      "see vignette(\"tutorial-survival-data\", package = \"MockData\"). ",
      "This warning is shown once per session.",
      call. = FALSE
    )
  }

```

Create `tests/testthat/helper-deprecation.R`:

```r
# create_wide_survival_data() warns once per session that it is deprecated
# (ADR v05-survival-dates D9). Mark the warning as already shown so the
# legacy survival tests do not each gain an unrelated warning; the
# deprecation test in test-survival-vars.R resets the flag to exercise it.
assign("wide_survival_warned", TRUE, envir = MockData:::.mockdata_state)
```

- [x] **Step 4: Run — expected PASS; full suite; commit**

Run the survival file, then the Task 1 Step 1 snippet. Expected: FAIL 0 | ERROR 0; WARN no higher than after Task 5, which shows the helper keeps the legacy tests quiet.

```bash
git add R/create_wide_survival_data.R tests/testthat/helper-deprecation.R tests/testthat/test-survival-vars.R
git commit -m "Deprecate create_wide_survival_data() in favour of anchor metadata (#40)" -m "Warns once per session, pointing to anchor/censored_by metadata and
create_mock_data(). The function is otherwise unchanged: it is the
reference the characterization tests pin. A test helper marks the warning
as shown so the legacy survival tests gain no unrelated warnings."
```

---

### Task 7: Documentation, NEWS, pkgdown and full verification

**Files:**
- Modify: `NEWS.md`, `_pkgdown.yml`
- Rewrite: `vignettes/tutorial-survival-data.qmd`
- Modify: `vignettes/tutorial-garbage-data.qmd`, `vignettes/reference-config.qmd`, `vignettes/advanced-topics.qmd`, `vignettes/design-philosophy-v04.qmd`
- Modify: `development/post-v040-development-plan.md` (Task 7 checkboxes), `development/adr/v05-survival-dates.md` (status line)

- [x] **Step 1: `_pkgdown.yml`**

Add `  - mock_spec_survival` on the line after `  - mock_spec_formula`, and `  - generate_survival_dates` on the line before `  - evaluate_mock_formulas`.

- [x] **Step 2: NEWS**

In `NEWS.md`, insert immediately before the line `## Reproducibility (breaking change)`:

```markdown
## Survival dates in create_mock_data() (#40)

- `create_mock_data()` now generates survival dates from metadata. A date
  whose `variables.csv` row sets `anchor` (its entry-date variable) is a
  survival date: `floor(n * event_prop)` rows receive a date between
  `followup_min` and `followup_max` days after the anchor, drawn from a
  uniform, exponential or Gompertz distribution, and the rest are `NA`. An
  optional `censored_by` column names a competing survival date, such as
  death, that sets this date to `NA` where it comes first. The statistics and
  rules are those of `create_wide_survival_data()`, ported exactly. New
  functions: `mock_spec_survival()` and `generate_survival_dates()`. This
  resolves the known issue, listed since v0.2.0, that survival data had to be
  generated separately.
- Migration: add `anchor` (and `censored_by` where a competing risk applies)
  to each survival date's row. A date with `followup_min`, `followup_max` or
  `event_prop` but no `anchor` now fails with a message naming the fix;
  previously it was silently dropped or generated as a plain calendar date.
- Missing codes and garbage are applied to survival dates after the survival
  rules. Garbage that places a date before entry is therefore kept, whereas
  the legacy engine set such dates to `NA`.
- Derived columns, from `mockFormula` or survival dates, describe the clean
  generated values; missing codes and garbage are then applied to each column
  independently. `is.na` is added to the `mockFormula` allow-list so status
  and follow-up time can be derived. Derive both from the same observation
  window: `as.integer(!is.na(death_date))` only says a death date exists,
  not that the death was observed before censoring.
- A `censored_by` target may not itself have `censored_by`. Chained censoring
  would report some events as observed after observation ended, so it is
  rejected in this version with a message naming the fix.
- The packaged minimal example now generates entirely through the v0.4
  pipeline, because its Gompertz survival dates no longer force the legacy
  generator. Its seeded output differs from v0.4.
- If the legacy generator is selected (`validate = FALSE`,
  `variable_details = NULL`, detail-level-only `databaseStart`, or another
  unsupported variable) on metadata that sets `anchor`, `create_mock_data()`
  stops and names the survival variables rather than dropping them.
- `create_wide_survival_data()` is deprecated and warns once per session.
- Known issues found while porting, reproduced unchanged: #54 (Gompertz
  follow-up times are degenerate with the packaged parameters), #55
  (administrative censoring is drawn per person), #56 (smaller legacy
  discrepancies).

```

In the 0.2.0 section, replace:

```markdown
- Survival variable type must be generated manually with `create_wide_survival_data()`
- Cannot be used in `create_mock_data()` batch generation (requires paired variables)
```

with:

```markdown
- Survival variable type must be generated manually with `create_wide_survival_data()` (resolved in 0.5.0, #40)
- Cannot be used in `create_mock_data()` batch generation (requires paired variables) (resolved in 0.5.0, #40)
```

(The acceptance criterion in #40 says "remove"; annotating keeps the historical entry accurate for readers of 0.2.0.)

- [x] **Step 3: Rewrite `vignettes/tutorial-survival-data.qmd`**

Replace the whole file with:

````markdown
---
title: "Generating survival data with competing risks"
format: html
vignette: >
  %\VignetteIndexEntry{Generating survival data with competing risks}
  %\VignetteEngine{quarto::html}
  %\VignetteEncoding{UTF-8}
---

```{r}
#| label: setup
#| include: false
# Load package - works in both local dev and pkgdown build
if (file.exists("../DESCRIPTION")) {
  devtools::load_all("../", quiet = TRUE)
} else {
  library(MockData)
}
```

::: {.vignette-about}
**About this vignette:** This tutorial shows how to generate survival data for cohort studies from metadata: an entry date, event dates, a competing risk (death) and censoring (loss to follow-up, administrative censoring). You will learn how survival dates are described in `variables.csv`, which temporal rules MockData applies, and how to derive follow-up time and event indicators. All code examples run during vignette build.
:::

## Overview

Survival analysis needs several date variables that respect each other:

- **Cohort entry date** (baseline, index date)
- **Event dates** (disease incidence, outcomes of interest)
- **Competing risks** (death prevents observation of the primary event)
- **Censoring** (loss to follow-up, administrative censoring)

From MockData 0.5, `create_mock_data()` generates all of these from metadata. A survival date is a date variable whose row in `variables.csv` names, in the `anchor` column, the entry date it is generated from.

This tutorial builds clean, analysis-ready survival data. To generate raw data with temporal violations for testing data-cleaning pipelines, see the [Garbage data tutorial](tutorial-garbage-data.html#survival-data-garbage).

## Describing survival dates in metadata

The packaged minimal example has an entry date and four survival dates:

```{r}
#| label: load-metadata
variables <- read.csv(
  system.file("extdata/minimal-example/variables.csv", package = "MockData"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
variable_details <- read.csv(
  system.file("extdata/minimal-example/variable_details.csv", package = "MockData"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

survival_columns <- c("variable", "anchor", "censored_by", "distribution",
                      "followup_min", "followup_max", "event_prop")
date_rows <- variables$rType == "date"
variables[date_rows, survival_columns]
```

Each survival date has:

- `anchor`: the entry-date variable it is generated from (`interview_date`)
- `followup_min`, `followup_max`: the follow-up window, in days after the anchor
- `event_prop`: the share of people who have the event; the rest are `NA` (censored)
- `distribution`: how follow-up times spread across the window (`uniform`, `exponential` or `gompertz`)
- `censored_by` (optional): a competing survival date. Where it comes first, this date is set to `NA`. Here `death_date` censors `primary_event_date`.

A date with follow-up parameters but no `anchor` fails validation, with a message naming the missing column.

## Generating survival data

The minimal example also adds future-date garbage to its survival dates, for data-quality testing. This section removes it to show clean data; the last section puts it back.

```{r}
#| label: generate
#| warning: false
#| message: false
clean_variables <- variables
clean_variables$garbage_high_prop[date_rows] <- 0

mock <- create_mock_data(
  databaseStart = "minimal-example",
  variables = clean_variables,
  variable_details = variable_details,
  n = 2000,
  seed = 123
)

surv <- mock[, c("interview_date", "primary_event_date", "death_date",
                 "ltfu_date", "admin_censor_date")]
head(surv)
```

Each row has an interview date (cohort entry). Survival dates that did not occur are `NA`.

### Event proportions

```{r}
#| label: event-proportions
#| echo: false
death_prop <- variables$event_prop[variables$variable == "death_date"]
n_deaths <- sum(!is.na(surv$death_date))
```

`death_date` has `event_prop = `r death_prop``, and `r n_deaths` of `r nrow(surv)` people have a death date. The count is exactly `floor(n * event_prop)`: MockData assigns a fixed number of events and shuffles who receives them.

## Competing risks and temporal rules

MockData applies these rules to each survival date, to the dates as generated and before any missing codes or garbage are added:

1. **Entry is the baseline.** A date earlier than its anchor is set to `NA`.
2. **Competing risks.** If a date has `censored_by`, it is set to `NA` wherever the censoring date is earlier. Death before a primary event means the event cannot be observed.

```{r}
#| label: verify-rules
events_after_entry <- all(surv$primary_event_date >= surv$interview_date, na.rm = TRUE)
deaths_after_entry <- all(surv$death_date >= surv$interview_date, na.rm = TRUE)
events_after_death <- sum(surv$death_date < surv$primary_event_date, na.rm = TRUE)
```

- All events on or after entry: `r events_after_entry`
- All deaths on or after entry: `r deaths_after_entry`
- Events recorded after a death: `r events_after_death`

With the packaged Gompertz parameters, every death falls exactly 365 days after entry and every primary event within about 94 days, so in this example no death precedes an event and the competing-risk rule never applies ([#54](https://github.com/Big-Life-Lab/MockData/issues/54)). The small specification below shows the rule at work, with uniform follow-up times that overlap:

```{r}
#| label: competing-risk-demo
spec <- mock_spec(
  mock_spec_date("entry", range = as.Date(c("2001-01-01", "2005-12-31"))),
  mock_spec_survival("death", anchor = "entry",
    followup_min = 0, followup_max = 3650, event_prop = 0.5),
  mock_spec_survival("event", anchor = "entry",
    followup_min = 0, followup_max = 3650, event_prop = 1,
    censored_by = "death")
)
baseline <- generate_mock_data_native(spec, n = 1000, seed = 1)
demo <- generate_survival_dates(baseline, spec, seed = 1)
n_censored <- sum(is.na(demo$event))
```

Everyone would have the event (`event_prop = 1`), but `r n_censored` of 1,000 events are removed because death came first.

## Deriving follow-up time and event indicators

### After generation, in R

Observation ends at the earliest of the primary event, death, loss to follow-up and administrative censoring:

```{r}
#| label: calculate-end-date
end_columns <- c("primary_event_date", "death_date", "ltfu_date", "admin_censor_date")
surv$t_end <- do.call(pmin, c(surv[end_columns], na.rm = TRUE))
surv$followup_days <- as.numeric(surv$t_end - surv$interview_date)

surv$event_indicator <- ifelse(
  !is.na(surv$primary_event_date) & surv$primary_event_date == surv$t_end, 1,
  ifelse(!is.na(surv$death_date) & surv$death_date == surv$t_end, 2, 0)
)
table(surv$event_indicator)
```

The indicator is 0 for censored (loss to follow-up or administrative censoring), 1 for the primary event and 2 for death.

### As generated columns, with mockFormula

Status and follow-up time can also be generated as columns, with formula variables (`mockFormula` in `variable_details.csv`, or `mock_spec_formula()` in R). Derive both from the same observation window. `!is.na(death)` only says that a death date exists: a death after administrative censoring was not observed, so its status is 0 and its follow-up ends at the censoring date. A formula cannot return a `Date`, so the end of observation is written out in both formulas:

```{r}
#| label: formula-derivation
spec_derived <- mock_spec(
  mock_spec_date("entry", range = as.Date(c("2001-01-01", "2005-12-31"))),
  mock_spec_survival("death", anchor = "entry",
    followup_min = 365, followup_max = 7300, event_prop = 0.2),
  mock_spec_survival("admin", anchor = "entry",
    followup_min = 1825, followup_max = 5475, event_prop = 1),
  mock_spec_formula("death_status",
    formula = "as.integer(!is.na(death) & death == pmin(death, admin, na.rm = TRUE))",
    rtype = "integer"),
  mock_spec_formula("followup_days",
    formula = "as.numeric(pmin(death, admin, na.rm = TRUE) - entry)")
)
derived <- evaluate_mock_formulas(
  generate_survival_dates(
    generate_mock_data_native(spec_derived, n = 1000, seed = 2),
    spec_derived, seed = 2
  ),
  spec_derived, seed = 2
)
head(derived)
```

A death on the censoring date counts as observed, which matches the censoring rule: an event is removed only when the censoring date is strictly earlier.

### Clean truth, observed data and analysis variables

Generation produces three layers:

- **Clean truth:** the generated dates and formula columns before contamination. The code above keeps this layer, because it stops before `postprocess_mock_data()`.
- **Observed data:** the output of `postprocess_mock_data()` and `create_mock_data()`, after missing codes and garbage.
- **Analysis variables:** status, follow-up time and similar quantities that a downstream analysis recalculates from the observed data, as in the R code above.

Formula columns belong to the clean-truth layer. If you add missing codes or garbage to `death`, they are applied afterwards and to each column independently, so `death_status` can be 1 on a row where `death` shows a missing code. When testing a cleaning pipeline that is useful, because the clean columns are the answer key. When the columns must agree, compute the analysis variables from the observed data.

## Distributions for follow-up times

- **uniform**: follow-up times spread evenly across the window (loss to follow-up, administrative censoring)
- **gompertz**: a hazard that rises over time (death, chronic disease), with `shape` (default 0.1) and `rate` (default 0.0001). See the note on the packaged parameters above.
- **exponential**: times concentrated early in the window. The rate is derived from the window as `1 / ((followup_max - followup_min) / 3)`; the `rate` column is not used ([#56](https://github.com/Big-Life-Lab/MockData/issues/56)).

Follow-up times are whole days, clamped to the window.

## Administrative censoring

In the minimal example, `admin_censor_date` is a survival date with `event_prop = 1`, so each person gets a random date between one and 20 years after entry. Administrative censoring is usually a single study end date; [#55](https://github.com/Big-Life-Lab/MockData/issues/55) tracks how to express that in metadata.

## Date formats

Survival dates are R `Date` objects. In this version, `sourceFormat` values other than `analysis` are not supported for survival dates or for the entry dates they are anchored to.

## Temporal violations for QA testing

The minimal example adds future-date garbage to its survival dates (`garbage_high_prop` and `garbage_high_range`). MockData applies garbage after the temporal rules, so the violations stay in the output for your validation pipeline to find:

```{r}
#| label: temporal-violations-qa
#| warning: false
#| message: false
mock_qa <- create_mock_data(
  databaseStart = "minimal-example",
  variables = variables,
  variable_details = variable_details,
  n = 1000,
  seed = 999
)
future_threshold <- as.Date("2025-01-01")
n_future_events <- sum(mock_qa$primary_event_date > future_threshold, na.rm = TRUE)
n_future_deaths <- sum(mock_qa$death_date > future_threshold, na.rm = TRUE)
```

- Future primary events: `r n_future_events`
- Future deaths: `r n_future_deaths`

## The legacy create_wide_survival_data()

Before MockData 0.5, survival data had to be generated separately with `create_wide_survival_data()`. The function still works but is deprecated and warns once per session. Its rules are the ones `create_mock_data()` now applies, ported exactly.

## Key concepts summary

| Concept | Implementation | Details |
|---------|----------------|---------|
| **Survival date** | `anchor` in variables.csv | Generated relative to the named entry date |
| **Event proportions** | `event_prop` in variables.csv | Exactly `floor(n * event_prop)` events |
| **Competing risks** | `censored_by` in variables.csv | Set to `NA` where the censoring date is earlier; no chains |
| **Temporal ordering** | Automatic | No survival date before its anchor |
| **Distributions** | `distribution` in variables.csv | Uniform, exponential or Gompertz follow-up times |
| **Derived columns** | `mockFormula` or R after generation | Formulas describe clean truth; derive status and time from one observation window |
| **QA testing** | `garbage_*` columns | Applied after the temporal rules |

## What you learned

- **Describing survival dates**: `anchor`, the follow-up window, `event_prop`, `distribution` and `censored_by`
- **Generating them**: `create_mock_data()` builds survival dates with every other variable
- **Temporal rules**: no date before its anchor; competing risks through `censored_by`
- **Derived variables**: follow-up time and event indicators, in R or as `mockFormula` columns
- **QA testing**: garbage that survives the temporal rules

## Next steps

**Tutorials:**

- [Date variables](tutorial-dates.html) - Interval notation and date distributions
- [Garbage data](tutorial-garbage-data.html) - Testing validation pipelines
- [Getting started](getting-started.html) - MockData fundamentals

**Reference:**

- [Configuration reference](reference-config.html) - Complete metadata schema
- [Advanced topics](advanced-topics.html) - Derived variables and technical details
````

- [x] **Step 4: Garbage tutorial survival section (`vignettes/tutorial-garbage-data.qmd`)**

Replace the sentence `The \`prop_garbage\` parameter in \`create_wide_survival_data()\` is deprecated. Instead, add garbage to individual date variables using these functions:` with `Add garbage to individual survival date variables with \`add_garbage()\`, then generate them with \`create_mock_data()\`:`.

Replace the whole `generate-survival-garbage` chunk body (from `# Define metadata (pass full data frames)` through `n_violations <- sum(future_deaths, na.rm = TRUE)`) with:

```r
# Define metadata: death_date is a survival date anchored on study_entry
surv_variables <- data.frame(
  variable = c("study_entry", "death_date"),
  variableType = c("Date", "Date"),
  rType = c("date", "date"),
  role = c("enabled", "enabled"),
  distribution = c("uniform", "gompertz"),
  rate = c(NA, 0.0001),
  shape = c(NA, 0.1),
  anchor = c("", "study_entry"),
  followup_min = c(NA, 30),
  followup_max = c(NA, 3650),
  event_prop = c(NA, 1.0),
  sourceFormat = c("analysis", "analysis"),
  stringsAsFactors = FALSE
)

surv_variable_details <- data.frame(
  variable = "study_entry",
  recStart = "[2010-01-01,2015-12-31]",
  recEnd = "copy",
  proportion = 1,
  stringsAsFactors = FALSE
)

# Add garbage to death_date (future dates for temporal violation testing)
surv_vars_with_garbage <- add_garbage(surv_variables, "death_date",
  garbage_high_prop = 0.03, garbage_high_range = "[2030-01-01, 2099-12-31]")

# Generate survival dates; garbage is applied after the temporal rules
survival_dates <- create_mock_data(
  databaseStart = "test",
  variables = surv_vars_with_garbage,
  variable_details = surv_variable_details,
  n = 2000,
  seed = 400
)

# Validate: check for impossibly future death dates (temporal violation proxy)
future_threshold <- as.Date("2030-01-01")
future_deaths <- survival_dates$death_date > future_threshold
n_violations <- sum(future_deaths, na.rm = TRUE)
```

Replace the five "Key points about survival garbage" bullets with:

```markdown
- Survival dates come from `create_mock_data()`: set `anchor` on each survival date's row
- Add garbage to individual date variables with the `add_garbage()` helper
- MockData applies garbage after the survival rules, so violations such as dates before entry stay in the output
- Test temporal validation by checking for impossible dates (for example, far-future death dates)
```

Replace the summary bullet `- **Add temporal violations in survival data** by adding garbage to individual date variables (not via \`create_wide_survival_data()\` function parameter)` with `- **Add temporal violations in survival data** by adding garbage to individual survival date variables`.

- [x] **Step 5: Reference, advanced topics, design philosophy**

`vignettes/reference-config.qmd`: directly after the heading `### Extension columns (MockData-specific)` insert:

```markdown
MockData reads its generation settings from extension columns added to the recodeflow files; recodeflow and its consuming packages (cchsflow, chmsflow) ignore them. The placement rule:

- On `variables.csv`, extension columns are unprefixed and sit beside the recodeflow columns (`rType`, `distribution`, `garbage_*`, `followup_min`, `anchor` and so on).
- On `variable_details.csv`, where MockData columns sit among recodeflow's own semantic columns (`recStart`, `recEnd`, `catLabel`), they carry a `mock` prefix, as `mockFormula` does.

Other packages can extend recodeflow metadata the same way. A MockData-owned sidecar file that keeps recodeflow files free of extension columns is planned ([#57](https://github.com/Big-Life-Lab/MockData/issues/57)).

```

Replace the three date-distribution bullets and the paragraph after them:

```markdown
- `"uniform"` - Equal probability for all dates
- `"gompertz"` - Age-related hazard (requires `rate`, `shape`, `followup_min`, `followup_max`, `event_prop`)
- `"exponential"` - Constant hazard (requires `rate`, `followup_min`, `followup_max`, `event_prop`)

The `followup_min`, `followup_max`, and `event_prop` fields apply only to the
date/survival use of `exponential`. For continuous variables, `exponential`
requires only `rate`.
```

with:

```markdown
- `"uniform"` - Equal probability for all dates, or follow-up times spread evenly across the window for survival dates
- `"gompertz"` - Survival dates only: a hazard rising over time, with `shape` and `rate` (defaults 0.1 and 0.0001)
- `"exponential"` - Survival dates only: follow-up times concentrated early in the window. The rate is derived from the window; the `rate` column is not used for survival dates ([#56](https://github.com/Big-Life-Lab/MockData/issues/56))

Survival dates also need `anchor`, `followup_min`, `followup_max` and `event_prop` (see below). For continuous variables, `exponential` requires only `rate`.
```

In the "Survival parameters (date variables with events)" table, add two rows after the `event_prop` row:

```markdown
| `anchor` | character | Entry-date variable this date is generated relative to; a non-blank value makes the variable a survival date | Name of a date variable | `interview_date` |
| `censored_by` | character | Optional competing survival date with the same anchor; where it is earlier, this date becomes `NA`. The target may not itself have `censored_by` | Name of a survival variable | `death_date` |
```

Replace the "When to use" bullets with:

```markdown
- Date variables representing events (death_date, disease_diagnosis, etc.)
- NOT for index dates (interview_date) - those are the anchor
- Every survival date needs `anchor`; a date with `followup_min`, `followup_max` or `event_prop` but no `anchor` fails validation
```

Replace the survival example block's three `uid,variable,distribution,followup_min,followup_max,event_prop` examples with:

```csv
# Primary event date: 10% experience dementia diagnosis within 1-15 years; death censors it
uid,variable,distribution,anchor,censored_by,followup_min,followup_max,event_prop
v005,primary_event_date,gompertz,interview_date,death_date,365,5475,0.1

# Death date: 20% die within 1-20 years (competing risk)
uid,variable,distribution,anchor,censored_by,followup_min,followup_max,event_prop
v006,death_date,gompertz,interview_date,,365,7300,0.2

# Loss to follow-up: 10% lost within 1-20 years (censoring)
uid,variable,distribution,anchor,censored_by,followup_min,followup_max,event_prop
v_007,ltfu_date,uniform,interview_date,,365,7300,0.1
```

`vignettes/advanced-topics.qmd`: after the paragraph under `## Derived variables` that ends `...the pattern below still applies to \`DerivedVar::\`/\`Func::\` variables without a \`mockFormula\`.`, insert:

```markdown

Survival dates are derived too: a date whose `variables.csv` row sets `anchor` is computed from that entry date (see `vignette("tutorial-survival-data")`).

Generation produces three layers. **Clean truth** is the generated data before contamination: run `generate_mock_data_native()`, `generate_survival_dates()` and `evaluate_mock_formulas()` yourself and keep the result. **Observed data** is what `postprocess_mock_data()` and `create_mock_data()` return, after missing codes and garbage. **Analysis variables**, such as status and follow-up time, are what a downstream analysis recalculates from the observed data. Formula columns belong to the clean-truth layer, so a derived status can disagree with a source column that postprocess later shows as missing. When they must agree, derive them from the observed data after generation.
```

`vignettes/design-philosophy-v04.qmd`: after the paragraph ending `...and a more general evaluator, remain deferred.`, insert:

```markdown

Metadata-driven survival dates also landed in v0.5: a date with an `anchor` is computed from its entry date in a post-baseline stage, with the rules of the legacy `create_wide_survival_data()`. Exposure-dependent hazards and other causal structure remain future work; `development/adr/v05-survival-dates.md` records how the design leaves room for them.
```

- [x] **Step 6: Stale-claims sweep**

Seven vignettes run `create_mock_data()` on the minimal example and now see v0.4 output with survival dates present. Run:

```bash
grep -nE 'primary_event_date|death_date|ltfu_date|admin_censor_date|anchor|Skipped variables|Falling back|legacy' \
  vignettes/advanced-topics.qmd vignettes/getting-started.qmd vignettes/for-recodeflow-users.qmd \
  vignettes/reference-config.qmd vignettes/tutorial-categorical-continuous.qmd \
  vignettes/tutorial-dates.qmd vignettes/tutorial-garbage-data.qmd vignettes/migrating-from-v03-v04.qmd
```

Read every hit. Fix any sentence that describes survival dates as absent, skipped or generated separately by `create_mock_data()`, or that says the minimal example uses the legacy generator. `tutorial-dates.qmd`'s standalone `create_date_var()` example with an `anchor_date` column documents the legacy standalone helper and stays. Then render each changed or affected vignette and check that it builds without error:

```bash
for f in tutorial-survival-data tutorial-garbage-data reference-config advanced-topics design-philosophy-v04 tutorial-dates getting-started for-recodeflow-users tutorial-categorical-continuous; do
  quarto render vignettes/$f.qmd --to html > /dev/null 2>&1 && echo "OK $f" || echo "FAIL $f"
done
```

If a render fails with `there is no package called 'MockData'`, run `Rscript -e 'devtools::install(upgrade = "never")'` first (#26). In the rendered `tutorial-survival-data.html`, check that `Events recorded after a death` is `0`, that `n_censored` is well above zero, and that the future-event and future-death counts are above zero.

- [x] **Step 7: Bookkeeping**

In `development/post-v040-development-plan.md`, tick the three `- [ ]` steps under `### Task 7: Survival pairs in batch generation (#40)`:

```bash
P=development/post-v040-development-plan.md
awk 'BEGIN{t=0} /^### Task 7/{t=1} /^### Task 8/{t=0} { if (t && /^- \[ \] \*\*Step/) sub(/^- \[ \]/, "- [x]"); print }' $P > "$P.tmp" && mv "$P.tmp" $P
awk '/^### Task 7/,/^### Task 8/' $P | grep -c '^- \[x\]'   # expect 3
```

 In `development/adr/v05-survival-dates.md`, append to the status line: ` Implemented on branch v05-survival-dates per development/plans/2026-09-24-survival-dates.md.` Tick this plan's checkboxes as tasks complete.

- [x] **Step 8: Full verification**

```bash
cd /Users/dmanuel/github/mock-data && Rscript -e 'devtools::document()' && Rscript -e '
df <- as.data.frame(devtools::test(reporter = "silent", stop_on_failure = FALSE))
cat(sprintf("FAIL %d | ERROR %d | WARN %d | SKIP %d | PASS %d\n",
  sum(df$failed), sum(df$error), sum(df$warning), sum(df$skipped), sum(df$passed)))'
D=$(mktemp -d) && cd $D && R CMD build --no-manual /Users/dmanuel/github/mock-data > build.log 2>&1 && \
  _R_CHECK_FORCE_SUGGESTS_=false R CMD check --no-manual --as-cran MockData_*.tar.gz > check.log 2>&1; \
  grep -nE 'ERROR|WARNING|NOTE|^Status' MockData.Rcheck/00check.log
cd /Users/dmanuel/github/mock-data && Rscript -e 'devtools::install(upgrade = "never", quiet = TRUE); pkgdown::build_site(new_process = FALSE, preview = FALSE)' 2>&1 | tail -3
```

Expected: suite FAIL 0 | ERROR 0; R CMD check 0 errors, 0 warnings, NOTEs only (new submission, time verification); pkgdown builds, including reference pages for `mock_spec_survival` and `generate_survival_dates`. Do not leave `MockData.Rcheck/` or tarballs in the repo (the check runs in a temp directory).

- [x] **Step 9: Commit**

```bash
git add NEWS.md _pkgdown.yml vignettes/ development/
git commit -m "Document metadata-driven survival dates (#40)" -m "Rewrites the survival tutorial around anchor metadata and
create_mock_data(), including the competing-risk rule, derived status and
follow-up time, and notes on #54 and #55. Updates the garbage tutorial's
survival section, the configuration reference (anchor, censored_by, date
distributions, and the extension-column placement rule), advanced topics
and design philosophy. NEWS gains the #40 section and marks the v0.2.0
known issue resolved."
```

---

## After this plan

Not part of the plan's tasks; recorded so the release train stays in order:

- Open the #40 PR into `dev`, stacked on #59 (merge order #51 → #52 → #59 → #40 → #53).
- Merge `v05-survival-dates` into `v05-release-prep` (#53) and fold the new NEWS section into the 0.5.0 structure: the breaking and behaviour changes under **Breaking changes**, the feature under **New features**, the deprecation under a **Deprecations** heading.
- Close #40 when the PR merges. Comment on #23 with what the new tests cover (exact event counts, no date before entry, censoring in both directions); #23 also asks for loss-to-follow-up censoring, which is now expressed with `censored_by` rather than a built-in rule, so leave #23 for the maintainer to close or narrow.
