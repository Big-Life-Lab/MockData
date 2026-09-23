# ADR: v0.5 Metadata-Driven Survival Dates

**Status**: PROPOSED 2026-09-22. Design agreed with the maintainer in conversation (scope, fidelity policy, architecture, metadata convention, semantics). Two points need explicit ratification before implementation: D5 (contamination after the consistency rules) and D8 (adding `is.na` to the formula allow-list).
**Date**: 2026-09-22
**Decision owner**: MockData maintainers
**Issue**: #40 (also advances #23, #17)
**Depends on**: #38 (seed contract), #39 (formula stage; dependency-ordering machinery reused here)

## Decision summary

| # | Question | Decision |
|---|---|---|
| D1 | Architecture | Survival dates are a new variable type computed in a **post-baseline stage** from their already-generated anchor date. One column per spec variable; the assembly contract is unchanged |
| D2 | Scope | **Full parity** with `create_wide_survival_data()`: entry, event, death, loss to follow-up, administrative censoring, and both consistency rules |
| D3 | Metadata convention | Two columns on `variables.csv` beside `followup_min`/`followup_max`/`event_prop`: `anchor` (required) and `censored_by` (optional) |
| D4 | Fidelity | **Exact port** of the legacy statistics and rules; concerns are filed as issues, not fixed in #40 |
| D5 | Contamination order | Consistency rules run on clean dates; missing codes and garbage are applied afterwards by postprocess (**ratify**) |
| D6 | Stage and seed | Pipeline becomes baseline, survival, formulas, postprocess. `.MOCK_STAGES` gains `survival = 4L` (appended; no existing index moves) |
| D7 | Dependencies | Survival dates record `depends_on = c(anchor, censored_by)`, the field formulas already use; one ordering utility serves every derived stage |
| D8 | Formula allow-list | Add `is.na`, so survival status and time can be derived with `mockFormula` (**ratify**; amends the #39 ADR's D3) |
| D9 | Legacy path | `create_wide_survival_data()` warns once as deprecated and is kept as the characterization reference |

## Context

Survival data has been generated outside `create_mock_data()` since v0.2.0. The NEWS known-issue entry reads: "Cannot be used in `create_mock_data()` batch generation (requires paired variables)". Users call `create_wide_survival_data()` by hand.

The legacy engine is a loop. It generates the entry date as a plain calendar date. It then generates each other date by calling `create_date_var()` with the entry date passed in a `df_mock` column named `anchor_date` (`R/create_wide_survival_data.R`, step 1). Finally it applies two rules: any date earlier than entry becomes `NA` (`:347`), and an event date later than the death date becomes `NA` (`:363`). The per-date statistics live in `create_date_var()` (`R/create_date_var.R:209-350`): a date is a survival date when `followup_min`, `followup_max` and `event_prop` are all present; `floor(n_valid * event_prop)` rows receive an event, shuffled; follow-up times are uniform, exponential or Gompertz within the window; non-events are `NA`.

The v0.4 pipeline handles these dates incorrectly today, in both of its paths (verified 2026-09-22 on the minimal example):

- A Gompertz or exponential survival date fails the native support check (`R/create_mock_data.R:36`), and the fallback is all-or-nothing for the spec. The legacy dispatcher then calls `create_date_var()` without an `anchor_date` column, so every survival date in the spec, uniform ones included, warns and is dropped. For the minimal example, `create_mock_data()` returns `interview_date` and none of the four survival dates.
- In a spec whose survival dates are all uniform, nothing forces the fallback, and the native backend generates them as plain calendar dates over their `recStart` range. The adapter reads `followup_min`, `followup_max` and `event_prop` onto the spec (`R/mock_spec_recodeflow.R:418`), but nothing downstream uses them. With `interview_date` and `ltfu_date` alone (n = 2,000), `ltfu_date` is 100 per cent non-missing although `event_prop` is 0.1, and 128 dates fall before entry.

So #40 fixes a correctness defect as well as a usability gap.

The design follows from #39. A formula variable is a column computed from other generated columns, evaluated in dependency order after baseline generation. A survival date has the same structure: a column computed from its anchor. The only difference is that it draws random numbers. Treating survival dates as a derived stage reuses #39's skip-in-baseline pattern, dependency ordering, strict validation at stage entry, and diagnostics marking.

### Constraints

- **One seeded-output break in v0.5**, already spent by #38. Specs without survival variables must produce byte-identical output; the #48 pinned-value tests enforce this.
- **No backward-compatibility obligation** for 0.x metadata (maintainer decision, 2026-09-22). Metadata that relied on the old silent behaviour may now fail validation, provided the error names the fix.
- **recodeflow semantics untouched.** The new columns are MockData extensions; cchsflow and chmsflow need no change.
- **Keep causal modelling open.** The maintainer expects mock data to be used to study causal structure (DAG-based simulation) in future. That is out of scope here, but no decision should make a later structural-equation stage harder. D1 and D7 are chosen with this in mind.

## Decision points

### D1: Architecture

**(a) Post-baseline anchored stage (chosen).** A new type `survival` (rtype `date`). Both backends skip it in baseline generation, as they skip `formula` (`R/mock_spec_native.R:87,405`; `R/mock_spec_simstudy.R:137,260`). A new exported `generate_survival_dates(data, spec, seed = NULL)` computes the survival dates from the anchor columns in `data`, then applies the consistency rules. Postprocess then treats them like any other column.

**(b) Multi-column generator (rejected).** One spec entry returning a data frame of two or more columns. This changes the one-column-per-variable contract in the native backend, the simstudy backend, postprocess and diagnostics. It also forces an awkward ownership question for a five-date family, since the entry date would be both a plain variable and a member of the group.

**(c) Delegate to `create_wide_survival_data()` (rejected).** This bypasses spec validation, diagnostics, the seed contract and postprocess, and makes a deprecated function part of the v0.4 pipeline.

### D2: Scope

Full parity with the five legacy roles and both rules. No time-to-event or status columns are generated; the legacy engine produces none. D8 lets users derive them with `mockFormula`.

### D3: Metadata convention

| Column | On | Meaning |
|---|---|---|
| `anchor` | `variables.csv` | Name of the date variable this date is generated relative to. A non-blank `anchor` makes the variable type `survival` |
| `censored_by` | `variables.csv` | Optional. Name of a competing survival date. Where that date is earlier than this one, this one becomes `NA` |

The minimal example becomes:

```
variable            anchor          censored_by  followup_min  followup_max  event_prop  distribution
interview_date                                                                           uniform
primary_event_date  interview_date  death_date   0             5475          0.3         gompertz
death_date          interview_date               365           7300          0.2         gompertz
ltfu_date           interview_date               365           7300          0.1         uniform
admin_censor_date   interview_date               365           7300          1.0
```

A single `survival_role` column (`entry`, `event`, `death`, `ltfu`, `admin_censor`) was considered and rejected. It reproduces the legacy function's five argument slots, which fix one entry date and one competing-risk rule. `anchor` and `censored_by` express the same case and extend to a second cohort or a second competing risk without a new vocabulary. `censored_by` also makes the competing-risk rule visible in metadata.

**Placement.** The columns are unprefixed and sit on `variables.csv`, beside the existing survival parameters. The rule, to be written into `reference-config.qmd`, is: MockData extension columns on `variables.csv` are unprefixed; MockData columns on `variable_details.csv`, where they sit among recodeflow's semantic columns, carry the `mock` prefix (as `mockFormula` does). A MockData-owned sidecar that keeps recodeflow files free of extension columns is a separate v0.6 decision (see Future directions); the spec layer does not depend on where columns are read from, so that change will not affect this design.

**Validation of the convention.** A date variable with any of `followup_min`, `followup_max` or `event_prop` but no `anchor` is an error at spec construction, naming the fix (`anchor = "<entry variable>"`). A variable with `anchor` but without all three parameters is also an error.

### D4: Fidelity

The legacy statistics and rules are ported verbatim:

1. `n_events = floor(n * event_prop)`; the event indicator is shuffled with `sample()`.
2. Follow-up days for events, by `distribution`. **Uniform:** `runif(n_events, followup_min, followup_max)`. **Exponential:** `rexp(n_events, rate = 1 / ((followup_max - followup_min) / 3)) + followup_min`, capped at `followup_max`. **Gompertz:** `(1/shape) * log(1 - (shape/rate) * log(1 - u))` with `u ~ runif`, clamped to the window; `shape` defaults to 0.1 and `rate` to 0.0001.
3. Date = anchor + follow-up days for events; `NA` otherwise.
4. After all survival dates are drawn: any date earlier than its anchor becomes `NA`; then, for each variable with `censored_by`, rows where the censoring date is earlier become `NA`.

Survival dates are drawn in spec `position` order. No ordering among them is needed, because every anchor is a baseline date.

Output cannot be bit-identical to `create_wide_survival_data()`, because the RNG streams differ (#38). Parity is therefore tested structurally and distributionally (Test strategy). Two further differences are inherent in the pipeline:

| Legacy | New pipeline | Reason |
|---|---|---|
| Missing codes fill the last `n - n_valid` rows; events are split across the first `n_valid` rows (`R/create_date_var.R:295,417`) | Postprocess assigns missing codes at random rows | Missingness belongs to postprocess in v0.4. Proportions match in expectation |
| Garbage is applied inside `create_date_var()`, before the rules, so before-entry garbage is erased | Rules run first; garbage afterwards (D5) | Stage order |

### D5: Contamination after the consistency rules (ratify)

The consistency rules produce clean, analysis-ready dates. Missing codes and garbage are applied afterwards, by postprocess, as for every other variable. This matches #39, where formulas are computed on clean baseline values before contamination.

It changes one behaviour. In the legacy engine, garbage that places a date before entry is set to `NA` by the before-entry rule; `test-survival-garbage-deprecation.R:147` acknowledges this. The garbage tutorial states that survival garbage exists to create temporal violations such as death before entry, for testing cleaning pipelines. Under D5 those violations survive, so the pipeline does what the tutorial describes. This is a change of stage order, not of any rule, but it alters legacy output and so needs explicit ratification under D4.

### D6: Stage and seed

`create_mock_data()` runs baseline, survival, formulas, then postprocess. Survival precedes formulas so that a `mockFormula` can use survival dates. `.MOCK_STAGES` (`R/mock_spec_native.R:12`) gains `survival = 4L`. Appending leaves indices 0 to 3 in place, so every existing pinned value holds; the frozen-stage test (`test-seed-contract.R:99`) is extended, not renumbered. Survival draws run inside `.with_mock_seed(seed, stage = "survival")`.

### D7: Dependencies

Survival variables set `depends_on = c(anchor, censored_by)`. `.order_formula_variables()` (`R/mock_spec_formula.R:88`) is generalized to order any derived type by `depends_on`, and the formula stage uses the generalized version. The purpose is forward compatibility: a later structural-equation stage, whether in MockData or a separate package, would read a single dependency field from the spec and add a type rather than a mechanism.

### D8: Add `is.na` to the formula allow-list (ratify)

The #39 allow-list has no missingness test, so a formula cannot derive an event indicator from a survival date. With `is.na` added, users can write, for example, `as.integer(!is.na(death_date))` for status and `as.numeric(pmin(death_date, admin_censor_date, na.rm = TRUE) - interview_date)` for follow-up time in days. The #39 ADR permits widening the list on concrete need; this is one. `is.na` has no side effects and cannot reach outside the sandbox.

### D9: Legacy path

`create_wide_survival_data()` is already tagged `@keywords deprecated`. v0.5 adds a one-time deprecation warning pointing to metadata-driven generation. The function is retained unchanged: it is the reference for the characterization tests that pin the rules before the port.

## Validation, direct API and diagnostics

**Validator.** A `survival` branch in `validate_mock_spec()` beside the `date` and `formula` branches (`R/mock_spec.R:968`):

- `anchor` names a spec variable of type `date` (not `survival` or `formula`; chained anchors are not supported)
- `censored_by`, if set, names a `survival` variable with the same `anchor`
- `followup_min` and `followup_max` finite, non-negative, and `followup_min <= followup_max`
- `event_prop` in [0, 1]
- `distribution` one of `uniform`, `exponential`, `gompertz`; `shape` and `rate` positive when supplied
- `rtype` is `date`

`generate_survival_dates()` strict-validates at entry, like `evaluate_mock_formulas()`, and stops if an anchor column is absent from `data`.

**Adapter.** `.recodeflow_variable_kind()` (`R/mock_spec_recodeflow.R:117`) returns `survival` for a date row with a non-blank `anchor`. Construction reads `anchor` and `censored_by` beside the existing `followup_*`, `event_prop`, `rate` and `shape` reads. The `recStart` range of a survival date is not used for generation, as in the legacy engine.

**Direct API.** `mock_survival()` returns a one-variable `mock_spec`; `mock_spec_survival()` returns a composable variable. Arguments: `name`, `anchor`, `followup_min`, `followup_max`, `event_prop`, `distribution = "uniform"`, `censored_by = NULL`, `shape = NULL`, `rate = NULL`, plus the usual missing-code, garbage, provenance and model-hint arguments.

**Diagnostics.** Following #39's D5 (`R/mock_spec_postprocess.R:35`): `derived = TRUE`, `anchor`, `censored_by`, `depends_on`, and `n_events`, the number of non-`NA` dates after the consistency rules and before postprocess.

## Concerns to file as issues (not fixed in #40)

Found while preparing this design. Each is reproduced exactly by the port.

1. **Gompertz output is degenerate with the packaged parameters.** With `shape = 0.1` and `rate = 1e-04`, time in days, the inverse-CDF never exceeds about 94 days (median 65). In the minimal example every non-garbage `death_date` therefore clamps to `followup_min`, exactly 365 days after entry (388 of 400 deaths in a 2,000-row legacy run; the other 12 are the 3 per cent high garbage). Every non-garbage `primary_event_date` falls within about 94 days despite a 15-year window. No death precedes an event, so the competing-risk rule never fires. The survival tutorial is built on this fixture. Whether the fault lies in the parameterization, the time scale, or the fixture values needs a methodological decision before the tutorial is rewritten around `create_mock_data()`.
2. **Administrative censoring is drawn per person.** `admin_censor_date` has `event_prop = 1.0` and a follow-up window, so each person gets a random date between one and 20 years after entry (1,762 distinct values in 2,000 rows). Its `variable_details` row specifies a fixed date, 2024-12-31, which is ignored. Administrative censoring is usually a fixed study end date.
3. **Declared date missingness is ignored.** Every missing row for the minimal example's dates is `else` with `NA::b` and a proportion (0.05 for `death_date`). Neither path applies it: the v0.4 adapter skips `else` rows (`R/mock_spec_recodeflow.R:232`), and the legacy `death_date` is exactly 20.0 per cent non-missing, its `event_prop`. Belongs with #15.
4. **The documentation overstates censoring.** `create_wide_survival_data()` documents that "observation ends at min(event, death, ltfu, admin_censor)" (`:61`), but the code applies only death before event. Under D3, users encode additional rules with `censored_by`.
5. **Positional missing-code placement** in `create_date_var()`: the last rows are the missing ones, so row order carries meaning.
6. **Inert range rows.** The `recStart` range on a survival date's `variable_details` row (for example `[2002-01-01,2021-01-01]`) never bounds anything, which invites the reader to think it does.

## Consequences

- `create_mock_data()` generates complete survival data from metadata, closing the NEWS known issue from v0.2.0.
- Survival metadata that previously generated silently wrong output now either generates correctly (with `anchor`) or fails validation with a message naming the fix.
- New exports: `generate_survival_dates()`, `mock_survival()`, `mock_spec_survival()`. Additions to `_pkgdown.yml` in the same PR.
- The formula allow-list grows by one function (D8).
- Specs without survival variables: output unchanged.

## Test strategy

1. **Characterization first.** Pin the legacy engine's two rules and its structural invariants on `create_wide_survival_data()` before any port code, as the reference.
2. **Validator and adapter.** One failing case, with its message, for each rule in "Validation"; the missing-anchor error.
3. **Generation.** Event proportion within two-sided binomial bounds for each distribution (#23's direction); every non-`NA` date at or after its anchor; `censored_by` sets `NA` exactly where the censoring date is earlier and nowhere else; typed zero-row output for `n = 0`; skipping the stage makes postprocess fail on the missing column.
4. **Contract.** Frozen-stage test extended with `survival = 4L`; pinned reference values for one survival spec; all existing pins untouched.
5. **End to end.** `create_mock_data()` on the amended minimal example produces all five dates with no fallback; the simstudy backend produces the same survival columns; a `mockFormula` derives status and follow-up time from them (D8); D5 is pinned by a test showing before-entry garbage survives.

## Migration

- Metadata: add `anchor` (and `censored_by` where a competing risk applies) to each survival date's row. Validation names the missing column.
- Code calling `create_wide_survival_data()` keeps working, with a deprecation warning. Replace it with `create_mock_data()` on metadata carrying `anchor`.
- Seeded survival output differs from the legacy function's; regenerate pinned expected values once.
- NEWS: feature entry; removal of the v0.2.0 known-issue entry with a migration note; the D5 behaviour change stated explicitly.

## Future directions

- **Sidecar overlay (v0.6, separate ADR).** A MockData-owned table keyed by variable, joined onto `variables` before spec construction, so all extension columns can live outside recodeflow files. The legacy `mock_data_config.csv` readers from v0.2 are the starting point to reconcile or retire.
- **Structural (causal) generation.** Out of scope. D1 and D7 keep one dependency field and one ordering mechanism for all derived variables, which is the base a DAG-driven stage would need.
