# User API: Effect Comparison Surfaces
# ============================================================================

#' Create a 3D treatment effect comparison surface
#'
#' Generates a surface showing how a treatment effect (difference between
#' two levels of a categorical variable, or a unit change in a continuous
#' variable) varies across a 2D grid of two moderators. This is effectively
#' a conditional average treatment effect (CATE) surface from observational
#' or experimental models.
#'
#' @inheritParams surf_prediction
#' @param variable Character. The treatment/contrast variable.
#' @param contrast Character or numeric. Specifies the contrast:
#'   - For factors: `"pairwise"`, `"reference"`, or a specific level
#'     (e.g., `"high N"` to compare against reference).
#'   - For numeric: a unit change value (default 1).
#' @param comparison Character. Type of comparison: `"difference"` (default),
#'   `"ratio"`, `"lnratio"`. Passed to [marginaleffects::comparisons()].
#'
#' @return An [effectsurf][new_effectsurf] object of type `"comparison"`.
#'
#' @seealso [surf_prediction()], [surf_slopes()], [surf_cate()]
#'
#' @export
#'
#' @examples
#' \donttest{
#' if (requireNamespace("mgcv", quietly = TRUE)) {
#'   model <- mgcv::gam(
#'     mpg ~ s(wt) + s(hp) + factor(cyl),
#'     data = mtcars
#'   )
#'
#'   # Effect of changing cyl from 4 to 8, across wt x hp grid
#'   es <- surf_comparison(model, x = "wt", y = "hp",
#'                         variable = "cyl",
#'                         x_length = 25, y_length = 25)
#'   plot(es)
#' }
#' }
surf_comparison <- function(model,
                            x,
                            y,
                            variable,
                            contrast = NULL,
                            comparison = "difference",
                            by = NULL,
                            x_range = NULL,
                            y_range = NULL,
                            x_length = 50L,
                            y_length = 50L,
                            ci = TRUE,
                            level = 0.95,
                            grid_type = "mean_or_mode",
                            at = NULL,
                            levels_needed = NULL,
                            transform = NULL,
                            labels = list(),
                            smooth = NULL,
                            method = c("marginaleffects", "emmeans", "manual"),
                            ...) {

  method <- match.arg(method)
  validate_model(model)
  smooth_opts <- resolve_smooth_opts(smooth)

  # Step 1: Create prediction grid (without the contrast variable)
  grid <- ems_grid(
    model = model,
    x = x, y = y, by = by,
    x_range = x_range, y_range = y_range,
    x_length = x_length, y_length = y_length,
    grid_type = grid_type,
    at = at,
    levels_needed = levels_needed,
    method = method,
    ...
  )

  # Step 2: Compute comparisons
  if (method == "emmeans") {
    em_out <- ems_comparisons_emmeans(model, grid, x, y, by, variable,
                                      contrast, level, ...)
    result <- em_out$result
    strata_var_out <- em_out$strata_var
  } else {
    comp_args <- list(
      model     = model,
      variables = variable,
      newdata   = as.data.frame(grid),
      conf_level = level,
      comparison = comparison
    )

    if (!is.null(contrast)) {
      comp_args$variables <- stats::setNames(list(contrast), variable)
    }

    comps <- do.call(marginaleffects::comparisons, comp_args)
    comps_dt <- as.data.table(comps)

    # Keep relevant columns
    grid_cols <- intersect(c(x, y, by), names(comps_dt))
    pred_cols <- intersect(
      c("estimate", "std.error", "conf.low", "conf.high"),
      names(comps_dt)
    )

    # Handle multiple contrasts
    has_contrasts <- "contrast" %in% names(comps_dt) &&
      length(unique(comps_dt[["contrast"]])) > 1L
    strata_var_out <- by

    if (has_contrasts && is.null(by)) {
      grid_cols <- c(grid_cols, "contrast")
      strata_var_out <- "contrast"
    } else if (has_contrasts && !is.null(by)) {
      comps_dt[, .strata_combined := paste(get(by), contrast, sep = " | ")]
      grid_cols <- c(intersect(c(x, y), names(comps_dt)), ".strata_combined")
      strata_var_out <- ".strata_combined"
    }

    keep_cols <- unique(c(grid_cols, pred_cols))
    result <- comps_dt[, ..keep_cols]
  }

  # Step 2b: Apply post-prediction smoothing if requested
  if (!is.null(smooth_opts)) {
    result <- smooth_surface_data(result, x, y, strata_var_out, smooth_opts)
  }

  # Step 3: Determine z label
  z_var <- paste0("effect_", variable)

  # Step 4: Build effectsurf object
  new_effectsurf(
    data       = result,
    x_var      = x,
    y_var      = y,
    z_var      = z_var,
    strata_var = strata_var_out,
    type       = "comparison",
    ci         = ci && all(c("conf.low", "conf.high") %in% names(result)),
    model_info = extract_model_info(model),
    labels     = labels,
    transform  = transform,
    meta       = list(
      variable   = variable,
      contrast   = contrast,
      comparison = comparison,
      grid_type  = grid_type,
      level      = level,
      method     = method,
      smooth     = smooth_opts
    )
  )
}


#' Compute comparisons via emmeans contrast matrices
#' @noRd
ems_comparisons_emmeans <- function(model, grid, x, y, by, variable,
                                     contrast, level, ...) {
  rlang::check_installed("emmeans", reason = "for emmeans-based comparisons.")

  # Build the at= list for the grid axes
  grid_cols <- intersect(c(x, y), names(grid))
  at_list <- lapply(grid_cols, function(v) sort(unique(grid[[v]])))
  names(at_list) <- grid_cols

  # emmeans formula: ~ variable | x * y [* by]
  cond_vars <- grid_cols
  if (!is.null(by)) cond_vars <- c(cond_vars, by)
  em_formula <- stats::as.formula(
    paste("~", variable, "|", paste(cond_vars, collapse = " * "))
  )

  # Add variable levels if factor, or by levels
  mf <- tryCatch(stats::model.frame(model), error = function(e) model$data)
  if (!is.null(mf) && variable %in% names(mf) && is.factor(mf[[variable]])) {
    at_list[[variable]] <- levels(mf[[variable]])
  }
  if (!is.null(by) && !is.null(mf) && by %in% names(mf) && is.factor(mf[[by]])) {
    at_list[[by]] <- levels(mf[[by]])
  }

  old_opt <- getOption("emmeans")
  emmeans::emm_options(rg.limit = 500000L)
  on.exit(options(emmeans = old_opt), add = TRUE)

  em <- emmeans::emmeans(model, em_formula, at = at_list, level = level, ...)

  # Apply contrasts: pairwise by default, or custom contrast matrix
  if (!is.null(contrast) && is.list(contrast)) {
    contr <- emmeans::contrast(em, contrast)
  } else {
    contr <- emmeans::contrast(em, method = "pairwise")
  }

  contr_dt <- as.data.table(as.data.frame(contr))

  # Map column names
  name_map <- c(
    "estimate"  = "estimate",
    "SE"        = "std.error",
    "lower.CL"  = "conf.low",
    "upper.CL"  = "conf.high",
    "asymp.LCL" = "conf.low",
    "asymp.UCL" = "conf.high"
  )
  for (old in names(name_map)) {
    if (old %in% names(contr_dt)) {
      data.table::setnames(contr_dt, old, name_map[[old]], skip_absent = TRUE)
    }
  }

  # Identify the contrast column
  contr_col <- intersect(c("contrast"), names(contr_dt))
  strata_var_out <- by

  if (length(contr_col) > 0 && length(unique(contr_dt[["contrast"]])) > 1L) {
    if (is.null(by)) {
      strata_var_out <- "contrast"
    }
  }

  pred_cols <- intersect(c("estimate", "std.error", "conf.low", "conf.high"),
                          names(contr_dt))
  out_cols <- intersect(c(grid_cols, by, "contrast", pred_cols), names(contr_dt))
  result <- contr_dt[, .SD, .SDcols = out_cols]

  list(result = result, strata_var = strata_var_out)
}
