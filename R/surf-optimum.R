# Surface Optimum Finder
# ============================================================================

#' Find the optimum (maximum or minimum) of a surface
#'
#' Locates the combination of x and y values that maximises or minimises
#' the predicted response on the surface grid.
#'
#' @param object An [effectsurf][new_effectsurf] object.
#' @param type Character. `"max"` (default) or `"min"`.
#'
#' @return A `data.table` with columns: `stratum` (if stratified), the
#'   x variable, the y variable, `estimate`, and optionally `conf.low`,
#'   `conf.high`.
#'
#' @export
#'
#' @examples
#' \donttest{
#' if (requireNamespace("mgcv", quietly = TRUE)) {
#'   model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
#'   es <- surf_prediction(model, x = "wt", y = "hp",
#'                         x_length = 30, y_length = 30)
#'   surf_optimum(es, type = "max")
#' }
#' }
surf_optimum <- function(object, type = c("max", "min")) {
  if (!inherits(object, "effectsurf")) {
    cli_abort("{.arg object} must be an {.cls effectsurf} object.")
  }

  type <- match.arg(type)
  dt <- copy(object$data)

  # Apply transform if present
  if (!is.null(object$transform)) {
    dt[, estimate := object$transform(estimate)]
    if (object$ci && "conf.low" %in% names(dt)) {
      dt[, conf.low := object$transform(conf.low)]
      dt[, conf.high := object$transform(conf.high)]
    }
  }

  fn <- if (type == "max") which.max else which.min

  if (!is.null(object$strata_var)) {
    result <- dt[, .SD[fn(estimate)], by = c(object$strata_var)]
  } else {
    result <- dt[fn(estimate)]
  }

  # Select relevant columns
  keep <- c(object$strata_var, object$x_var, object$y_var, "estimate")
  if (object$ci) {
    keep <- c(keep, intersect(c("conf.low", "conf.high"), names(result)))
  }
  result <- result[, ..keep]

  cli_inform(c(
    "i" = "Surface {type} found:",
    "*" = "{.field {object$x_var}} = {.val {result[[object$x_var]]}}",
    "*" = "{.field {object$y_var}} = {.val {result[[object$y_var]]}}",
    "*" = "{.field estimate} = {.val {round(result$estimate, 4)}}"
  ))

  result
}
