# Scalar Variable Generation Helpers

Helper functions for scalar variable generation (single variables at a
time). Used by create_cat_var(), create_con_var(), create_date_var()
when called with individual variable parameters (var_raw, cycle, etc.)
rather than configuration data frames.

## Usage

``` r
get_variable_details_for_raw(
  var_raw,
  cycle,
  variable_details,
  variables = NULL
)
```

## Arguments

- var_raw:

  Character. Raw variable name (e.g., "alc_11", "HGT_CM")

- cycle:

  Character. Cycle identifier (e.g., "cycle1", "cchs2001")

- variable_details:

  Data frame. Full variable_details metadata

- variables:

  Data frame. Optional variables metadata (not used currently)

## Value

Data frame subset of variable_details for this variable + cycle

## Details

These helpers work with recodeflow-style metadata (variables.csv +
variable_details.csv from cchsflow/chmsflow). Get variable details for
raw variable and cycle

Filters variable_details to rows matching a specific raw variable name
and cycle. Handles multiple naming patterns from recodeflow packages.

Tries three matching strategies in order:

1.  Database-prefixed format: `"cycle::var_raw"`

2.  Bracket format: `"[var_raw]"` with databaseStart filtering

3.  Plain format: exact match on variableStart with cycle filtering
