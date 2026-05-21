# Create a MockData specification

`mock_spec()` creates the normalized v0.4 specification object used by
the new architecture. Direct APIs and recodeflow adapters should both
normalize into this shape before validation and generation.

## Usage

``` r
mock_spec(
  ...,
  spec_version = .mock_spec_version,
  provenance = list(adapter = "direct", source = "direct"),
  model_hint = "auto",
  validate = TRUE
)
```

## Arguments

- ...:

  `mock_spec_variable` objects, or a single list of them. `NULL` creates
  an empty specification.

- spec_version:

  Character version of the specification shape.

- provenance:

  List or character describing where the spec came from.

- model_hint:

  Character backend hint. One of the supported MockData model hints.

- validate:

  Logical. If `TRUE`, validate the constructed specification before
  returning it.

## Value

S3 object of class `mock_spec`.

## Details

The v0.4 API is layered. The `mock_*()` helpers are the simple direct
API for one-variable specifications. The `mock_spec_*()` constructors
create variable specifications that can be composed with `mock_spec()`.
Metadata adapters, such as
[`mock_spec_from_recodeflow()`](https://big-life-lab.github.io/MockData/reference/mock_spec_from_recodeflow.md),
translate external metadata into the same internal shape. Generation
backends consume `mock_spec` objects rather than re-reading user-facing
metadata.

## See also

[`mock_continuous()`](https://big-life-lab.github.io/MockData/reference/mock_continuous.md),
[`mock_categorical()`](https://big-life-lab.github.io/MockData/reference/mock_categorical.md),
[`mock_date()`](https://big-life-lab.github.io/MockData/reference/mock_date.md),
[`mock_spec_from_recodeflow()`](https://big-life-lab.github.io/MockData/reference/mock_spec_from_recodeflow.md),
[`generate_mock_data_native()`](https://big-life-lab.github.io/MockData/reference/generate_mock_data_native.md),
[`postprocess_mock_data()`](https://big-life-lab.github.io/MockData/reference/postprocess_mock_data.md)

Other mock specification APIs:
[`mock_spec_categorical()`](https://big-life-lab.github.io/MockData/reference/mock_spec_categorical.md),
[`mock_spec_continuous()`](https://big-life-lab.github.io/MockData/reference/mock_spec_continuous.md),
[`mock_spec_date()`](https://big-life-lab.github.io/MockData/reference/mock_spec_date.md),
[`mock_spec_from_recodeflow()`](https://big-life-lab.github.io/MockData/reference/mock_spec_from_recodeflow.md)

## Examples

``` r
spec <- mock_spec(
  mock_spec_continuous("age", range = c(18, 85), rtype = "integer"),
  mock_spec_categorical(
    "smoking",
    levels = c("never", "former", "current"),
    proportions = c(0.5, 0.3, 0.2)
  )
)
validate_mock_spec(spec)
#> MockData mock_spec validation result: valid
```
