# Tests for ems_predict() — prediction on grids
# ============================================================================

# =============================================================================
# Basic predictions via marginaleffects
# =============================================================================

test_that("ems_predict() returns data.table with expected columns", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp) + factor(cyl), data = mtcars)
  grid <- ems_grid(model, x = "wt", y = "hp", x_length = 5L, y_length = 5L)
  preds <- ems_predict(model, grid, ci = TRUE)

  expect_s3_class(preds, "data.table")
  expect_true("estimate" %in% names(preds))
  expect_true("wt" %in% names(preds))
  expect_true("hp" %in% names(preds))
  expect_equal(nrow(preds), nrow(grid))
})

test_that("ems_predict() includes CI columns when ci = TRUE", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  grid <- ems_grid(model, x = "wt", y = "hp", x_length = 5L, y_length = 5L)
  preds <- ems_predict(model, grid, ci = TRUE)

  expect_true("conf.low" %in% names(preds))
  expect_true("conf.high" %in% names(preds))
  # CI should be ordered correctly
  expect_true(all(preds$conf.low <= preds$conf.high))
})

test_that("ems_predict() omits CI columns when ci = FALSE", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  grid <- ems_grid(model, x = "wt", y = "hp", x_length = 5L, y_length = 5L)
  preds <- ems_predict(model, grid, ci = FALSE)

  expect_true("estimate" %in% names(preds))
  # When vcov = FALSE, marginaleffects should not produce CI columns
  expect_false("conf.low" %in% names(preds))
  expect_false("conf.high" %in% names(preds))
})

# =============================================================================
# Custom predict function
# =============================================================================

test_that("ems_predict() with custom predict_fun returns estimates", {
  skip_if_not_installed("mgcv")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  grid <- ems_grid(model, x = "wt", y = "hp", x_length = 5L, y_length = 5L,
                   method = "manual")

  custom_fn <- function(mod, newdata) {
    predict(mod, newdata = newdata, type = "response")
  }

  preds <- ems_predict(model, grid, predict_fun = custom_fn)

  expect_s3_class(preds, "data.table")
  expect_true("estimate" %in% names(preds))
  expect_equal(nrow(preds), nrow(grid))
  expect_true(all(is.finite(preds$estimate)))
})

test_that("ems_predict() with custom predict_fun returning data.frame works", {
  skip_if_not_installed("mgcv")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  grid <- ems_grid(model, x = "wt", y = "hp", x_length = 5L, y_length = 5L,
                   method = "manual")

  custom_fn <- function(mod, newdata) {
    p <- predict(mod, newdata = newdata, se.fit = TRUE)
    data.frame(estimate = p$fit, std.error = p$se.fit)
  }

  preds <- ems_predict(model, grid, predict_fun = custom_fn)

  expect_true("estimate" %in% names(preds))
  expect_true("std.error" %in% names(preds))
})

# =============================================================================
# Base predict fallback
# =============================================================================

test_that("ems_predict() with method = 'predict' works with CI", {
  skip_if_not_installed("mgcv")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  grid <- ems_grid(model, x = "wt", y = "hp", x_length = 5L, y_length = 5L,
                   method = "manual")

  preds <- ems_predict(model, grid, ci = TRUE, method = "predict")

  expect_s3_class(preds, "data.table")
  expect_true("estimate" %in% names(preds))
  expect_equal(nrow(preds), nrow(grid))
})

test_that("ems_predict() with method = 'predict' works without CI", {
  skip_if_not_installed("mgcv")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  grid <- ems_grid(model, x = "wt", y = "hp", x_length = 5L, y_length = 5L,
                   method = "manual")

  preds <- ems_predict(model, grid, ci = FALSE, method = "predict")

  expect_s3_class(preds, "data.table")
  expect_true("estimate" %in% names(preds))
})

# =============================================================================
# Prediction values are sensible
# =============================================================================

test_that("ems_predict() returns finite numeric estimates", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  grid <- ems_grid(model, x = "wt", y = "hp", x_length = 5L, y_length = 5L)
  preds <- ems_predict(model, grid, ci = FALSE)

  expect_true(all(is.finite(preds$estimate)))
  # Predicted mpg should be in a reasonable range
  expect_true(all(preds$estimate > 0))
  expect_true(all(preds$estimate < 50))
})
