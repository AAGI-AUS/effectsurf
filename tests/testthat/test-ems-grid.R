# Tests for ems_grid() — grid creation
# ============================================================================

# =============================================================================
# Basic grid creation with marginaleffects
# =============================================================================

test_that("ems_grid() creates a grid with correct dimensions (marginaleffects)", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp) + factor(cyl), data = mtcars)
  grid <- ems_grid(model, x = "wt", y = "hp", x_length = 10L, y_length = 15L)

  expect_s3_class(grid, "data.table")
  expect_equal(nrow(grid), 10L * 15L)
  expect_true("wt" %in% names(grid))
  expect_true("hp" %in% names(grid))
})

test_that("ems_grid() auto-detects variable ranges", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  grid <- ems_grid(model, x = "wt", y = "hp", x_length = 5L, y_length = 5L)

  wt_range <- range(mtcars$wt)
  hp_range <- range(mtcars$hp)

  expect_true(min(grid$wt) >= wt_range[1] - 0.01)
  expect_true(max(grid$wt) <= wt_range[2] + 0.01)
  expect_true(min(grid$hp) >= hp_range[1] - 0.01)
  expect_true(max(grid$hp) <= hp_range[2] + 0.01)
})

# =============================================================================
# Range parameters
# =============================================================================

test_that("ems_grid() respects explicit x_range and y_range", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  grid <- ems_grid(model, x = "wt", y = "hp",
                   x_range = c(2, 4), y_range = c(100, 200),
                   x_length = 10L, y_length = 10L)

  expect_equal(min(grid$wt), 2, tolerance = 0.01)
  expect_equal(max(grid$wt), 4, tolerance = 0.01)
  expect_equal(min(grid$hp), 100, tolerance = 0.01)
  expect_equal(max(grid$hp), 200, tolerance = 0.01)
})

# =============================================================================
# Stratified grids
# =============================================================================

test_that("ems_grid() with by creates stratified grid", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  dat <- mtcars
  dat$cyl <- factor(dat$cyl)
  model <- mgcv::gam(mpg ~ s(wt) + s(hp) + cyl, data = dat)

  grid <- ems_grid(model, x = "wt", y = "hp", by = "cyl",
                   x_length = 5L, y_length = 5L)

  n_levels <- length(unique(dat$cyl))
  expect_equal(nrow(grid), 5L * 5L * n_levels)
  expect_true("cyl" %in% names(grid))
})

test_that("levels_needed subsets strata correctly", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")

  dat <- mtcars
  dat$cyl <- factor(dat$cyl)
  model <- mgcv::gam(mpg ~ s(wt) + s(hp) + cyl, data = dat)

  grid <- ems_grid(model, x = "wt", y = "hp", by = "cyl",
                   levels_needed = c("4", "6"),
                   x_length = 5L, y_length = 5L)

  cyl_vals <- unique(as.character(grid$cyl))
  expect_true(all(cyl_vals %in% c("4", "6")))
  expect_false("8" %in% cyl_vals)
})

# =============================================================================
# Manual fallback
# =============================================================================

test_that("ems_grid() with method = 'manual' creates valid grid", {
  skip_if_not_installed("mgcv")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp) + factor(cyl), data = mtcars)
  grid <- ems_grid(model, x = "wt", y = "hp",
                   x_length = 8L, y_length = 8L,
                   method = "manual")

  expect_s3_class(grid, "data.table")
  expect_equal(nrow(grid), 8L * 8L)
  expect_true("wt" %in% names(grid))
  expect_true("hp" %in% names(grid))
})

test_that("ems_grid() manual method fills non-focal variables with reference values", {
  skip_if_not_installed("mgcv")

  dat <- mtcars
  dat$cyl <- factor(dat$cyl)
  model <- mgcv::gam(mpg ~ s(wt) + s(hp) + cyl, data = dat)
  grid <- ems_grid(model, x = "wt", y = "hp",
                   x_length = 5L, y_length = 5L,
                   method = "manual")

  # cyl should be filled in at its mode
  expect_true("cyl" %in% names(grid))
  expect_equal(length(unique(grid$cyl)), 1L)
})

# =============================================================================
# Error handling
# =============================================================================

test_that("ems_grid() errors on NULL model", {
  expect_error(
    ems_grid(NULL, x = "wt", y = "hp")
  )
})

test_that("ems_grid() errors when range cannot be auto-detected for unknown variable", {
  skip_if_not_installed("mgcv")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  expect_error(
    ems_grid(model, x = "nonexistent", y = "hp", x_length = 5L, y_length = 5L),
    "auto-detect"
  )
})
