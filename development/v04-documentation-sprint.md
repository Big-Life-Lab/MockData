# MockData v0.4 Documentation Sprint

This sprint treats documentation as implementation validation. The goal is not
only to explain the v0.4 API, but to run realistic user workflows during
vignette and pkgdown builds.

## Principles

- Use Divio's four documentation needs: tutorials, how-to guides, reference, and
  explanation.
- Keep vignette code executable unless the code genuinely depends on an
  external package or private data.
- Prefer small, focused vignettes over one large tour.
- Use seeds in every stochastic example so rendered output is stable.
- Include at least one diagnostics example because the v0.4 pipeline's
  auditability contract is a central design change.

## First pass

- `getting-started-v04.qmd`: tutorial for the v0.4 `mock_spec` workflow.
- README: update the top-level status and quick example so users see v0.4
  immediately.
- `_pkgdown.yml`: expose the new v0.4 tutorial in site navigation.

## Follow-up vignettes

Tutorial:

- `getting-started-v04.qmd`: linear first-use path.

How-to:

- `recodeflow-metadata-v04.qmd`: use existing `variables.csv` and
  `variable_details.csv`.
- `diagnostics-and-garbage-v04.qmd`: inspect missing-code and garbage
  diagnostics.
- `choosing-a-backend-v04.qmd`: native vs optional `simstudy`.
- `migrating-from-v03-v04.qmd`: seed behavior, diagnostics attribute,
  fallback conditions, and compatibility wrappers.

Explanation:

- `design-philosophy-v04.qmd`: distill the architecture review, hybrid backend
  decision, and mock-data versus synthetic-data boundary.

Reference:

- Keep roxygen pages and `_pkgdown.yml` synchronized with exported functions.
- Keep `NEWS.md` as the release-note source of truth.

## Review checklist

- Does every vignette render locally?
- Does every code chunk either run or clearly justify `eval: false`?
- Does each vignette commit to one Divio purpose?
- Do examples use the public API exactly as users should use it?
- Are error messages and diagnostics understandable in rendered output?
