# Create a 3D conditional average treatment effect (CATE) surface

Generates a surface of treatment effect heterogeneity from causal
inference models (e.g., causal forests from `grf`, or custom CATE
estimators). Requires a custom `predict_fun` that returns treatment
effect estimates for each observation.

## Usage

``` r
surf_cate(
  model,
  x,
  y,
  x_range = NULL,
  y_range = NULL,
  x_length = 50L,
  y_length = 50L,
  predict_fun = NULL,
  ci = FALSE,
  training_data = NULL,
  at = NULL,
  smooth = NULL,
  transform = NULL,
  labels = list(),
  ...
)
```

## Arguments

- model:

  A fitted causal model (e.g., from `grf::causal_forest()`).

- x:

  Character. Name of the x-axis moderator variable.

- y:

  Character. Name of the y-axis moderator variable.

- x_range, y_range:

  Numeric vectors of length 2.

- x_length, y_length:

  Integer. Grid resolution.

- predict_fun:

  A function with signature `function(model, newdata)` returning a
  numeric vector of CATE estimates. For `grf::causal_forest`, this would
  be `function(m, d) predict(m, d)$predictions`.

- ci:

  Logical. Whether to include confidence intervals. Requires
  `predict_fun` to return a data.frame with `estimate`, `conf.low`,
  `conf.high` columns.

- training_data:

  A `data.frame` of the original training data. Needed for determining
  non-focal variable reference values when the model object does not
  store training data.

- at:

  Named list of fixed variable values.

- smooth:

  Post-prediction surface smoothing via
  [`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html). See
  [`surf_prediction()`](https://aagi-aus.github.io/effectsurf/reference/surf_prediction.md)
  for full documentation. `NULL` (default) = no smoothing; `TRUE` =
  auto-smooth; or a named list with `k`, `bs`, `smooth_ci`.

- transform:

  Back-transformation specification.

- labels:

  Custom axis labels.

- ...:

  Additional arguments passed to `predict_fun`.

## Value

An
[effectsurf](https://aagi-aus.github.io/effectsurf/reference/new_effectsurf.md)
object of type `"cate"`.

## Details

For standard regression models, use
[`surf_comparison()`](https://aagi-aus.github.io/effectsurf/reference/surf_comparison.md)
instead — it provides CATE-like surfaces via
[`marginaleffects::comparisons()`](https://rdrr.io/pkg/marginaleffects/man/comparisons.html).

## See also

[`surf_comparison()`](https://aagi-aus.github.io/effectsurf/reference/surf_comparison.md),
[`surf_prediction()`](https://aagi-aus.github.io/effectsurf/reference/surf_prediction.md)

## Examples

``` r
# \donttest{
# Example with a simple model (grf requires separate installation)
# library(grf)
# cf <- causal_forest(X, Y, W)
# es <- surf_cate(cf, x = "age", y = "income",
#                 predict_fun = function(m, d) predict(m, d)$predictions,
#                 training_data = X)
# plot(es)
# }
```
