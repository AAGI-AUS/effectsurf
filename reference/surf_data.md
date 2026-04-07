# Extract data from an effectsurf object

Returns the underlying prediction grid as a `data.table`.

## Usage

``` r
surf_data(object, as_matrix = FALSE)
```

## Arguments

- object:

  An `effectsurf` object.

- as_matrix:

  Logical. If `TRUE`, returns a list of matrices suitable for direct use
  with
  [`plotly::add_surface()`](https://rdrr.io/pkg/plotly/man/add_trace.html).
  Default `FALSE`.

## Value

A `data.table` (default) or a named list of matrices.

## Examples

``` r
# After creating a surface
# es <- surf_prediction(model, x = "x1", y = "x2")
# surf_data(es)               # data.table
# surf_data(es, as_matrix = TRUE)  # list of z-matrices
```
