# Surface Derivative Computation
# ============================================================================
#
# Computes numerical derivative surfaces from effectsurf grid data using
# central finite differences. No additional model calls or dependencies.
#
# First order:  dz/dx, dz/dy, gradient magnitude
# Second order: d2z/dx2, d2z/dy2, d2z/dxdy (cross-partial = interaction)
#
# Each derivative is returned as a standard effectsurf object, reusable
# with plot(), surf_contour(), surf_export(), surf_profile(), etc.
# ============================================================================

#' Compute derivative surfaces from an effectsurf object
#'
#' Calculates first-order (gradient) and second-order (curvature, interaction)
#' derivative surfaces using central finite differences on the prediction grid.
#' Each derivative is returned as a standard `effectsurf` object that can be
#' plotted, exported, and analysed with all existing package functions.
#'
#' @param object An [effectsurf][new_effectsurf] object (typically from
#'   [surf_prediction()]).
#' @param order Integer. `1` for first-order derivatives only (gradient),
#'   `2` for both first- and second-order (curvature + interaction).
#'   Default `2`.
#' @param sigdigits Integer. Noise suppression threshold. Derivative values
#'   smaller than `10^(-sigdigits) * max(|z|)` are set to exactly zero.
#'   This removes floating-point artefacts (e.g., `1e-13` instead of `0`)
#'   that arise when finite differences are applied to flat or near-linear
#'   surfaces. Default `10` -- conservative, only removes values below
#'   10 orders of magnitude of the surface range. Set to `NULL` to disable.
#' @param type Character vector specifying which derivatives to compute.
#'   Default `"all"`. Options:
#'   \describe{
#'     \item{`"dzdx"`}{Partial derivative w.r.t. x (dz/dx)}
#'     \item{`"dzdy"`}{Partial derivative w.r.t. y (dz/dy)}
#'     \item{`"gradient"`}{Gradient magnitude sqrt((dz/dx)^2 + (dz/dy)^2)}
#'     \item{`"d2zdx2"`}{Second partial w.r.t. x (d^2z/dx^2) -- curvature in x}
#'     \item{`"d2zdy2"`}{Second partial w.r.t. y (d^2z/dy^2) -- curvature in y}
#'     \item{`"d2zdxdy"`}{Cross-partial (d^2z/dxdy) -- local interaction strength}
#'     \item{`"all"`}{All of the above (filtered by `order`)}
#'   }
#'
#' @return A named list of `effectsurf` objects, one per requested derivative.
#'   Each can be passed to [plot.effectsurf()], [surf_contour()],
#'   [surf_export()], [surf_profile()], etc.
#'
#' @details
#' **Finite difference scheme:** Central differences are used for interior
#' points; forward/backward differences at boundaries. The grid spacing
#' is determined from the effectsurf object's x and y sequences.
#'
#' **Scientific interpretation:**
#' \itemize{
#'   \item **dz/dx, dz/dy**: Local sensitivity of outcome to each predictor.
#'     Regions where the gradient is near zero indicate plateaus or optima.
#'   \item **Gradient magnitude**: Identifies regions of rapid vs stable response.
#'   \item **d^2z/dx^2, d^2z/dy^2**: Curvature. Negative = concave (diminishing
#'     returns); positive = convex (accelerating response). Zero-crossings
#'     locate inflection points.
#'   \item **d^2z/dxdy**: Spatially-resolved interaction strength. Non-zero
#'     values indicate that the effect of x depends on the level of y (and
#'     vice versa) at that specific grid location.
#' }
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
#'   derivs <- surf_derivatives(es)
#'   plot(derivs$dzdx)          # Sensitivity to wt
#'   plot(derivs$gradient)      # Overall sensitivity map
#'   plot(derivs$d2zdxdy)       # Interaction surface
#' }
#' }
surf_derivatives <- function(object,
                             order = 2L,
                             type = "all",
                             sigdigits = 10L) {

  if (!inherits(object, "effectsurf")) {
    cli_abort("{.arg object} must be an {.cls effectsurf} object.")
  }
  order <- as.integer(order)
  if (!order %in% 1:2) {
    cli_abort("{.arg order} must be 1 or 2.")
  }

  # Resolve requested types
  first_types  <- c("dzdx", "dzdy", "gradient")
  second_types <- c("d2zdx2", "d2zdy2", "d2zdxdy")
  all_types <- if (order >= 2L) c(first_types, second_types) else first_types

  if (identical(type, "all")) {
    type <- all_types
  } else {
    bad <- setdiff(type, c(first_types, second_types))
    if (length(bad) > 0L) {
      cli_abort("Unknown derivative type(s): {.val {bad}}")
    }
    if (order == 1L && any(type %in% second_types)) {
      cli_warn("Second-order types requested but {.arg order} = 1. Set {.arg order} = 2.")
      type <- intersect(type, first_types)
    }
  }

  # Convert to matrices
  surf_matrices <- to_surface_matrices(object)
  strata_names <- names(surf_matrices)

  # Grid spacing (constant for regular grid)
  x_vals <- surf_matrices[[1L]]$x
  y_vals <- surf_matrices[[1L]]$y
  dx <- diff(x_vals[1:2])
  dy <- diff(y_vals[1:2])

  x_var <- object$x_var
  y_var <- object$y_var
  x_lab <- object$labels$x
  y_lab <- object$labels$y
  z_lab <- object$labels$z

  # Compute derivatives for each stratum
  results <- list()

  for (dtype in type) {
    # Build data.table with derivative values for all strata
    dt_list <- list()

    for (s in seq_along(strata_names)) {
      z_mat <- surf_matrices[[s]]$z   # rows = y, cols = x (or vice versa)
      nr <- nrow(z_mat)
      nc <- ncol(z_mat)

      deriv_mat <- switch(dtype,
        "dzdx"    = fd_dx(z_mat, dx),
        "dzdy"    = fd_dy(z_mat, dy),
        "gradient" = {
          gx <- fd_dx(z_mat, dx)
          gy <- fd_dy(z_mat, dy)
          sqrt(gx^2 + gy^2)
        },
        "d2zdx2"  = fd_d2x(z_mat, dx),
        "d2zdy2"  = fd_d2y(z_mat, dy),
        "d2zdxdy" = fd_dxdy(z_mat, dx, dy)
      )

      # Two-stage noise suppression for finite-difference artefacts:
      if (!is.null(sigdigits)) {
        z_scale <- max(abs(z_mat), na.rm = TRUE)
        if (z_scale > 0) {
          noise_floor <- 10^(-sigdigits) * z_scale

          # Stage 1: Zero out values that are small relative to the surface
          # (e.g., d2z/dx2 ~= 1e-13 when it should be 0 for a plane)
          deriv_mat[abs(deriv_mat) < noise_floor] <- 0

          # Stage 2: Stabilise effectively-constant matrices.
          # When the VARIATION is below the noise floor but the VALUES are not
          # (e.g., d2z/dxdy = 7.19e-06 +/- 1e-17), the matrix is constant --
          # the tiny variation is machine-epsilon noise from repeated FD ops.
          # Plotly's WebGL renderer culls zero-thickness mesh triangles, so a
          # truly flat surface renders blank. Fix: replace noise with a tiny
          # controlled gradient (+/- 0.1% of the value) so the mesh is renderable
          # while appearing visually flat.
          d_range <- diff(range(deriv_mat, na.rm = TRUE))
          if (d_range > 0 && d_range < noise_floor) {
            center_val <- mean(deriv_mat, na.rm = TRUE)
            # Tiny spread: 0.1% of |value| or 1e-8 if value is near zero
            spread <- max(abs(center_val) * 1e-3, 1e-8)
            nr_d <- nrow(deriv_mat); nc_d <- ncol(deriv_mat)
            # Linear ramp across the grid to give plotly renderable variation
            ramp <- outer(
              seq(-1, 1, length.out = nr_d),
              seq(-1, 1, length.out = nc_d),
              "+"
            ) / 2  # range [-1, 1]
            deriv_mat[] <- center_val + spread * ramp
          }
        }
      }

      # Convert matrix back to long data.table
      dt_s <- matrix_to_dt(deriv_mat, x_vals, y_vals, x_var, y_var)

      if (!is.null(object$strata_var)) {
        dt_s[, (object$strata_var) := strata_names[s]]
      }
      dt_list[[s]] <- dt_s
    }

    dt_all <- data.table::rbindlist(dt_list)
    if (!is.null(object$strata_var)) {
      dt_all[, (object$strata_var) := factor(
        get(object$strata_var), levels = strata_names
      )]
    }

    # Warn if derivative is effectively constant (no spatial variation)
    all_est <- dt_all[["estimate"]]
    if (diff(range(all_est, na.rm = TRUE)) < .Machine$double.eps^0.5 * max(abs(all_est), 1)) {
      val <- signif(all_est[1L], 4)
      cli_inform(c("i" = "{.val {dtype}} is constant ({val}) across the grid.",
                    "*" = "The surface is flat in this derivative -- no spatial variation."))
    }

    # Labels for this derivative type
    deriv_labels <- deriv_label_info(dtype, x_lab, y_lab, z_lab)

    results[[dtype]] <- new_effectsurf(
      data       = dt_all,
      x_var      = x_var,
      y_var      = y_var,
      z_var      = deriv_labels$z_var,
      strata_var = object$strata_var,
      type       = "prediction",
      ci         = FALSE,
      model_info = c(object$model_info, list(derivative = dtype)),
      labels     = list(
        x     = x_lab,
        y     = y_lab,
        z     = deriv_labels$z_lab,
        title = deriv_labels$title
      ),
      transform  = NULL,
      meta       = list(
        derivative_type  = dtype,
        derivative_order = if (dtype %in% first_types) 1L else 2L,
        dx = dx, dy = dy,
        source_type = object$type
      )
    )
  }

  results
}


# ============================================================================
# Finite difference helpers (central differences, forward/backward at edges)
# ============================================================================

#' First partial derivative w.r.t. x (columns)
#' @noRd
fd_dx <- function(z, dx) {
  nr <- nrow(z); nc <- ncol(z)
  dz <- matrix(NA_real_, nr, nc)
  # Central differences for interior
  if (nc >= 3L) {
    dz[, 2:(nc - 1)] <- (z[, 3:nc] - z[, 1:(nc - 2)]) / (2 * dx)
  }
  # Forward/backward at edges
  dz[, 1]  <- (z[, 2] - z[, 1]) / dx
  dz[, nc] <- (z[, nc] - z[, nc - 1]) / dx
  dz
}

#' First partial derivative w.r.t. y (rows)
#' @noRd
fd_dy <- function(z, dy) {
  nr <- nrow(z); nc <- ncol(z)
  dz <- matrix(NA_real_, nr, nc)
  if (nr >= 3L) {
    dz[2:(nr - 1), ] <- (z[3:nr, ] - z[1:(nr - 2), ]) / (2 * dy)
  }
  dz[1, ]  <- (z[2, ] - z[1, ]) / dy
  dz[nr, ] <- (z[nr, ] - z[nr - 1, ]) / dy
  dz
}

#' Second partial derivative w.r.t. x
#' @noRd
fd_d2x <- function(z, dx) {
  nr <- nrow(z); nc <- ncol(z)
  dz <- matrix(NA_real_, nr, nc)
  if (nc >= 3L) {
    dz[, 2:(nc - 1)] <- (z[, 3:nc] - 2 * z[, 2:(nc - 1)] + z[, 1:(nc - 2)]) / (dx^2)
  }
  # Edge: use same as nearest interior
  dz[, 1]  <- dz[, 2]
  dz[, nc] <- dz[, nc - 1]
  dz
}

#' Second partial derivative w.r.t. y
#' @noRd
fd_d2y <- function(z, dy) {
  nr <- nrow(z); nc <- ncol(z)
  dz <- matrix(NA_real_, nr, nc)
  if (nr >= 3L) {
    dz[2:(nr - 1), ] <- (z[3:nr, ] - 2 * z[2:(nr - 1), ] + z[1:(nr - 2), ]) / (dy^2)
  }
  dz[1, ]  <- dz[2, ]
  dz[nr, ] <- dz[nr - 1, ]
  dz
}

#' Cross partial derivative d2z/dxdy
#' @noRd
fd_dxdy <- function(z, dx, dy) {
  # d2z/dxdy: apply dy to (dz/dx)
  dzdx <- fd_dx(z, dx)
  fd_dy(dzdx, dy)
}


# ============================================================================
# Helper: matrix -> long data.table
# ============================================================================

#' @noRd
matrix_to_dt <- function(mat, x_vals, y_vals, x_var, y_var) {
  # mat: rows correspond to y_vals, columns to x_vals
  # CJ sorts y-slow/x-fast; t(mat) vectorises to the same order
  dt <- data.table::CJ(y = y_vals, x = x_vals)
  data.table::setnames(dt, c("y", "x"), c(y_var, x_var))
  dt[, estimate := as.vector(t(mat))]
  dt
}


# ============================================================================
# Helper: labels for each derivative type
# ============================================================================

#' @noRd
deriv_label_info <- function(dtype, x_lab, y_lab, z_lab) {
  switch(dtype,
    "dzdx" = list(
      z_var  = paste0("d_", z_lab, "_d_", x_lab),
      z_lab  = bquote(paste(partialdiff, .(z_lab), " / ", partialdiff, .(x_lab))),
      title  = paste0("Sensitivity: ", z_lab, " w.r.t. ", x_lab)
    ),
    "dzdy" = list(
      z_var  = paste0("d_", z_lab, "_d_", y_lab),
      z_lab  = bquote(paste(partialdiff, .(z_lab), " / ", partialdiff, .(y_lab))),
      title  = paste0("Sensitivity: ", z_lab, " w.r.t. ", y_lab)
    ),
    "gradient" = list(
      z_var  = paste0("gradient_", z_lab),
      z_lab  = paste0("|", "\u2207", z_lab, "|"),
      title  = paste0("Gradient magnitude: ", z_lab)
    ),
    "d2zdx2" = list(
      z_var  = paste0("d2_", z_lab, "_d_", x_lab, "2"),
      z_lab  = bquote(paste(partialdiff^2, .(z_lab), " / ", partialdiff, .(x_lab)^2)),
      title  = paste0("Curvature in ", x_lab, ": ", z_lab)
    ),
    "d2zdy2" = list(
      z_var  = paste0("d2_", z_lab, "_d_", y_lab, "2"),
      z_lab  = bquote(paste(partialdiff^2, .(z_lab), " / ", partialdiff, .(y_lab)^2)),
      title  = paste0("Curvature in ", y_lab, ": ", z_lab)
    ),
    "d2zdxdy" = list(
      z_var  = paste0("d2_", z_lab, "_d_", x_lab, "_d_", y_lab),
      z_lab  = bquote(paste(partialdiff^2, .(z_lab), " / ", partialdiff, .(x_lab), partialdiff, .(y_lab))),
      title  = paste0("Interaction: ", x_lab, " \u00d7 ", y_lab, " on ", z_lab)
    )
  )
}
