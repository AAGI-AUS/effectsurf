# Logit function

Computes the logit transformation: \\logit(p) = \log\frac{p}{1-p}\\.

## Usage

``` r
logit(p)
```

## Arguments

- p:

  Numeric vector on (0, 1).

## Value

Numeric vector.

## Examples

``` r
logit(0.5)  # 0
#> [1] 0
logit(0.1)  # -2.197
#> [1] -2.197225
```
