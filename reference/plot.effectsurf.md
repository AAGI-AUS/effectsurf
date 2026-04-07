# Plot an effectsurf object as an interactive 3D surface

Renders an `effectsurf` object as an interactive Plotly 3D surface plot.
When the object is stratified by a categorical variable, overlaid
surfaces are produced with independent colourscales and legend toggles.

## Usage

``` r
# S3 method for class 'effectsurf'
plot(
  x,
  opacity = 0.85,
  colourscale = "Viridis",
  show_ci = FALSE,
  ci_opacity = 0.3,
  wireframe = FALSE,
  show_data = FALSE,
  camera = NULL,
  save_html = NULL,
  fmt = NULL,
  width = NULL,
  height = NULL,
  ...
)
```

## Arguments

- x:

  An
  [effectsurf](https://aagi-aus.github.io/effectsurf/reference/new_effectsurf.md)
  object.

- opacity:

  Numeric (0-1). Surface opacity. Default `0.85`.

- colourscale:

  Character or list. Plotly colourscale name (e.g., `"Viridis"`,
  `"RdBu"`, `"Blues"`) or a custom colourscale list. For stratified
  surfaces, a vector of colours is used instead.

- show_ci:

  Logical. Whether to show confidence interval surfaces (upper/lower
  bounds as translucent surfaces). Default `FALSE`.

- ci_opacity:

  Numeric (0-1). Opacity for CI surfaces. Default `0.3`.

- wireframe:

  Logical. If `TRUE`, render surfaces as wireframes instead of filled
  surfaces. Default `FALSE`.

- show_data:

  Logical. If `TRUE` and the model's training data is available, overlay
  observed data points. Default `FALSE`.

- camera:

  A list specifying camera position, e.g.,
  `list(eye = list(x = 1.5, y = 1.5, z = 1.2))`.

- save_html:

  Character or `NULL`. If a file path is provided, saves the interactive
  plot as a self-contained HTML file. When saving, 2D maximum-profile
  plots (PDF) are also generated alongside the HTML, matching the
  prototype workflow. Default `NULL` (no file saved).

- fmt:

  A
  [`label_format()`](https://aagi-aus.github.io/effectsurf/reference/label_format.md)
  object controlling number formatting in hover text and axes. Default
  `NULL` (auto-format).

- width, height:

  Plot dimensions in pixels. `NULL` for auto-sizing.

- ...:

  Additional arguments (currently unused).

## Value

A `plotly` htmlwidget object (invisibly if `save_html` is used).

## See also

[`surf_prediction()`](https://aagi-aus.github.io/effectsurf/reference/surf_prediction.md),
[`surf_export()`](https://aagi-aus.github.io/effectsurf/reference/surf_export.md),
[`surf_profile()`](https://aagi-aus.github.io/effectsurf/reference/surf_profile.md),
[`label_format()`](https://aagi-aus.github.io/effectsurf/reference/label_format.md)

## Examples

``` r
# \donttest{
if (requireNamespace("mgcv", quietly = TRUE)) {
  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 25, y_length = 25)
  plot(es)
  plot(es, opacity = 0.9, colourscale = "RdBu")

  # Save to HTML (also produces 2D profile PDFs)
  plot(es, save_html = tempfile(fileext = ".html"))
}
#> Saved to /tmp/RtmpkGMl2L/file1bd32dcdeeed.html
# }
```
