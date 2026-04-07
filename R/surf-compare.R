# Model Comparison Surfaces
# ============================================================================

#' Compare two surfaces side-by-side or as a difference surface
#'
#' Computes the difference between two `effectsurf` objects or creates
#' a side-by-side comparison. Useful for comparing models (e.g.,
#' DAG-informed vs legacy), or comparing two different treatments.
#'
#' @param object1 An [effectsurf][new_effectsurf] object.
#' @param object2 An [effectsurf][new_effectsurf] object with the same
#'   x and y variables and grid resolution.
#' @param type Character. `"difference"` (default) computes
#'   `object1 - object2` as a new surface. `"side_by_side"` returns
#'   both objects in a list for manual comparison.
#' @param labels Named list. Custom labels for the difference surface.
#'
#' @return For `"difference"`: a new `effectsurf` object. For
#'   `"side_by_side"`: a named list with elements `surface1` and `surface2`.
#'
#' @export
#'
#' @examples
#' \donttest{
#' if (requireNamespace("mgcv", quietly = TRUE)) {
#'   m1 <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
#'   m2 <- mgcv::gam(mpg ~ s(wt) + hp, data = mtcars)
#'
#'   es1 <- surf_prediction(m1, x = "wt", y = "hp",
#'                          x_length = 20, y_length = 20)
#'   es2 <- surf_prediction(m2, x = "wt", y = "hp",
#'                          x_length = 20, y_length = 20)
#'
#'   diff_surf <- surf_compare(es1, es2, type = "difference")
#'   plot(diff_surf)
#' }
#' }
surf_compare <- function(object1,
                         object2,
                         type = c("difference", "side_by_side"),
                         labels = list()) {

  if (!inherits(object1, "effectsurf") || !inherits(object2, "effectsurf")) {
    cli_abort("Both {.arg object1} and {.arg object2} must be {.cls effectsurf} objects.")
  }

  type <- match.arg(type)

  if (type == "side_by_side") {
    return(list(surface1 = object1, surface2 = object2))
  }

  # Difference surface
  if (object1$x_var != object2$x_var || object1$y_var != object2$y_var) {
    cli_abort("Both surfaces must have the same x and y variables.")
  }

  dt1 <- copy(object1$data)
  dt2 <- copy(object2$data)

  # Apply transforms if present

  if (!is.null(object1$transform)) {
    dt1[, estimate := object1$transform(estimate)]
  }
  if (!is.null(object2$transform)) {
    dt2[, estimate := object2$transform(estimate)]
  }

  # Merge on grid coordinates
  merge_cols <- c(object1$x_var, object1$y_var)
  if (!is.null(object1$strata_var) && !is.null(object2$strata_var) &&
      object1$strata_var == object2$strata_var) {
    merge_cols <- c(merge_cols, object1$strata_var)
  }

  merged <- merge(
    dt1[, c(merge_cols, "estimate"), with = FALSE],
    dt2[, c(merge_cols, "estimate"), with = FALSE],
    by = merge_cols,
    suffixes = c(".1", ".2")
  )
  merged[, estimate := estimate.1 - estimate.2]
  merged[, c("estimate.1", "estimate.2") := NULL]

  # Build default labels
  default_labels <- list(
    x = object1$labels$x,
    y = object1$labels$y,
    z = paste0("Difference (", object1$labels$z, ")"),
    title = "Model comparison: Surface 1 - Surface 2"
  )
  for (nm in names(labels)) {
    default_labels[[nm]] <- labels[[nm]]
  }

  new_effectsurf(
    data       = merged,
    x_var      = object1$x_var,
    y_var      = object1$y_var,
    z_var      = paste0("diff_", object1$z_var),
    strata_var = if (length(merge_cols) > 2L) merge_cols[3L] else NULL,
    type       = "comparison",
    ci         = FALSE,
    model_info = list(
      class = "comparison",
      model1 = object1$model_info$class,
      model2 = object2$model_info$class
    ),
    labels     = default_labels,
    transform  = NULL,
    meta       = list(comparison_type = "model_difference")
  )
}
