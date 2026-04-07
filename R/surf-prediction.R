# User API: Prediction Surfaces
# ============================================================================

#' Create a 3D prediction surface
#'
#' Generates an Estimated Marginal Surface (EMS) of model predictions across
#' two continuous focal variables. Non-focal variables are marginalised
#' (held at mean/mode or averaged). Optionally stratified by a categorical
#' variable to produce overlaid surfaces.
#'
#' @param model A fitted model object. Supports 100+ model classes via
#'   `marginaleffects`, including `lm`, `glm`, `gam`, `bam`, `lmer`,
#'   `glmer`, `brm`, and many more.
#' @param x Character. Name of the x-axis continuous variable.
#' @param y Character. Name of the y-axis continuous variable.
#' @param by Character or `NULL`. Name of a categorical variable for
#'   stratification. Each level produces a separate surface.
#' @param x_range Numeric vector of length 2. Range `c(min, max)` for x.
#'   If `NULL`, auto-detected from the model's training data.
#' @param y_range Numeric vector of length 2. Range `c(min, max)` for y.
#'   If `NULL`, auto-detected.
#' @param x_length Integer. Number of grid points along x. Default 50.
#' @param y_length Integer. Number of grid points along y. Default 50.
#' @param ci Logical. Whether to compute confidence intervals. Default `TRUE`.
#' @param level Numeric. Confidence level. Default `0.95`.
#' @param grid_type Character. How to handle non-focal variables. One of
#'   `"mean_or_mode"` (default) or `"counterfactual"`. See
#'   [marginaleffects::datagrid()] for details.
#' @param at Named list. Fix specific variables at given values
#'   (e.g., `at = list(state = "WA", nitrogen = 80)`).
#' @param levels_needed Character vector or `NULL`. Subset the `by` variable
#'   to specific levels.
#' @param transform Character, function, or `NULL`. Back-transformation for
#'   the response (e.g., `"expit"` for logit-scale models, `"exp"` for
#'   log-scale). Built-in options: `"expit"`, `"exp"`, `"square"`,
#'   `"percent_expit"`. Or supply a custom function.
#' @param labels Named list with custom axis labels: `x`, `y`, `z`, `title`.
#' @param smooth Post-prediction surface smoothing via [mgcv::gam()].
#'   Useful for non-smooth models (random forests, boosted trees, MARS) where
#'   raw predictions form jagged or step-function surfaces. A tensor product
#'   smooth `te(x, y)` is fitted to the predicted values as a visual
#'   approximation. Options:
#'   - `NULL` (default): No smoothing -- raw predictions displayed.
#'   - `TRUE`: Auto-smooth with `te(x, y, k = -1, bs = "tp")`, letting
#'     `mgcv` auto-select the basis dimension (same default as [mgcv::s()]).
#'   - A named list for manual control:
#'     - `k`: Basis dimension per marginal (default `-1` = auto).
#'       Higher values preserve more detail; lower values smooth more.
#'     - `bs`: Basis type (default `"tp"`). See [mgcv::te()].
#'     - `smooth_ci`: Logical. Also smooth confidence intervals?
#'       Default `TRUE`.
#'   When strata are present (`by` is set), a separate smooth is fitted
#'   per stratum, preserving interaction structure across groups.
#'   Requires the `mgcv` package.
#' @param predict_fun Custom prediction function with signature
#'   `function(model, newdata)`. Bypasses `marginaleffects`.
#' @param method Character. Computation backend: `"marginaleffects"` (default),
#'   `"gratia"` (for mgcv models), or `"manual"` (fallback).
#' @param ... Additional arguments passed to the prediction backend.
#'
#' @return An [effectsurf][new_effectsurf] object. Use [plot()] to visualise,
#'   [surf_data()] to extract the prediction grid.
#'
#' @seealso [plot.effectsurf()], [surf_comparison()], [surf_slopes()],
#'   [surf_profile()], [surf_export()]
#'
#' @export
#'
#' @examples
#' \donttest{
#' if (requireNamespace("mgcv", quietly = TRUE)) {
#'   # Fit a GAM
#'   model <- mgcv::gam(
#'     mpg ~ s(wt) + s(hp) + factor(cyl),
#'     data = mtcars
#'   )
#'
#'   # Basic prediction surface
#'   es <- surf_prediction(model, x = "wt", y = "hp")
#'
#'   # Stratified by cylinder count
#'   es_strat <- surf_prediction(model, x = "wt", y = "hp",
#'                               by = "cyl",
#'                               x_length = 30, y_length = 30)
#'
#'   # Plot interactively
#'   plot(es_strat)
#' }
#' }
surf_prediction <- function(model,
                            x,
                            y,
                            by = NULL,
                            x_range = NULL,
                            y_range = NULL,
                            x_length = 50L,
                            y_length = 50L,
                            ci = TRUE,
                            level = 0.95,
                            grid_type = "mean_or_mode",
                            at = NULL,
                            levels_needed = NULL,
                            transform = NULL,
                            labels = list(),
                            smooth = NULL,
                            predict_fun = NULL,
                            method = c("marginaleffects", "emmeans", "gratia", "manual"),
                            ...) {

  method <- match.arg(method)
  validate_model(model)
  smooth_opts <- resolve_smooth_opts(smooth)

  # Step 1: Create prediction grid
  grid <- ems_grid(
    model = model,
    x = x, y = y, by = by,
    x_range = x_range, y_range = y_range,
    x_length = x_length, y_length = y_length,
    grid_type = grid_type,
    at = at,
    levels_needed = levels_needed,
    method = method,
    ...
  )

  # Step 2: Generate predictions
  pred_method <- if (!is.null(predict_fun)) "predict" else method
  preds <- ems_predict(
    model = model,
    grid = grid,
    ci = ci,
    level = level,
    predict_fun = predict_fun,
    method = pred_method,
    ...
  )

  # Step 2b: Apply post-prediction smoothing if requested
  if (!is.null(smooth_opts)) {
    preds <- smooth_surface_data(preds, x, y, by, smooth_opts)
  }

  # Step 3: Determine z_var name (response variable)
  z_var <- tryCatch({
    all.vars(stats::formula(model))[1L]
  }, error = function(e) "response")

  # Step 4: Build effectsurf object
  new_effectsurf(
    data       = preds,
    x_var      = x,
    y_var      = y,
    z_var      = z_var,
    strata_var = by,
    type       = "prediction",
    ci         = ci && all(c("conf.low", "conf.high") %in% names(preds)),
    model_info = extract_model_info(model),
    labels     = labels,
    transform  = transform,
    meta       = list(
      grid_type = grid_type,
      level     = level,
      method    = method,
      at        = at,
      smooth    = smooth_opts
    )
  )
}
