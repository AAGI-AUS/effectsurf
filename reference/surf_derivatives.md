# Compute derivative surfaces from an effectsurf object

Calculates first-order (gradient) and second-order (curvature,
interaction) derivative surfaces using central finite differences on the
prediction grid. Each derivative is returned as a standard `effectsurf`
object that can be plotted, exported, and analysed with all existing
package functions.

## Usage

``` r
surf_derivatives(object, order = 2L, type = "all", sigdigits = 10L)
```

## Arguments

- object:

  An
  [effectsurf](https://aagi-aus.github.io/effectsurf/reference/new_effectsurf.md)
  object (typically from
  [`surf_prediction()`](https://aagi-aus.github.io/effectsurf/reference/surf_prediction.md)).

- order:

  Integer. `1` for first-order derivatives only (gradient), `2` for both
  first- and second-order (curvature + interaction). Default `2`.

- type:

  Character vector specifying which derivatives to compute. Default
  `"all"`. Options:

  `"dzdx"`

  :   Partial derivative w.r.t. x (dz/dx)

  `"dzdy"`

  :   Partial derivative w.r.t. y (dz/dy)

  `"gradient"`

  :   Gradient magnitude sqrt((dz/dx)^2 + (dz/dy)^2)

  `"d2zdx2"`

  :   Second partial w.r.t. x (d^2z/dx^2) – curvature in x

  `"d2zdy2"`

  :   Second partial w.r.t. y (d^2z/dy^2) – curvature in y

  `"d2zdxdy"`

  :   Cross-partial (d^2z/dxdy) – local interaction strength

  `"all"`

  :   All of the above (filtered by `order`)

- sigdigits:

  Integer. Noise suppression threshold. Derivative values smaller than
  `10^(-sigdigits) * max(|z|)` are set to exactly zero. This removes
  floating-point artefacts (e.g., `1e-13` instead of `0`) that arise
  when finite differences are applied to flat or near-linear surfaces.
  Default `10` – conservative, only removes values below 10 orders of
  magnitude of the surface range. Set to `NULL` to disable.

## Value

A named list of `effectsurf` objects, one per requested derivative. Each
can be passed to
[`plot.effectsurf()`](https://aagi-aus.github.io/effectsurf/reference/plot.effectsurf.md),
[`surf_contour()`](https://aagi-aus.github.io/effectsurf/reference/surf_contour.md),
[`surf_export()`](https://aagi-aus.github.io/effectsurf/reference/surf_export.md),
[`surf_profile()`](https://aagi-aus.github.io/effectsurf/reference/surf_profile.md),
etc.

## Details

**Finite difference scheme:** Central differences are used for interior
points; forward/backward differences at boundaries. The grid spacing is
determined from the effectsurf object's x and y sequences.

**Scientific interpretation:**

- **dz/dx, dz/dy**: Local sensitivity of outcome to each predictor.
  Regions where the gradient is near zero indicate plateaus or optima.

- **Gradient magnitude**: Identifies regions of rapid vs stable
  response.

- **d^2z/dx^2, d^2z/dy^2**: Curvature. Negative = concave (diminishing
  returns); positive = convex (accelerating response). Zero-crossings
  locate inflection points.

- **d^2z/dxdy**: Spatially-resolved interaction strength. Non-zero
  values indicate that the effect of x depends on the level of y (and
  vice versa) at that specific grid location.

## Examples

``` r
# \donttest{
if (requireNamespace("mgcv", quietly = TRUE)) {
  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 30, y_length = 30)

  derivs <- surf_derivatives(es)
  plot(derivs$dzdx)          # Sensitivity to wt
  plot(derivs$gradient)      # Overall sensitivity map
  plot(derivs$d2zdxdy)       # Interaction surface
}
#> ℹ "d2zdxdy" is constant (0) across the grid.
#> • The surface is flat in this derivative -- no spatial variation.

{"x":{"visdat":{"1bd319d878a8":["function () ","plotlyVisDat"]},"cur_data":"1bd319d878a8","attrs":{"1bd319d878a8":{"x":[1.5129999999999999,1.6478620689655172,1.7827241379310343,1.9175862068965517,2.0524482758620688,2.1873103448275861,2.3221724137931035,2.4570344827586208,2.5918965517241377,2.7267586206896555,2.8616206896551724,2.9964827586206897,3.131344827586207,3.2662068965517239,3.4010689655172417,3.5359310344827586,3.6707931034482759,3.8056551724137933,3.9405172413793106,4.075379310344827,4.2102413793103448,4.3451034482758626,4.4799655172413795,4.6148275862068964,4.7496896551724141,4.884551724137931,5.0194137931034479,5.1542758620689657,5.2891379310344835,5.4240000000000004],"y":[52,61.758620689655174,71.517241379310349,81.275862068965523,91.034482758620697,100.79310344827587,110.55172413793103,120.31034482758621,130.06896551724139,139.82758620689657,149.58620689655174,159.34482758620692,169.10344827586206,178.86206896551724,188.62068965517241,198.37931034482759,208.13793103448276,217.89655172413794,227.65517241379311,237.41379310344828,247.17241379310346,256.93103448275861,266.68965517241384,276.44827586206895,286.20689655172413,295.9655172413793,305.72413793103448,315.48275862068965,325.24137931034483,335],"showscale":true,"showlegend":false,"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"z":{},"type":"surface","opacity":0.84999999999999998,"colorscale":"Viridis","inherit":true}},"layout":{"margin":{"b":40,"l":60,"t":25,"r":10},"title":"Interaction: Wt × Hp on Mpg","scene":{"xaxis":{"title":"Wt"},"yaxis":{"title":"Hp"},"zaxis":{"title":{},"range":[-9.9999999999999995e-07,9.9999999999999995e-07]}},"hovermode":"closest","showlegend":false},"source":"A","config":{"modeBarButtonsToAdd":["hoverclosest","hovercompare"],"showSendToCloud":false},"data":[{"colorbar":{"title":"z_list[[1L]]","ticklen":2},"colorscale":"Viridis","showscale":true,"x":[1.5129999999999999,1.6478620689655172,1.7827241379310343,1.9175862068965517,2.0524482758620688,2.1873103448275861,2.3221724137931035,2.4570344827586208,2.5918965517241377,2.7267586206896555,2.8616206896551724,2.9964827586206897,3.131344827586207,3.2662068965517239,3.4010689655172417,3.5359310344827586,3.6707931034482759,3.8056551724137933,3.9405172413793106,4.075379310344827,4.2102413793103448,4.3451034482758626,4.4799655172413795,4.6148275862068964,4.7496896551724141,4.884551724137931,5.0194137931034479,5.1542758620689657,5.2891379310344835,5.4240000000000004],"y":[52,61.758620689655174,71.517241379310349,81.275862068965523,91.034482758620697,100.79310344827587,110.55172413793103,120.31034482758621,130.06896551724139,139.82758620689657,149.58620689655174,159.34482758620692,169.10344827586206,178.86206896551724,188.62068965517241,198.37931034482759,208.13793103448276,217.89655172413794,227.65517241379311,237.41379310344828,247.17241379310346,256.93103448275861,266.68965517241384,276.44827586206895,286.20689655172413,295.9655172413793,305.72413793103448,315.48275862068965,325.24137931034483,335],"showlegend":false,"z":[[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]],"type":"surface","opacity":0.84999999999999998,"frame":null}],"highlight":{"on":"plotly_click","persistent":false,"dynamic":false,"selectize":false,"opacityDim":0.20000000000000001,"selected":{"opacity":1},"debounce":0},"shinyEvents":["plotly_hover","plotly_click","plotly_selected","plotly_relayout","plotly_brushed","plotly_brushing","plotly_clickannotation","plotly_doubleclick","plotly_deselect","plotly_afterplot","plotly_sunburstclick"],"base_url":"https://plot.ly"},"evals":[],"jsHooks":[]}# }
```
