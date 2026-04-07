# Computation Layer: Predictions on Grid
# ============================================================================

#' Generate predictions on a grid
#'
#' Computes model predictions (with optional confidence intervals) on a
#' prediction grid. Uses [marginaleffects::predictions()] as the primary
#' backend, with a fallback to [stats::predict()].
#'
#' @param model A fitted model object.
#' @param grid A `data.frame` or `data.table` prediction grid, typically
#'   produced by [ems_grid()].
#' @param ci Logical. Whether to compute confidence intervals. Default `TRUE`.
#' @param level Numeric. Confidence level for intervals. Default `0.95`.
#' @param vcov Variance-covariance specification passed to
#'   [marginaleffects::predictions()]. Use `FALSE` for fast predictions
#'   without standard errors.
#' @param predict_fun A custom prediction function with signature
#'   `function(model, newdata)` returning a numeric vector. If supplied,
#'   bypasses both `marginaleffects` and `predict()`.
#' @param method Character. One of `"marginaleffects"` (default), `"gratia"`,
#'   or `"predict"`.
#' @param ... Additional arguments passed to the prediction backend.
#'
#' @return A `data.table` with the grid columns plus `estimate`,
#'   and optionally `std.error`, `conf.low`, `conf.high`.
#' @export
ems_predict <- function(model,
                        grid,
                        ci = TRUE,
                        level = 0.95,
                        vcov = NULL,
                        predict_fun = NULL,
                        method = c("marginaleffects", "emmeans", "gratia", "predict"),
                        ...) {

  method <- match.arg(method)
  grid <- as.data.table(grid)

  # Custom predict function takes priority
  if (!is.null(predict_fun)) {
    return(ems_predict_custom(model, grid, predict_fun, ...))
  }

  # Dispatch to backend
  result <- switch(
    method,
    marginaleffects = ems_predict_marginaleffects(
      model, grid, ci, level, vcov, ...
    ),
    emmeans = ems_predict_emmeans(model, grid, ci, level, ...),
    gratia = ems_predict_gratia(model, grid, ci, level, ...),
    predict = ems_predict_base(model, grid, ci, level, ...)
  )

  as.data.table(result)
}


#' Predictions via marginaleffects
#' @noRd
ems_predict_marginaleffects <- function(model, grid, ci, level, vcov, ...) {
  pred_args <- list(
    model = model,
    newdata = as.data.frame(grid),
    conf_level = level
  )

  if (!is.null(vcov)) {
    pred_args$vcov <- vcov
  }
  if (!ci) {
    pred_args$vcov <- FALSE
  }

  preds <- do.call(marginaleffects::predictions, pred_args)
  preds_dt <- as.data.table(preds)

  # Keep grid columns plus prediction columns
  grid_cols <- names(grid)
  pred_cols <- intersect(
    c("estimate", "std.error", "conf.low", "conf.high"),
    names(preds_dt)
  )

  keep_cols <- unique(c(grid_cols, pred_cols))
  keep_cols <- intersect(keep_cols, names(preds_dt))

  result <- preds_dt[, ..keep_cols]

  # If marginaleffects doesn't produce CI columns and ci = FALSE, that's fine

  # If ci = TRUE but no CI columns, warn
  if (ci && !all(c("conf.low", "conf.high") %in% names(result))) {
    cli_warn(
      "Confidence intervals requested but not available from the model. ",
      "Try setting {.arg vcov} explicitly."
    )
  }

  result
}


#' Predictions via emmeans
#'
#' Uses emmeans::emmeans() to compute predictions on the grid.
#' Typically 1.5-2.5x faster than marginaleffects for GAMs.
#' @noRd
ems_predict_emmeans <- function(model, grid, ci, level, ...) {
  rlang::check_installed("emmeans",
                         reason = "for emmeans-based predictions.")

  # Identify focal variables: those with >1 unique value in the grid
  # (excludes reference-value columns like random effects held at a constant)
  grid_cols <- names(grid)
  focal_cols <- vapply(grid_cols, function(v) {
    length(unique(grid[[v]])) > 1L
  }, logical(1L))
  focal_vars <- grid_cols[focal_cols]

  if (length(focal_vars) == 0L) {
    cli_abort("No varying columns in the grid for emmeans.")
  }

  # Build the at= list from only the focal variables
  at_list <- lapply(focal_vars, function(v) {
    vals <- grid[[v]]
    if (is.factor(vals) || is.character(vals)) {
      unique(as.character(vals))
    } else if (is.numeric(vals)) {
      sort(unique(vals))
    } else {
      unique(vals)
    }
  })
  names(at_list) <- focal_vars

  # Build emmeans formula: ~ var1 * var2 * ...
  em_formula <- stats::as.formula(paste("~", paste(focal_vars, collapse = " * ")))

  # Raise rg.limit: emmeans expands ALL factor levels in the model internally,
  # not just the focal ones, so the reference grid can be much larger than the
  # user's prediction grid. Set to 500K to cover complex multi-factor GAMs.
  old_opt <- getOption("emmeans")
  emmeans::emm_options(rg.limit = 500000L)
  on.exit(options(emmeans = old_opt), add = TRUE)

  em <- emmeans::emmeans(
    model, em_formula,
    at = at_list,
    level = level,
    type = "response",
    ...
  )

  em_dt <- as.data.table(as.data.frame(em))

  # Map emmeans column names to effectsurf convention
  # emmeans uses: emmean/response, SE, lower.CL, upper.CL (or asymp.LCL/asymp.UCL)
  name_map <- c(
    "emmean"    = "estimate",
    "response"  = "estimate",
    "prediction" = "estimate",
    "SE"        = "std.error",
    "lower.CL"  = "conf.low",
    "upper.CL"  = "conf.high",
    "asymp.LCL" = "conf.low",
    "asymp.UCL" = "conf.high"
  )

  for (old in names(name_map)) {
    if (old %in% names(em_dt)) {
      data.table::setnames(em_dt, old, name_map[[old]], skip_absent = TRUE)
    }
  }

  pred_cols <- intersect(
    c("estimate", "std.error", "conf.low", "conf.high"),
    names(em_dt)
  )
  keep_cols <- intersect(c(focal_vars, pred_cols), names(em_dt))
  result <- em_dt[, ..keep_cols]

  if (!ci) {
    for (col in intersect(c("std.error", "conf.low", "conf.high"), names(result))) {
      result[, (col) := NULL]
    }
  }

  result
}


#' Predictions via gratia (for mgcv models)
#' @noRd
ems_predict_gratia <- function(model, grid, ci, level, ...) {
  rlang::check_installed("gratia",
                         reason = "for gratia-based predictions.")

  if (!inherits(model, c("gam", "bam"))) {
    cli_warn(
      "gratia prediction method is for {.cls gam}/{.cls bam} models. ",
      "Falling back to marginaleffects."
    )
    return(ems_predict_marginaleffects(model, grid, ci, level, vcov = NULL, ...))
  }

  # Use gratia::fitted_values for predictions with CIs
  fv <- gratia::fitted_values(
    model,
    data = as.data.frame(grid),
    scale = "response"
  )

  fv_dt <- as.data.table(fv)

  # Rename gratia columns to effectsurf convention
  col_map <- c(
    ".fitted"  = "estimate",
    ".se"      = "std.error",
    ".lower_ci" = "conf.low",
    ".upper_ci" = "conf.high"
  )

  for (old_name in names(col_map)) {
    if (old_name %in% names(fv_dt)) {
      data.table::setnames(fv_dt, old_name, col_map[[old_name]])
    }
  }

  # Merge with grid to keep all original columns
  grid_cols <- names(grid)
  pred_cols <- intersect(
    c("estimate", "std.error", "conf.low", "conf.high"),
    names(fv_dt)
  )

  # Combine grid columns with predictions
  result <- cbind(grid, fv_dt[, ..pred_cols])

  if (!ci) {
    result[, c("std.error", "conf.low", "conf.high") := NULL]
  }

  result
}


#' Predictions via base predict()
#' @noRd
ems_predict_base <- function(model, grid, ci, level, ...) {
  grid_df <- as.data.frame(grid)

  # Try predict with se.fit
  if (ci) {
    pred <- tryCatch(
      stats::predict(model, newdata = grid_df, se.fit = TRUE, ...),
      error = function(e) NULL
    )

    if (!is.null(pred) && is.list(pred)) {
      result <- copy(grid)
      result[, estimate := pred$fit]
      if (!is.null(pred$se.fit)) {
        z_val <- stats::qnorm(1 - (1 - level) / 2)
        result[, std.error := pred$se.fit]
        result[, conf.low := estimate - z_val * std.error]
        result[, conf.high := estimate + z_val * std.error]
      }
      return(result)
    }
  }

  # Simple predict without SE
  pred <- stats::predict(model, newdata = grid_df, ...)
  result <- copy(grid)

  if (is.matrix(pred)) {
    result[, estimate := pred[, 1L]]
  } else {
    result[, estimate := as.numeric(pred)]
  }

  result
}


#' Predictions via custom function
#' @noRd
ems_predict_custom <- function(model, grid, predict_fun, ...) {
  grid_df <- as.data.frame(grid)
  pred <- predict_fun(model, grid_df)

  result <- copy(grid)

  if (is.data.frame(pred)) {
    # Custom function returned a data.frame — merge prediction columns
    pred <- as.data.table(pred)
    if ("estimate" %in% names(pred)) {
      result[, estimate := pred[["estimate"]]]
    }
    for (col in intersect(c("std.error", "conf.low", "conf.high"),
                          names(pred))) {
      result[[col]] <- pred[[col]]
    }
  } else if (is.numeric(pred)) {
    result[, estimate := pred]
  } else {
    cli_abort(
      "{.arg predict_fun} must return a numeric vector or a data.frame ",
      "with an {.val estimate} column."
    )
  }

  result
}
