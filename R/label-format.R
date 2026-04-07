# Label Formatting Utilities
# ============================================================================

#' Create a label format specification
#'
#' Defines how numeric values are formatted in axis labels, hover text,
#' colorbar, and legend. Accepts `sprintf`-style format strings, custom
#' functions, or named shortcuts.
#'
#' @param x Format for x-axis values. A `sprintf` format string
#'   (e.g., `"%.0f kg/ha"`), a function, or `NULL` (auto).
#' @param y Format for y-axis values. Same as `x`.
#' @param z Format for z-axis values. Same as `x`.
#' @param hover_x Format for x values in hover text. Defaults to `x`.
#' @param hover_y Format for y values in hover text. Defaults to `y`.
#' @param hover_z Format for z values in hover text. Defaults to `z`.
#' @param digits Integer. Default number of decimal places when format
#'   is `NULL`. Default 2.
#'
#' @return A `label_format` list used by [plot.effectsurf()].
#' @export
#'
#' @examples
#' # Format nitrogen as integer with unit, rainfall with no decimals
#' fmt <- label_format(
#'   x = "%.0f kg/ha",
#'   y = "%.0f mm",
#'   z = "%.2f t/ha"
#' )
#'
#' # Custom function
#' fmt2 <- label_format(
#'   z = function(v) paste0(round(v * 100, 1), "%")
#' )
label_format <- function(x = NULL, y = NULL, z = NULL,
                         hover_x = NULL, hover_y = NULL, hover_z = NULL,
                         digits = 2L) {
  structure(
    list(
      x = x, y = y, z = z,
      hover_x = hover_x %||% x,
      hover_y = hover_y %||% y,
      hover_z = hover_z %||% z,
      digits = digits
    ),
    class = "label_format"
  )
}


#' Apply a format specification to a numeric value
#'
#' @param value Numeric value(s).
#' @param fmt A format string, function, or NULL.
#' @param digits Default digits if fmt is NULL.
#' @return Character string(s).
#' @noRd
apply_format <- function(value, fmt = NULL, digits = 2L) {
  if (is.null(fmt)) {
    return(round(value, digits))
  }
  if (is.function(fmt)) {
    return(fmt(value))
  }
  if (is.character(fmt)) {
    return(sprintf(fmt, value))
  }
  round(value, digits)
}


#' Build plotly hovertemplate from labels and format spec
#'
#' @param labels Named list with x, y, z labels.
#' @param fmt A `label_format` object or NULL.
#' @param strata_var Stratum variable name or NULL.
#' @param stratum_value Current stratum label or NULL.
#' @return Character string for plotly hovertemplate.
#' @noRd
build_hovertemplate <- function(labels, fmt = NULL, strata_var = NULL,
                                stratum_value = NULL) {
  # Determine format strings for hover
  if (!is.null(fmt) && inherits(fmt, "label_format")) {
    x_fmt <- resolve_hover_fmt(fmt$hover_x, fmt$digits)
    y_fmt <- resolve_hover_fmt(fmt$hover_y, fmt$digits)
    z_fmt <- resolve_hover_fmt(fmt$hover_z, fmt$digits)
  } else {
    x_fmt <- ":.2f"
    y_fmt <- ":.2f"
    z_fmt <- ":.3f"
  }

  parts <- c()
  if (!is.null(strata_var) && !is.null(stratum_value)) {
    parts <- c(parts, paste0("<b>", strata_var, ": ", stratum_value, "</b>"))
  }
  parts <- c(parts,
    paste0(labels$x, ": %{x", x_fmt, "}"),
    paste0(labels$y, ": %{y", y_fmt, "}"),
    paste0(labels$z, ": %{z", z_fmt, "}")
  )

  paste0(paste(parts, collapse = "<br>"), "<extra></extra>")
}


#' Convert a format spec to plotly hover format string
#' @noRd
resolve_hover_fmt <- function(fmt, digits) {
  if (is.null(fmt)) {
    return(paste0(":.", digits, "f"))
  }
  if (is.character(fmt)) {
    # Extract precision from sprintf format like "%.2f t/ha"
    m <- regmatches(fmt, regexpr("%\\.?(\\d*)f", fmt))
    if (length(m) > 0L && nchar(m) > 0L) {
      d <- gsub("[^0-9]", "", sub("%", "", m))
      if (nchar(d) > 0L) return(paste0(":.", d, "f"))
    }
  }
  # Default
  paste0(":.", digits, "f")
}
