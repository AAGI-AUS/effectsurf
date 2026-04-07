# 2D Contour Projections
# ============================================================================

#' Create a 2D contour/heatmap from a 3D surface
#'
#' Projects the 3D prediction surface into a 2D contour plot or filled
#' heatmap. Useful for publication-ready static figures.
#'
#' @param object An [effectsurf][new_effectsurf] object.
#' @param type Character. `"contour"` (default) for contour lines,
#'   `"heatmap"` for a filled heatmap.
#' @param nlevels Integer. Number of contour levels. Default 10.
#' @param colourscale Character. Colour palette name for fill. Default
#'   `"Viridis"`.
#' @param interactive Logical. If `TRUE` (default), returns an interactive
#'   Plotly widget. If `FALSE` and `ggplot2` is available, returns a ggplot.
#' @param ... Additional arguments passed to Plotly or ggplot functions.
#'
#' @return A `plotly` widget or `ggplot` object.
#'
#' @export
#'
#' @examples
#' \donttest{
#' if (requireNamespace("mgcv", quietly = TRUE)) {
#'   model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
#'   es <- surf_prediction(model, x = "wt", y = "hp",
#'                         x_length = 30, y_length = 30)
#'   surf_contour(es, type = "heatmap")
#' }
#' }
surf_contour <- function(object,
                         type = c("contour", "heatmap"),
                         nlevels = 10L,
                         colourscale = "Viridis",
                         interactive = TRUE,
                         ...) {

  if (!inherits(object, "effectsurf")) {
    cli_abort("{.arg object} must be an {.cls effectsurf} object.")
  }

  type <- match.arg(type)
  surf_matrices <- to_surface_matrices(object)

  if (interactive) {
    return(render_contour_plotly(
      object, surf_matrices, type, nlevels, colourscale
    ))
  }

  if (rlang::is_installed("ggplot2")) {
    return(render_contour_ggplot(object, type, nlevels))
  }

  cli_abort(
    "Non-interactive contour requires {.pkg ggplot2}. ",
    "Install it or set {.arg interactive = TRUE}."
  )
}


#' Plotly contour rendering
#' @noRd
render_contour_plotly <- function(object, surf_matrices, type,
                                  nlevels, colourscale) {
  is_stratified <- length(surf_matrices) > 1L

  if (!is_stratified) {
    mat <- surf_matrices[[1L]]
    if (type == "heatmap") {
      p <- plotly::plot_ly(
        x = mat$x, y = mat$y, z = mat$z,
        type = "heatmap", colorscale = colourscale,
        colorbar = list(title = object$labels$z)
      )
    } else {
      p <- plotly::plot_ly(
        x = mat$x, y = mat$y, z = mat$z,
        type = "contour", colorscale = colourscale,
        ncontours = nlevels,
        colorbar = list(title = object$labels$z)
      )
    }
  } else {
    # For stratified data, use subplot with facets
    p <- plotly::plot_ly()
    for (nm in names(surf_matrices)) {
      mat <- surf_matrices[[nm]]
      p <- p |>
        plotly::add_contour(
          x = mat$x, y = mat$y, z = mat$z,
          name = nm, ncontours = nlevels,
          showscale = (nm == names(surf_matrices)[1L])
        )
    }
  }

  p <- p |>
    plotly::layout(
      title = object$labels$title,
      xaxis = list(title = object$labels$x),
      yaxis = list(title = object$labels$y)
    )

  p
}


#' ggplot2 contour rendering
#' @noRd
render_contour_ggplot <- function(object, type, nlevels) {
  ggplot2 <- asNamespace("ggplot2")
  dt <- copy(object$data)

  if (!is.null(object$transform)) {
    dt[, estimate := object$transform(estimate)]
  }

  p <- ggplot2::ggplot(
    dt,
    ggplot2::aes(x = .data[[object$x_var]], y = .data[[object$y_var]],
                 z = .data[["estimate"]])
  )

  if (type == "heatmap") {
    p <- p +
      ggplot2::geom_tile(
        ggplot2::aes(fill = .data[["estimate"]])
      ) +
      ggplot2::scale_fill_viridis_c()
  } else {
    p <- p +
      ggplot2::geom_contour_filled(bins = nlevels) +
      ggplot2::scale_fill_viridis_d()
  }

  p <- p +
    ggplot2::labs(
      x = object$labels$x,
      y = object$labels$y,
      fill = object$labels$z,
      title = object$labels$title
    ) +
    ggplot2::theme_minimal(base_size = 12L)

  if (!is.null(object$strata_var)) {
    p <- p + ggplot2::facet_wrap(ggplot2::vars(.data[[object$strata_var]]))
  }

  p
}
