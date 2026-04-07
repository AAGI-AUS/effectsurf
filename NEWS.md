# effectsurf (development version)

## effectsurf 0.2.0.9000

* **New feature: Post-prediction surface smoothing** (`smooth` parameter).
  All `surf_*()` functions now accept a `smooth` argument that applies
  `mgcv::gam()` tensor product smoothing (`te(x, y)`) to predicted values.
  This is particularly useful for non-smooth models (random forests, boosted
  trees, MARS) where raw predictions form jagged or step-function surfaces.
  - `smooth = NULL` (default): No smoothing -- raw predictions displayed.
  - `smooth = TRUE`: Auto-smooth with `te(x, y, k = -1, bs = "tp")`,
    using `mgcv`'s automatic basis dimension selection (same default as
    `mgcv::s()`).
  - `smooth = list(k = 15, bs = "cr", smooth_ci = FALSE)`: Full manual
    control over basis dimension, basis type, and CI smoothing.
  - Separate smooth fitted per stratum when `by` is used, preserving
    interaction structure across groups.
  - Smoothing metadata stored in the effectsurf object for traceability.
* Previous version (0.1.0.9000) archived to `zz_archive/`.

## effectsurf 0.1.0.9000

* Initial development version.
* Core surface functions: `surf_prediction()`, `surf_comparison()`,
  `surf_slopes()`, `surf_cate()`.
* Interactive 3D Plotly rendering with categorical stratification.
* Confidence envelope surfaces.
* 2D profile projections via `surf_profile()`.
* Sensitivity analysis via `surf_sensitivity()`.
* Model-agnostic via `marginaleffects` (100+ model classes).
* Optional `gratia` integration for GAM smooth surfaces.
* Bundled `barley_trials` example dataset.
* HTML export via `surf_export()`.
