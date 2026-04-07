# User API: Sensitivity Analysis Surfaces
# ============================================================================

#' Create a sensitivity analysis surface
#'
#' Generates a surface showing how the effect of a focal treatment variable
#' varies across a 2D grid of two moderators. This is conceptually a
#' "treatment effect landscape" — answering "where does the treatment work
#' best?"
#'
#' @inheritParams surf_prediction
#' @param focal Character. The treatment variable whose effect is being
#'   examined.
#' @param focal_contrast For categorical `focal`: a specific contrast
#'   (e.g., `"high N - nil N"`). For continuous `focal`: a numeric step
#'   size (default 1).
#' @param comparison Character. `"difference"` (default), `"ratio"`, or
#'   `"lnratio"`.
#'
#' @return An [effectsurf][new_effectsurf] object of type `"comparison"`.
#'
#' @details
#' This function is a convenience wrapper around [surf_comparison()] that
#' emphasises the sensitivity/moderation framing: "How does the effect of
#' the focal variable change across the moderator space?"
#'
#' @seealso [surf_comparison()], [surf_slopes()]
#'
#' @export
#'
#' @examples
#' \donttest{
#' if (requireNamespace("mgcv", quietly = TRUE)) {
#'   model <- mgcv::gam(
#'     mpg ~ s(wt) + s(hp) + factor(am),
#'     data = mtcars
#'   )
#'   # How does the effect of transmission type vary across wt x hp?
#'   es <- surf_sensitivity(model, x = "wt", y = "hp", focal = "am",
#'                          x_length = 25, y_length = 25)
#'   plot(es)
#' }
#' }
surf_sensitivity <- function(model,
                             x,
                             y,
                             focal,
                             focal_contrast = NULL,
                             comparison = "difference",
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

  # Build default labels if not supplied
  if (is.null(labels$z)) {
    labels$z <- paste0("Effect of ", prettify_name(focal))
  }
  if (is.null(labels$title)) {
    labels$title <- paste0(
      "Sensitivity: effect of ", prettify_name(focal),
      " across ", prettify_name(x), " \u00d7 ", prettify_name(y)
    )
  }

  surf_comparison(
    model = model,
    x = x, y = y,
    variable = focal,
    contrast = focal_contrast,
    comparison = comparison,
    by = by,
    x_range = x_range, y_range = y_range,
    x_length = x_length, y_length = y_length,
    ci = ci, level = level,
    grid_type = grid_type,
    at = at,
    levels_needed = levels_needed,
    transform = transform,
    labels = labels,
    smooth = smooth,
    method = method,
    ...
  )
}
