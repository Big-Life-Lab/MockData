# Parse variableStart field to extract raw variable name

This function parses the `variableStart` field from variable_details
metadata and extracts the raw variable name for a specific
database/cycle. It supports recodeflow-standard formats:
database-prefixed (`"database::varname"`), bracket (`"[varname]"`),
mixed, and plain formats.

## Usage

``` r
parse_variable_start(variable_start, cycle)
```

## Arguments

- variable_start:

  Character string from variableStart field. Can contain multiple
  database specifications separated by commas (e.g., "cycle1::age,
  cycle2::AGE").

- cycle:

  Character string specifying the database/cycle to extract (e.g.,
  "cycle1", "cchs2001").

## Value

Character string with the raw variable name, or NULL if not found.

## Details

The function implements recodeflow-standard parsing strategies:

1.  Database-prefixed format: `"database::varname"` - for
    database-specific names

2.  Bracket format (whole string): `"[varname]"` - for database-agnostic
    names

3.  Bracket format (segment): `"database1::var1, [var2]"` - `[var2]` is
    DEFAULT for other databases

4.  Plain format: `"varname"` - uses value as-is

**Important**: `[variable]` represents the DEFAULT for all databases not
explicitly referenced with database:: notation. This reduces repetition
when only one or a few databases use different variable names.

For DerivedVar format, returns NULL (requires custom derivation logic).

## See also

Other parsing-utilities:
[`parse_range_notation()`](https://big-life-lab.github.io/MockData/reference/parse_range_notation.md)

## Examples

``` r
# Database-prefixed format
parse_variable_start("cycle1::height, cycle2::HEIGHT", "cycle1")
#> [1] "height"
# Returns: "height"

# Bracket format (database-agnostic)
parse_variable_start("[gen_015]", "cycle1")
#> [1] "gen_015"
# Returns: "gen_015"

# Mixed format - [variable] is DEFAULT for databases not explicitly listed
parse_variable_start("cycle1::amsdmva1, [ammdmva1]", "cycle2")
#> [1] "ammdmva1"
# Returns: "ammdmva1" (uses default for cycle2)

# Plain format
parse_variable_start("bmi", "cycle1")
#> [1] "bmi"
# Returns: "bmi"

# No match for specified database
parse_variable_start("cycle2::age", "cycle1")
#> NULL
# Returns: NULL
```
