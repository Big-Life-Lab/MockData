# Check whether an object is a MockData specification

Check whether an object is a MockData specification

## Usage

``` r
is_mock_spec(x)
```

## Arguments

- x:

  Object to check.

## Value

Logical scalar.

## Examples

``` r
spec <- mock_spec()
is_mock_spec(spec)
#> [1] TRUE
is_mock_spec(list())
#> [1] FALSE
```
