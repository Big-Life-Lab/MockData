# tests/testthat/test-range-missing-codes.R
# Range-notation missing codes such as "[997,999]" on the v0.4 path (#58).
# recodeflow writes grouped missing codes (don't know / refusal / not stated)
# as integer ranges; the adapter must expand them into individual codes.

range_continuous_metadata <- function(missing_start = "[997,999]") {
  list(
    variables = data.frame(
      variable = "age",
      variableType = "Continuous",
      rType = "integer",
      role = "enabled",
      stringsAsFactors = FALSE
    ),
    variable_details = data.frame(
      variable = "age",
      recStart = c("[18,85]", "996", missing_start),
      recEnd = c("copy", "NA::a", "NA::b"),
      proportion = c(NA, 0.05, 0.09),
      stringsAsFactors = FALSE
    )
  )
}

range_categorical_metadata <- function() {
  list(
    variables = data.frame(
      variable = "smoke",
      variableType = "Categorical",
      rType = "character",
      role = "enabled",
      stringsAsFactors = FALSE
    ),
    variable_details = data.frame(
      variable = "smoke",
      recStart = c("1", "2", "6", "[7, 9]"),
      recEnd = c("1", "2", "NA::a", "NA::b"),
      proportion = c(0.5, 0.3, 0.05, 0.15),
      stringsAsFactors = FALSE
    )
  )
}

test_that("the adapter expands an integer range missing code on a continuous variable", {
  md <- range_continuous_metadata()
  spec <- mock_spec_from_recodeflow(md$variables, md$variable_details)
  age <- spec$variables$age
  expect_identical(age$missing_codes, c("996", "997", "998", "999"))
  expect_equal(age$missing_proportions, c(0.05, 0.03, 0.03, 0.03))
})

test_that("the adapter expands an integer range missing code on a categorical variable", {
  md <- range_categorical_metadata()
  spec <- suppressWarnings(mock_spec_from_recodeflow(md$variables, md$variable_details))
  smoke <- spec$variables$smoke
  expect_identical(smoke$missing_codes, c("6", "7", "8", "9"))
  expect_equal(sum(smoke$missing_proportions[2:4]), sum(smoke$missing_proportions) - smoke$missing_proportions[1])
  expect_equal(smoke$missing_proportions[2], smoke$missing_proportions[3])
  expect_false(any(startsWith(smoke$missing_codes, "[")))
})

test_that("create_mock_data generates range missing codes on the v0.4 path (#58 reproduction)", {
  md <- range_continuous_metadata()
  expect_message(
    result <- create_mock_data("study", md$variables, md$variable_details,
                               n = 3000, seed = 1, verbose = TRUE),
    "Generating via v0.4 mock_spec pipeline"
  )
  expect_true(all(c(997L, 998L, 999L) %in% result$age))
  valid <- result$age[result$age < 996]
  expect_true(all(valid >= 18 & valid <= 85))
})

test_that("categorical output never contains a literal bracketed code", {
  md <- range_categorical_metadata()
  result <- suppressWarnings(create_mock_data(
    "study", md$variables, md$variable_details, n = 2000, seed = 1
  ))
  expect_false(any(startsWith(as.character(result$smoke), "[")))
  expect_true(all(c("7", "8", "9") %in% result$smoke))
})

test_that("a non-integer range missing code fails with a message naming the fix", {
  md <- range_continuous_metadata(missing_start = "[99.6,99.9]")
  expect_error(
    mock_spec_from_recodeflow(md$variables, md$variable_details),
    "Variable 'age' has a range missing code '\\[99.6,99.9\\]' that is not an integer range"
  )
})

test_that("an unparseable bracketed missing code fails rather than passing through literally", {
  md <- range_continuous_metadata(missing_start = "[996]")
  expect_error(
    mock_spec_from_recodeflow(md$variables, md$variable_details),
    "has a range missing code '\\[996\\]' that is not an integer range"
  )
})

test_that("the minimal example's non-survival variables generate via the v0.4 pipeline", {
  # The minimal example's Gompertz survival dates force the legacy generator,
  # which hid that the rest of the example failed on the v0.4 path: BMI's
  # "[997,999]" missing code (#58) and two fixture errors (BMI's garbage range
  # typo, height's low-garbage proportion of 1.00). #40 depends on this.
  vars <- system.file("extdata", "minimal-example", "variables.csv", package = "MockData")
  dets <- system.file("extdata", "minimal-example", "variable_details.csv", package = "MockData")
  if (!nzchar(vars) || !nzchar(dets)) skip("minimal-example fixtures not installed")
  variables <- read.csv(vars, stringsAsFactors = FALSE, check.names = FALSE)
  variable_details <- read.csv(dets, stringsAsFactors = FALSE, check.names = FALSE)
  survival <- c("primary_event_date", "death_date", "ltfu_date", "admin_censor_date")
  variables <- variables[!variables$variable %in% survival, ]

  expect_message(
    result <- suppressWarnings(create_mock_data(
      "minimal-example", variables, variable_details,
      n = 500, seed = 1, verbose = TRUE
    )),
    "Generating via v0.4 mock_spec pipeline"
  )
  expect_true(all(c("age", "smoking", "BMI", "height", "weight") %in% names(result)))
  expect_true(any(result$BMI %in% c(997, 998, 999)))
})
