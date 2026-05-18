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

test_that("create_mock_data matches enabled as an exact role token", {
  variables <- data.frame(
    variable = c("age", "visits"),
    variableType = c("Continuous", "Continuous"),
    rType = c("integer", "integer"),
    role = c("enabled", "disabled"),
    stringsAsFactors = FALSE
  )

  variable_details <- data.frame(
    variable = c("age", "visits"),
    recStart = c("[18,85]", "[0,20]"),
    recEnd = c("copy", "copy"),
    proportion = c(1, 1),
    stringsAsFactors = FALSE
  )

  result <- create_mock_data(
    databaseStart = "study",
    variables = variables,
    variable_details = variable_details,
    n = 5,
    seed = 1
  )

  expect_equal(names(result), "age")
})

test_that("create_mock_data supports whitespace-separated role tokens", {
  variables <- data.frame(
    variable = c("age", "visits"),
    variableType = c("Continuous", "Continuous"),
    rType = c("integer", "integer"),
    role = c("enabled predictor", "disabled"),
    stringsAsFactors = FALSE
  )

  variable_details <- data.frame(
    variable = c("age", "visits"),
    recStart = c("[18,85]", "[0,20]"),
    recEnd = c("copy", "copy"),
    proportion = c(1, 1),
    stringsAsFactors = FALSE
  )

  result <- create_mock_data(
    databaseStart = "study",
    variables = variables,
    variable_details = variable_details,
    n = 5,
    seed = 1
  )

  expect_equal(names(result), "age")
})

test_that("extract_proportions uses recEnd rather than numeric code heuristics for missingness", {
  details <- data.frame(
    variable = "visits",
    recStart = c("7", "17", "27", "99"),
    recEnd = c("7", "17", "27", "NA::b"),
    proportion = c(0.25, 0.25, 0.25, 0.25),
    stringsAsFactors = FALSE
  )

  props <- extract_proportions(details, variable_name = "visits")

  expect_equal(props$categories, c("7", "17", "27"))
  expect_equal(names(props$missing), "99")
  expect_equal(props$valid, 0.75)
})

test_that("create_mock_data fallback mode works when variable_details is NULL", {
  variables <- data.frame(
    variable = c("smoking", "age", "interview_date"),
    variableType = c("Categorical", "Continuous", "Date"),
    rType = c("factor", "integer", "date"),
    role = "enabled",
    stringsAsFactors = FALSE
  )

  expect_warning(
    result <- create_mock_data(
      databaseStart = "study",
      variables = variables,
      variable_details = NULL,
      n = 5,
      seed = 1
    ),
    "No variable_details rows found"
  )

  expect_equal(names(result), variables$variable)
  expect_equal(nrow(result), 5)
  expect_s3_class(result$smoking, "factor")
  expect_type(result$age, "integer")
  expect_s3_class(result$interview_date, "Date")
})

test_that("create_mock_data validate controls unknown rType failures", {
  variables <- data.frame(
    variable = "mystery",
    variableType = "Unknown",
    rType = "unsupported",
    role = "enabled",
    stringsAsFactors = FALSE
  )

  expect_error(
    create_mock_data(
      databaseStart = "study",
      variables = variables,
      variable_details = NULL,
      n = 5,
      validate = TRUE
    ),
    "Unknown variable type"
  )

  expect_warning(
    result <- create_mock_data(
      databaseStart = "study",
      variables = variables,
      variable_details = NULL,
      n = 5,
      validate = FALSE
    ),
    "Unknown variable type"
  )
  expect_equal(nrow(result), 5)
  expect_equal(ncol(result), 0)
})

test_that("rType defaults and validation use lowercase date consistently", {
  details <- data.frame(
    variable = "interview_date",
    typeEnd = "date",
    recStart = "[2020-01-01,2020-12-31]",
    stringsAsFactors = FALSE
  )

  defaulted <- apply_rtype_defaults(details)
  expect_equal(defaulted$rType, "date")

  existing <- details
  existing$rType <- "Date"
  normalized <- apply_rtype_defaults(existing)
  expect_equal(normalized$rType, "date")

  variables <- data.frame(
    variable = "interview_date",
    rType = c("Date", "numeric"),
    stringsAsFactors = FALSE
  )
  result <- MockData:::validate_rtype(variables)
  expect_length(result$errors, 0)
})

test_that("corrupt garbage columns are migrated with a deprecation warning", {
  variables <- data.frame(
    variable = "age",
    variableType = "Continuous",
    rType = "integer",
    role = "enabled",
    corrupt_high_prop = 1,
    corrupt_high_range = "[150,150]",
    stringsAsFactors = FALSE
  )
  details <- data.frame(
    variable = "age",
    recStart = "[18,20]",
    recEnd = "copy",
    proportion = 1,
    stringsAsFactors = FALSE
  )

  expect_warning(
    result <- create_mock_data(
      databaseStart = "study",
      variables = variables,
      variable_details = details,
      n = 5,
      seed = 1
    ),
    "corrupt_\\* garbage columns are deprecated"
  )

  expect_true(all(result$age == 150))
})

test_that("read_mock_data_config migrates corrupt garbage columns", {
  config_file <- tempfile(fileext = ".csv")
  write.csv(data.frame(
    variable = "age",
    role = "enabled",
    variableType = "Continuous",
    rType = "integer",
    position = 1,
    corrupt_low_prop = 0.1,
    corrupt_low_range = "[-1,0]",
    stringsAsFactors = FALSE
  ), config_file, row.names = FALSE)

  expect_warning(
    config <- read_mock_data_config(config_file, validate = TRUE),
    "corrupt_\\* garbage columns are deprecated"
  )

  expect_equal(config$garbage_low_prop, 0.1)
  expect_equal(config$garbage_low_range, "[-1,0]")
})

test_that("read_mock_data_config_details migrates corrupt recStart values", {
  details_file <- tempfile(fileext = ".csv")
  write.csv(data.frame(
    variable = "age",
    recStart = c("[18,20]", "corrupt_high"),
    recEnd = c("copy", "copy"),
    proportion = c(1, 0.1),
    stringsAsFactors = FALSE
  ), details_file, row.names = FALSE)

  expect_warning(
    details <- read_mock_data_config_details(details_file, validate = TRUE),
    "corrupt_\\* recStart values are deprecated"
  )

  expect_true("garbage_high" %in% details$recStart)
})

test_that("garbage validation rejects low and high proportions above one", {
  variables <- data.frame(
    variable = "age",
    garbage_low_prop = 0.6,
    garbage_low_range = "[-1,0]",
    garbage_high_prop = 0.6,
    garbage_high_range = "[150,200]",
    stringsAsFactors = FALSE
  )

  result <- MockData:::validate_garbage(variables)

  expect_match(
    result$errors,
    "garbage_low_prop \\+ garbage_high_prop must be <= 1"
  )
})

test_that("garbage validation rejects non-numeric proportions", {
  variables <- data.frame(
    variable = "age",
    garbage_low_prop = "high",
    garbage_low_range = "[-1,0]",
    garbage_high_prop = "0,5",
    garbage_high_range = "[150,200]",
    stringsAsFactors = FALSE
  )

  result <- MockData:::validate_garbage(variables)

  expect_true(any(grepl("garbage_low_prop values must be numeric", result$errors)))
  expect_true(any(grepl("garbage_high_prop values must be numeric", result$errors)))
})

test_that("create_mock_data summarizes skipped variables when validate is FALSE", {
  variables <- data.frame(
    variable = "mystery",
    variableType = "Unknown",
    rType = "unsupported",
    role = "enabled",
    stringsAsFactors = FALSE
  )

  expect_message(
    expect_warning(
      result <- create_mock_data(
        databaseStart = "study",
        variables = variables,
        variable_details = NULL,
        n = 5,
        validate = FALSE
      ),
      "Unknown variable type"
    ),
    "Skipped variables"
  )

  expect_equal(nrow(result), 5)
  expect_equal(ncol(result), 0)
})
