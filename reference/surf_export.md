# Export an effectsurf plot to HTML

Saves an interactive 3D surface visualisation as a self-contained HTML
file that can be opened in any web browser, shared, or embedded in
reports. Also generates 2D maximum-profile PDFs alongside the HTML.

## Usage

``` r
surf_export(object, path, selfcontained = TRUE, title = NULL, ...)
```

## Arguments

- object:

  An
  [effectsurf](https://aagi-aus.github.io/effectsurf/reference/new_effectsurf.md)
  object.

- path:

  Character. File path for the output HTML. Must end in `.html`.

- selfcontained:

  Logical. If `TRUE` (default), produces a single self-contained HTML
  file (~3.8 MB, fully portable).

- title:

  Character or `NULL`. HTML page title (currently unused, title comes
  from the effectsurf object).

- ...:

  Additional arguments passed to
  [`plot.effectsurf()`](https://aagi-aus.github.io/effectsurf/reference/plot.effectsurf.md)
  for controlling the visualisation appearance.

## Value

Invisibly returns the file path.

## Examples

``` r
# \donttest{
if (requireNamespace("mgcv", quietly = TRUE)) {
  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 20, y_length = 20)
  # Export to temp file
  tmp <- tempfile(fileext = ".html")
  surf_export(es, path = tmp)
}
#> Saved to /tmp/RtmpkGMl2L/file1bd3b974e32.html
#> Exported to /tmp/RtmpkGMl2L/file1bd3b974e32.html
# }
```
