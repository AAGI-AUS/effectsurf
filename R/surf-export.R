# Surface Export Utilities
# ============================================================================

#' Export an effectsurf plot to HTML
#'
#' Saves an interactive 3D surface visualisation as a self-contained HTML
#' file that can be opened in any web browser, shared, or embedded in
#' reports. Also generates 2D maximum-profile PDFs alongside the HTML.
#'
#' @param object An [effectsurf][new_effectsurf] object.
#' @param path Character. File path for the output HTML. Must end in `.html`.
#' @param selfcontained Logical. If `TRUE` (default), produces a single
#'   self-contained HTML file (~3.8 MB, fully portable).
#' @param title Character or `NULL`. HTML page title (currently unused,
#'   title comes from the effectsurf object).
#' @param ... Additional arguments passed to [plot.effectsurf()] for
#'   controlling the visualisation appearance.
#'
#' @return Invisibly returns the file path.
#'
#' @export
#'
#' @examples
#' \donttest{
#' if (requireNamespace("mgcv", quietly = TRUE)) {
#'   model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
#'   es <- surf_prediction(model, x = "wt", y = "hp",
#'                         x_length = 20, y_length = 20)
#'   # Export to temp file
#'   tmp <- tempfile(fileext = ".html")
#'   surf_export(es, path = tmp)
#' }
#' }
surf_export <- function(object,
                        path,
                        selfcontained = TRUE,
                        title = NULL,
                        ...) {

  if (!inherits(object, "effectsurf")) {
    cli_abort("{.arg object} must be an {.cls effectsurf} object.")
  }

  if (!grepl("\\.html$", path, ignore.case = TRUE)) {
    cli_abort("{.arg path} must end in {.val .html}.")
  }

  # Ensure directory exists
  dir_path <- dirname(path)
  if (!dir.exists(dir_path)) {
    dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
  }

  # Use plot.effectsurf with save_html which handles:
  # - Self-contained HTML via as_widget() + saveWidget
  # - Cleanup of _files/ directory
  # - 2D profile PDFs
  plot.effectsurf(object, save_html = path, ...)

  cli_inform("Exported to {.path {path}}")
  invisible(path)
}


#' Null-coalescing operator
#' @noRd
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
