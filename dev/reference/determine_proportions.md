# Determine proportions for categorical variable generation

Helper function to determine proportions for categorical variables based
on priority: explicit parameter \> metadata column \> uniform
distribution

## Usage

``` r
determine_proportions(categories, proportions_param, var_details)
```

## Arguments

- categories:

  character vector. Category codes/values

- proportions_param:

  Proportions specification. Can be:

  - NULL: Use uniform distribution

  - Named list: Maps category codes to proportions

  - Numeric vector: Proportions in same order as categories

- var_details:

  data.frame. Variable details metadata (may contain proportion column)

## Value

Numeric vector of proportions (normalized to sum to 1), same length as
categories

## Details

Priority order:

1.  proportions_param if provided (explicit user specification)

2.  proportion column in var_details if present

3.  Uniform distribution (fallback)
