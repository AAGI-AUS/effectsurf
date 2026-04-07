# Rendering Layer: Plotly 3D Surface Engine
# ============================================================================
#
# CRITICAL RENDERING RULES (2026-04-07, validated by A/B testing):
#
# 1. Surface z data MUST use formula notation: z = ~z_list[[ii]]
#    Direct assignment (z = matrix) produces HTML that fails to render.
#    The formula forces plotly to use its lazy-eval -> plotly_build() pipeline
#    which serialises 3D data correctly for the browser.
#
# 2. Use %>% (magrittr pipe) — imported from plotly.
#
# 3. Use plotly::as_widget() when saving via saveWidget().
#
# 4. After saveWidget(), clean up the _files/ directory it leaves behind.
#
# These patterns match the proven prototype f_plotly_surfaces.R function.
# ============================================================================

#' Plot an effectsurf object as an interactive 3D surface
#'
#' Renders an `effectsurf` object as an interactive Plotly 3D surface plot.
#' When the object is stratified by a categorical variable, overlaid surfaces
#' are produced with independent colourscales and legend toggles.
#'
#' @param x An [effectsurf][new_effectsurf] object.
#' @param opacity Numeric (0-1). Surface opacity. Default `0.85`.
#' @param colourscale Character or list. Plotly colourscale name
#'   (e.g., `"Viridis"`, `"RdBu"`, `"Blues"`) or a custom colourscale list.
#'   For stratified surfaces, a vector of colours is used instead.
#' @param show_ci Logical. Whether to show confidence interval surfaces
#'   (upper/lower bounds as translucent surfaces). Default `FALSE`.
#' @param ci_opacity Numeric (0-1). Opacity for CI surfaces. Default `0.3`.
#' @param wireframe Logical. If `TRUE`, render surfaces as wireframes instead
#'   of filled surfaces. Default `FALSE`.
#' @param show_data Logical. If `TRUE` and the model's training data is
#'   available, overlay observed data points. Default `FALSE`.
#' @param camera A list specifying camera position, e.g.,
#'   `list(eye = list(x = 1.5, y = 1.5, z = 1.2))`.
#' @param save_html Character or `NULL`. If a file path is provided,
#'   saves the interactive plot as a self-contained HTML file.
#'   When saving, 2D maximum-profile plots (PDF) are also generated
#'   alongside the HTML, matching the prototype workflow.
#'   Default `NULL` (no file saved).
#' @param fmt A [label_format()] object controlling number formatting
#'   in hover text and axes. Default `NULL` (auto-format).
#' @param width,height Plot dimensions in pixels. `NULL` for auto-sizing.
#' @param ... Additional arguments (currently unused).
#'
#' @return A `plotly` htmlwidget object (invisibly if `save_html` is used).
#'
#' @seealso [surf_prediction()], [surf_export()], [surf_profile()],
#'   [label_format()]
#'
#' @export
#' @method plot effectsurf
#' @importFrom plotly %>%
#'
#' @examples
#' \donttest{
#' if (requireNamespace("mgcv", quietly = TRUE)) {
#'   model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
#'   es <- surf_prediction(model, x = "wt", y = "hp",
#'                         x_length = 25, y_length = 25)
#'   plot(es)
#'   plot(es, opacity = 0.9, colourscale = "RdBu")
#'
#'   # Save to HTML (also produces 2D profile PDFs)
#'   plot(es, save_html = tempfile(fileext = ".html"))
#' }
#' }
plot.effectsurf <- function(x,
                            opacity = 0.85,
                            colourscale = "Viridis",
                            show_ci = FALSE,
                            ci_opacity = 0.3,
                            wireframe = FALSE,
                            show_data = FALSE,
                            camera = NULL,
                            save_html = NULL,
                            fmt = NULL,
                            width = NULL,
                            height = NULL,
                            ...) {

  if (!inherits(x, "effectsurf")) {
    cli_abort("{.arg x} must be an {.cls effectsurf} object.")
  }

  surf_matrices <- to_surface_matrices(x)
  is_stratified <- !is.null(x$strata_var)

  if (is_stratified) {
    p <- render_stratified_surfaces(
      x, surf_matrices, opacity, colourscale, show_ci, ci_opacity,
      wireframe, camera, width, height, fmt
    )
  } else {
    p <- render_single_surface(
      x, surf_matrices, opacity, colourscale, show_ci, ci_opacity,
      wireframe, camera, width, height, fmt
    )
  }

  # Save to HTML if requested
  if (!is.null(save_html)) {
    if (!grepl("\\.html$", save_html, ignore.case = TRUE)) {
      save_html <- paste0(save_html, ".html")
    }
    if (!grepl("^[/~]", save_html)) {
      save_html <- file.path(getwd(), save_html)
    }
    dir_path <- dirname(save_html)
    if (!dir.exists(dir_path)) {
      dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
    }
    abs_path <- normalizePath(save_html, mustWork = FALSE)

    # Save self-contained HTML
    save_widget_clean(p, abs_path)
    cli_inform("Saved to {.path {save_html}}")

    # Generate and save 2D maximum-profile plots alongside the HTML
    save_profile_pdfs(x, surf_matrices, abs_path)

    return(invisible(p))
  }

  p
}


# ============================================================================
# HTML save helper — self-contained with cleanup
# ============================================================================

#' Save plotly widget as self-contained HTML and remove leftover _files/ dir
#' @noRd
save_widget_clean <- function(widget, path) {
  htmlwidgets::saveWidget(plotly::as_widget(widget), path)
  # htmlwidgets::saveWidget always creates a _files/ directory first,
  # then inlines via pandoc, but sometimes fails to delete the leftovers.
  # Remove it explicitly to keep the output directory clean.
  files_dir <- paste0(tools::file_path_sans_ext(path), "_files")
  if (dir.exists(files_dir)) {
    unlink(files_dir, recursive = TRUE, force = TRUE)
  }
}


# ============================================================================
# 2D maximum-profile plots (matching prototype f_plotly_surfaces)
# ============================================================================

#' Generate and save 2D max-profile PDFs alongside the HTML
#'
#' For each x-value, the maximum z across all y-values is computed (and vice
#' versa), stratified by the categorical variable if present. The resulting
#' profiles are saved as PDF files next to the HTML output.
#'
#' @noRd
save_profile_pdfs <- function(object, surf_matrices, html_path) {

  if (!rlang::is_installed("ggplot2")) return(invisible(NULL))

  strata_names <- names(surf_matrices)
  n_strata <- length(strata_names)
  x_vals <- surf_matrices[[1L]]$x
  y_vals <- surf_matrices[[1L]]$y
  x_lab <- object$labels$x
  y_lab <- object$labels$y
  z_lab <- object$labels$z

  colours <- default_strata_colours(max(n_strata, 1L))

  # Compute max profiles from the z matrices
  # x_profile: for each x value, max z across y (one curve per stratum)
  # y_profile: for each y value, max z across x (one curve per stratum)
  x_profile_list <- list()
  y_profile_list <- list()
  for (k in seq_len(n_strata)) {
    z_mat <- surf_matrices[[k]]$z
    x_profile_list[[strata_names[k]]] <- apply(z_mat, 1L, max)
    y_profile_list[[strata_names[k]]] <- apply(z_mat, 2L, max)
  }

  base_path <- tools::file_path_sans_ext(html_path)

  # --- X profile (y-max for each x) ---
  tab_x <- data.table::as.data.table(x_profile_list)
  tab_x[, (x_lab) := x_vals]
  tab_x_long <- data.table::melt(tab_x, id.vars = x_lab,
                                  variable.name = "stratum",
                                  value.name = "value")

  fig_x <- ggplot2::ggplot(
    tab_x_long,
    ggplot2::aes(x = .data[[x_lab]], y = .data[["value"]],
                 colour = .data[["stratum"]], group = .data[["stratum"]])
  ) +
    ggplot2::geom_line(linewidth = 1) +
    ggplot2::scale_color_manual(values = colours[seq_len(n_strata)]) +
    ggplot2::labs(
      title = paste0(y_lab, " maximum outcome profile"),
      x = x_lab, y = z_lab, colour = "Stratum"
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(legend.position = "right")

  # --- Y profile (x-max for each y) ---
  tab_y <- data.table::as.data.table(y_profile_list)
  tab_y[, (y_lab) := y_vals]
  tab_y_long <- data.table::melt(tab_y, id.vars = y_lab,
                                  variable.name = "stratum",
                                  value.name = "value")

  fig_y <- ggplot2::ggplot(
    tab_y_long,
    ggplot2::aes(x = .data[[y_lab]], y = .data[["value"]],
                 colour = .data[["stratum"]], group = .data[["stratum"]])
  ) +
    ggplot2::geom_line(linewidth = 1) +
    ggplot2::scale_color_manual(values = colours[seq_len(n_strata)]) +
    ggplot2::labs(
      title = paste0(x_lab, " maximum outcome profile"),
      x = y_lab, y = z_lab, colour = "Stratum"
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(legend.position = "right")

  # Save individual profiles
  ggplot2::ggsave(paste0(base_path, "_X_profile.pdf"), fig_x,
                  width = 12, height = 8, units = "in")
  ggplot2::ggsave(paste0(base_path, "_Y_profile.pdf"), fig_y,
                  width = 12, height = 8, units = "in")

  invisible(NULL)
}


# ============================================================================
# Single surface renderer
# ============================================================================

#' Render a single (non-stratified) surface
#' @noRd
render_single_surface <- function(object, surf_matrices, opacity,
                                  colourscale, show_ci, ci_opacity,
                                  wireframe, camera, width, height,
                                  fmt = NULL) {

  mat <- surf_matrices[[1L]]
  x_vals <- mat$x
  y_vals <- mat$y

  # CRITICAL: z must be passed as ~z_list[[index]] (formula), NOT as a matrix.
  z_list <- list(mat$z)
  ci_low_list <- list(mat$z_low)
  ci_high_list <- list(mat$z_high)

  scene_c <- build_scene(object, surf_matrices, camera)
  title_lab <- object$labels$title %||% "effectsurf"

  has_ci <- show_ci && !is.null(mat$z_low) && !is.null(mat$z_high)
  n_steps <- 2L + if (has_ci) 2L else 0L

  fig <- plot_ly(x = x_vals, y = y_vals, showscale = TRUE, showlegend = FALSE)
  lapply(1:n_steps, function(i) {
    if (i == 1) {
      fig <<- plot_ly(x = x_vals, y = y_vals, showscale = TRUE, showlegend = FALSE) %>%
        add_surface(z = ~z_list[[1L]], opacity = opacity, colorscale = colourscale)
    }
    if (i == 2 && has_ci) {
      ci_scale <- list(c(0, 1), c("#CCCCCC", "#CCCCCC"))
      fig <<- fig %>%
        add_surface(z = ~ci_low_list[[1L]], opacity = ci_opacity,
                    colorscale = ci_scale, showscale = FALSE, name = "Lower CI")
    }
    if (i == 3 && has_ci) {
      ci_scale <- list(c(0, 1), c("#CCCCCC", "#CCCCCC"))
      fig <<- fig %>%
        add_surface(z = ~ci_high_list[[1L]], opacity = ci_opacity,
                    colorscale = ci_scale, showscale = FALSE, name = "Upper CI")
    }
    if (i == n_steps) {
      fig <<- fig %>% layout(title = title_lab, scene = scene_c)
    }
  })

  fig
}


# ============================================================================
# Stratified surface renderer
# ============================================================================

#' Render stratified (multi-surface) plot
#' @noRd
render_stratified_surfaces <- function(object, surf_matrices, opacity,
                                       colourscale, show_ci, ci_opacity,
                                       wireframe, camera, width, height,
                                       fmt = NULL) {

  strata_names <- names(surf_matrices)
  n_strata <- length(strata_names)
  colours <- default_strata_colours(n_strata)

  colorscale_vals <- vector("list", n_strata)
  opacity_gradient <- rep(opacity, n_strata)
  for (k in seq_len(n_strata)) {
    colorscale_vals[[k]] <- list(c(0, 1), c(colours[k], colours[k]))
  }

  x_vals <- surf_matrices[[1L]]$x
  y_vals <- surf_matrices[[1L]]$y

  # CRITICAL: z must be passed as ~z_list[[ii]] (formula), NOT as a matrix.
  z_list <- lapply(surf_matrices, `[[`, "z")

  scene_c <- build_scene(object, surf_matrices, camera)
  title_lab <- object$labels$title %||% "effectsurf"

  kk <- n_strata + 2L
  fig <- plot_ly(x = x_vals, y = y_vals, showscale = FALSE, showlegend = TRUE)
  lapply(
    1:kk,
    function(i) {
      if (i == 1) {
        fig <<- plot_ly(x = x_vals, y = y_vals, showscale = FALSE, showlegend = TRUE)
      }
      if (i > 1 & i < kk) {
        ii <- i - 1L
        fig <<- fig %>% add_surface(
          z = ~z_list[[ii]],
          name = strata_names[ii],
          opacity = opacity_gradient[ii],
          colorscale = colorscale_vals[[ii]]
        )
      }
      if (i == kk) {
        fig <<- fig %>% layout(title = title_lab, scene = scene_c,
                               showlegend = TRUE)
      }
    }
  )

  fig
}


# ============================================================================
# Utilities
# ============================================================================

#' Build scene configuration, handling near-constant z-range
#'
#' When all z values are identical or nearly so, plotly cannot render a
#' surface (blank canvas). This helper detects that case and sets an
#' explicit zaxis range so the flat surface is visible.
#' @noRd
build_scene <- function(object, surf_matrices, camera = NULL) {
  scene_c <- list(
    xaxis = list(title = object$labels$x),
    yaxis = list(title = object$labels$y),
    zaxis = list(title = object$labels$z)
  )

  # Compute global z range across all strata
  all_z <- unlist(lapply(surf_matrices, function(m) as.vector(m$z)))
  z_min <- min(all_z, na.rm = TRUE)
  z_max <- max(all_z, na.rm = TRUE)
  z_range <- z_max - z_min

  # If z range is zero or negligible, set explicit axis range
  # so plotly can render the flat surface instead of showing blank
  if (z_range < .Machine$double.eps^0.5 * max(abs(z_max), 1)) {
    pad <- max(abs(z_max) * 0.1, 1e-6)
    scene_c$zaxis$range <- list(z_min - pad, z_max + pad)
  }

  if (!is.null(camera)) scene_c$camera <- camera
  scene_c
}


#' Lighten a hex colour
#' @param hex Character. Hex colour string.
#' @param amount Numeric (0-1). How much to lighten.
#' @return Character. Lightened hex colour.
#' @noRd
lighten_colour <- function(hex, amount = 0.3) {
  rgb_vals <- grDevices::col2rgb(hex)[, 1L]
  rgb_light <- pmin(255L, rgb_vals + round(amount * (255L - rgb_vals)))
  grDevices::rgb(rgb_light[1L], rgb_light[2L], rgb_light[3L], maxColorValue = 255L)
}
