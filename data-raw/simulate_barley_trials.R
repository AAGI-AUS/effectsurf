# ============================================================================
# Simulate barley_trials dataset for effectsurf package
#
# Produces agronomic patterns matching Figures 5-7 in the GRDC Theme 4
# report (Paynter, Moldovan, Graham, Khan, 2026):
#   Fig 5: Yield & Retention  vs  N x Seedrate      (by variety_type)
#   Fig 6: Yield & Hectolitre vs  N x Rainfall       (by variety_type)
#   Fig 7: Yield & Retention  vs  Seedrate x Sow DOY (by variety_type)
#
# Key relationships embedded:
#   - Yield: diminishing returns to N, strong N x rainfall interaction,
#     variety_type differences (sdw > erectoides > tall at high inputs),
#     erectoides most N-responsive, sowing optimum ~DOY 148
#   - Hectolitre: relatively stable (68-71), small variety effect,
#     slight negative N effect, mild positive rainfall effect
#   - Retention: 50-95%, sdw highest, decreases with late sowing and
#     excess N, inversely related to screenings
#   - Screenings: 1-25%, erectoides highest, increases with N
#   - Protein: inverse dilution with yield, increases with N
# ============================================================================

set.seed(42)

# ---- Trial structure ----
n_trials <- 20
trials <- data.frame(
  trial = paste0("T", sprintf("%02d", 1:n_trials)),
  state = rep(c("WA", "WA", "VIC", "NSW", "NSW"), length.out = n_trials),
  year = rep(2010:2016, length.out = n_trials),
  site_rainfall = round(runif(n_trials, 120, 550)),
  site_sow_doy = round(runif(n_trials, 132, 165)),
  trial_effect = rnorm(n_trials, 0, 0.45),
  stringsAsFactors = FALSE
)
year_effects <- setNames(rnorm(7, 0, 0.25), as.character(2010:2016))

# ---- Variety mapping ----
varieties <- data.frame(
  variety = c("Bass", "Buloke", "Commander", "Granger", "La Trobe"),
  variety_type = c("sdw", "tall", "tall", "sdw", "erectoides"),
  stringsAsFactors = FALSE
)

# ---- Treatment design ----
nitrogen_levels <- c(0, 20, 30, 80, 90, 150)
seedrate_levels <- c(75, 150, 300)
reps <- 1:3

# Each trial uses 3 of 5 varieties
set.seed(42)
trial_varieties <- lapply(1:n_trials, function(i) sample(varieties$variety, 3))

# ---- Build the dataset ----
rows <- list()
row_id <- 0L

for (t in seq_len(n_trials)) {
  tr <- trials[t, ]
  yr_eff <- year_effects[as.character(tr$year)]
  vars <- trial_varieties[[t]]

  for (v in vars) {
    vtype <- varieties$variety_type[varieties$variety == v]
    for (n in nitrogen_levels) {
      for (sr in seedrate_levels) {
        for (r in reps) {
          row_id <- row_id + 1L

          rainfall <- max(90, min(610, tr$site_rainfall + rnorm(1, 0, 15)))
          sow_doy <- tr$site_sow_doy + sample(-2:2, 1)

          # -- YIELD (Figs 5L, 6L, 7L) --
          base_yield <- switch(vtype,
            tall = 2.10, sdw = 2.30, erectoides = 1.90)
          rain_eff <- 1.8 * plogis((rainfall - 280) / 70)
          n_max <- switch(vtype,
            tall = 0.70, sdw = 0.80, erectoides = 1.30)
          n_eff <- n_max * (1 - exp(-n / 60))
          n_rain_eff <- 0.004 * n * plogis((rainfall - 250) / 80)
          sr_eff <- 0.25 * (1 - exp(-(sr - 50) / 120))
          sow_opt <- switch(vtype, tall = 146, sdw = 148, erectoides = 150)
          sow_eff <- -0.018 * (sow_doy - sow_opt)^2 / 10
          state_eff <- switch(tr$state, WA = 0, VIC = 0.15, NSW = -0.10)
          yield <- max(0.3, base_yield + rain_eff + n_eff + n_rain_eff +
            sr_eff + sow_eff + state_eff + tr$trial_effect + yr_eff +
            rnorm(1, 0, 0.22))

          # -- PROTEIN (dilution with yield, increases with N) --
          protein <- max(6, min(22,
            14.5 - 1.0 * (yield - 2.5) + 0.012 * n + rnorm(1, 0, 0.6)))
          protein_yield <- yield * protein / 100

          # -- HECTOLITRE (Fig 6R: ~68-71, near-flat) --
          hecto_base <- switch(vtype,
            tall = 69.2, sdw = 70.0, erectoides = 68.8)
          hectolitre <- max(62, min(75,
            hecto_base + 0.002 * (rainfall - 200) - 0.004 * n -
            0.02 * abs(sow_doy - 148) + rnorm(1, 0, 0.55)))

          # -- RETENTION (Figs 5R, 7R: 50-95%) --
          ret_base <- switch(vtype, tall = 78, sdw = 85, erectoides = 72)
          retention <- max(40, min(98,
            ret_base + 0.015 * (rainfall - 250) - 0.035 * n +
            0.008 * (sr - 150) - 0.12 * max(0, sow_doy - 150) -
            0.05 * max(0, 145 - sow_doy) + rnorm(1, 0, 2.5)))

          # -- SCREENINGS (roughly inverse of retention) --
          scr_base <- switch(vtype, tall = 5.0, sdw = 3.5, erectoides = 7.0)
          screenings <- max(0.5, min(30,
            scr_base + 0.025 * n - 0.008 * (rainfall - 250) +
            0.08 * max(0, sow_doy - 150) + rnorm(1, 0, 1.5)))

          # -- AVERAGE GRAIN WEIGHT (mg) --
          agw_base <- switch(vtype, tall = 42, sdw = 44, erectoides = 40)
          agw <- max(28, min(58,
            agw_base + 0.005 * rainfall - 0.01 * n + rnorm(1, 0, 1.8)))

          # -- GRAINS PER M2 --
          grains_m2 <- max(3000, round((yield * 1e6) / agw + rnorm(1, 0, 800)))

          rows[[row_id]] <- data.frame(
            yield = round(yield, 2), protein = round(protein, 1),
            protein_yield = round(protein_yield, 3),
            hectolitre = round(hectolitre, 1),
            screenings = round(screenings, 1), retention = round(retention, 1),
            avgrainwt = round(agw, 1), grains_m2 = grains_m2,
            nitrogen = n, seedrate = sr,
            rainfall = round(rainfall, 0), sow_doy = as.integer(sow_doy),
            variety = v, variety_type = vtype,
            state = tr$state, trial = tr$trial,
            year = tr$year, rep = as.character(r),
            stringsAsFactors = FALSE)
        }
      }
    }
  }
}

barley_trials <- do.call(rbind, rows)
rownames(barley_trials) <- NULL

barley_trials$variety      <- factor(barley_trials$variety)
barley_trials$variety_type <- factor(barley_trials$variety_type,
                                     levels = c("tall", "sdw", "erectoides"))
barley_trials$state        <- factor(barley_trials$state, levels = c("WA", "VIC", "NSW"))
barley_trials$trial        <- factor(barley_trials$trial)
barley_trials$rep          <- factor(barley_trials$rep)

cat("Dataset:", nrow(barley_trials), "x", ncol(barley_trials), "\n")
cat("Yield:", range(barley_trials$yield), "\n")
cat("Hectolitre:", range(barley_trials$hectolitre), "\n")
cat("Retention:", range(barley_trials$retention), "\n")

save(barley_trials, file = "data/barley_trials.rda", compress = "xz")
cat("Saved to data/barley_trials.rda\n")
