# Create a label format specification

Defines how numeric values are formatted in axis labels, hover text,
colorbar, and legend. Accepts `sprintf`-style format strings, custom
functions, or named shortcuts.

## Usage

``` r
label_format(
  x = NULL,
  y = NULL,
  z = NULL,
  hover_x = NULL,
  hover_y = NULL,
  hover_z = NULL,
  digits = 2L
)
```

## Arguments

- x:

  Format for x-axis values. A `sprintf` format string (e.g.,
  `"%.0f kg/ha"`), a function, or `NULL` (auto).

- y:

  Format for y-axis values. Same as `x`.

- z:

  Format for z-axis values. Same as `x`.

- hover_x:

  Format for x values in hover text. Defaults to `x`.

- hover_y:

  Format for y values in hover text. Defaults to `y`.

- hover_z:

  Format for z values in hover text. Defaults to `z`.

- digits:

  Integer. Default number of decimal places when format is `NULL`.
  Default 2.

## Value

A `label_format` list used by
[`plot.effectsurf()`](https://aagi-aus.github.io/effectsurf/reference/plot.effectsurf.md).

## Examples

``` r
# Format nitrogen as integer with unit, rainfall with no decimals
fmt <- label_format(
  x = "%.0f kg/ha",
  y = "%.0f mm",
  z = "%.2f t/ha"
)

# Custom function
fmt2 <- label_format(
  z = function(v) paste0(round(v * 100, 1), "%")
)
```
