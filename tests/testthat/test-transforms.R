# Tests for transform functions
# ============================================================================

# =============================================================================
# expit() and logit()
# =============================================================================

test_that("expit(0) equals 0.5", {
  expect_equal(expit(0), 0.5)
})

test_that("expit() and logit() are inverses", {
  vals <- c(0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99)
  expect_equal(expit(logit(vals)), vals, tolerance = 1e-10)
})

test_that("logit(expit(x)) round-trips", {
  vals <- c(-5, -2, -1, 0, 1, 2, 5)
  expect_equal(logit(expit(vals)), vals, tolerance = 1e-10)
})

test_that("expit() handles extreme values", {
  expect_equal(expit(-Inf), 0)
  expect_equal(expit(Inf), 1)
  expect_true(expit(-100) < 1e-10)
  expect_true(expit(100) > 1 - 1e-10)
})

test_that("logit() handles boundary values", {
  expect_equal(logit(0.5), 0)
  expect_equal(logit(0), -Inf)
  expect_equal(logit(1), Inf)
})

test_that("expit() is vectorised", {
  x <- c(-2, -1, 0, 1, 2)
  result <- expit(x)
  expect_length(result, 5L)
  expect_true(all(result >= 0 & result <= 1))
  # Should be monotonically increasing
  expect_true(all(diff(result) > 0))
})

test_that("logit() is vectorised", {
  p <- c(0.1, 0.3, 0.5, 0.7, 0.9)
  result <- logit(p)
  expect_length(result, 5L)
  expect_true(all(diff(result) > 0))
})

# =============================================================================
# resolve_transform()
# =============================================================================

test_that("resolve_transform(NULL) returns NULL", {
  expect_null(resolve_transform(NULL))
})

test_that("resolve_transform('expit') returns a function that maps 0 to 0.5", {
  fn <- resolve_transform("expit")
  expect_true(is.function(fn))
  expect_equal(fn(0), 0.5)
})

test_that("resolve_transform('plogis') returns expit equivalent", {
  fn <- resolve_transform("plogis")
  expect_true(is.function(fn))
  expect_equal(fn(0), 0.5)
})

test_that("resolve_transform('exp') returns exp function", {
  fn <- resolve_transform("exp")
  expect_true(is.function(fn))
  expect_equal(fn(0), 1)
  expect_equal(fn(1), exp(1))
})

test_that("resolve_transform('square') returns squaring function", {
  fn <- resolve_transform("square")
  expect_true(is.function(fn))
  expect_equal(fn(3), 9)
  expect_equal(fn(-2), 4)
})

test_that("resolve_transform('identity') returns identity function", {
  fn <- resolve_transform("identity")
  expect_true(is.function(fn))
  expect_equal(fn(42), 42)
})

test_that("resolve_transform('percent_expit') returns expit * 100", {
  fn <- resolve_transform("percent_expit")
  expect_true(is.function(fn))
  expect_equal(fn(0), 50)
})

test_that("resolve_transform() accepts a custom function", {
  custom <- function(x) x^3
  fn <- resolve_transform(custom)
  expect_true(is.function(fn))
  expect_equal(fn(2), 8)
})

test_that("resolve_transform() errors on invalid character", {
  expect_error(resolve_transform("not_a_transform"), "should be one of")
})

test_that("resolve_transform() errors on non-function, non-character, non-NULL input", {
  expect_error(resolve_transform(42))
})
