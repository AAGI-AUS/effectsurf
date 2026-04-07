# Tests for surf_derivatives() — numerical derivative surfaces
# ============================================================================
#
# Strategy: use lm() with mtcars to avoid extra dependencies.
# For mathematical correctness, fit z = a*x + b*y + c*x:y so that
# analytical derivatives are known exactly.
# ============================================================================

# =============================================================================
# Shared test fixtures
# =============================================================================

# Helper: build a simple effectsurf from a linear model with known coefficients.
# Model: mpg ~ wt + hp + wt:hp (linear in both, with interaction).
# Derivatives are analytically:
#   dz/dwt  = coef_wt + coef_wt:hp * hp
#   dz/dhp  = coef_hp + coef_wt:hp * wt
#   d2z/dwt2  = 0
#   d2z/dhp2  = 0
#   d2z/dwt_dhp = coef_wt:hp
make_linear_surface <- function(n_grid = 20L) {
  set.seed(42L)
  model <- lm(mpg ~ wt + hp + wt:hp, data = mtcars)
  surf_prediction(model, x = "wt", y = "hp",
                  x_length = n_grid, y_length = n_grid,
                  ci = FALSE, method = "manual",
                  predict_fun = function(mod, newdata) {
                    predict(mod, newdata = newdata)
                  })
}

# Helper: build a stratified surface (by cyl)
make_stratified_surface <- function(n_grid = 15L) {
  set.seed(42L)
  dat <- mtcars
  dat$cyl <- factor(dat$cyl)
  model <- lm(mpg ~ wt * hp + cyl, data = dat)
  surf_prediction(model, x = "wt", y = "hp", by = "cyl",
                  x_length = n_grid, y_length = n_grid,
                  ci = FALSE, method = "manual",
                  predict_fun = function(mod, newdata) {
                    predict(mod, newdata = newdata)
                  })
}


# =============================================================================
# 1. Basic functionality — return structure
# =============================================================================

test_that("surf_derivatives() returns a named list of effectsurf objects", {
  es <- make_linear_surface()
  derivs <- surf_derivatives(es, order = 2L, type = "all")

  expect_type(derivs, "list")
  expect_true(length(derivs) > 0L)

  # Every element must be effectsurf

  for (nm in names(derivs)) {
    expect_s3_class(derivs[[nm]], "effectsurf")
  }
})

test_that("order = 2 (default) returns all 6 derivative types", {
  es <- make_linear_surface()
  derivs <- surf_derivatives(es)

  expected_names <- c("dzdx", "dzdy", "gradient",
                      "d2zdx2", "d2zdy2", "d2zdxdy")
  expect_named(derivs, expected_names, ignore.order = FALSE)
})

test_that("order = 1 returns only first-order types", {
  es <- make_linear_surface()
  derivs <- surf_derivatives(es, order = 1L)

  expected_names <- c("dzdx", "dzdy", "gradient")
  expect_named(derivs, expected_names, ignore.order = FALSE)
  expect_equal(length(derivs), 3L)
})

test_that("type = 'dzdx' returns only that single derivative", {
  es <- make_linear_surface()
  derivs <- surf_derivatives(es, type = "dzdx")

  expect_named(derivs, "dzdx")
  expect_equal(length(derivs), 1L)
  expect_s3_class(derivs[["dzdx"]], "effectsurf")
})

test_that("type accepts a vector of specific types", {
  es <- make_linear_surface()
  derivs <- surf_derivatives(es, type = c("dzdx", "d2zdxdy"))

  expect_named(derivs, c("dzdx", "d2zdxdy"), ignore.order = FALSE)
  expect_equal(length(derivs), 2L)
})


# =============================================================================
# 2. Mathematical correctness — analytically known derivatives
# =============================================================================

test_that("dz/dx approximates analytical partial derivative (linear model)", {
  set.seed(42L)
  es <- make_linear_surface(n_grid = 30L)
  derivs <- surf_derivatives(es, type = "dzdx")

  model <- lm(mpg ~ wt + hp + wt:hp, data = mtcars)
  coefs <- coef(model)
  coef_wt   <- coefs["wt"]
  coef_wthp <- coefs["wt:hp"]


  # dz/dwt = coef_wt + coef_wt:hp * hp
  dt <- derivs[["dzdx"]]$data
  analytical <- as.numeric(coef_wt + coef_wthp * dt[["hp"]])

  expect_equal(dt[["estimate"]], analytical, tolerance = 0.5)
})

test_that("dz/dy approximates analytical partial derivative (linear model)", {
  set.seed(42L)
  es <- make_linear_surface(n_grid = 30L)
  derivs <- surf_derivatives(es, type = "dzdy")

  model <- lm(mpg ~ wt + hp + wt:hp, data = mtcars)
  coefs <- coef(model)
  coef_hp   <- coefs["hp"]
  coef_wthp <- coefs["wt:hp"]

  dt <- derivs[["dzdy"]]$data
  analytical <- coef_hp + coef_wthp * dt[["wt"]]

  expect_equal(dt[["estimate"]], analytical, tolerance = 0.1)
})

test_that("d2z/dx2 is approximately zero for linear model", {
  set.seed(42L)
  es <- make_linear_surface(n_grid = 30L)
  derivs <- surf_derivatives(es, type = "d2zdx2")

  dt <- derivs[["d2zdx2"]]$data
  # For a plane with interaction (z = a + bx + cy + dxy), d2z/dx2 = 0
  expect_equal(dt[["estimate"]], rep(0, nrow(dt)), tolerance = 0.1)
})

test_that("d2z/dy2 is approximately zero for linear model", {
  set.seed(42L)
  es <- make_linear_surface(n_grid = 30L)
  derivs <- surf_derivatives(es, type = "d2zdy2")

  dt <- derivs[["d2zdy2"]]$data
  expect_equal(dt[["estimate"]], rep(0, nrow(dt)), tolerance = 0.1)
})

test_that("d2z/dxdy approximates the interaction coefficient", {
  set.seed(42L)
  es <- make_linear_surface(n_grid = 30L)
  derivs <- surf_derivatives(es, type = "d2zdxdy")

  model <- lm(mpg ~ wt + hp + wt:hp, data = mtcars)
  coef_interaction <- coef(model)["wt:hp"]

  dt <- derivs[["d2zdxdy"]]$data
  # Cross-partial should be constant and equal to the interaction coefficient
  expect_equal(dt[["estimate"]],
               rep(as.numeric(coef_interaction), nrow(dt)),
               tolerance = 0.5)
})

test_that("gradient magnitude equals sqrt(dzdx^2 + dzdy^2)", {
  set.seed(42L)
  es <- make_linear_surface(n_grid = 25L)
  derivs <- surf_derivatives(es, order = 1L)

  dt_dzdx <- derivs[["dzdx"]]$data
  dt_dzdy <- derivs[["dzdy"]]$data
  dt_grad <- derivs[["gradient"]]$data

  expected_grad <- sqrt(dt_dzdx[["estimate"]]^2 + dt_dzdy[["estimate"]]^2)
  expect_equal(dt_grad[["estimate"]], expected_grad, tolerance = 1e-10)
})


# =============================================================================
# 3. Stratified surfaces
# =============================================================================

test_that("surf_derivatives() works with stratified (by=) effectsurf", {
  es <- make_stratified_surface()
  derivs <- surf_derivatives(es)

  expect_type(derivs, "list")
  expect_equal(length(derivs), 6L)

  for (nm in names(derivs)) {
    expect_s3_class(derivs[[nm]], "effectsurf")
  }
})

test_that("strata_var is preserved in derivative surfaces", {
  es <- make_stratified_surface()
  derivs <- surf_derivatives(es)

  for (nm in names(derivs)) {
    expect_equal(derivs[[nm]]$strata_var, "cyl",
                 info = paste("strata_var preserved in", nm))
  }
})

test_that("all strata are present in each derivative surface", {
  es <- make_stratified_surface()
  original_levels <- levels(es$data[["cyl"]])
  derivs <- surf_derivatives(es, type = "dzdx")

  deriv_levels <- levels(derivs[["dzdx"]]$data[["cyl"]])
  expect_setequal(deriv_levels, original_levels)
})

test_that("stratified derivative grid has correct number of rows", {
  n_grid <- 15L
  es <- make_stratified_surface(n_grid = n_grid)
  n_strata <- length(unique(es$data[["cyl"]]))
  derivs <- surf_derivatives(es, type = "gradient")

  expect_equal(nrow(derivs[["gradient"]]$data),
               n_grid * n_grid * n_strata)
})


# =============================================================================
# 4. Input validation
# =============================================================================

test_that("surf_derivatives() errors on non-effectsurf input", {
  expect_error(
    surf_derivatives(data.frame(x = 1:3)),
    "effectsurf"
  )
  expect_error(
    surf_derivatives(list(a = 1)),
    "effectsurf"
  )
  expect_error(
    surf_derivatives(42),
    "effectsurf"
  )
})

test_that("surf_derivatives() errors on invalid order", {
  es <- make_linear_surface()

  expect_error(surf_derivatives(es, order = 0), "order")
  expect_error(surf_derivatives(es, order = 3), "order")
  expect_error(surf_derivatives(es, order = -1), "order")
})

test_that("surf_derivatives() errors on unknown type", {
  es <- make_linear_surface()

  expect_error(
    surf_derivatives(es, type = "nonsense"),
    "Unknown"
  )
  expect_error(
    surf_derivatives(es, type = c("dzdx", "bogus")),
    "Unknown"
  )
})

test_that("second-order type with order = 1 gives warning", {
  es <- make_linear_surface()

  expect_warning(
    derivs <- surf_derivatives(es, order = 1L, type = "d2zdxdy"),
    "order"
  )
  # After warning, second-order types should be dropped
  expect_equal(length(derivs), 0L)
})

test_that("mixed first/second types with order = 1 warns and keeps only first-order", {
  es <- make_linear_surface()

  expect_warning(
    derivs <- surf_derivatives(es, order = 1L, type = c("dzdx", "d2zdxdy")),
    "order"
  )
  expect_named(derivs, "dzdx")
  expect_equal(length(derivs), 1L)
})


# =============================================================================
# 5. Output structure — labels, meta, variable preservation
# =============================================================================

test_that("derivative surfaces preserve x_var and y_var from input", {
  es <- make_linear_surface()
  derivs <- surf_derivatives(es)

  for (nm in names(derivs)) {
    expect_equal(derivs[[nm]]$x_var, "wt",
                 info = paste("x_var in", nm))
    expect_equal(derivs[[nm]]$y_var, "hp",
                 info = paste("y_var in", nm))
  }
})

test_that("each derivative surface has meaningful labels", {
  es <- make_linear_surface()
  derivs <- surf_derivatives(es)

  for (nm in names(derivs)) {
    labs <- derivs[[nm]]$labels
    expect_true(!is.null(labs$title) && nchar(as.character(labs$title)) > 0L,
                info = paste("title label in", nm))
    expect_true(!is.null(labs$z),
                info = paste("z label in", nm))
    expect_true(!is.null(labs$x) && nchar(as.character(labs$x)) > 0L,
                info = paste("x label in", nm))
    expect_true(!is.null(labs$y) && nchar(as.character(labs$y)) > 0L,
                info = paste("y label in", nm))
  }
})

test_that("meta contains derivative_type and derivative_order", {
  es <- make_linear_surface()
  derivs <- surf_derivatives(es)

  first_types  <- c("dzdx", "dzdy", "gradient")
  second_types <- c("d2zdx2", "d2zdy2", "d2zdxdy")

  for (nm in names(derivs)) {
    meta <- derivs[[nm]]$meta
    expect_equal(meta$derivative_type, nm,
                 info = paste("derivative_type in", nm))

    expected_order <- if (nm %in% first_types) 1L else 2L
    expect_equal(meta$derivative_order, expected_order,
                 info = paste("derivative_order in", nm))
  }
})

test_that("derivative meta contains grid spacing (dx, dy)", {
  es <- make_linear_surface()
  derivs <- surf_derivatives(es, type = "dzdx")

  meta <- derivs[["dzdx"]]$meta
  expect_true(!is.null(meta$dx))
  expect_true(!is.null(meta$dy))
  expect_true(is.numeric(meta$dx) && meta$dx > 0)
  expect_true(is.numeric(meta$dy) && meta$dy > 0)
})

test_that("derivative data contains estimate column with no NAs (interior)", {
  es <- make_linear_surface(n_grid = 20L)
  derivs <- surf_derivatives(es)

  for (nm in names(derivs)) {
    dt <- derivs[[nm]]$data
    expect_true("estimate" %in% names(dt),
                info = paste("estimate column in", nm))
    # All values should be finite for a well-behaved linear model
    expect_true(all(is.finite(dt[["estimate"]])),
                info = paste("all finite estimates in", nm))
  }
})

test_that("derivative surface has type = 'prediction'", {
  es <- make_linear_surface()
  derivs <- surf_derivatives(es, type = "gradient")

  expect_equal(derivs[["gradient"]]$type, "prediction")
})
