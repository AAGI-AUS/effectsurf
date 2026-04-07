# Tests for surf_compare() — model comparison
# ============================================================================

# =============================================================================
# Difference surface
# =============================================================================

test_that("surf_compare() difference returns an effectsurf object", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  m1 <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  m2 <- mgcv::gam(mpg ~ s(wt) + hp, data = mtcars)

  es1 <- surf_prediction(m1, x = "wt", y = "hp",
                         x_length = 10L, y_length = 10L, ci = FALSE)
  es2 <- surf_prediction(m2, x = "wt", y = "hp",
                         x_length = 10L, y_length = 10L, ci = FALSE)

  diff_surf <- surf_compare(es1, es2, type = "difference")

  expect_s3_class(diff_surf, "effectsurf")
  expect_equal(diff_surf$type, "comparison")
  expect_equal(diff_surf$x_var, "wt")
  expect_equal(diff_surf$y_var, "hp")
})

test_that("surf_compare() difference has correct values (es1 - es2)", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  m1 <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  m2 <- mgcv::gam(mpg ~ s(wt) + hp, data = mtcars)

  es1 <- surf_prediction(m1, x = "wt", y = "hp",
                         x_length = 5L, y_length = 5L, ci = FALSE)
  es2 <- surf_prediction(m2, x = "wt", y = "hp",
                         x_length = 5L, y_length = 5L, ci = FALSE)

  diff_surf <- surf_compare(es1, es2, type = "difference")

  # Merge original data and verify difference
  d1 <- data.table::copy(es1$data)[, .(wt, hp, est1 = estimate)]
  d2 <- data.table::copy(es2$data)[, .(wt, hp, est2 = estimate)]
  merged <- merge(d1, d2, by = c("wt", "hp"))
  merged[, expected_diff := est1 - est2]

  diff_data <- surf_data(diff_surf)
  merged_check <- merge(diff_data[, .(wt, hp, estimate)],
                        merged[, .(wt, hp, expected_diff)],
                        by = c("wt", "hp"))

  expect_equal(merged_check$estimate, merged_check$expected_diff,
               tolerance = 1e-8)
})

test_that("surf_compare() difference of identical models is zero", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 5L, y_length = 5L, ci = FALSE)

  diff_surf <- surf_compare(es, es, type = "difference")
  diff_data <- surf_data(diff_surf)

  expect_true(all(abs(diff_data$estimate) < 1e-10))
})

# =============================================================================
# Side-by-side comparison
# =============================================================================

test_that("surf_compare() side_by_side returns a list of two surfaces", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  m1 <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  m2 <- mgcv::gam(mpg ~ s(wt) + hp, data = mtcars)

  es1 <- surf_prediction(m1, x = "wt", y = "hp",
                         x_length = 5L, y_length = 5L)
  es2 <- surf_prediction(m2, x = "wt", y = "hp",
                         x_length = 5L, y_length = 5L)

  result <- surf_compare(es1, es2, type = "side_by_side")

  expect_type(result, "list")
  expect_named(result, c("surface1", "surface2"))
  expect_s3_class(result$surface1, "effectsurf")
  expect_s3_class(result$surface2, "effectsurf")
})

# =============================================================================
# Error handling
# =============================================================================

test_that("surf_compare() errors when x/y variables don't match", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp) + s(disp), data = mtcars)

  es1 <- surf_prediction(model, x = "wt", y = "hp",
                         x_length = 5L, y_length = 5L, ci = FALSE)
  es2 <- surf_prediction(model, x = "wt", y = "disp",
                         x_length = 5L, y_length = 5L, ci = FALSE)

  expect_error(
    surf_compare(es1, es2, type = "difference"),
    "same x and y"
  )
})

test_that("surf_compare() errors on non-effectsurf inputs", {
  dt <- data.table::data.table(x = 1:4, y = 1:4, estimate = 1:4)
  es <- new_effectsurf(dt, x_var = "x", y_var = "y", z_var = "z",
                       type = "prediction")

  expect_error(
    surf_compare(es, list(a = 1)),
    "effectsurf"
  )
  expect_error(
    surf_compare(list(a = 1), es),
    "effectsurf"
  )
})

# =============================================================================
# Custom labels for difference surface
# =============================================================================

test_that("surf_compare() accepts custom labels", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 5L, y_length = 5L, ci = FALSE)

  diff_surf <- surf_compare(
    es, es,
    type = "difference",
    labels = list(title = "My Comparison", z = "Delta MPG")
  )

  expect_equal(diff_surf$labels$title, "My Comparison")
  expect_equal(diff_surf$labels$z, "Delta MPG")
})
