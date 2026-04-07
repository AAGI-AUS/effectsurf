# Package index

## Surface Constructors

Create 3D effect surfaces from fitted models.

- [`surf_prediction()`](https://aagi-aus.github.io/effectsurf/reference/surf_prediction.md)
  : Create a 3D prediction surface
- [`surf_comparison()`](https://aagi-aus.github.io/effectsurf/reference/surf_comparison.md)
  : Create a 3D treatment effect comparison surface
- [`surf_slopes()`](https://aagi-aus.github.io/effectsurf/reference/surf_slopes.md)
  : Create a 3D marginal effect (slope) surface
- [`surf_sensitivity()`](https://aagi-aus.github.io/effectsurf/reference/surf_sensitivity.md)
  : Create a sensitivity analysis surface
- [`surf_cate()`](https://aagi-aus.github.io/effectsurf/reference/surf_cate.md)
  : Create a 3D conditional average treatment effect (CATE) surface
- [`surf_derivatives()`](https://aagi-aus.github.io/effectsurf/reference/surf_derivatives.md)
  : Compute derivative surfaces from an effectsurf object

## Visualisation & Export

Plot, project, and export surfaces.

- [`plot(`*`<effectsurf>`*`)`](https://aagi-aus.github.io/effectsurf/reference/plot.effectsurf.md)
  : Plot an effectsurf object as an interactive 3D surface
- [`surf_contour()`](https://aagi-aus.github.io/effectsurf/reference/surf_contour.md)
  : Create a 2D contour/heatmap from a 3D surface
- [`surf_profile()`](https://aagi-aus.github.io/effectsurf/reference/surf_profile.md)
  : Extract 2D profile slices from a 3D surface
- [`surf_export()`](https://aagi-aus.github.io/effectsurf/reference/surf_export.md)
  : Export an effectsurf plot to HTML

## Analysis

Extract data, find optima, and compare surfaces.

- [`surf_data()`](https://aagi-aus.github.io/effectsurf/reference/surf_data.md)
  : Extract data from an effectsurf object
- [`surf_optimum()`](https://aagi-aus.github.io/effectsurf/reference/surf_optimum.md)
  : Find the optimum (maximum or minimum) of a surface
- [`surf_compare()`](https://aagi-aus.github.io/effectsurf/reference/surf_compare.md)
  : Compare two surfaces side-by-side or as a difference surface
- [`surf_tidy()`](https://aagi-aus.github.io/effectsurf/reference/surf_tidy.md)
  : Convert an effectsurf object to a tidy data.frame
- [`es_meta()`](https://aagi-aus.github.io/effectsurf/reference/es_meta.md)
  : Access effectsurf metadata
- [`coef(`*`<effectsurf>`*`)`](https://aagi-aus.github.io/effectsurf/reference/coef.effectsurf.md)
  : Extract coefficients (estimates) from an effectsurf object

## Computation Layer

Lower-level grid and prediction functions.

- [`ems_grid()`](https://aagi-aus.github.io/effectsurf/reference/ems_grid.md)
  : Create a prediction grid for surface estimation
- [`ems_predict()`](https://aagi-aus.github.io/effectsurf/reference/ems_predict.md)
  : Generate predictions on a grid

## Class & Constructors

The effectsurf S3 class.

- [`new_effectsurf()`](https://aagi-aus.github.io/effectsurf/reference/new_effectsurf.md)
  : Create an effectsurf object
- [`is_effectsurf()`](https://aagi-aus.github.io/effectsurf/reference/is_effectsurf.md)
  : Check if an object is an effectsurf object
- [`effectsurf`](https://aagi-aus.github.io/effectsurf/reference/effectsurf-package.md)
  [`effectsurf-package`](https://aagi-aus.github.io/effectsurf/reference/effectsurf-package.md)
  : effectsurf: Interactive 3D Estimated Marginal Surfaces for
  Conditional Effect Visualisation

## Utilities

Helper and transform functions.

- [`expit()`](https://aagi-aus.github.io/effectsurf/reference/expit.md)
  : Expit (inverse logit) function
- [`logit()`](https://aagi-aus.github.io/effectsurf/reference/logit.md)
  : Logit function
- [`label_format()`](https://aagi-aus.github.io/effectsurf/reference/label_format.md)
  : Create a label format specification

## Data

Example datasets bundled with the package.

- [`barley_trials`](https://aagi-aus.github.io/effectsurf/reference/barley_trials.md)
  : Simulated Australian Barley Agronomy Trials
