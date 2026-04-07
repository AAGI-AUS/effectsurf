# Computation Layer: Grid Creation
# ============================================================================

#' Create a prediction grid for surface estimation
#'
#' Generates a cross-product grid of two focal continuous variables, with
#' non-focal variables held at reference values (mean for numeric, mode for
#' factors). Wraps [marginaleffects::datagrid()] when available, with a
#' lightweight fallback for unsupported models.
#'
#' @param model A fitted model object.
#' @param x Character. Name of the x-axis variable.
#' @param y Character. Name of the y-axis variable.
#' @param by Character or `NULL`. Name of a categorical variable for
#'   stratification.
#' @param x_range Numeric vector of length 2. Range for x variable. If `NULL`,
#'   auto-detected from the model's training data.
#' @param y_range Numeric vector of length 2. Range for y variable. If `NULL`,
#'   auto-detected.
#' @param x_length Integer. Number of grid points along x. Default 50.
#' @param y_length Integer. Number of grid points along y. Default 50.
#' @param grid_type Character. One of `"mean_or_mode"` (default),
#'   `"counterfactual"`, `"balanced"`. Passed to
#'   [marginaleffects::datagrid()].
#' @param at Named list. Additional variables to hold at specific values
#'   (e.g., `at = list(state = "WA")`).
#' @param levels_needed Character vector or `NULL`. If `by` is specified, subset
#'   to only these levels.
#' @param method Character. One of `"marginaleffects"` (default), `"gratia"`,
#'   or `"manual"`. Controls the grid creation backend.
#' @param ... Additional arguments passed to the backend.
#'
#' @return A `data.table` representing the prediction grid.
#' @export
#'
#' @examples
#' if (requireNamespace("mgcv", quietly = TRUE)) {
#'   model <- mgcv::gam(mpg ~ s(wt) + s(hp) + cyl, data = mtcars)
#'   grid <- ems_grid(model, x = "wt", y = "hp", x_length = 20, y_length = 20)
#'   head(grid)
#' }
ems_grid <- function(model,
                     x,
                     y,
                     by = NULL,
                     x_range = NULL,
                     y_range = NULL,
                     x_length = 50L,
                     y_length = 50L,
                     grid_type = "mean_or_mode",
                     at = NULL,
                     levels_needed = NULL,
                     method = c("marginaleffects", "emmeans", "gratia", "manual"),
                     ...) {

  method <- match.arg(method)
  # Note: validate_model() is called by the top-level surf_*() functions,
  # so we skip it here to avoid redundant model.frame() calls.

  # Resolve ranges (extract model data once if needed, avoid repeated model.frame())
  if (is.null(x_range) || is.null(y_range)) {
    model_data <- tryCatch(stats::model.frame(model), error = function(e) NULL)
    if (is.null(model_data)) model_data <- model$data
    if (is.null(model_data)) model_data <- model$model
  }

  if (is.null(x_range)) {
    if (!is.null(model_data) && x %in% names(model_data) && is.numeric(model_data[[x]])) {
      x_range <- range(model_data[[x]], na.rm = TRUE)
    } else {
      x_range <- detect_var_range(model, x)
    }
    if (is.null(x_range)) {
      cli_abort("Cannot auto-detect range for {.val {x}}. Please supply {.arg x_range}.")
    }
  }

  if (is.null(y_range)) {
    if (!is.null(model_data) && y %in% names(model_data) && is.numeric(model_data[[y]])) {
      y_range <- range(model_data[[y]], na.rm = TRUE)
    } else {
      y_range <- detect_var_range(model, y)
    }
    if (is.null(y_range)) {
      cli_abort("Cannot auto-detect range for {.val {y}}. Please supply {.arg y_range}.")
    }
  }

  x_seq <- seq(x_range[1L], x_range[2L], length.out = x_length)
  y_seq <- seq(y_range[1L], y_range[2L], length.out = y_length)

  # Dispatch to backend
  # emmeans builds its own ref grid internally, so use manual grid for it
  grid <- switch(
    method,
    marginaleffects = ems_grid_marginaleffects(
      model, x, y, by, x_seq, y_seq, grid_type, at, levels_needed, ...
    ),
    emmeans = ems_grid_manual(
      model, x, y, by, x_seq, y_seq, at, levels_needed, ...
    ),
    gratia = ems_grid_gratia(
      model, x, y, by, x_seq, y_seq, at, levels_needed, ...
    ),
    manual = ems_grid_manual(
      model, x, y, by, x_seq, y_seq, at, levels_needed, ...
    )
  )

  as.data.table(grid)
}


#' Grid creation via marginaleffects
#' @noRd
ems_grid_marginaleffects <- function(model, x, y, by, x_seq, y_seq,
                                     grid_type, at, levels_needed, ...) {
  # Build the datagrid call arguments
  grid_args <- list(model = model, grid_type = grid_type)
  grid_args[[x]] <- x_seq
  grid_args[[y]] <- y_seq

  # Add stratification variable — must explicitly expand all levels
  if (!is.null(by)) {
    if (!is.null(levels_needed)) {
      grid_args[[by]] <- levels_needed
    } else {
      # datagrid defaults to mode; we need all levels for stratification
      mf <- tryCatch(stats::model.frame(model), error = function(e) NULL)
      if (!is.null(mf) && by %in% names(mf)) {
        by_vals <- mf[[by]]
        if (is.factor(by_vals)) {
          grid_args[[by]] <- levels(by_vals)
        } else {
          grid_args[[by]] <- sort(unique(by_vals))
        }
      }
    }
  }

  # Add fixed-value variables
  if (!is.null(at)) {
    for (nm in names(at)) {
      grid_args[[nm]] <- at[[nm]]
    }
  }

  grid <- do.call(marginaleffects::datagrid, grid_args)

  # Subset to requested levels if needed and datagrid expanded all levels
  if (!is.null(by) && !is.null(levels_needed)) {
    grid <- grid[grid[[by]] %in% levels_needed, , drop = FALSE]
  }

  grid
}


#' Grid creation via gratia (for mgcv models)
#' @noRd
ems_grid_gratia <- function(model, x, y, by, x_seq, y_seq,
                            at, levels_needed, ...) {
  rlang::check_installed("gratia", reason = "for gratia-based grid creation.")

  if (!inherits(model, c("gam", "bam"))) {
    cli_warn(
      "gratia method is designed for {.cls gam}/{.cls bam} models. ",
      "Falling back to marginaleffects."
    )
    return(ems_grid_marginaleffects(
      model, x, y, by, x_seq, y_seq, "mean_or_mode", at, levels_needed, ...
    ))
  }

  # Build data_slice arguments
  slice_args <- list(.model = model)
  slice_args[[x]] <- gratia::evenly(model$model[[x]], n = length(x_seq),
                                     lower = min(x_seq), upper = max(x_seq))
  slice_args[[y]] <- gratia::evenly(model$model[[y]], n = length(y_seq),
                                     lower = min(y_seq), upper = max(y_seq))

  if (!is.null(by)) {
    if (!is.null(levels_needed)) {
      slice_args[[by]] <- levels_needed
    }
  }

  grid <- do.call(gratia::data_slice, slice_args)

  # Apply additional fixed values
  if (!is.null(at)) {
    for (nm in names(at)) {
      grid[[nm]] <- at[[nm]]
    }
  }

  as.data.frame(grid)
}


#' Manual grid creation fallback
#' @noRd
ems_grid_manual <- function(model, x, y, by, x_seq, y_seq,
                            at, levels_needed, ...) {
  # Create the base cross-product grid
  grid <- data.table::CJ(x_tmp = x_seq, y_tmp = y_seq)
  data.table::setnames(grid, c("x_tmp", "y_tmp"), c(x, y))

  # Get reference values for non-focal variables
  mf <- tryCatch(stats::model.frame(model), error = function(e) NULL)
  if (is.null(mf)) {
    mf <- tryCatch(model$data, error = function(e) NULL)
  }

  if (!is.null(mf)) {
    other_vars <- setdiff(names(mf), c(x, y, by))
    # Remove response variable
    resp <- tryCatch({
      resp_name <- all.vars(stats::formula(model))[1L]
      resp_name
    }, error = function(e) NULL)
    if (!is.null(resp)) {
      other_vars <- setdiff(other_vars, resp)
    }

    for (v in other_vars) {
      vals <- mf[[v]]
      if (is.numeric(vals)) {
        grid[[v]] <- mean(vals, na.rm = TRUE)
      } else if (is.factor(vals)) {
        tab <- table(vals)
        grid[[v]] <- factor(names(tab)[which.max(tab)], levels = levels(vals))
      } else if (is.character(vals)) {
        tab <- table(vals)
        grid[[v]] <- names(tab)[which.max(tab)]
      }
    }
  }

  # Add stratification variable
  if (!is.null(by) && !is.null(mf) && by %in% names(mf)) {
    by_vals <- if (!is.null(levels_needed)) {
      levels_needed
    } else {
      unique(mf[[by]])
    }
    grid <- grid[rep(seq_len(.N), length(by_vals))]
    grid[[by]] <- rep(by_vals, each = length(x_seq) * length(y_seq))
    if (is.factor(mf[[by]])) {
      grid[[by]] <- factor(grid[[by]], levels = levels(mf[[by]]))
    }
  }

  # Override with user-specified values
  if (!is.null(at)) {
    for (nm in names(at)) {
      grid[[nm]] <- at[[nm]]
    }
  }

  as.data.frame(grid)
}
