# Add garbage specifications to variables data frame

Helper function to add garbage data specifications to a variables data
frame. This provides a convenient way to specify invalid/garbage values
for quality assurance testing. Works consistently across all variable
types (categorical, continuous, date).

## Usage

``` r
add_garbage(
  variables,
  var,
  garbage_low_prop = NULL,
  garbage_low_range = NULL,
  garbage_high_prop = NULL,
  garbage_high_range = NULL
)
```

## Arguments

- variables:

  Data frame with variable metadata (typically read from variables.csv)

- var:

  Character. Variable name to add garbage specifications to. Must exist
  in `variables$variable`.

- garbage_low_prop:

  Numeric. Proportion of observations to generate as low-range garbage
  (0-1). If NULL, no low-range garbage is added.

- garbage_low_range:

  Character. Interval notation specifying the range for low-range
  garbage values (e.g., `[-2, 0]` for categorical, `[0, 1.4)` for
  continuous, `[1900-01-01, 1950-12-31]` for dates). If NULL, no
  low-range garbage is added.

- garbage_high_prop:

  Numeric. Proportion of observations to generate as high-range garbage
  (0-1). If NULL, no high-range garbage is added.

- garbage_high_range:

  Character. Interval notation specifying the range for high-range
  garbage values (e.g., `[10, 15]` for categorical, `[60, 150]` for
  continuous, `[2025-01-01, 2099-12-31]` for dates). If NULL, no
  high-range garbage is added.

## Value

Modified variables data frame with garbage specifications added. If the
garbage columns don't exist, they are created and initialized with NA
for all other variables.

## Details

### Unified garbage API

All variable types use the same garbage specification pattern:

- `garbage_low_prop` + `garbage_low_range` for values below valid range

- `garbage_high_prop` + `garbage_high_range` for values above valid
  range

### Variable type examples

**Categorical (ordinal treatment):**

    # Valid codes: 1, 2, 3, 7
    # Generate codes -2, -1, 0 below valid range
    vars <- add_garbage(vars, "smoking",
      garbage_low_prop = 0.02, garbage_low_range = "[-2, 0]")

**Continuous:**

    # Valid range: [18, 100]
    # Generate extreme ages above valid range
    vars <- add_garbage(vars, "age",
      garbage_high_prop = 0.03, garbage_high_range = "[150, 200]")

**Date:**

    # Valid range: [2000-01-01, 2020-12-31]
    # Generate future dates for QA testing
    vars <- add_garbage(vars, "death_date",
      garbage_high_prop = 0.03, garbage_high_range = "[2025-01-01, 2099-12-31]")

### Pipe-friendly usage

This function returns the modified variables data frame, making it
pipe-friendly:

    vars_with_garbage <- variables %>%
      add_garbage("age", garbage_high_prop = 0.03, garbage_high_range = "[150, 200]") %>%
      add_garbage("smoking", garbage_low_prop = 0.02, garbage_low_range = "[-2, 0]") %>%
      add_garbage("death_date", garbage_high_prop = 0.03,
        garbage_high_range = "[2025-01-01, 2099-12-31]")

## See also

- [`create_cat_var()`](https://big-life-lab.github.io/MockData/reference/create_cat_var.md)
  for categorical variable generation

- [`create_con_var()`](https://big-life-lab.github.io/MockData/reference/create_con_var.md)
  for continuous variable generation

- [`create_date_var()`](https://big-life-lab.github.io/MockData/reference/create_date_var.md)
  for date variable generation

- [`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md)
  for batch generation of all variables

## Examples

``` r
variables <- data.frame(
  variable = c("age", "smoking"),
  variableType = c("Continuous", "Categorical"),
  stringsAsFactors = FALSE
)

# Add high-range garbage to age and low-range garbage to smoking
vars_with_garbage <- variables |>
  add_garbage("age",
    garbage_high_prop = 0.03, garbage_high_range = "[150, 200]"
  ) |>
  add_garbage("smoking",
    garbage_low_prop = 0.02, garbage_low_range = "[-2, 0]"
  )
vars_with_garbage
#>   variable variableType garbage_high_prop garbage_high_range garbage_low_prop
#> 1      age   Continuous              0.03         [150, 200]               NA
#> 2  smoking  Categorical                NA               <NA>             0.02
#>   garbage_low_range
#> 1              <NA>
#> 2           [-2, 0]

# Pass the result as the `variables` argument of create_mock_data() —
# see ?create_mock_data.
```
