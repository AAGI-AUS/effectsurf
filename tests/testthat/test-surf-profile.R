# Tests for surf_profile() — 2D profile slices
# ============================================================================

# =============================================================================
# Basic profile extraction
# =============================================================================

test_that("surf_profile() returns data when use_ggplot = FALSE", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 10L, y_length = 10L)

  result <- surf_profile(es, along = "x", use_ggplot = FALSE)

  expect_type(result, "list")
  expect_true("data" %in% names(result))
  expect_s3_class(result$data, "data.table")
  expect_true("estimate" %in% names(result$data))
  expect_true("slice_label" %in% names(result$data))
})

test_that("surf_profile() along = 'x' fixes y at specific values", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 10L, y_length = 10L)

  result <- surf_profile(es, along = "x", use_ggplot = FALSE)

  # hp should have only a few unique values (the slice values)
  n_slices <- length(unique(result$data$hp))
  expect_true(n_slices <= 5L)
  expect_equal(result$along_var, "wt")
  expect_equal(result$fixed_var, "hp")
})

test_that("surf_profile() along = 'y' fixes x at specific values", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 10L, y_length = 10L)

  result <- surf_profile(es, along = "y", use_ggplot = FALSE)

  n_slices <- length(unique(result$data$wt))
  expect_true(n_slices <= 5L)
  expect_equal(result$along_var, "hp")
  expect_equal(result$fixed_var, "wt")
})

# =============================================================================
# Custom at values
# =============================================================================

test_that("surf_profile() respects custom at values", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 20L, y_length = 20L)

  at_vals <- c(100, 150, 200)
  result <- surf_profile(es, along = "x", at = at_vals, use_ggplot = FALSE)

  # The number of unique hp values should match the number of at values
  # (or fewer if grid snapping reduces them)
  n_slices <- length(unique(result$data$hp))
  expect_true(n_slices <= length(at_vals))
  expect_true(n_slices >= 1L)
})

# =============================================================================
# ggplot2 output
# =============================================================================

test_that("surf_profile() returns a ggplot when use_ggplot = TRUE", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")
  skip_if_not_installed("ggplot2")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 10L, y_length = 10L)

  p <- surf_profile(es, along = "x", use_ggplot = TRUE)
  expect_s3_class(p, "ggplot")
})

# =============================================================================
# Error handling
# =============================================================================

test_that("surf_profile() errors on non-effectsurf input", {
  expect_error(
    surf_profile(list(a = 1)),
    "effectsurf"
  )
})

test_that("surf_profile() errors on invalid along value", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 5L, y_length = 5L)

  expect_error(surf_profile(es, along = "z"), "should be one of")
})

# =============================================================================
# Profile with stratified surface
# =============================================================================

test_that("surf_profile() works with stratified surface", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  dat <- mtcars
  dat$cyl <- factor(dat$cyl)
  model <- mgcv::gam(mpg ~ s(wt) + s(hp) + cyl, data = dat)
  es <- surf_prediction(model, x = "wt", y = "hp", by = "cyl",
                        x_length = 10L, y_length = 10L)

  result <- surf_profile(es, along = "x", use_ggplot = FALSE)

  expect_s3_class(result$data, "data.table")
  expect_true("cyl" %in% names(result$data))
})
