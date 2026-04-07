# Post-Prediction Surface Smoothing via mgcv
# ============================================================================
#
# Provides GAM-based smoothing of prediction surfaces from non-smooth models
# (e.g., random forests, boosted trees, MARS). Fits mgcv::gam() as a surrogate
# to the predicted values on the grid, producing smooth visual approximations.
#
# This is a post-estimation technique: the original model's predictions are
# computed first, then smoothed for visualisation. The underlying model is
# never re-fitted.
# ============================================================================

#' Resolve smooth parameter to a standardised options list
#'
#' Normalises the user-facing `smooth` argument (NULL, TRUE, or list)
#' into a consistent options list for internal use.
#'
#' @param smooth NULL (no smoothing), TRUE (auto), or a named list with
#'   optional elements: `k`, `bs`, `smooth_ci`.
#' @return NULL (no smoothing) or a named list with `k`, `bs`, `smooth_ci`.
#' @noRd
resolve_smooth_opts <- function(smooth) {
  if (is.null(smooth) || identical(smooth, FALSE)) {
    return(NULL)
  }

  # Default options: k = -1 matches mgcv::s() auto-selection

  defaults <- list(
    k         = -1L,
    bs        = "tp",
    smooth_ci = TRUE
  )

  if (isTRUE(smooth)) {
    return(defaults)
  }

  if (is.list(smooth)) {
    valid_names <- c("k", "bs", "smooth_ci")
    bad <- setdiff(names(smooth), valid_names)
    if (length(bad) > 0L) {
      cli_warn("Unknown smooth option(s) ignored: {.val {bad}}")
    }
    for (nm in valid_names) {
      if (nm %in% names(smooth)) {
        defaults[[nm]] <- smooth[[nm]]
      }
    }
    return(defaults)
  }

  cli_abort(
    "{.arg smooth} must be NULL, TRUE, or a named list ",
    "(e.g., {.code list(k = 15, bs = \"tp\")})."
  )
}


#' Apply GAM smoothing to effectsurf prediction data
#'
#' Fits a `mgcv::gam()` with `te(x, y)` to the predicted surface values,
#' replacing the original predictions with the smooth approximation.
#' When strata are present, a separate smooth is fitted per stratum.
#'
#' @param data A `data.table` with columns for x, y, `estimate`, and
#'   optionally `conf.low`, `conf.high`, and a strata variable.
#' @param x_var Character. Name of the x variable.
#' @param y_var Character. Name of the y variable.
#' @param strata_var Character or NULL. Name of stratification variable.
#' @param smooth_opts A list from `resolve_smooth_opts()` with `k`, `bs`,
#'   `smooth_ci`.
#' @return The input `data.table`, modified in place with smoothed values.
#' @noRd
smooth_surface_data <- function(data, x_var, y_var, strata_var, smooth_opts) {
  rlang::check_installed("mgcv", reason = "for surface smoothing (smooth = TRUE).")

  k  <- smooth_opts$k
  bs <- smooth_opts$bs
  smooth_ci <- smooth_opts$smooth_ci

  # Determine strata

  if (!is.null(strata_var) && strata_var %in% names(data)) {
    strata_levels <- unique(data[[strata_var]])
  } else {
    strata_levels <- NULL
  }

  # Build formula: estimate ~ te(x, y, k = k, bs = bs)
  # Use te() to capture full interaction surface
  te_call <- if (identical(k, -1L) || identical(k, -1)) {
    sprintf("te(%s, %s, bs = \"%s\")", x_var, y_var, bs)
  } else {
    sprintf("te(%s, %s, k = %s, bs = \"%s\")", x_var, y_var,
            deparse(k), bs)
  }
  base_formula <- stats::as.formula(paste("estimate ~", te_call))

  # Columns to smooth
  smooth_cols <- "estimate"
  has_ci <- all(c("conf.low", "conf.high") %in% names(data))
  if (smooth_ci && has_ci) {
    smooth_cols <- c(smooth_cols, "conf.low", "conf.high")
  }

  # Smooth function for a single data subset
  smooth_one <- function(dt_sub) {
    df_sub <- as.data.frame(dt_sub)

    for (col in smooth_cols) {
      # Build formula for this column
      if (col == "estimate") {
        fml <- base_formula
      } else {
        fml <- stats::as.formula(
          paste(col, "~", te_call)
        )
      }

      gam_fit <- mgcv::gam(fml, data = df_sub)
      dt_sub[, (col) := predict(gam_fit, newdata = df_sub)]
    }

    # Ensure conf.low <= estimate <= conf.high after smoothing
    if (smooth_ci && has_ci) {
      dt_sub[conf.low > estimate, conf.low := estimate]
      dt_sub[conf.high < estimate, conf.high := estimate]
    }

    dt_sub
  }

  cli_inform(c(
    "i" = "Surface smoothed via {.fn mgcv::gam} surrogate.",
    "*" = "Smooth: {.code {te_call}}",
    "*" = "Predictions are approximate -- not raw model output."
  ))

  if (is.null(strata_levels)) {
    # No strata: smooth entire dataset
    data <- smooth_one(data)
  } else {
    # Smooth each stratum independently
    for (s in strata_levels) {
      idx <- data[[strata_var]] == s
      sub <- data[idx]
      smoothed <- smooth_one(sub)
      # Write back
      for (col in smooth_cols) {
        data[idx, (col) := smoothed[[col]]]
      }
    }
  }

  data
}
