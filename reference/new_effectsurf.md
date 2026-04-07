# Create an effectsurf object

Constructor for the `effectsurf` S3 class. Not typically called directly
by users; instead, use
[`surf_prediction()`](https://aagi-aus.github.io/effectsurf/reference/surf_prediction.md),
[`surf_comparison()`](https://aagi-aus.github.io/effectsurf/reference/surf_comparison.md),
[`surf_slopes()`](https://aagi-aus.github.io/effectsurf/reference/surf_slopes.md),
or
[`surf_cate()`](https://aagi-aus.github.io/effectsurf/reference/surf_cate.md).

## Usage

``` r
new_effectsurf(
  data,
  x_var,
  y_var,
  z_var,
  strata_var = NULL,
  type = c("prediction", "comparison", "slopes", "cate"),
  ci = FALSE,
  model_info = list(),
  labels = list(),
  transform = NULL,
  meta = list()
)
```

## Arguments

- data:

  A `data.table` containing the prediction grid with columns for the x
  variable, y variable, `estimate`, and optionally `std.error`,
  `conf.low`, `conf.high`, and the stratification variable.

- x_var:

  Character. Name of the x-axis variable.

- y_var:

  Character. Name of the y-axis variable.

- z_var:

  Character. Name of the response (z-axis) variable.

- strata_var:

  Character or `NULL`. Name of the categorical stratification variable.

- type:

  Character. One of `"prediction"`, `"comparison"`, `"slopes"`,
  `"cate"`.

- ci:

  Logical. Whether confidence intervals are included.

- model_info:

  A named list with model metadata: `class`, `formula`, `n_obs`, `call`.

- labels:

  A named list with display labels: `x`, `y`, `z`, `title`.

- transform:

  Character or function or `NULL`. Back-transformation to apply for
  display (e.g., `"expit"` for logit models).

- meta:

  A named list with additional metadata.

## Value

An object of class `effectsurf`.

## Examples

``` r
# Typically created via surf_prediction(), not directly
es <- new_effectsurf(
  data = data.table::data.table(
    x = rep(1:3, each = 3), y = rep(1:3, 3),
    estimate = rnorm(9)
  ),
  x_var = "x", y_var = "y", z_var = "response",
  type = "prediction"
)
print(es)
#> ℹ <effectsurf> — Prediction Surface
#> • X: x | Y: y | Z: response
#> • Grid: 9 points (9 per stratum)
#> • CI: FALSE | Transform: FALSE
#> ℹ Use `plot()` to visualise, `surf_data()` to extract data.
```
