# Tests for post-prediction surface smoothing (smooth parameter)
# ============================================================================

test_that("resolve_smooth_opts: NULL returns NULL", {

  expect_null(resolve_smooth_opts(NULL))
})

test_that("resolve_smooth_opts: FALSE returns NULL", {
  expect_null(resolve_smooth_opts(FALSE))
})

test_that("resolve_smooth_opts: TRUE returns defaults", {
  opts <- resolve_smooth_opts(TRUE)
  expect_type(opts, "list")
  expect_equal(opts$k, -1L)
  expect_equal(opts$bs, "tp")
  expect_true(opts$smooth_ci)
})

test_that("resolve_smooth_opts: custom list merges with defaults", {
  opts <- resolve_smooth_opts(list(k = 15))
  expect_equal(opts$k, 15)
  expect_equal(opts$bs, "tp")       # default preserved
  expect_true(opts$smooth_ci)       # default preserved
})

test_that("resolve_smooth_opts: all custom options respected", {
  opts <- resolve_smooth_opts(list(k = 20, bs = "cr", smooth_ci = FALSE))
  expect_equal(opts$k, 20)
  expect_equal(opts$bs, "cr")
  expect_false(opts$smooth_ci)
})

test_that("resolve_smooth_opts: unknown options warn", {
  expect_warning(
    resolve_smooth_opts(list(k = 10, bogus = TRUE)),
    "Unknown smooth"
  )
})

test_that("resolve_smooth_opts: bad input type errors", {
  expect_error(resolve_smooth_opts("yes"), "must be NULL")
  expect_error(resolve_smooth_opts(42), "must be NULL")
})


# --- Integration tests with mgcv and actual models ---

skip_if_not_installed("mgcv")

test_that("smooth_surface_data smooths predictions (no strata)", {
  model <- mgcv::gam(mpg ~ wt + hp, data = mtcars)
  es_raw <- surf_prediction(model, x = "wt", y = "hp",
                            x_length = 15, y_length = 15,
                            smooth = NULL)
  es_smooth <- surf_prediction(model, x = "wt", y = "hp",
                               x_length = 15, y_length = 15,
                               smooth = TRUE)

  expect_s3_class(es_smooth, "effectsurf")
  expect_equal(nrow(es_smooth$data), nrow(es_raw$data))

  # Smoothed estimates should differ from raw (lm is already smooth,

  # but the te() re-fit introduces slight differences)
  expect_false(identical(es_raw$data$estimate, es_smooth$data$estimate))

  # Metadata should record smooth options

  expect_false(is.null(es_smooth$meta$smooth))
  expect_equal(es_smooth$meta$smooth$k, -1L)
  expect_equal(es_smooth$meta$smooth$bs, "tp")
})

test_that("smooth_surface_data with strata smooths each stratum", {
  mt <- mtcars
  mt$cyl_f <- factor(mt$cyl)
  model <- mgcv::gam(mpg ~ wt + hp + cyl_f, data = mt)
  es <- surf_prediction(model, x = "wt", y = "hp", by = "cyl_f",
                        x_length = 15, y_length = 15,
                        smooth = TRUE)

  expect_s3_class(es, "effectsurf")
  strata <- unique(es$data[[es$strata_var]])
  expect_true(length(strata) > 1L)

  # Each stratum should have data
  for (s in strata) {
    n <- sum(es$data[[es$strata_var]] == s)
    expect_equal(n, 15L * 15L)
  }
})

test_that("smooth with custom k works", {
  model <- mgcv::gam(mpg ~ wt + hp, data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 15, y_length = 15,
                        smooth = list(k = 5))

  expect_s3_class(es, "effectsurf")
  expect_equal(es$meta$smooth$k, 5)
})

test_that("smooth = NULL produces no smoothing (default)", {
  model <- mgcv::gam(mpg ~ wt + hp, data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 15, y_length = 15)

  expect_null(es$meta$smooth)
})

test_that("smooth preserves CI columns when smooth_ci = TRUE", {
  model <- mgcv::gam(mpg ~ wt + hp, data = mtcars)
  es <- surf_prediction(model, x = "wt", y = "hp",
                        x_length = 15, y_length = 15,
                        ci = TRUE, smooth = TRUE)

  expect_true("conf.low" %in% names(es$data))
  expect_true("conf.high" %in% names(es$data))
  # Verify ordering: conf.low <= estimate <= conf.high
  expect_true(all(es$data$conf.low <= es$data$estimate + 1e-10))
  expect_true(all(es$data$conf.high >= es$data$estimate - 1e-10))
})

test_that("smooth_ci = FALSE leaves CIs unsmoothed", {
  model <- mgcv::gam(mpg ~ wt + hp, data = mtcars)
  es_raw <- surf_prediction(model, x = "wt", y = "hp",
                            x_length = 15, y_length = 15, ci = TRUE)
  es_smooth <- surf_prediction(model, x = "wt", y = "hp",
                               x_length = 15, y_length = 15, ci = TRUE,
                               smooth = list(smooth_ci = FALSE))

  # CIs should be identical to raw (not smoothed)
  expect_equal(es_raw$data$conf.low, es_smooth$data$conf.low)
  expect_equal(es_raw$data$conf.high, es_smooth$data$conf.high)
  # But estimates should differ (smoothed)
  expect_false(identical(es_raw$data$estimate, es_smooth$data$estimate))
})

test_that("smooth works with surf_comparison()", {
  model <- mgcv::gam(mpg ~ s(wt) + s(hp) + factor(cyl), data = mtcars)
  es <- surf_comparison(model, x = "wt", y = "hp",
                        variable = "cyl",
                        x_length = 15, y_length = 15,
                        smooth = TRUE)
  expect_s3_class(es, "effectsurf")
  expect_false(is.null(es$meta$smooth))
})

test_that("smooth works with surf_slopes()", {
  model <- mgcv::gam(mpg ~ s(wt) + s(hp) + s(disp), data = mtcars)
  es <- surf_slopes(model, x = "hp", y = "disp",
                    variable = "wt",
                    x_length = 15, y_length = 15,
                    smooth = TRUE)
  expect_s3_class(es, "effectsurf")
  expect_false(is.null(es$meta$smooth))
})

test_that("smooth works with surf_sensitivity()", {
  model <- mgcv::gam(mpg ~ s(wt) + s(hp) + factor(am), data = mtcars)
  es <- surf_sensitivity(model, x = "wt", y = "hp",
                         focal = "am",
                         x_length = 15, y_length = 15,
                         smooth = TRUE)
  expect_s3_class(es, "effectsurf")
  expect_false(is.null(es$meta$smooth))
})

test_that("smooth with different bs types works", {
  model <- mgcv::gam(mpg ~ wt + hp, data = mtcars)
  for (bs_type in c("tp", "cr", "ps")) {
    es <- surf_prediction(model, x = "wt", y = "hp",
                          x_length = 15, y_length = 15,
                          smooth = list(bs = bs_type))
    expect_s3_class(es, "effectsurf")
    expect_equal(es$meta$smooth$bs, bs_type)
  }
})
