# Parse range notation from variable_details

Parses recodeflow-standard range notation strings from
variable_details.csv (recodes column) into structured data for mock data
generation. Supports integer ranges, continuous ranges, special codes,
and function calls.

## Usage

``` r
parse_range_notation(range_string, range_type = "auto", expand_integers = TRUE)
```

## Arguments

- range_string:

  Character string containing range notation

- range_type:

  Character. One of:

  - "auto" (default): Auto-detect based on bracket notation and decimal
    values

  - "integer": Force integer range interpretation (generates sequence)

  - "continuous": Force continuous range interpretation

- expand_integers:

  Logical. If TRUE and range_type is "integer", returns all integers in
  the range as a vector

## Value

For continuous ranges: List with min, max, min_inclusive, max_inclusive
For integer ranges: List with min, max, values (if expand_integers=TRUE)
Returns NULL if parsing fails

## Details

**Recodeflow-Standard Range Notation:**

These patterns work across all recodeflow projects (CHMS, CCHS, etc.):

- Integer ranges: `[7,9]` → integers 7,8,9

- Continuous ranges: `[18.5,25)` → 18.5 ≤ x \< 25

- Continuous ranges: `[18.5,25]` → 18.5 ≤ x ≤ 25

- Infinity ranges: `[30,inf)` → x ≥ 30

- Special codes: `NA::a`, `NA::b`, `copy`, `else` (passed through
  unchanged)

- Function calls: `Func::function_name` (passed through unchanged)

**Mathematical Bracket Notation:**

- `[a,b]` - Closed interval: a ≤ x ≤ b

- `[a,b)` - Half-open interval: a ≤ x \< b

- `(a,b]` - Half-open interval: a \< x ≤ b

- `(a,b)` - Open interval: a \< x \< b

**Auto-Detection Logic:**

- Contains decimal values → continuous range

- Uses mathematical bracket notation `[a,b)` → continuous range

- Simple `[integer,integer]` → integer range (generates sequence)

- Contains "inf" → continuous range

\[a,b)\` - Half-open interval: a ≤ x \< b

- \`(a,b\]:
  R:a,b)%60%20-%20Half-open%20interval:%20a%20%E2%89%A4%20x%20%3C%20b%0A-%20%60(a,b
  \[integer,integer\]: R:integer,integer

## Note

Adapted from cchsflow v4.0.0 (2025-07-27) - universal across recodeflow
projects

## See also

Other parsing-utilities:
[`parse_variable_start()`](https://big-life-lab.github.io/MockData/reference/parse_variable_start.md)

## Examples

``` r
# Integer ranges
parse_range_notation("[7,9]")
#> $type
#> [1] "integer"
#> 
#> $min
#> [1] 7
#> 
#> $max
#> [1] 9
#> 
#> $values
#> [1] 7 8 9
#> 
#> $min_inclusive
#> [1] TRUE
#> 
#> $max_inclusive
#> [1] TRUE
#> 
# Returns: list(min=7, max=9, values=c(7,8,9), type="integer")

# Continuous ranges
parse_range_notation("[18.5,25)")
#> $type
#> [1] "continuous"
#> 
#> $min
#> [1] 18.5
#> 
#> $max
#> [1] 25
#> 
#> $min_inclusive
#> [1] TRUE
#> 
#> $max_inclusive
#> [1] FALSE
#> 
# Returns: list(min=18.5, max=25, min_inclusive=TRUE, max_inclusive=FALSE, type="continuous")

parse_range_notation("[30,inf)")
#> $type
#> [1] "continuous"
#> 
#> $min
#> [1] 30
#> 
#> $max
#> [1] Inf
#> 
#> $min_inclusive
#> [1] TRUE
#> 
#> $max_inclusive
#> [1] FALSE
#> 
# Returns: list(min=30, max=Inf, min_inclusive=TRUE, max_inclusive=FALSE, type="continuous")

# Special cases
parse_range_notation("NA::a")   # Returns: list(type="special", value="NA::a")
#> $type
#> [1] "special"
#> 
#> $value
#> [1] "NA::a"
#> 
parse_range_notation("copy")    # Returns: list(type="special", value="copy")
#> $type
#> [1] "special"
#> 
#> $value
#> [1] "copy"
#> 
parse_range_notation("else")    # Returns: list(type="special", value="else")
#> $type
#> [1] "special"
#> 
#> $value
#> [1] "else"
#> 
```
