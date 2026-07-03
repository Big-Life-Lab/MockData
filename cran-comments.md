# CRAN Comments

## Local check

Checked with:

- R 4.4.2
- macOS 26.5, aarch64-apple-darwin20
- `R CMD check --as-cran --no-manual`

Result:

- 0 errors
- 0 warnings
- 3 notes

Notes:

- New submission.
- `simstudy` was not installed in the local check environment, so the local
  check used `_R_CHECK_FORCE_SUGGESTS_=false`. `simstudy` is listed in
  `Suggests` and is used only for the optional backend.
- The local check reported `unable to verify current time`.

## Release notes

This is the first CRAN submission of MockData. The package generates mock
testing data from metadata specifications supplied as data frames or CSV files.
It supports categorical, continuous, date, garbage-data, and survival-style
variables for testing data pipelines and documentation examples.

MockData generates mock data for software testing and workflow validation. It
does not generate privacy-preserving synthetic data for inference or data
release.
