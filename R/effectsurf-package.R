#' @keywords internal
"_PACKAGE"

#' @import data.table
#' @importFrom rlang .data .env abort warn inform check_installed is_installed
#' @importFrom cli cli_abort cli_warn cli_inform cli_progress_bar
#'   cli_progress_update cli_progress_done
#' @importFrom plotly plot_ly add_surface add_trace layout config
#' @importFrom htmlwidgets saveWidget
#' @importFrom marginaleffects datagrid predictions comparisons slopes
#' @importFrom stats predict complete.cases quantile sd median setNames
#'   model.frame formula terms nobs qnorm
#' @importFrom utils head tail
NULL

# Suppress R CMD check NOTEs for data.table non-standard evaluation
utils::globalVariables(c(
  ".", ".N", ".SD", ".I", ".GRP", ".BY", ".EACHI",
  "estimate", "std.error", "conf.low", "conf.high",
  "estimate.1", "estimate.2",
  ".x_grid", ".y_grid", ".strata", ".strata_tmp", ".strata_combined",
  "slice_label",
  "..keep_cols", "..keep", "..pred_cols"
))
