# effectsurf S3 Class Definition and Methods
# ============================================================================

#' Create an effectsurf object
#'
#' Constructor for the `effectsurf` S3 class. Not typically called directly
#' by users; instead, use [surf_prediction()], [surf_comparison()],
#' [surf_slopes()], or [surf_cate()].
#'
#' @param data A `data.table` containing the prediction grid with columns for
#'   the x variable, y variable, `estimate`, and optionally `std.error`,
#'   `conf.low`, `conf.high`, and the stratification variable.
#' @param x_var Character. Name of the x-axis variable.
#' @param y_var Character. Name of the y-axis variable.
#' @param z_var Character. Name of the response (z-axis) variable.
#' @param strata_var Character or `NULL`. Name of the categorical
#'   stratification variable.
#' @param type Character. One of `"prediction"`, `"comparison"`, `"slopes"`,
#'   `"cate"`.
#' @param ci Logical. Whether confidence intervals are included.
#' @param model_info A named list with model metadata: `class`, `formula`,
#'   `n_obs`, `call`.
#' @param labels A named list with display labels: `x`, `y`, `z`, `title`.
#' @param transform Character or function or `NULL`. Back-transformation to
#'   apply for display (e.g., `"expit"` for logit models).
#' @param meta A named list with additional metadata.
#'
#' @return An object of class `effectsurf`.
#' @export
#' @examples
#' # Typically created via surf_prediction(), not directly
#' es <- new_effectsurf(
#'   data = data.table::data.table(
#'     x = rep(1:3, each = 3), y = rep(1:3, 3),
#'     estimate = rnorm(9)
#'   ),
#'   x_var = "x", y_var = "y", z_var = "response",
#'   type = "prediction"
#' )
#' print(es)
new_effectsurf <- function(data,
                           x_var,
                           y_var,
                           z_var,
                           strata_var = NULL,
                           type = c("prediction", "comparison", "slopes", "cate"),
                           ci = FALSE,
                           model_info = list(),
                           labels = list(),
                           transform = NULL,
                           meta = list()) {

  type <- match.arg(type)

  # Validate inputs
  if (!is.data.frame(data)) {
    cli_abort("{.arg data} must be a data.frame or data.table.")
  }
  if (!is.data.table(data)) {
    data <- as.data.table(data)
  }

  required_cols <- c(x_var, y_var, "estimate")
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0L) {
    cli_abort("Missing required columns in {.arg data}: {.val {missing_cols}}.")
  }

  if (!is.null(strata_var) && !strata_var %in% names(data)) {
    cli_abort(
      "Stratification variable {.val {strata_var}} not found in {.arg data}."
    )
  }

  if (ci) {
    ci_cols <- c("conf.low", "conf.high")
    missing_ci <- setdiff(ci_cols, names(data))
    if (length(missing_ci) > 0L) {
      cli_warn(
        "{.arg ci} is TRUE but columns {.val {missing_ci}} are missing. ",
        "Setting {.arg ci} to FALSE."
      )
      ci <- FALSE
    }
  }

  # Resolve transform function
  transform_fn <- resolve_transform(transform)

  # Build default labels from variable names if not provided
  labels <- build_labels(labels, x_var, y_var, z_var, strata_var, type)

  structure(
    list(
      data       = data,
      x_var      = x_var,
      y_var      = y_var,
      z_var      = z_var,
      strata_var = strata_var,
      type       = type,
      ci         = ci,
      model_info = model_info,
      labels     = labels,
      transform  = transform_fn,
      meta       = meta
    ),
    class = "effectsurf"
  )
}


#' @export
print.effectsurf <- function(x, ...) {
  type_label <- switch(
    x$type,
    prediction = "Prediction Surface",
    comparison = "Effect Comparison Surface",
    slopes     = "Marginal Effect Surface",
    cate       = "CATE Surface"
  )

  n_points <- nrow(x$data)
  n_strata <- if (!is.null(x$strata_var)) {
    length(unique(x$data[[x$strata_var]]))
  } else {
    1L
  }

  cli_inform(c(
    "i" = "{.cls effectsurf} \u2014 {type_label}",
    "*" = "X: {.field {x$x_var}} | Y: {.field {x$y_var}} | Z: {.field {x$z_var}}",
    "*" = "Grid: {.val {n_points}} points ({.val {n_points / n_strata}} per stratum)",
    "*" = if (!is.null(x$strata_var)) {
      "Stratified by: {.field {x$strata_var}} ({.val {n_strata}} levels)"
    },
    "*" = "CI: {.val {x$ci}} | Transform: {.val {!is.null(x$transform)}}",
    "i" = "Use {.fn plot} to visualise, {.fn surf_data} to extract data."
  ))

  invisible(x)
}


#' @export
summary.effectsurf <- function(object, ...) {
  cat("Estimated Marginal Surface (EMS)\n")
  cat("================================\n\n")

  cat("Type:    ", object$type, "\n")
  cat("X var:   ", object$x_var, "\n")
  cat("Y var:   ", object$y_var, "\n")
  cat("Z var:   ", object$z_var, "\n")

  if (!is.null(object$strata_var)) {
    strata_levels <- unique(object$data[[object$strata_var]])
    cat("Strata:  ", object$strata_var,
        " (", length(strata_levels), " levels: ",
        paste(head(strata_levels, 5L), collapse = ", "),
        if (length(strata_levels) > 5L) ", ..." else "",
        ")\n", sep = "")
  }

  cat("Grid:    ", nrow(object$data), " points\n")
  cat("CI:      ", object$ci, "\n")
  cat("Transform:", if (is.null(object$transform)) "none" else "yes", "\n")

  # Response summary
  est <- object$data[["estimate"]]
  cat("\nResponse summary (estimate):\n")
  cat("  Min:    ", round(min(est, na.rm = TRUE), 4L), "\n")
  cat("  Median: ", round(median(est, na.rm = TRUE), 4L), "\n")
  cat("  Mean:   ", round(mean(est, na.rm = TRUE), 4L), "\n")
  cat("  Max:    ", round(max(est, na.rm = TRUE), 4L), "\n")

  if (!is.null(object$strata_var)) {
    cat("\nResponse by stratum:\n")
    dt <- object$data
    strata_col <- object$strata_var
    strata_summary <- dt[, .(
      mean = round(mean(estimate, na.rm = TRUE), 4L),
      min  = round(min(estimate, na.rm = TRUE), 4L),
      max  = round(max(estimate, na.rm = TRUE), 4L)
    ), by = strata_col]
    print(strata_summary, row.names = FALSE)
  }

  # Model info
  if (length(object$model_info) > 0L) {
    cat("\nModel: ", paste(object$model_info$class, collapse = "/"), "\n")
    if (!is.null(object$model_info$n_obs)) {
      cat("N obs:  ", object$model_info$n_obs, "\n")
    }
  }

  invisible(object)
}


#' Extract data from an effectsurf object
#'
#' Returns the underlying prediction grid as a `data.table`.
#'
#' @param object An `effectsurf` object.
#' @param as_matrix Logical. If `TRUE`, returns a list of matrices suitable
#'   for direct use with [plotly::add_surface()]. Default `FALSE`.
#'
#' @return A `data.table` (default) or a named list of matrices.
#' @export
#' @examples
#' # After creating a surface
#' # es <- surf_prediction(model, x = "x1", y = "x2")
#' # surf_data(es)               # data.table
#' # surf_data(es, as_matrix = TRUE)  # list of z-matrices
surf_data <- function(object, as_matrix = FALSE) {
  if (!inherits(object, "effectsurf")) {
    cli_abort("{.arg object} must be an {.cls effectsurf} object.")
  }

  if (!as_matrix) {
    return(copy(object$data))
  }

  # Convert to matrix format for plotly
  to_surface_matrices(object)
}


#' Check if an object is an effectsurf object
#'
#' @param x An object to test.
#' @return Logical.
#' @export
is_effectsurf <- function(x) {
  inherits(x, "effectsurf")
}


#' Convert an effectsurf object to a tidy data.frame
#'
#' Returns a clean `data.frame` with only the essential columns:
#' the x variable, y variable, `estimate`, and optionally `std.error`,
#' `conf.low`, `conf.high`, and the stratification variable.
#' All metadata and class information are stripped.
#'
#' @param x An `effectsurf` object.
#' @param transformed Logical. If `TRUE` and a back-transformation is
#'   stored, apply it to the estimates. Default `FALSE`.
#' @param ... Ignored.
#'
#' @return A plain `data.frame`.
#' @export
surf_tidy <- function(x, transformed = FALSE, ...) {
  dt <- copy(x$data)

  if (transformed && !is.null(x$transform)) {
    dt[, estimate := x$transform(estimate)]
    if (x$ci && "conf.low" %in% names(dt)) {
      dt[, conf.low := x$transform(conf.low)]
      dt[, conf.high := x$transform(conf.high)]
    }
  }

  keep <- c(x$x_var, x$y_var, "estimate")
  if ("std.error" %in% names(dt)) keep <- c(keep, "std.error")
  if (x$ci) keep <- c(keep, intersect(c("conf.low", "conf.high"), names(dt)))
  if (!is.null(x$strata_var)) keep <- c(keep, x$strata_var)
  keep <- intersect(keep, names(dt))

  as.data.frame(dt[, ..keep])
}


#' @export
as.data.frame.effectsurf <- function(x, row.names = NULL,
                                      optional = FALSE, ...) {
  as.data.frame(x$data, row.names = row.names, optional = optional, ...)
}


#' Extract coefficients (estimates) from an effectsurf object
#'
#' @param object An `effectsurf` object.
#' @param ... Ignored.
#' @return Numeric vector of estimates.
#' @export
coef.effectsurf <- function(object, ...) {
  object$data[["estimate"]]
}


#' Access effectsurf metadata
#'
#' Returns the metadata list containing variable names, type, model info,
#' labels, and other settings.
#'
#' @param x An `effectsurf` object.
#' @return A named list.
#' @export
#'
#' @examples
#' # es <- surf_prediction(model, x = "wt", y = "hp")
#' # es_meta(es)$x_var
#' # es_meta(es)$type
es_meta <- function(x) {
  if (!inherits(x, "effectsurf")) {
    cli_abort("{.arg x} must be an {.cls effectsurf} object.")
  }
  list(
    x_var      = x$x_var,
    y_var      = x$y_var,
    z_var      = x$z_var,
    strata_var = x$strata_var,
    type       = x$type,
    ci         = x$ci,
    model_info = x$model_info,
    labels     = x$labels,
    transform  = x$transform,
    meta       = x$meta,
    n_grid     = nrow(x$data),
    n_strata   = if (!is.null(x$strata_var)) {
      length(unique(x$data[[x$strata_var]]))
    } else { 1L }
  )
}
