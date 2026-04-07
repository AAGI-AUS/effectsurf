# Tests for effectsurf S3 class
# ============================================================================

# -- Helper: minimal valid effectsurf data ------------------------------------
make_es_data <- function(strata = FALSE) {
  dt <- data.table::data.table(
    x = rep(seq(1, 3, length.out = 5), each = 5),
    y = rep(seq(1, 3, length.out = 5), times = 5),
    estimate  = rnorm(25),
    conf.low  = rnorm(25, -1),
    conf.high = rnorm(25,  1)
  )

  if (strata) {
    dt <- rbind(
      data.table::copy(dt)[, grp := "A"],
      data.table::copy(dt)[, grp := "B"]
    )
  }
  dt
}

# =============================================================================
# new_effectsurf() constructor
# =============================================================================

test_that("new_effectsurf() creates a valid effectsurf object", {
  dt <- make_es_data()
  es <- new_effectsurf(
    data  = dt,
    x_var = "x",
    y_var = "y",
    z_var = "response",
    type  = "prediction"
  )

  expect_s3_class(es, "effectsurf")
  expect_equal(es$x_var, "x")
  expect_equal(es$y_var, "y")
  expect_equal(es$z_var, "response")
  expect_equal(es$type, "prediction")
  expect_false(es$ci)
  expect_null(es$strata_var)
  expect_true(data.table::is.data.table(es$data))
})

test_that("new_effectsurf() accepts plain data.frame and converts to data.table", {
  df <- data.frame(x = 1:4, y = 1:4, estimate = rnorm(4))
  es <- new_effectsurf(df, x_var = "x", y_var = "y", z_var = "z", type = "prediction")
  expect_true(data.table::is.data.table(es$data))
})

test_that("new_effectsurf() errors when data is not a data.frame", {
  expect_error(
    new_effectsurf(list(a = 1), x_var = "a", y_var = "b", z_var = "z", type = "prediction"),
    "data.frame"
  )
})

test_that("new_effectsurf() errors on missing required columns", {
  dt <- data.table::data.table(x = 1:3, estimate = 1:3)
  expect_error(
    new_effectsurf(dt, x_var = "x", y_var = "y", z_var = "z", type = "prediction"),
    "Missing required columns"
  )
})

test_that("new_effectsurf() errors when strata_var is not in data", {
  dt <- data.table::data.table(x = 1:3, y = 1:3, estimate = 1:3)
  expect_error(
    new_effectsurf(dt, x_var = "x", y_var = "y", z_var = "z",
                   strata_var = "grp", type = "prediction"),
    "not found"
  )
})

test_that("new_effectsurf() sets ci = FALSE with warning when CI columns are missing", {
  dt <- data.table::data.table(x = 1:3, y = 1:3, estimate = 1:3)
  expect_warning(
    es <- new_effectsurf(dt, x_var = "x", y_var = "y", z_var = "z",
                         ci = TRUE, type = "prediction"),
    "missing"
  )
  expect_false(es$ci)
})

test_that("new_effectsurf() ci = TRUE works when CI columns are present", {
  dt <- make_es_data()
  es <- new_effectsurf(dt, x_var = "x", y_var = "y", z_var = "z",
                       ci = TRUE, type = "prediction")
  expect_true(es$ci)
})

test_that("new_effectsurf() validates type argument", {
  dt <- data.table::data.table(x = 1:3, y = 1:3, estimate = 1:3)
  expect_error(
    new_effectsurf(dt, x_var = "x", y_var = "y", z_var = "z", type = "invalid"),
    "should be one of"
  )
})

# =============================================================================
# Stratified objects
# =============================================================================

test_that("stratified effectsurf records strata_var correctly", {
  dt <- make_es_data(strata = TRUE)
  es <- new_effectsurf(dt, x_var = "x", y_var = "y", z_var = "z",
                       strata_var = "grp", type = "prediction")
  expect_equal(es$strata_var, "grp")
  expect_equal(length(unique(es$data[["grp"]])), 2L)
})

# =============================================================================
# print() and summary()
# =============================================================================

test_that("print.effectsurf() runs without error", {
  dt <- make_es_data()
  es <- new_effectsurf(dt, x_var = "x", y_var = "y", z_var = "response",
                       type = "prediction")
  expect_no_error(print(es))
})

test_that("print.effectsurf() returns object invisibly", {
  dt <- make_es_data()
  es <- new_effectsurf(dt, x_var = "x", y_var = "y", z_var = "z",
                       type = "prediction")
  out <- print(es)
  expect_identical(out, es)
})

test_that("print.effectsurf() works on stratified objects", {
  dt <- make_es_data(strata = TRUE)
  es <- new_effectsurf(dt, x_var = "x", y_var = "y", z_var = "z",
                       strata_var = "grp", type = "prediction")
  expect_no_error(print(es))
})

test_that("summary.effectsurf() runs without error", {
  dt <- make_es_data()
  es <- new_effectsurf(dt, x_var = "x", y_var = "y", z_var = "response",
                       type = "prediction")
  expect_no_error(summary(es))
})

test_that("summary.effectsurf() returns object invisibly", {
  dt <- make_es_data()
  es <- new_effectsurf(dt, x_var = "x", y_var = "y", z_var = "z",
                       type = "prediction")
  out <- summary(es)
  expect_identical(out, es)
})

test_that("summary.effectsurf() works on stratified objects", {
  dt <- make_es_data(strata = TRUE)
  es <- new_effectsurf(dt, x_var = "x", y_var = "y", z_var = "z",
                       strata_var = "grp", type = "prediction")
  expect_no_error(summary(es))
})

# =============================================================================
# surf_data()
# =============================================================================

test_that("surf_data() returns a data.table", {
  dt <- make_es_data()
  es <- new_effectsurf(dt, x_var = "x", y_var = "y", z_var = "z",
                       type = "prediction")
  out <- surf_data(es)
  expect_true(data.table::is.data.table(out))
  expect_true("estimate" %in% names(out))
})

test_that("surf_data() returns a copy, not a reference", {
  dt <- make_es_data()
  es <- new_effectsurf(dt, x_var = "x", y_var = "y", z_var = "z",
                       type = "prediction")
  out <- surf_data(es)
  out[, estimate := 999]
  expect_false(all(es$data$estimate == 999))
})

test_that("surf_data(as_matrix = TRUE) returns a list with matrix components", {
  dt <- make_es_data()
  es <- new_effectsurf(dt, x_var = "x", y_var = "y", z_var = "z",
                       type = "prediction")
  mats <- surf_data(es, as_matrix = TRUE)
  expect_type(mats, "list")
  expect_true(length(mats) >= 1L)
  expect_true(is.matrix(mats[[1L]]$z))
  expect_true(is.numeric(mats[[1L]]$x))
  expect_true(is.numeric(mats[[1L]]$y))
})

test_that("surf_data() errors on non-effectsurf input", {
  expect_error(surf_data(list(a = 1)), "effectsurf")
})

# =============================================================================
# is_effectsurf()
# =============================================================================

test_that("is_effectsurf() returns TRUE for effectsurf objects", {
  dt <- data.table::data.table(x = 1:3, y = 1:3, estimate = 1:3)
  es <- new_effectsurf(dt, x_var = "x", y_var = "y", z_var = "z",
                       type = "prediction")
  expect_true(is_effectsurf(es))
})

test_that("is_effectsurf() returns FALSE for non-effectsurf objects", {
  expect_false(is_effectsurf(list(a = 1)))
  expect_false(is_effectsurf(data.frame(x = 1)))
  expect_false(is_effectsurf(NULL))
  expect_false(is_effectsurf(42))
})
