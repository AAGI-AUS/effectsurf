# Create a prediction grid for surface estimation

Generates a cross-product grid of two focal continuous variables, with
non-focal variables held at reference values (mean for numeric, mode for
factors). Wraps
[`marginaleffects::datagrid()`](https://rdrr.io/pkg/marginaleffects/man/datagrid.html)
when available, with a lightweight fallback for unsupported models.

## Usage

``` r
ems_grid(
  model,
  x,
  y,
  by = NULL,
  x_range = NULL,
  y_range = NULL,
  x_length = 50L,
  y_length = 50L,
  grid_type = "mean_or_mode",
  at = NULL,
  levels_needed = NULL,
  method = c("marginaleffects", "emmeans", "gratia", "manual"),
  ...
)
```

## Arguments

- model:

  A fitted model object.

- x:

  Character. Name of the x-axis variable.

- y:

  Character. Name of the y-axis variable.

- by:

  Character or `NULL`. Name of a categorical variable for
  stratification.

- x_range:

  Numeric vector of length 2. Range for x variable. If `NULL`,
  auto-detected from the model's training data.

- y_range:

  Numeric vector of length 2. Range for y variable. If `NULL`,
  auto-detected.

- x_length:

  Integer. Number of grid points along x. Default 50.

- y_length:

  Integer. Number of grid points along y. Default 50.

- grid_type:

  Character. One of `"mean_or_mode"` (default), `"counterfactual"`,
  `"balanced"`. Passed to
  [`marginaleffects::datagrid()`](https://rdrr.io/pkg/marginaleffects/man/datagrid.html).

- at:

  Named list. Additional variables to hold at specific values (e.g.,
  `at = list(state = "WA")`).

- levels_needed:

  Character vector or `NULL`. If `by` is specified, subset to only these
  levels.

- method:

  Character. One of `"marginaleffects"` (default), `"gratia"`, or
  `"manual"`. Controls the grid creation backend.

- ...:

  Additional arguments passed to the backend.

## Value

A `data.table` representing the prediction grid.

## Examples

``` r
if (requireNamespace("mgcv", quietly = TRUE)) {
  model <- mgcv::gam(mpg ~ s(wt) + s(hp) + cyl, data = mtcars)
  grid <- ems_grid(model, x = "wt", y = "hp", x_length = 20, y_length = 20)
  head(grid)
}
#>    rowid   cyl      mpg    wt        hp
#>    <int> <int>    <num> <num>     <num>
#> 1:     1     6 20.09062 1.513  52.00000
#> 2:     2     6 20.09062 1.513  66.89474
#> 3:     3     6 20.09062 1.513  81.78947
#> 4:     4     6 20.09062 1.513  96.68421
#> 5:     5     6 20.09062 1.513 111.57895
#> 6:     6     6 20.09062 1.513 126.47368
```
