# tests/testthat/test-survival-characterization.R
# Characterization of the legacy survival engine (create_wide_survival_data()),
# pinned before the #40 port. ADR: development/adr/v05-survival-dates.md (D4).
# These describe current behaviour, including behaviour filed as concerns
# (#54, #56); they are the reference the metadata-driven stage must match.

legacy_fixture <- function(event_window, death_window,
                           event_prop = 1, death_prop = 1) {
  list(
    variables = data.frame(
      variable = c("entry", "event", "death"),
      variableType = c("Date", "Date", "Date"),
      rType = c("date", "date", "date"),
      role = c("enabled", "enabled", "enabled"),
      distribution = c("uniform", "uniform", "uniform"),
      followup_min = c(NA, event_window[1], death_window[1]),
      followup_max = c(NA, event_window[2], death_window[2]),
      event_prop = c(NA, event_prop, death_prop),
      sourceFormat = c("analysis", "analysis", "analysis"),
      stringsAsFactors = FALSE
    ),
    variable_details = data.frame(
      variable = c("entry", "event", "death"),
      recStart = c("[2001-01-01,2001-12-31]",
                   "[2001-01-01,2040-12-31]",
                   "[2001-01-01,2040-12-31]"),
      recEnd = c("copy", "copy", "copy"),
      proportion = c(1, 1, 1),
      stringsAsFactors = FALSE
    )
  )
}

run_legacy <- function(fx, n = 200, seed = 1) {
  suppressWarnings(create_wide_survival_data(
    var_entry_date = "entry",
    var_event_date = "event",
    var_death_date = "death",
    databaseStart = "test",
    variables = fx$variables,
    variable_details = fx$variable_details,
    n = n,
    seed = seed
  ))
}

days_from_entry <- function(result, column) {
  as.numeric(result[[column]] - result$entry)
}

test_that("legacy: an event later than death is set to NA (competing risk)", {
  result <- run_legacy(legacy_fixture(c(1000, 2000), c(0, 500)))
  expect_true(all(is.na(result$event)))
  expect_false(any(is.na(result$death)))
})

test_that("legacy: an event earlier than death is kept", {
  result <- run_legacy(legacy_fixture(c(0, 500), c(1000, 2000)))
  expect_false(any(is.na(result$event)))
})

test_that("legacy: exactly floor(n * event_prop) rows receive an event", {
  result <- run_legacy(legacy_fixture(c(100, 200), c(100, 200),
                                      event_prop = 0.3, death_prop = 0),
                       n = 200)
  expect_identical(sum(!is.na(result$event)), 60L)
  expect_true(all(is.na(result$death)))
})

test_that("legacy: follow-up days are whole days inside the window", {
  result <- run_legacy(legacy_fixture(c(100, 200), c(5000, 6000)))
  days <- days_from_entry(result, "event")
  days <- days[!is.na(days)]
  expect_true(all(days == floor(days)))
  expect_true(all(days >= 100 & days <= 200))
})

test_that("legacy: on the minimal example no date precedes the entry date", {
  vars <- system.file("extdata", "minimal-example", "variables.csv", package = "MockData")
  dets <- system.file("extdata", "minimal-example", "variable_details.csv", package = "MockData")
  if (!nzchar(vars) || !nzchar(dets)) skip("minimal-example fixtures not installed")
  variables <- read.csv(vars, stringsAsFactors = FALSE, check.names = FALSE)
  variable_details <- read.csv(dets, stringsAsFactors = FALSE, check.names = FALSE)
  result <- suppressWarnings(create_wide_survival_data(
    var_entry_date = "interview_date",
    var_event_date = "primary_event_date",
    var_death_date = "death_date",
    var_ltfu = "ltfu_date",
    var_admin_censor = "admin_censor_date",
    databaseStart = "minimal-example",
    variables = variables,
    variable_details = variable_details,
    n = 2000,
    seed = 1
  ))
  for (column in c("primary_event_date", "death_date", "ltfu_date", "admin_censor_date")) {
    ok <- !is.na(result[[column]])
    expect_true(all(result[[column]][ok] >= result$interview_date[ok]), info = column)
  }
  # #54: with the packaged Gompertz parameters every non-garbage death lands
  # exactly at followup_min (365 days). Garbage deaths are 2025 or later.
  # Update this expectation deliberately when #54 is resolved.
  days <- as.numeric(result$death_date - result$interview_date)
  clean <- !is.na(days) & result$death_date < as.Date("2025-01-01")
  expect_true(any(clean))
  expect_true(all(days[clean] == 365))
})
