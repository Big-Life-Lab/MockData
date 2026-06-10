# Tests for .load_metadata_df() — shared metadata-loading helper

test_that(".load_metadata_df passes data frames and NULL through unchanged", {
  df <- data.frame(variable = "age", stringsAsFactors = FALSE)
  expect_identical(MockData:::.load_metadata_df(df, "variables"), df)
  expect_null(MockData:::.load_metadata_df(NULL, "variable_details"))
})

test_that(".load_metadata_df reads a CSV path with check.names = FALSE", {
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path))
  write.csv(
    data.frame(`odd name` = 1:2, check.names = FALSE),
    path, row.names = FALSE
  )
  result <- MockData:::.load_metadata_df(path, "variables")
  expect_s3_class(result, "data.frame")
  expect_named(result, "odd name")
})

test_that(".load_metadata_df errors clearly on a missing file", {
  expect_error(
    MockData:::.load_metadata_df("no/such/file.csv", "variables"),
    "variables file does not exist"
  )
})

test_that(".load_metadata_df rejects non-path, non-data-frame input", {
  expect_error(
    MockData:::.load_metadata_df(c("a.csv", "b.csv"), "variables"),
    "must be a data frame or a single CSV file path"
  )
  expect_error(
    MockData:::.load_metadata_df(42, "variables"),
    "must be a data frame or a single CSV file path"
  )
})

test_that(".load_metadata_df emits the reading message when verbose", {
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path))
  write.csv(data.frame(variable = "age"), path, row.names = FALSE)

  expect_message(
    MockData:::.load_metadata_df(path, "variables", verbose = TRUE),
    "Reading variables file: "
  )
  expect_silent(MockData:::.load_metadata_df(path, "variables"))
})

test_that(".load_metadata_df rejects a directory path", {
  dir_path <- tempfile()
  dir.create(dir_path)
  on.exit(unlink(dir_path, recursive = TRUE))

  expect_error(
    MockData:::.load_metadata_df(dir_path, "variables"),
    "is a directory, not a CSV file"
  )
})
