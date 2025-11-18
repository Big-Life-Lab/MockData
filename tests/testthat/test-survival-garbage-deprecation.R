test_that("create_wide_survival_data() shows deprecation warning for prop_garbage", {
  variables <- read.csv(
    system.file("extdata/minimal-example/variables.csv", package = "MockData"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  variable_details <- read.csv(
    system.file("extdata/minimal-example/variable_details.csv", package = "MockData"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  # Using prop_garbage should trigger deprecation warning
  expect_warning(
    create_wide_survival_data(
      var_entry_date = "interview_date",
      var_event_date = "primary_event_date",
      var_death_date = NULL,
      var_ltfu = NULL,
      var_admin_censor = NULL,
      databaseStart = "minimal-example",
      variables = variables,
      variable_details = variable_details,
      n = 100,
      seed = 123,
      prop_garbage = 0.03  # This should trigger warning
    ),
    regexp = "deprecated as of v0.3.1"
  )
})

test_that("create_wide_survival_data() works without prop_garbage parameter", {
  variables <- read.csv(
    system.file("extdata/minimal-example/variables.csv", package = "MockData"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  variable_details <- read.csv(
    system.file("extdata/minimal-example/variable_details.csv", package = "MockData"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  # Should work without deprecation warnings when prop_garbage is NULL
  # (Note: May produce other warnings like auto-normalize, which is expected)
  result <- suppressWarnings(
    create_wide_survival_data(
      var_entry_date = "interview_date",
      var_event_date = "primary_event_date",
      var_death_date = "death_date",
      var_ltfu = NULL,
      var_admin_censor = NULL,
      databaseStart = "minimal-example",
      variables = variables,
      variable_details = variable_details,
      n = 100,
      seed = 456
    )
  )

  # Should generate data successfully
  expect_true(is.data.frame(result))
  expect_true("interview_date" %in% names(result))
  expect_true("primary_event_date" %in% names(result))
  expect_true("death_date" %in% names(result))
  expect_equal(nrow(result), 100)
})

test_that("survival data temporal ordering is enforced (no garbage mode)", {
  variables <- read.csv(
    system.file("extdata/minimal-example/variables.csv", package = "MockData"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  variable_details <- read.csv(
    system.file("extdata/minimal-example/variable_details.csv", package = "MockData"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  result <- create_wide_survival_data(
    var_entry_date = "interview_date",
    var_event_date = "primary_event_date",
    var_death_date = "death_date",
    var_ltfu = NULL,
    var_admin_censor = NULL,
    databaseStart = "minimal-example",
    variables = variables,
    variable_details = variable_details,
    n = 500,
    seed = 789
  )

  # Check: All events occur after entry
  entry_dates <- result$interview_date
  event_dates <- result$primary_event_date
  death_dates <- result$death_date

  # Events after entry
  events_after_entry <- event_dates[!is.na(event_dates)] >= entry_dates[!is.na(event_dates)]
  expect_true(all(events_after_entry))

  # Deaths after entry
  deaths_after_entry <- death_dates[!is.na(death_dates)] >= entry_dates[!is.na(death_dates)]
  expect_true(all(deaths_after_entry))
})

test_that("survival data garbage via individual date variables works", {
  variables <- read.csv(
    system.file("extdata/minimal-example/variables.csv", package = "MockData"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  variable_details <- read.csv(
    system.file("extdata/minimal-example/variable_details.csv", package = "MockData"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  # Add garbage to death_date using new unified API
  vars_with_garbage <- add_garbage(variables, "death_date",
    garbage_high_prop = 0.05, garbage_high_range = "[2025-01-01, 2099-12-31]")

  # Generate survival data (no prop_garbage parameter)
  result <- create_wide_survival_data(
    var_entry_date = "interview_date",
    var_event_date = "primary_event_date",
    var_death_date = "death_date",
    var_ltfu = NULL,
    var_admin_censor = NULL,
    databaseStart = "minimal-example",
    variables = vars_with_garbage,  # Uses modified variables
    variable_details = variable_details,
    n = 1000,
    seed = 321
  )

  # Check for future death dates (garbage)
  future_threshold <- as.Date("2025-01-01")
  n_future_deaths <- sum(result$death_date > future_threshold, na.rm = TRUE)

  # Should have approximately 5% garbage deaths
  # Note: Some may be set to NA by temporal ordering constraints
  expect_true(n_future_deaths > 0,
    info = "Should have at least some future death dates from garbage")
})

test_that("deprecated prop_garbage parameter is ignored (does not affect results)", {
  variables <- read.csv(
    system.file("extdata/minimal-example/variables.csv", package = "MockData"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  variable_details <- read.csv(
    system.file("extdata/minimal-example/variable_details.csv", package = "MockData"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  # Generate with prop_garbage (should be ignored)
  suppressWarnings(
    result_with_prop <- create_wide_survival_data(
      var_entry_date = "interview_date",
      var_event_date = "primary_event_date",
      var_death_date = "death_date",
      var_ltfu = NULL,
      var_admin_censor = NULL,
      databaseStart = "minimal-example",
      variables = variables,
      variable_details = variable_details,
      n = 100,
      seed = 100,
      prop_garbage = 0.10  # Should be ignored
    )
  )

  # Generate without prop_garbage (same seed)
  result_without_prop <- create_wide_survival_data(
    var_entry_date = "interview_date",
    var_event_date = "primary_event_date",
    var_death_date = "death_date",
    var_ltfu = NULL,
    var_admin_censor = NULL,
    databaseStart = "minimal-example",
    variables = variables,
    variable_details = variable_details,
    n = 100,
    seed = 100
  )

  # Results should be identical (prop_garbage was ignored)
  expect_equal(result_with_prop$interview_date, result_without_prop$interview_date)
  expect_equal(result_with_prop$primary_event_date, result_without_prop$primary_event_date)
  expect_equal(result_with_prop$death_date, result_without_prop$death_date)
})

test_that("survival data creates clean temporally-ordered data by default", {
  variables <- read.csv(
    system.file("extdata/minimal-example/variables.csv", package = "MockData"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  variable_details <- read.csv(
    system.file("extdata/minimal-example/variable_details.csv", package = "MockData"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  result <- create_wide_survival_data(
    var_entry_date = "interview_date",
    var_event_date = "primary_event_date",
    var_death_date = "death_date",
    var_ltfu = NULL,
    var_admin_censor = NULL,
    databaseStart = "minimal-example",
    variables = variables,
    variable_details = variable_details,
    n = 200,
    seed = 999
  )

  # Temporal ordering should be enforced
  # No events should occur before entry
  entry <- result$interview_date
  event <- result$primary_event_date
  death <- result$death_date

  # Check events
  if (any(!is.na(event))) {
    expect_true(all(event[!is.na(event)] >= entry[!is.na(event)]))
  }

  # Check deaths
  if (any(!is.na(death))) {
    expect_true(all(death[!is.na(death)] >= entry[!is.na(death)]))
  }

  # If death occurs before event, event should be NA (competing risk logic)
  # After competing risk logic: if both death and event are non-NA, death >= event
  for (i in 1:nrow(result)) {
    if (!is.na(death[i]) && !is.na(event[i])) {
      # If both exist, death should be >= event (otherwise event would be NA)
      expect_true(death[i] >= event[i],
        info = paste("Row", i, ": death =", death[i], "event =", event[i]))
    }
  }
})
