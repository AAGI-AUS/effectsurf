# Convert an effectsurf object to a tidy data.frame

Returns a clean `data.frame` with only the essential columns: the x
variable, y variable, `estimate`, and optionally `std.error`,
`conf.low`, `conf.high`, and the stratification variable. All metadata
and class information are stripped.

## Usage

``` r
surf_tidy(x, transformed = FALSE, ...)
```

## Arguments

- x:

  An `effectsurf` object.

- transformed:

  Logical. If `TRUE` and a back-transformation is stored, apply it to
  the estimates. Default `FALSE`.

- ...:

  Ignored.

## Value

A plain `data.frame`.
