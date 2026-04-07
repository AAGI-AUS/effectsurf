# User API: Marginal Effect Surfaces (Slopes)
# ============================================================================

#' Create a 3D marginal effect (slope) surface
#'
#' Generates a surface showing how the marginal effect (partial derivative)
#' of a focal variable varies across a 2D grid of two moderators.
#' Uses [marginaleffects::slopes()] as the computation backend.
#'
#' @inheritParams surf_prediction
#' @param variable Character. The focal variable whose marginal effect
#'   (slope) is computed.
#' @param slope Character. Type of slope: `"dydx"` (default), `"eyex"`,
#'   `"eydx"`, `"dyex"`. See [marginaleffects::slopes()].
#'
#' @return An [effectsurf][new_effectsurf] object of type `"slopes"`.
#'
#' @seealso [surf_prediction()], [surf_comparison()], [surf_sensitivity()]
#'
#' @export
#'
#' @examples
#' \donttest{
#' if (requireNamespace("mgcv", quietly = TRUE)) {
#'   model <- mgcv::gam(mpg ~ s(wt) + s(hp) + s(disp), data = mtcars)
#'
#'   # How does the marginal effect of wt change across hp x disp?
#'   es <- surf_slopes(model, x = "hp", y = "disp",
#'                     variable = "wt",
#'                     x_length = 25, y_length = 25)
#'   plot(es)
#' }
#' }
surf_slopes <- function(model,
                        x,
                        y,
                        variable,
                        slope = "dydx",
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
                        method = c("marginaleffects", "emmeans", "manual"),
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

  # Step 2: Compute slopes
  if (method == "emmeans") {
    result <- ems_slopes_emmeans(model, grid, x, y, by, variable, level, ...)
  } else {
    slopes_result <- marginaleffects::slopes(
      model,
      variables = variable,
      newdata = as.data.frame(grid),
      slope = slope,
      conf_level = level
    )
    slopes_dt <- as.data.table(slopes_result)

    # Keep relevant columns
    grid_cols <- intersect(c(x, y, by), names(slopes_dt))
    pred_cols <- intersect(
      c("estimate", "std.error", "conf.low", "conf.high"),
      names(slopes_dt)
    )
    keep_cols <- unique(c(grid_cols, pred_cols))
    result <- slopes_dt[, ..keep_cols]
  }

  # Step 2b: Apply post-prediction smoothing if requested
  if (!is.null(smooth_opts)) {
    result <- smooth_surface_data(result, x, y, by, smooth_opts)
  }

  # Step 3: z label
  z_var <- paste0("d_", variable)

  # Step 4: Build effectsurf object
  new_effectsurf(
    data       = result,
    x_var      = x,
    y_var      = y,
    z_var      = z_var,
    strata_var = by,
    type       = "slopes",
    ci         = ci && all(c("conf.low", "conf.high") %in% names(result)),
    model_info = extract_model_info(model),
    labels     = labels,
    transform  = transform,
    meta       = list(
      variable  = variable,
      slope     = slope,
      grid_type = grid_type,
      level     = level,
      method    = method,
      smooth    = smooth_opts
    )
  )
}


#' Compute slopes via emmeans::emtrends()
#' @noRd
ems_slopes_emmeans <- function(model, grid, x, y, by, variable, level, ...) {
  rlang::check_installed("emmeans", reason = "for emmeans-based slopes.")

  grid_cols <- intersect(c(x, y, by), names(grid))

  # Build at= list from grid
  at_list <- lapply(grid_cols, function(v) {
    vals <- grid[[v]]
    if (is.factor(vals) || is.character(vals)) unique(as.character(vals))
    else sort(unique(vals))
  })
  names(at_list) <- grid_cols

  em_formula <- stats::as.formula(paste("~", paste(grid_cols, collapse = " * ")))

  old_opt <- getOption("emmeans")
  emmeans::emm_options(rg.limit = 500000L)
  on.exit(options(emmeans = old_opt), add = TRUE)

  em <- emmeans::emtrends(model, em_formula, var = variable,
                           at = at_list, level = level, ...)
  em_dt <- as.data.table(as.data.frame(em))

  # Map column names
  # emtrends produces: <variable>.trend, SE, lower.CL, upper.CL
  trend_col <- paste0(variable, ".trend")
  name_map <- c(
    "SE"        = "std.error",
    "lower.CL"  = "conf.low",
    "upper.CL"  = "conf.high",
    "asymp.LCL" = "conf.low",
    "asymp.UCL" = "conf.high"
  )
  name_map[[trend_col]] <- "estimate"

  for (old in names(name_map)) {
    if (old %in% names(em_dt)) {
      data.table::setnames(em_dt, old, name_map[[old]], skip_absent = TRUE)
    }
  }

  keep <- intersect(c(grid_cols, "estimate", "std.error", "conf.low", "conf.high"),
                    names(em_dt))
  em_dt[, ..keep]
}
