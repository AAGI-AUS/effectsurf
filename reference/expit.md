# Expit (inverse logit) function

Computes the inverse of the logit transformation: \\expit(x) =
\frac{e^x}{1 + e^x}\\.

## Usage

``` r
expit(x)
```

## Arguments

- x:

  Numeric vector.

## Value

Numeric vector on (0, 1) scale.

## Examples

``` r
expit(0)     # 0.5
#> [1] 0.5
expit(-Inf)  # 0
#> [1] 0
expit(Inf)   # 1
#> [1] 1
```
