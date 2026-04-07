# Back-transformation Functions
# ============================================================================

#' Resolve a transform specification to a function
#'
#' Accepts a character string naming a built-in transform, a custom function,
#' or NULL (identity).
#'
#' @param transform Character, function, or NULL.
#' @return A function or NULL.
#' @noRd
resolve_transform <- function(transform) {
  if (is.null(transform)) {
    return(NULL)
  }

  if (is.function(transform)) {
    return(transform)
  }

  if (is.character(transform)) {
    transform <- match.arg(
      transform,
      choices = c("expit", "exp", "square", "identity", "plogis",
                  "percent_expit")
    )
    fn <- switch(
      transform,
      expit          = expit,
      plogis         = expit,
      exp            = exp,
      square         = function(x) x^2,
      identity       = function(x) x,
      percent_expit  = function(x) expit(x) * 100
    )
    return(fn)
  }

  cli_abort(paste0(
    "{.arg transform} must be NULL, a function, or one of: ",
    "{.val expit}, {.val exp}, {.val square}, {.val identity}, ",
    "{.val percent_expit}."
  ))
}


#' Expit (inverse logit) function
#'
#' Computes the inverse of the logit transformation:
#' \eqn{expit(x) = \frac{e^x}{1 + e^x}}{expit(x) = exp(x) / (1 + exp(x))}.
#'
#' @param x Numeric vector.
#' @return Numeric vector on (0, 1) scale.
#' @export
#' @examples
#' expit(0)     # 0.5
#' expit(-Inf)  # 0
#' expit(Inf)   # 1
expit <- function(x) {
  1 / (1 + exp(-x))
}


#' Logit function
#'
#' Computes the logit transformation:
#' \eqn{logit(p) = \log\frac{p}{1-p}}{logit(p) = log(p / (1 - p))}.
#'
#' @param p Numeric vector on (0, 1).
#' @return Numeric vector.
#' @export
#' @examples
#' logit(0.5)  # 0
#' logit(0.1)  # -2.197
logit <- function(p) {
  log(p / (1 - p))
}
