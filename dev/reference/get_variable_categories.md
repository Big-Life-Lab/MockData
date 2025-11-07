# Extract categories from variable details

Extracts categorical values from variable_details recStart/recEnd
columns. Handles range notation, special codes, and missing code
patterns.

## Usage

``` r
get_variable_categories(var_details, include_na = FALSE)
```

## Arguments

- var_details:

  Data frame. Filtered variable_details rows

- include_na:

  Logical. Include NA/missing codes (default FALSE)

## Value

Character vector of category values

## Details

Handles recodeflow notation:

- Simple categories: "1", "2", "3"

- Integer ranges: `"[7,9]"` → c("7", "8", "9")

- Continuous ranges: "\[18.5,25)" (kept as single value)

- Special codes: "copy", "else" (EXCLUDED from v0.1 generation)

- Missing codes: Identified by "NA" in recEnd

Note: "else" is excluded because it represents a harmonization rule, not
a predictable raw data value.
