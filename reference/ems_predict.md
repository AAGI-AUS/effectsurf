# Generate predictions on a grid

Computes model predictions (with optional confidence intervals) on a
prediction grid. Uses
[`marginaleffects::predictions()`](https://rdrr.io/pkg/marginaleffects/man/predictions.html)
as the primary backend, with a fallback to
[`stats::predict()`](https://rdrr.io/r/stats/predict.html).

## Usage

``` r
ems_predict(
  model,
  grid,
  ci = TRUE,
  level = 0.95,
  vcov = NULL,
  predict_fun = NULL,
  method = c("marginaleffects", "emmeans", "gratia", "predict"),
  ...
)
```

## Arguments

- model:

  A fitted model object.

- grid:

  A `data.frame` or `data.table` prediction grid, typically produced by
  [`ems_grid()`](https://aagi-aus.github.io/effectsurf/reference/ems_grid.md).

- ci:

  Logical. Whether to compute confidence intervals. Default `TRUE`.

- level:

  Numeric. Confidence level for intervals. Default `0.95`.

- vcov:

  Variance-covariance specification passed to
  [`marginaleffects::predictions()`](https://rdrr.io/pkg/marginaleffects/man/predictions.html).
  Use `FALSE` for fast predictions without standard errors.

- predict_fun:

  A custom prediction function with signature `function(model, newdata)`
  returning a numeric vector. If supplied, bypasses both
  `marginaleffects` and
  [`predict()`](https://rdrr.io/r/stats/predict.html).

- method:

  Character. One of `"marginaleffects"` (default), `"gratia"`, or
  `"predict"`.

- ...:

  Additional arguments passed to the prediction backend.

## Value

A `data.table` with the grid columns plus `estimate`, and optionally
`std.error`, `conf.low`, `conf.high`.
