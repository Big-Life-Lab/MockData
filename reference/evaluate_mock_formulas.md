# Evaluate formula-derived variables over generated data

Computes each `type = "formula"` variable in `spec` by evaluating its
expression over the columns of `data`, in dependency order. Evaluation
runs in a restricted environment exposing only the data columns and a
fixed allow-list of base functions — formulas cannot reach the caller's
environment. Any randomness would draw from the isolated `formula`
sub-stream (see the v0.5 seed contract), though the Phase A allow-list
is RNG-free, so evaluation is deterministic given `data`.

## Usage

``` r
evaluate_mock_formulas(data, spec, seed = NULL)
```

## Arguments

- data:

  Data frame of generated baseline values (from
  [`generate_mock_data_native()`](https://big-life-lab.github.io/MockData/reference/generate_mock_data_native.md)
  or
  [`generate_mock_data_simstudy()`](https://big-life-lab.github.io/MockData/reference/generate_mock_data_simstudy.md)).

- spec:

  A `mock_spec`. Non-formula variables must already be columns of
  `data`. Strict-validated at entry (like
  [`postprocess_mock_data()`](https://big-life-lab.github.io/MockData/reference/postprocess_mock_data.md)),
  so an unparseable formula, an unknown referent, a disallowed symbol,
  or a dependency cycle raises here rather than silently skipping the
  affected variable.

- seed:

  Optional whole-number seed; reserved for future formulas with random
  components. The caller's RNG state and kind are restored on exit.

## Value

`data` with one appended column per formula variable. Returns `data`
unchanged if the spec has no formula variables.

## See also

[`mock_formula()`](https://big-life-lab.github.io/MockData/reference/mock_formula.md),
[`postprocess_mock_data()`](https://big-life-lab.github.io/MockData/reference/postprocess_mock_data.md)
