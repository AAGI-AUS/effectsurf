# Tests for surf_export() — HTML export
# ============================================================================

# =============================================================================
# Successful export
# =============================================================================

test_that("surf_export() creates an HTML file", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")
  skip_if_not_installed("plotly")
  skip_if_not_installed("htmlwidgets")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 5L, y_length = 5L)

  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp), add = TRUE)

  result <- surf_export(es, path = tmp, selfcontained = FALSE)

  expect_true(file.exists(tmp))
  expect_equal(result, tmp)
})

test_that("surf_export() creates a file with non-zero size", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")
  skip_if_not_installed("plotly")
  skip_if_not_installed("htmlwidgets")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 5L, y_length = 5L)

  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp), add = TRUE)

  surf_export(es, path = tmp, selfcontained = FALSE)

  expect_gt(file.info(tmp)$size, 0L)
})

test_that("surf_export() returns path invisibly", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")
  skip_if_not_installed("plotly")
  skip_if_not_installed("htmlwidgets")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 5L, y_length = 5L)

  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp), add = TRUE)

  result <- surf_export(es, path = tmp, selfcontained = FALSE)
  expect_equal(result, tmp)
})

# =============================================================================
# Error handling
# =============================================================================

test_that("surf_export() errors when path doesn't end in .html", {
  dt <- data.table::data.table(x = 1:4, y = 1:4, estimate = 1:4)
  es <- new_effectsurf(dt, x_var = "x", y_var = "y", z_var = "z",
                       type = "prediction")

  expect_error(
    surf_export(es, path = "output.pdf"),
    "\\.html"
  )
})

test_that("surf_export() errors on non-effectsurf input", {
  expect_error(
    surf_export(list(a = 1), path = "test.html"),
    "effectsurf"
  )
})

# =============================================================================
# Custom title
# =============================================================================

test_that("surf_export() accepts custom title", {
  skip_if_not_installed("mgcv")
  skip_if_not_installed("marginaleffects")
  skip_if_not_installed("plotly")
  skip_if_not_installed("htmlwidgets")

  model <- mgcv::gam(mpg ~ s(wt) + s(hp), data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 5L, y_length = 5L)

  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp), add = TRUE)

  expect_no_error(
    surf_export(es, path = tmp, title = "Custom Title",
                selfcontained = FALSE)
  )
  expect_true(file.exists(tmp))
})
