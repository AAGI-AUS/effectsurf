# User API: CATE Surfaces
# ============================================================================

#' Create a 3D conditional average treatment effect (CATE) surface
#'
#' Generates a surface of treatment effect heterogeneity from causal
#' inference models (e.g., causal forests from `grf`, or custom CATE
#' estimators). Requires a custom `predict_fun` that returns treatment
#' effect estimates for each observation.
#'
#' For standard regression models, use [surf_comparison()] instead —
#' it provides CATE-like surfaces via `marginaleffects::comparisons()`.
#'
#' @param model A fitted causal model (e.g., from `grf::causal_forest()`).
#' @param x Character. Name of the x-axis moderator variable.
#' @param y Character. Name of the y-axis moderator variable.
#' @param x_range,y_range Numeric vectors of length 2.
#' @param x_length,y_length Integer. Grid resolution.
#' @param predict_fun A function with signature `function(model, newdata)`
#'   returning a numeric vector of CATE estimates. For `grf::causal_forest`,
#'   this would be `function(m, d) predict(m, d)$predictions`.
#' @param ci Logical. Whether to include confidence intervals. Requires
#'   `predict_fun` to return a data.frame with `estimate`, `conf.low`,
#'   `conf.high` columns.
#' @param training_data A `data.frame` of the original training data. Needed
#'   for determining non-focal variable reference values when the model
#'   object does not store training data.
#' @param at Named list of fixed variable values.
#' @param smooth Post-prediction surface smoothing via [mgcv::gam()].
#'   See [surf_prediction()] for full documentation. `NULL` (default) = no
#'   smoothing; `TRUE` = auto-smooth; or a named list with `k`, `bs`,
#'   `smooth_ci`.
#' @param transform Back-transformation specification.
#' @param labels Custom axis labels.
#' @param ... Additional arguments passed to `predict_fun`.
#'
#' @return An [effectsurf][new_effectsurf] object of type `"cate"`.
#'
#' @seealso [surf_comparison()], [surf_prediction()]
#'
#' @export
#'
#' @examples
#' \donttest{
#' # Example with a simple model (grf requires separate installation)
#' # library(grf)
#' # cf <- causal_forest(X, Y, W)
#' # es <- surf_cate(cf, x = "age", y = "income",
#' #                 predict_fun = function(m, d) predict(m, d)$predictions,
#' #                 training_data = X)
#' # plot(es)
#' }
surf_cate <- function(model,
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
                      ...) {

  if (is.null(predict_fun)) {
    cli_abort(
      "{.fn surf_cate} requires a {.arg predict_fun}. ",
      "For standard regression models, use {.fn surf_comparison} instead."
    )
  }

  # Resolve ranges from training data if model doesn't store it
  if (is.null(x_range)) {
    if (!is.null(training_data) && x %in% names(training_data)) {
      x_range <- range(training_data[[x]], na.rm = TRUE)
    } else {
      x_range <- detect_var_range(model, x)
    }
    if (is.null(x_range)) {
      cli_abort(
        "Cannot detect range for {.val {x}}. ",
        "Supply {.arg x_range} or {.arg training_data}."
      )
    }
  }

  if (is.null(y_range)) {
    if (!is.null(training_data) && y %in% names(training_data)) {
      y_range <- range(training_data[[y]], na.rm = TRUE)
    } else {
      y_range <- detect_var_range(model, y)
    }
    if (is.null(y_range)) {
      cli_abort(
        "Cannot detect range for {.val {y}}. ",
        "Supply {.arg y_range} or {.arg training_data}."
      )
    }
  }

  # Build grid manually (CATE models typically don't work with datagrid)
  x_seq <- seq(x_range[1L], x_range[2L], length.out = x_length)
  y_seq <- seq(y_range[1L], y_range[2L], length.out = y_length)

  grid <- data.table::CJ(x_tmp = x_seq, y_tmp = y_seq)
  data.table::setnames(grid, c("x_tmp", "y_tmp"), c(x, y))

  # Add reference values for other variables from training data
  if (!is.null(training_data)) {
    other_vars <- setdiff(names(training_data), c(x, y))
    for (v in other_vars) {
      vals <- training_data[[v]]
      if (is.numeric(vals)) {
        grid[[v]] <- mean(vals, na.rm = TRUE)
      } else if (is.factor(vals)) {
        tab <- table(vals)
        grid[[v]] <- factor(names(tab)[which.max(tab)], levels = levels(vals))
      } else if (is.character(vals)) {
        tab <- table(vals)
        grid[[v]] <- names(tab)[which.max(tab)]
      }
    }
  }

  # Override with user-specified values
  if (!is.null(at)) {
    for (nm in names(at)) {
      grid[[nm]] <- at[[nm]]
    }
  }

  # Generate CATE predictions
  preds <- ems_predict_custom(model, grid, predict_fun, ...)

  # Apply post-prediction smoothing if requested
  smooth_opts <- resolve_smooth_opts(smooth)
  if (!is.null(smooth_opts)) {
    preds <- smooth_surface_data(preds, x, y, NULL, smooth_opts)
  }

  # Build effectsurf object
  new_effectsurf(
    data       = preds,
    x_var      = x,
    y_var      = y,
    z_var      = "CATE",
    strata_var = NULL,
    type       = "cate",
    ci         = ci && all(c("conf.low", "conf.high") %in% names(preds)),
    model_info = list(class = class(model)),
    labels     = labels,
    transform  = transform,
    meta       = list(x_range = x_range, y_range = y_range, at = at,
                      smooth = smooth_opts)
  )
}
