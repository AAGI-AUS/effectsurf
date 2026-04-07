# effectsurf

The goal of {effectsurf} is to extend traditional 2D estimated marginal
means (EMMs) into interactive 3D **Estimated Marginal Surfaces** (EMS).
It provides model-agnostic visualisation of predictions, conditional
effect sizes, and conditional average treatment effects (CATE) from
fitted statistical models.

Surfaces are rendered as interactive [plotly](https://plotly.com/r/) 3D
charts with:

- **Categorical stratification** – overlaid surfaces by group
- **Confidence envelopes** – upper/lower CI surfaces
- **2D profile projections** – slices through the 3D surface
- **Derivative surfaces** – sensitivity, curvature, and interaction maps
- **Post-prediction smoothing** – smooth jagged surfaces from non-smooth
  models (e.g., random forests) via
  [`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html) surrogates

Supports 100+ model classes via
[marginaleffects](https://marginaleffects.com/), with optional
[emmeans](https://cran.r-project.org/package=emmeans) and
[gratia](https://gavinsimpson.github.io/gratia/) backends.

## Installation

You can install the development version of {effectsurf} from
[GitHub](https://github.com/AAGI-AUS/effectsurf) with:

``` r
if (!require("pak")) {
  install.packages("pak")
}

pak::pak("AAGI-AUS/effectsurf")
```

## Getting started

{effectsurf} works with any fitted model that supports
[`predict()`](https://rdrr.io/r/stats/predict.html). Here is a minimal
example using a GAM fitted with {mgcv}:

### Fit a model

``` r
library(effectsurf)

model <- mgcv::gam(
  mpg ~ s(wt) + s(hp) + factor(cyl),
  data = mtcars
)
```

### Create a prediction surface

``` r
es <- surf_prediction(
  model,
  x = "wt", y = "hp",
  x_length = 30, y_length = 30,
  labels = list(
    x = "Weight (1000 lbs)",
    y = "Horsepower",
    z = "Fuel efficiency (mpg)"
  )
)
es
#> ℹ <effectsurf> — Prediction Surface
#> • X: wt | Y: hp | Z: mpg
#> • Grid: 900 points (900 per stratum)
#> • CI: TRUE | Transform: FALSE
#> ℹ Use `plot()` to visualise, `surf_data()` to extract data.
```

### Visualise interactively

``` r
plot(es)
```

This opens an interactive 3D surface in your browser or RStudio viewer.
Drag to rotate, scroll to zoom, hover for values.

### Stratified surfaces

Overlay surfaces by a categorical variable to visualise interactions:

``` r
es_strat <- surf_prediction(
  model,
  x = "wt", y = "hp",
  by = "cyl",
  x_length = 25, y_length = 25,
  labels = list(
    x = "Weight (1000 lbs)",
    y = "Horsepower",
    z = "Fuel efficiency (mpg)",
    title = "Prediction surface by cylinder count"
  )
)
es_strat
#> ℹ <effectsurf> — Prediction Surface
#> • X: wt | Y: hp | Z: mpg
#> • Grid: 625 points (625 per stratum)
#> • Stratified by: cyl (1 levels)
#> • CI: TRUE | Transform: FALSE
#> ℹ Use `plot()` to visualise, `surf_data()` to extract data.
```

``` r
plot(es_strat, opacity = 0.85)
```

### Export to self-contained HTML

``` r
surf_export(es, "my_surface.html")
```

## Core functions

| Function                                                                                    | Purpose                                                |
|---------------------------------------------------------------------------------------------|--------------------------------------------------------|
| [`surf_prediction()`](https://aagi-aus.github.io/effectsurf/reference/surf_prediction.md)   | Prediction surface (fitted values across x, y)         |
| [`surf_comparison()`](https://aagi-aus.github.io/effectsurf/reference/surf_comparison.md)   | Treatment effect surface (contrasts between groups)    |
| [`surf_slopes()`](https://aagi-aus.github.io/effectsurf/reference/surf_slopes.md)           | Marginal effect surface (partial derivatives)          |
| [`surf_sensitivity()`](https://aagi-aus.github.io/effectsurf/reference/surf_sensitivity.md) | CATE surface (where does treatment work best?)         |
| [`surf_cate()`](https://aagi-aus.github.io/effectsurf/reference/surf_cate.md)               | CATE from causal models (e.g., causal forests)         |
| [`surf_derivatives()`](https://aagi-aus.github.io/effectsurf/reference/surf_derivatives.md) | Gradient, curvature, and interaction maps              |
| [`surf_profile()`](https://aagi-aus.github.io/effectsurf/reference/surf_profile.md)         | 2D profile slices from a 3D surface                    |
| [`surf_contour()`](https://aagi-aus.github.io/effectsurf/reference/surf_contour.md)         | 2D contour plot                                        |
| [`surf_optimum()`](https://aagi-aus.github.io/effectsurf/reference/surf_optimum.md)         | Find the (x, y) combination that maximises/minimises z |
| [`surf_export()`](https://aagi-aus.github.io/effectsurf/reference/surf_export.md)           | Export to self-contained HTML                          |

All `surf_*()` functions support the `smooth` parameter for
post-prediction surface smoothing via
[`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html) – useful for
random forests, boosted trees, and other non-smooth models.

## Agricultural example

{effectsurf} includes a bundled `barley_trials` dataset simulated from
Australian barley trial data (GRDC Project UCS2301-002RTX).

``` r
data(barley_trials)

m_barley <- mgcv::gam(
  yield ~ s(rainfall, k = 5) + nitrogen + seedrate +
    variety_type + state + nitrogen:variety_type +
    s(trial, bs = "re"),
  data = barley_trials,
  method = "REML"
)

es_barley <- surf_prediction(
  m_barley,
  x = "nitrogen", y = "rainfall",
  by = "variety_type",
  x_length = 30, y_length = 30,
  labels = list(
    x = "Nitrogen applied (kg/ha)",
    y = "April-October rainfall (mm)",
    z = "Grain yield (t/ha)",
    title = "Yield response surface by variety type"
  )
)
summary(es_barley)
#> Estimated Marginal Surface (EMS)
#> ================================
#> 
#> Type:     prediction 
#> X var:    nitrogen 
#> Y var:    rainfall 
#> Z var:    yield 
#> Strata:  variety_type (3 levels: tall, sdw, erectoides)
#> Grid:     2700  points
#> CI:       TRUE 
#> Transform: none 
#> 
#> Response summary (estimate):
#>   Min:     1.8153 
#>   Median:  3.8023 
#>   Mean:    3.7412 
#>   Max:     5.3814 
#> 
#> Response by stratum:
#>  variety_type   mean    min    max
#>        <fctr>  <num>  <num>  <num>
#>          tall 3.5795 1.9141 4.8689
#>           sdw 3.8580 2.1059 5.2341
#>    erectoides 3.7863 1.8153 5.3814
#> 
#> Model:  gam/glm/lm 
#> N obs:   3240
```

``` r
plot(es_barley, opacity = 0.85)
```

## Citation

``` r
citation("effectsurf")
To cite package 'effectsurf' in publications use:

  Moldovan M (2026). _effectsurf: Interactive 3D Estimated Marginal
  Surfaces for Conditional Effect Visualisation_. R package version
  0.1.0.9000, <https://github.com/maxmoldovan/effectsurf>.

A BibTeX entry for LaTeX users is

  @Manual{,
    title = {effectsurf: Interactive 3D Estimated Marginal Surfaces for Conditional Effect Visualisation},
    author = {Max Moldovan},
    year = {2026},
    note = {R package version 0.1.0.9000},
    url = {https://github.com/maxmoldovan/effectsurf},
  }
```

## Code of Conduct

Please note that this project is released with a [Contributor Code of
Conduct](https://www.contributor-covenant.org/version/2/1/code_of_conduct/).
By participating in this project you agree to abide by its terms.
