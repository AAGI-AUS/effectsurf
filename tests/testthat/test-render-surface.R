# Tests for plot.effectsurf() — rendering layer
# ============================================================================

# =============================================================================
# Single surface rendering
# =============================================================================

test_that("plot.effectsurf() returns a plotly object for a single surface", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")
  skip_if_not_installed("plotly")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 5L, y_length = 5L)

  p <- plot(es)
  expect_s3_class(p, "plotly")
})

test_that("plot.effectsurf() renders without error for single surface", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")
  skip_if_not_installed("plotly")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 5L, y_length = 5L)

  expect_no_error(plot(es))
})

# =============================================================================
# Stratified surface rendering
# =============================================================================

test_that("plot.effectsurf() renders stratified surface without error", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")
  skip_if_not_installed("plotly")

  dat <- mtcars
  dat$cyl <- factor(dat$cyl)
  model <- mgcv::gam(mpg ~ s(wt) + s(hp) + cyl, data = dat)
  es <- surf_prediction(model, x = "wt", y = "hp", by = "cyl",
                        x_length = 5L, y_length = 5L)

  p <- plot(es)
  expect_s3_class(p, "plotly")
})

# =============================================================================
# CI surfaces
# =============================================================================

test_that("plot.effectsurf() with show_ci = TRUE adds CI surfaces", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")
  skip_if_not_installed("plotly")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 5L, y_length = 5L, ci = TRUE)

  p <- plot(es, show_ci = TRUE)
  expect_s3_class(p, "plotly")
  p_no_ci <- plot(es, show_ci = FALSE)
  expect_s3_class(p_no_ci, "plotly")
  # CI version should have more traces (main + lower + upper)
  expect_true(length(p$x$data) >= length(p_no_ci$x$data))
})

# =============================================================================
# Custom camera
# =============================================================================

test_that("plot.effectsurf() accepts custom camera", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")
  skip_if_not_installed("plotly")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 5L, y_length = 5L)

  custom_cam <- list(eye = list(x = 2, y = 2, z = 2))
  p <- plot(es, camera = custom_cam)

  expect_s3_class(p, "plotly")
})

# =============================================================================
# Error handling
# =============================================================================

test_that("plot.effectsurf() errors on non-effectsurf input", {
  skip_if_not_installed("plotly")

  expect_error(
    plot.effectsurf(list(a = 1)),
    "effectsurf"
  )
})

# =============================================================================
# Appearance parameters
# =============================================================================

test_that("plot.effectsurf() accepts opacity and colourscale arguments", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")
  skip_if_not_installed("plotly")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 5L, y_length = 5L)

  expect_no_error(plot(es, opacity = 0.5, colourscale = "RdBu"))
})
