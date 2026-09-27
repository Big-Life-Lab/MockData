# CRAN Comments

## Local check

Checked with:

- R 4.4.2
- macOS 27.0, aarch64-apple-darwin20
- `R CMD check --as-cran --no-manual` on the built tarball
- `_R_CHECK_FORCE_SUGGESTS_=false`, because the local check library does not
  include the suggested package `simstudy`

Result:

- 0 errors
- 0 warnings
- 3 notes

Notes:

- New submission.
- `simstudy` (suggested) not available for checking locally. It is installed
  in continuous integration, where its tests run.
- The local check reported `unable to verify current time`.

## Continuous integration

The `R-CMD-check` workflow runs the same check on Ubuntu 24.04 with
R 4.6.1, with all suggested packages installed, for every push to
`main`/`dev` and every pull request into them. Latest result: `Status: OK`
(0 errors, 0 warnings, 0 notes).

## Release notes

This is the first CRAN submission of MockData. The package generates mock
testing data from metadata specifications supplied as data frames or CSV files.
It supports categorical, continuous, date, garbage-data, formula-derived, and
survival-style variables for testing data pipelines and documentation examples.

MockData generates mock data for software testing and workflow validation. It
does not generate privacy-preserving synthetic data for inference or data
release.
