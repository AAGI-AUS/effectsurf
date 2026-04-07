# Tests for surf_optimum() — optimum finder
# ============================================================================

# =============================================================================
# Basic max/min finding
# =============================================================================

test_that("surf_optimum() returns data.table with correct columns", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 10L, y_length = 10L)

  result <- surf_optimum(es, type = "max")

  expect_s3_class(result, "data.table")
  expect_true("wt" %in% names(result))
  expect_true("hp" %in% names(result))
  expect_true("estimate" %in% names(result))
  expect_equal(nrow(result), 1L)
})

test_that("surf_optimum() max returns the global maximum", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 10L, y_length = 10L, ci = FALSE)

  result_max <- surf_optimum(es, type = "max")
  result_min <- surf_optimum(es, type = "min")

  # Max estimate should be >= min estimate

  expect_true(result_max$estimate >= result_min$estimate)

  # Max should equal the actual max of the data
  expect_equal(result_max$estimate, max(es$data$estimate), tolerance = 1e-8)
  expect_equal(result_min$estimate, min(es$data$estimate), tolerance = 1e-8)
})

test_that("surf_optimum() min works correctly", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 10L, y_length = 10L, ci = FALSE)

  result <- surf_optimum(es, type = "min")

  expect_s3_class(result, "data.table")
  expect_equal(nrow(result), 1L)
  expect_equal(result$estimate, min(es$data$estimate), tolerance = 1e-8)
})

# =============================================================================
# Stratified surfaces
# =============================================================================

test_that("surf_optimum() works with stratified surfaces", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  dat <- mtcars
  dat$cyl <- factor(dat$cyl)
  model <- mgcv::gam(mpg ~ s(wt) + s(hp) + cyl, data = dat)
  es <- surf_prediction(model, x = "wt", y = "hp", by = "cyl",
                        x_length = 5L, y_length = 5L, ci = FALSE)

  result <- surf_optimum(es, type = "max")

  expect_s3_class(result, "data.table")
  # One row per stratum
  n_levels <- length(unique(dat$cyl))
  expect_equal(nrow(result), n_levels)
  expect_true("cyl" %in% names(result))
})

# =============================================================================
# With transform
# =============================================================================

test_that("surf_optimum() applies transform before finding optimum", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 5L, y_length = 5L, ci = FALSE,
                        transform = "exp")

  result <- surf_optimum(es, type = "max")

  # With exp transform, the optimum estimate should be exp() of the raw max
  raw_max <- max(es$data$estimate)
  expect_equal(result$estimate, exp(raw_max), tolerance = 1e-6)
})

# =============================================================================
# Error handling
# =============================================================================

test_that("surf_optimum() errors on non-effectsurf input", {
  expect_error(
    surf_optimum(list(a = 1)),
    "effectsurf"
  )
})

test_that("surf_optimum() errors on invalid type", {
  dt <- data.table::data.table(x = 1:4, y = 1:4, estimate = 1:4)
  es <- new_effectsurf(dt, x_var = "x", y_var = "y", z_var = "z",
                       type = "prediction")
  expect_error(surf_optimum(es, type = "median"), "should be one of")
})
