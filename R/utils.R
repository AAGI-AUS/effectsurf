# Internal Utility Functions
# ============================================================================

#' Convert effectsurf data to matrix format for plotly
#'
#' @param object An effectsurf object.
#' @return Named list of matrices and axis vectors, one set per stratum.
#' @noRd
to_surface_matrices <- function(object) {
  dt <- copy(object$data)
  x_var <- object$x_var
  y_var <- object$y_var
  strata_var <- object$strata_var

  # Apply back-transformation if present
  if (!is.null(object$transform)) {
    dt[, estimate := object$transform(estimate)]
    if (object$ci) {
      dt[, conf.low := object$transform(conf.low)]
      dt[, conf.high := object$transform(conf.high)]
    }
  }

  # Get unique axis values (sorted)
  x_vals <- sort(unique(dt[[x_var]]))
  y_vals <- sort(unique(dt[[y_var]]))
  nx <- length(x_vals)
  ny <- length(y_vals)

  # Split by strata if present
  if (!is.null(strata_var)) {
    strata_levels <- unique(dt[[strata_var]])
  } else {
    strata_levels <- "all"
    dt[, .strata_tmp := "all"]
    strata_var <- ".strata_tmp"
  }

  # Vectorised long-to-matrix conversion via dcast (replaces O(n^2) double loop)
  # Old approach: 14,400 per-cell data.table lookups for 40x40x3 grid
  # New approach: single dcast per value column — ~50-100x faster
  has_ci <- object$ci && all(c("conf.low", "conf.high") %in% names(dt))

  result <- lapply(strata_levels, function(s) {
    sub <- dt[get(strata_var) == s]

    # dcast: long -> wide, rows = y, cols = x, value = estimate
    wide <- data.table::dcast(sub, get(y_var) ~ get(x_var), value.var = "estimate")
    z_mat <- as.matrix(wide[, -1L, with = FALSE])

    out <- list(x = x_vals, y = y_vals, z = z_mat, stratum = s)

    if (has_ci) {
      wide_low <- data.table::dcast(sub, get(y_var) ~ get(x_var), value.var = "conf.low")
      wide_high <- data.table::dcast(sub, get(y_var) ~ get(x_var), value.var = "conf.high")
      out$z_low  <- as.matrix(wide_low[, -1L, with = FALSE])
      out$z_high <- as.matrix(wide_high[, -1L, with = FALSE])
    }

    out
  })

  names(result) <- strata_levels
  attr(result, "x_vals") <- x_vals
  attr(result, "y_vals") <- y_vals
  result
}


#' Build default labels
#'
#' @param labels User-supplied labels list.
#' @param x_var,y_var,z_var Variable names.
#' @param strata_var Stratification variable name or NULL.
#' @param type Surface type.
#' @return Complete labels list.
#' @noRd
build_labels <- function(labels, x_var, y_var, z_var, strata_var, type) {
  defaults <- list(
    x = prettify_name(x_var),
    y = prettify_name(y_var),
    z = prettify_name(z_var),
    title = NULL
  )

  # Build default title
  type_label <- switch(
    type,
    prediction = "Prediction surface",
    comparison = "Effect comparison",
    slopes     = "Marginal effect surface",
    cate       = "CATE surface"
  )

  if (is.null(strata_var)) {
    defaults$title <- sprintf("%s: %s", type_label, prettify_name(z_var))
  } else {
    defaults$title <- sprintf(
      "%s: %s by %s",
      type_label, prettify_name(z_var), prettify_name(strata_var)
    )
  }

  # Override defaults with user-supplied labels
  for (nm in names(labels)) {
    defaults[[nm]] <- labels[[nm]]
  }

  defaults
}


#' Convert variable names to human-readable labels
#'
#' Replaces underscores with spaces and applies title case.
#'
#' @param x Character string.
#' @return Character string.
#' @noRd
prettify_name <- function(x) {
  x <- gsub("_", " ", x, fixed = TRUE)
  x <- gsub("\\b(\\w)", "\\U\\1", x, perl = TRUE)
  x
}


#' Validate model input
#'
#' Checks that the model object is suitable for prediction.
#'
#' @param model A fitted model object.
#' @return Invisibly returns TRUE; aborts on failure.
#' @noRd
validate_model <- function(model) {
  if (is.null(model)) {
    cli_abort("{.arg model} cannot be NULL.")
  }

  # Fast check: S3 predict method exists (covers lm, glm, gam, lmer, etc.)
  has_predict <- any(vapply(class(model), function(cl) {
    !is.null(utils::getS3method("predict", cl, optional = TRUE))
  }, logical(1L)))

  # Slow fallback only if fast check fails (rare S4 models)
  if (!has_predict) {
    has_predict <- tryCatch({
      !is.null(stats::predict(model, newdata = head(stats::model.frame(model), 1L)))
    }, error = function(e) FALSE)
  }

  if (!has_predict) {
    cli_abort(
      "No {.fn predict} method found for model of class {.cls {class(model)}}."
    )
  }

  invisible(TRUE)
}


#' Extract model information
#'
#' Extracts metadata from a fitted model for the effectsurf object.
#'
#' @param model A fitted model object.
#' @return A named list.
#' @noRd
extract_model_info <- function(model) {
  info <- list(class = class(model))

  # Try to get number of observations
  info$n_obs <- tryCatch(stats::nobs(model), error = function(e) NULL)

  # Try to get formula
  info$formula <- tryCatch(
    deparse(stats::formula(model), width.cutoff = 80L),
    error = function(e) NULL
  )

  # Try to get call
  info$call <- tryCatch(deparse(model$call, width.cutoff = 80L),
                        error = function(e) NULL)

  info
}


#' Detect variable range from model data
#'
#' Attempts to extract the range of a variable from the model's training data.
#'
#' @param model A fitted model object.
#' @param var_name Character. Variable name.
#' @return Numeric vector of length 2 (min, max) or NULL.
#' @noRd
detect_var_range <- function(model, var_name) {
  # Try model.frame first
  mf <- tryCatch(stats::model.frame(model), error = function(e) NULL)
  if (!is.null(mf) && var_name %in% names(mf)) {
    vals <- mf[[var_name]]
    if (is.numeric(vals)) {
      return(range(vals, na.rm = TRUE))
    }
  }

  # Try model$data
  if (!is.null(model$data) && var_name %in% names(model$data)) {
    vals <- model$data[[var_name]]
    if (is.numeric(vals)) {
      return(range(vals, na.rm = TRUE))
    }
  }

  # Try model$model
  if (!is.null(model$model) && var_name %in% names(model$model)) {
    vals <- model$model[[var_name]]
    if (is.numeric(vals)) {
      return(range(vals, na.rm = TRUE))
    }
  }

  NULL
}


#' Generate default colourscale for strata
#'
#' Returns a vector of colours for stratified surfaces.
#'
#' @param n Integer. Number of strata.
#' @return Character vector of hex colours.
#' @noRd
default_strata_colours <- function(n) {
  if (n <= 8L) {
    # Colourblind-safe palette (Wong, 2011)
    palette <- c(
      "#0072B2", # blue
      "#D55E00", # vermillion
      "#009E73", # bluish green
      "#CC79A7", # reddish purple
      "#E69F00", # orange
      "#56B4E9", # sky blue
      "#F0E442", # yellow
      "#000000"  # black
    )
    return(palette[seq_len(n)])
  }

  # Fall back to viridis for many strata
  if (rlang::is_installed("viridisLite")) {
    return(viridisLite::viridis(n))
  }

  grDevices::hcl.colors(n, palette = "viridis")
}
