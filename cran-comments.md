# CRAN Comments

## Local check

Checked with:

- R 4.4.2
- macOS 26.0, aarch64-apple-darwin20
- `R CMD check --as-cran --no-manual` on the built tarball
- Suggests installed, including `simstudy` 0.9.2, so the optional backend's
  tests ran rather than skipped

Result:

- 0 errors
- 0 warnings
- 2 notes

Notes:

- New submission.
- The local check reported `unable to verify current time`.

Continuous integration runs the same check on Ubuntu (`R-CMD-check`
workflow) for every push to `main`/`dev` and every pull request into them.

## Release notes

This is the first CRAN submission of MockData. The package generates mock
testing data from metadata specifications supplied as data frames or CSV files.
It supports categorical, continuous, date, garbage-data, formula-derived, and
survival-style variables for testing data pipelines and documentation examples.

MockData generates mock data for software testing and workflow validation. It
does not generate privacy-preserving synthetic data for inference or data
release.
