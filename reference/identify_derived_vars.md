# Identify derived variables using recodeflow patterns

Identifies derived variables using recodeflow metadata patterns in
variable_details. Derived variables are calculated from raw variables
(e.g., BMI from height/weight) and should NOT be generated as mock data.

This function uses the recodeflow approach: derived variables are
identified by metadata patterns in variable_details, NOT by role column
flags.

## Usage

``` r
identify_derived_vars(variables, variable_details)
```

## Arguments

- variables:

  data.frame. Variable-level metadata with column: variable

- variable_details:

  data.frame. Required. Detail-level metadata with columns: variable,
  recStart, recEnd. Contains DerivedVar:: and Func:: patterns that
  identify derived variables.

## Value

Character vector of derived variable names (may be empty if none found)

## Details

**Detection methods** (recodeflow patterns only):

1.  **DerivedVar:: pattern**: Variables with `DerivedVar::` in recStart
    column

    - Example: `recStart = "DerivedVar::[HWTGHTM, HWTGWTK]"`

    - Indicates variable is derived from listed raw variables

2.  **Func:: pattern**: Variables with `Func::` in recEnd column

    - Example: `recEnd = "Func::bmi_fun"`

    - Indicates transformation function applied to derive variable

**Why variable_details is required:**

The recodeflow approach stores derivation logic in variable_details, not
in variables. The role column (if present) is NOT used for derived
variable detection. This ensures:

- Derivation logic is explicit (what variables, what function)

- Metadata is self-documenting

- Compatible with cchsflow and other recodeflow tools

**Note:** This function does NOT check role = "derived" even if present.
Derived status is determined solely by DerivedVar:: and Func:: patterns.

## See also

Other helpers:
[`get_raw_var_dependencies()`](https://big-life-lab.github.io/MockData/reference/get_raw_var_dependencies.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# BMI derived from height and weight
variables <- data.frame(
  variable = c("height", "weight", "BMI_derived"),
  variableType = c("Continuous", "Continuous", "Continuous"),
  role = c("enabled", "enabled", "enabled"),  # NO "derived" flag needed
  stringsAsFactors = FALSE
)

variable_details <- data.frame(
  variable = c("height", "weight", "BMI_derived"),
  recStart = c("[1.4,2.1]", "[45,150]", "DerivedVar::[height, weight]"),
  recEnd = c("copy", "copy", "Func::bmi_fun"),
  stringsAsFactors = FALSE
)

identify_derived_vars(variables, variable_details)
# Returns: "BMI_derived"

# ADL derived from 5 ADL items
variable_details_adl <- data.frame(
  variable = c("ADL_01", "ADL_02", "ADL_03", "ADL_04", "ADL_05", "ADL_der"),
  recStart = c(rep("1", 5), "DerivedVar::[ADL_01, ADL_02, ADL_03, ADL_04, ADL_05]"),
  recEnd = c(rep("1", 5), "Func::adl_fun"),
  stringsAsFactors = FALSE
)

identify_derived_vars(variables, variable_details_adl)
# Returns: "ADL_der"
} # }
```
