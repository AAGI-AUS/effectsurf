# Tests for surf_prediction() — main user API
# ============================================================================

# =============================================================================
# End-to-end: GAM model -> surf_prediction() -> valid effectsurf
# =============================================================================

test_that("surf_prediction() returns a valid effectsurf object", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp) + factor(cyl), data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 10L, y_length = 10L)

  expect_s3_class(es, "effectsurf")
  expect_equal(es$x_var, "wt")
  expect_equal(es$y_var, "hp")
  expect_equal(es$z_var, "mpg")
  expect_equal(es$type, "prediction")
  expect_true(es$ci)
  expect_equal(nrow(es$data), 10L * 10L)
})

test_that("surf_prediction() with ci = FALSE omits CI columns", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 5L, y_length = 5L, ci = FALSE)

  expect_false(es$ci)
})

# =============================================================================
# Stratified surface via by parameter
# =============================================================================

test_that("surf_prediction() with by creates stratified surface", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  dat <- mtcars
  dat$cyl <- factor(dat$cyl)
  model <- mgcv::gam(mpg ~ s(wt) + s(hp) + cyl, data = dat)

  es <- surf_prediction(model, x = "wt", y = "hp", by = "cyl",
                        x_length = 5L, y_length = 5L)

  expect_equal(es$strata_var, "cyl")
  n_levels <- length(unique(dat$cyl))
  expect_equal(nrow(es$data), 5L * 5L * n_levels)
})

# =============================================================================
# Transform parameter
# =============================================================================

test_that("surf_prediction() with transform = 'expit' stores transform function", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 5L, y_length = 5L,
                        transform = "expit")

  expect_true(is.function(es$transform))
  expect_equal(es$transform(0), 0.5)
})

test_that("surf_prediction() with transform = 'exp' stores exp function", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 5L, y_length = 5L,
                        transform = "exp")

  expect_true(is.function(es$transform))
  expect_equal(es$transform(0), 1)
  expect_equal(es$transform(1), exp(1))
})

# =============================================================================
# Labels parameter
# =============================================================================

test_that("surf_prediction() custom labels override defaults", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 5L, y_length = 5L,
                        labels = list(x = "Weight (1000 lbs)",
                                      z = "Fuel Efficiency"))

  expect_equal(es$labels$x, "Weight (1000 lbs)")
  expect_equal(es$labels$z, "Fuel Efficiency")
  # y should get a default label

  expect_true(nchar(es$labels$y) > 0L)
})

# =============================================================================
# Model info extraction
# =============================================================================

test_that("surf_prediction() extracts model info", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 5L, y_length = 5L)

  expect_true("gam" %in% es$model_info$class)
  expect_equal(es$model_info$n_obs, nrow(mtcars))
})

# =============================================================================
# Manual method fallback
# =============================================================================

test_that("surf_prediction() with method = 'manual' and custom predict_fun works end-to-end", {
  skip_if_not_installed("mgcv")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  custom_fn <- function(mod, newdata) {
    predict(mod, newdata = newdata, type = "response")
  }

  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 5L, y_length = 5L,
                        method = "manual",
                        predict_fun = custom_fn)

  expect_s3_class(es, "effectsurf")
  expect_true("estimate" %in% names(es$data))
  expect_equal(nrow(es$data), 5L * 5L)
})

# =============================================================================
# Error handling
# =============================================================================

test_that("surf_prediction() errors on NULL model", {
  expect_error(
    surf_prediction(NULL, x = "wt", y = "hp"),
    "NULL"
  )
})

test_that("surf_prediction() errors on model without predict method", {
  bad_model <- structure(list(), class = "no_predict_class_xyz")
  expect_error(
    surf_prediction(bad_model, x = "wt", y = "hp"),
    "predict"
  )
})
