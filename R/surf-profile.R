# 2D Profile Projections from 3D Surfaces
# ============================================================================

#' Extract 2D profile slices from a 3D surface
#'
#' Projects the 3D surface into 2D by fixing one variable at specific values
#' and plotting the response against the other variable. This bridges
#' interactive 3D exploration with publication-ready 2D figures.
#'
#' @param object An [effectsurf][new_effectsurf] object.
#' @param along Character. Which axis to plot along: `"x"` (default) or `"y"`.
#'   - `"x"`: fix y at specific values, plot response vs x.
#'   - `"y"`: fix x at specific values, plot response vs y.
#' @param at Numeric vector or `NULL`. Values at which to fix the other
#'   variable. If `NULL`, uses 5 evenly spaced quantile values.
#' @param use_ggplot Logical. If `TRUE` and `ggplot2` is available, returns
#'   a ggplot2 object. If `FALSE` (default), returns a list of data and
#'   a base R plot.
#' @param ... Additional arguments passed to plotting functions.
#'
#' @return If `use_ggplot = TRUE`, a `ggplot` object. Otherwise, a named list
#'   with `data` (a data.table of profile slices) and `plot` (called for
#'   side effect).
#'
#' @export
#'
#' @examples
#' \donttest{
#' if (requireNamespace("mgcv", quietly = TRUE)) {
#'   model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
#'   es <- surf_prediction(model, x = "wt", y = "hp",
#'                         x_length = 30, y_length = 30)
#'
#'   # Profile along x at 5 values of y
#'   surf_profile(es, along = "x")
#'
#'   # Profile along y at specific x values
#'   surf_profile(es, along = "y", at = c(2, 3, 4, 5))
#' }
#' }
surf_profile <- function(object,
                         along = c("x", "y"),
                         at = NULL,
                         use_ggplot = TRUE,
                         ...) {

  if (!inherits(object, "effectsurf")) {
    cli_abort("{.arg object} must be an {.cls effectsurf} object.")
  }

  along <- match.arg(along)
  dt <- copy(object$data)

  # Apply back-transformation
  if (!is.null(object$transform)) {
    dt[, estimate := object$transform(estimate)]
    if (object$ci && "conf.low" %in% names(dt)) {
      dt[, conf.low := object$transform(conf.low)]
      dt[, conf.high := object$transform(conf.high)]
    }
  }

  # Determine which variable is the "along" axis and which is "fixed"
  if (along == "x") {
    along_var <- object$x_var
    fixed_var <- object$y_var
    along_label <- object$labels$x
    fixed_label <- object$labels$y
  } else {
    along_var <- object$y_var
    fixed_var <- object$x_var
    along_label <- object$labels$y
    fixed_label <- object$labels$x
  }

  # Determine slice values for the fixed variable
  fixed_vals <- dt[[fixed_var]]
  unique_fixed <- sort(unique(fixed_vals))

  if (is.null(at)) {
    # Use 5 evenly spaced quantile positions
    at_indices <- round(seq(1L, length(unique_fixed), length.out = 5L))
    at <- unique_fixed[at_indices]
  }

  # Find nearest available grid values
  at_matched <- vapply(at, function(v) {
    unique_fixed[which.min(abs(unique_fixed - v))]
  }, numeric(1L))
  at_matched <- unique(at_matched)

  # Filter to slices
  profiles <- dt[get(fixed_var) %in% at_matched]
  profiles[, slice_label := paste0(fixed_label, " = ", round(get(fixed_var), 1L))]

  # Plot
  if (use_ggplot && rlang::is_installed("ggplot2")) {
    p <- render_profile_ggplot(
      profiles, along_var, fixed_var, object$strata_var,
      along_label, object$labels$z, fixed_label, object$ci
    )
    return(p)
  }

  # Return data for manual plotting
  list(data = profiles, along_var = along_var, fixed_var = fixed_var)
}


#' Render profile plot with ggplot2
#' @noRd
render_profile_ggplot <- function(profiles, along_var, fixed_var,
                                  strata_var, x_label, y_label,
                                  fixed_label, has_ci) {
  ggplot2 <- asNamespace("ggplot2")

  p <- ggplot2::ggplot(
    profiles,
    ggplot2::aes(x = .data[[along_var]], y = .data[["estimate"]],
                 colour = .data[["slice_label"]])
  )

  # Add CI ribbon if available
  if (has_ci && all(c("conf.low", "conf.high") %in% names(profiles))) {
    p <- p + ggplot2::geom_ribbon(
      ggplot2::aes(ymin = .data[["conf.low"]],
                   ymax = .data[["conf.high"]],
                   fill = .data[["slice_label"]]),
      alpha = 0.15, colour = NA
    )
  }

  p <- p +
    ggplot2::geom_line(linewidth = 0.8) +
    ggplot2::labs(x = x_label, y = y_label,
                  colour = fixed_label, fill = fixed_label) +
    ggplot2::theme_minimal(base_size = 12L)

  # Facet by strata if present
  if (!is.null(strata_var) && strata_var %in% names(profiles)) {
    p <- p + ggplot2::facet_wrap(ggplot2::vars(.data[[strata_var]]))
  }

  p
}
