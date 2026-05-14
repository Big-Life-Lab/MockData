test_that("create_con_var falls back cleanly when distribution parameters are absent", {
  details <- data.frame(
    variable = "age",
    recStart = "[18,85]",
    recEnd = "valid",
    proportion = 1,
    databaseStart = "study",
    stringsAsFactors = FALSE
  )

  variables_normal <- data.frame(
    variable = "age",
    variableType = "Continuous",
    rType = "integer",
    distribution = "normal",
    stringsAsFactors = FALSE
  )

  expect_warning(
    normal_result <- create_con_var(
      var = "age",
      databaseStart = "study",
      variables = variables_normal,
      variable_details = details,
      n = 10,
      seed = 1
    ),
    "requested normal distribution"
  )
  expect_s3_class(normal_result, "data.frame")
  expect_equal(nrow(normal_result), 10)

  variables_exponential <- variables_normal
  variables_exponential$distribution <- "exponential"

  expect_warning(
    exponential_result <- create_con_var(
      var = "age",
      databaseStart = "study",
      variables = variables_exponential,
      variable_details = details,
      n = 10,
      seed = 1
    ),
    "requested exponential distribution"
  )
  expect_s3_class(exponential_result, "data.frame")
  expect_equal(nrow(exponential_result), 10)
})

test_that("garbage validation accepts comma and semicolon interval notation", {
  variables <- data.frame(
    variable = "age",
    garbage_low_prop = 0.02,
    garbage_low_range = "[-10, 15)",
    garbage_high_prop = 0.03,
    garbage_high_range = "[150; 200]",
    stringsAsFactors = FALSE
  )

  result <- MockData:::validate_garbage(variables)

  expect_length(result$errors, 0)
})

test_that("print.mockdata_validation_result prints info entries", {
  result <- list(
    files = list(variables = "variables.csv", variable_details = "variable_details.csv"),
    mode = "basic",
    timestamp = as.POSIXct("2026-05-14", tz = "UTC"),
    valid = TRUE,
    errors = character(0),
    warnings = character(0),
    info = c("first note", "second note")
  )
  class(result) <- "mockdata_validation_result"

  expect_output(print(result), "1. first note")
  expect_output(print(result), "2. second note")
})

test_that("create_survival_dates reads v0.3 date ranges from recStart", {
  entry_row <- data.frame(variable = "entry_date", stringsAsFactors = FALSE)
  event_row <- data.frame(variable = "event_date", stringsAsFactors = FALSE)

  entry_details <- data.frame(
    variable = "entry_date",
    recStart = c("2010-01-01", "2010-01-01"),
    recEnd = c("date_start", "date_end"),
    value = c(NA, "2010-01-01"),
    proportion = NA_real_,
    catLabel = NA_character_,
    stringsAsFactors = FALSE
  )

  event_details <- data.frame(
    variable = "event_date",
    recStart = c("followup_min", "followup_max"),
    recEnd = c("followup_min", "followup_max"),
    value = c(30, 30),
    proportion = NA_real_,
    catLabel = NA_character_,
    stringsAsFactors = FALSE
  )

  result <- create_survival_dates(
    entry_var_row = entry_row,
    entry_details_subset = entry_details,
    event_var_row = event_row,
    event_details_subset = event_details,
    n = 3,
    seed = 1
  )

  expect_equal(result$entry_date, rep(as.Date("2010-01-01"), 3))
  expect_equal(result$event_date, rep(as.Date("2010-01-31"), 3))
})

test_that("apply_garbage samples from a length-one valid index safely", {
  var_row <- data.frame(
    variable = "age",
    garbage_low_prop = 1,
    garbage_low_range = "[-1,0]",
    garbage_high_prop = NA_real_,
    garbage_high_range = NA_character_,
    stringsAsFactors = FALSE
  )

  result <- apply_garbage(c(NA, 10), var_row, "integer", seed = 1)

  expect_true(is.na(result[1]))
  expect_true(!is.na(result[2]))
  expect_true(result[2] <= 0)
})

test_that("generators match databaseStart as exact comma-separated tokens", {
  variables <- data.frame(
    variable = "smoking",
    variableType = "Categorical",
    rType = "character",
    stringsAsFactors = FALSE
  )
  details <- data.frame(
    variable = c("smoking", "smoking"),
    recStart = c("1", "2"),
    recEnd = c("valid", "valid"),
    catLabel = c("Current smoker", "Former smoker"),
    proportion = c(1, 1),
    databaseStart = c("cycle1", "cycle10"),
    stringsAsFactors = FALSE
  )

  result <- create_cat_var(
    var = "smoking",
    databaseStart = "cycle1",
    variables = variables,
    variable_details = details,
    n = 5,
    seed = 1
  )

  expect_equal(unique(result$smoking), "1")
})

test_that("import_from_recodeflow uses exact databaseStart tokens", {
  temp_dir <- tempfile()
  dir.create(temp_dir)

  variables_path <- file.path(temp_dir, "variables.csv")
  details_path <- file.path(temp_dir, "variable_details.csv")
  output_dir <- file.path(temp_dir, "out")

  write.csv(data.frame(
    variable = c("age_2017", "age_2018"),
    role = c("mockdata", "mockdata"),
    variableType = c("Continuous", "Continuous"),
    databaseStart = c("cchs2017", "cchs2017_2018_p"),
    stringsAsFactors = FALSE
  ), variables_path, row.names = FALSE)

  write.csv(data.frame(
    variable = c("age_2017", "age_2018"),
    recStart = c("[18,100]", "[18,100]"),
    databaseStart = c("cchs2017", "cchs2017_2018_p"),
    stringsAsFactors = FALSE
  ), details_path, row.names = FALSE)

  imported <- import_from_recodeflow(
    variables_path = variables_path,
    variable_details_path = details_path,
    database = "cchs2017",
    output_dir = output_dir
  )

  expect_equal(imported$config$variable, "age_2017")
  expect_equal(imported$details$variable, "age_2017")
})
