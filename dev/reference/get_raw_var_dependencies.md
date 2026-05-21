# Extract raw variable dependencies from derived variable metadata

For a given derived variable, extract the list of raw variables it
depends on by parsing the
DerivedVar::[...](https://rdrr.io/r/base/dots.html) pattern in
variable_details.

## Usage

``` r
get_raw_var_dependencies(derived_var, variable_details)
```

## Arguments

- derived_var:

  character. Name of the derived variable

- variable_details:

  data.frame. Detail-level metadata with columns: variable, recStart

## Value

Character vector of raw variable names that the derived variable depends
on. Returns character(0) if no dependencies found.

## Details

Parses patterns like:

- `DerivedVar::[HWTGHTM, HWTGWTK]` → c("HWTGHTM", "HWTGWTK")

- `DerivedVar::[ADL_01, ADL_02, ADL_03, ADL_04, ADL_05]` → c("ADL_01",
  ...)

## See also

Other helpers:
[`identify_derived_vars()`](https://big-life-lab.github.io/MockData/reference/identify_derived_vars.md)

## Examples

``` r
if (FALSE) { # \dontrun{
variable_details <- data.frame(
  variable = c("HWTGBMI_der"),
  recStart = c("DerivedVar::[HWTGHTM, HWTGWTK]"),
  stringsAsFactors = FALSE
)

get_raw_var_dependencies("HWTGBMI_der", variable_details)
# Returns: c("HWTGHTM", "HWTGWTK")
} # }
```
