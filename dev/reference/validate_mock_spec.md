# Validate a MockData specification

Validate a MockData specification

## Usage

``` r
validate_mock_spec(spec, n = NULL, strict = TRUE)
```

## Arguments

- spec:

  A `mock_spec` object.

- n:

  Optional number of rows expected for generation. If supplied, must be
  a non-negative whole number.

- strict:

  Logical. If `TRUE`, invalid specs throw an error. If `FALSE`, a
  validation result object is returned.

## Value

A `mock_spec_validation_result` object when valid or `strict = FALSE`.

## Examples

``` r
spec <- mock_spec(mock_spec_continuous("age", range = c(18, 85)))
validate_mock_spec(spec)
#> MockData mock_spec validation result: valid

result <- validate_mock_spec(list(), strict = FALSE)
result$valid
#> [1] FALSE
```
