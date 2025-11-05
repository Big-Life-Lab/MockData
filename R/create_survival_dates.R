#' Create paired survival dates for cohort studies
#'
#' Generates entry and event dates with guaranteed temporal ordering (entry < event).
#' Useful for survival analysis, cohort studies, and time-to-event modeling.
#'
#' **Configuration v0.2 format (NEW):**
#' @param entry_var_row data.frame. Single row from mock_data_config for entry date variable
#' @param entry_details_subset data.frame. Rows from mock_data_config_details for entry date
#' @param event_var_row data.frame. Single row from mock_data_config for event date variable
#' @param event_details_subset data.frame. Rows from mock_data_config_details for event date
#' @param n integer. Number of observations to generate
#' @param seed integer. Random seed for reproducibility. If NULL, uses global seed.
#' @param df_mock data.frame. The current mock data (to check if variables already exist)
#'
#' **Configuration v0.1 format (LEGACY):**
#' @param entry_var character. Name for entry date variable
#' @param event_var character. Name for event date variable
#' @param entry_start Date. Start of entry period
#' @param entry_end Date. End of entry period
#' @param followup_min integer. Minimum follow-up days
#' @param followup_max integer. Maximum follow-up days
#' @param length integer. Number of records to generate
#' @param event_distribution character. Distribution for time-to-event: "uniform", "gompertz", "exponential"
#' @param prop_censored numeric. Proportion of records to censor (0-1)
#' @param prop_NA numeric. Proportion of missing values (0-1)
#'
#' @return data.frame with entry_date, event_date, and optionally event_status columns, or NULL if:
#'   - Variables already exist in df_mock
#'   - Missing required configuration
#'
#' @details
#' **v0.2 format (NEW):**
#' - Extracts date ranges from entry_details_subset and event_details_subset
#' - Generates entry dates uniformly distributed
#' - Calculates event dates to ensure entry < event
#' - Supports fallback mode: reasonable defaults when details_subset is NULL
#'
#' **v0.1 format (LEGACY):**
#' - Accepts explicit date ranges and follow-up parameters
#' - Supports multiple event distributions (uniform, gompertz, exponential)
#' - Handles censoring and missing values via parameters
#'
#' The function auto-detects which format based on parameter names.
#'
#' This function generates realistic survival data by:
#' 1. Creating entry dates uniformly distributed across entry period
#' 2. Generating follow-up times using specified distribution
#' 3. Calculating event dates (entry + follow-up)
#' 4. Optionally censoring events (event_status = 0)
#' 5. Ensuring entry_date < event_date for all records
#'
#' **Event distributions:**
#' - "uniform": Constant hazard over follow-up period
#' - "gompertz": Increasing hazard (mortality increases with time)
#' - "exponential": Decreasing hazard (early events more common)
#'
#' **Censoring:**
#' When prop_censored > 0, generates event_status column:
#' - 1 = event observed
#' - 0 = censored (event_date becomes censoring date)
#'
#' @examples
#' \dontrun{
#' # v0.2 format - called by create_mock_data()
#' config <- read_mock_data_config("mock_data_config.csv")
#' details <- read_mock_data_config_details("mock_data_config_details.csv")
#' entry_row <- config[config$variable == "study_entry", ]
#' entry_details <- get_variable_details(details, variable_name = "study_entry")
#' event_row <- config[config$variable == "death_date", ]
#' event_details <- get_variable_details(details, variable_name = "death_date")
#' surv_data <- create_survival_dates(
#'   entry_var_row = entry_row,
#'   entry_details_subset = entry_details,
#'   event_var_row = event_row,
#'   event_details_subset = event_details,
#'   n = 1000,
#'   seed = 123
#' )
#'
#' # v0.1 format (legacy) - Basic mortality study
#' surv_data <- create_survival_dates(
#'   entry_var = "study_entry",
#'   event_var = "death_date",
#'   entry_start = as.Date("2000-01-01"),
#'   entry_end = as.Date("2005-12-31"),
#'   followup_min = 365,
#'   followup_max = 3650,
#'   length = 1000,
#'   df_mock = data.frame(),
#'   event_distribution = "gompertz"
#' )
#'
#' # v0.1 with censoring
#' surv_data <- create_survival_dates(
#'   entry_var = "cohort_entry",
#'   event_var = "event_date",
#'   entry_start = as.Date("2010-01-01"),
#'   entry_end = as.Date("2015-12-31"),
#'   followup_min = 30,
#'   followup_max = 1825,
#'   length = 500,
#'   df_mock = data.frame(),
#'   event_distribution = "exponential",
#'   prop_censored = 0.3
#' )
#' }
#'
#' @family generators
#' @export
create_survival_dates <- function(entry_var_row = NULL, entry_details_subset = NULL,
                                   event_var_row = NULL, event_details_subset = NULL,
                                   n = NULL, seed = NULL, df_mock = NULL,
                                   # v0.1 legacy parameters
                                   entry_var = NULL, event_var = NULL,
                                   entry_start = NULL, entry_end = NULL,
                                   followup_min = NULL, followup_max = NULL,
                                   length = NULL,
                                   event_distribution = "uniform",
                                   prop_censored = 0,
                                   prop_NA = NULL) {

  # Auto-detect format based on parameters
  use_v02 <- !is.null(entry_var_row) && is.data.frame(entry_var_row) && nrow(entry_var_row) == 1 &&
             !is.null(event_var_row) && is.data.frame(event_var_row) && nrow(event_var_row) == 1

  if (use_v02) {
    # ========== v0.2 IMPLEMENTATION ==========
    entry_var_name <- entry_var_row$variable
    event_var_name <- event_var_row$variable

    # Check if variables already exist in mock data
    if (!is.null(df_mock) && (entry_var_name %in% names(df_mock) || event_var_name %in% names(df_mock))) {
      return(NULL)
    }

    # Set seed if provided
    if (!is.null(seed)) set.seed(seed)

    # FALLBACK MODE: Default ranges if details_subset is NULL
    if (is.null(entry_details_subset) || nrow(entry_details_subset) == 0) {
      entry_start <- as.Date("2000-01-01")
      entry_end <- as.Date("2005-12-31")
    } else {
      # Extract date_start and date_end from entry_details_subset
      date_start_row <- entry_details_subset[entry_details_subset$recEnd == "date_start", ]
      date_end_row <- entry_details_subset[entry_details_subset$recEnd == "date_end", ]

      if (nrow(date_start_row) == 0 || nrow(date_end_row) == 0) {
        warning(paste0("Missing date_start or date_end for ", entry_var_name, ". Using defaults."))
        entry_start <- as.Date("2000-01-01")
        entry_end <- as.Date("2005-12-31")
      } else {
        entry_start <- as.Date(date_start_row$date_start[1])
        entry_end <- as.Date(date_end_row$date_end[1])

        if (is.na(entry_start) || is.na(entry_end)) {
          warning(paste0("Invalid date_start or date_end for ", entry_var_name, ". Using defaults."))
          entry_start <- as.Date("2000-01-01")
          entry_end <- as.Date("2005-12-31")
        }
      }
    }

    # For event dates, extract follow-up range if available
    if (is.null(event_details_subset) || nrow(event_details_subset) == 0) {
      # Default: 1-10 years follow-up
      followup_min <- 365
      followup_max <- 3650
    } else {
      # Look for followup_min and followup_max in details_subset
      followup_min_row <- event_details_subset[event_details_subset$recEnd == "followup_min", ]
      followup_max_row <- event_details_subset[event_details_subset$recEnd == "followup_max", ]

      if (nrow(followup_min_row) > 0 && nrow(followup_max_row) > 0) {
        followup_min <- as.numeric(followup_min_row$value[1])
        followup_max <- as.numeric(followup_max_row$value[1])

        if (is.na(followup_min) || is.na(followup_max)) {
          warning(paste0("Invalid followup range for ", event_var_name, ". Using defaults."))
          followup_min <- 365
          followup_max <- 3650
        }
      } else {
        # Fallback: 1-10 years
        followup_min <- 365
        followup_max <- 3650
      }
    }

    # Generate entry dates (uniform distribution)
    entry_range_days <- as.numeric(entry_end - entry_start)
    entry_days <- sample(0:entry_range_days, n, replace = TRUE)
    entry_dates <- entry_start + entry_days

    # Generate follow-up times (uniform distribution for v0.2)
    followup_days <- sample(followup_min:followup_max, n, replace = TRUE)

    # Calculate event dates
    event_dates <- entry_dates + round(followup_days)

    # Create result data frame
    result <- data.frame(
      entry = entry_dates,
      event = event_dates,
      stringsAsFactors = FALSE
    )

    # Rename columns to variable names
    names(result)[1] <- entry_var_name
    names(result)[2] <- event_var_name

    return(result)

  } else {
    # ========== v0.1 LEGACY IMPLEMENTATION ==========

    # Validate inputs
    if (!inherits(entry_start, "Date") || !inherits(entry_end, "Date")) {
      stop("entry_start and entry_end must be Date objects")
    }
    if (entry_start >= entry_end) {
      stop("entry_start must be before entry_end")
    }
    if (followup_min >= followup_max) {
      stop("followup_min must be less than followup_max")
    }
    if (prop_censored < 0 || prop_censored > 1) {
      stop("prop_censored must be between 0 and 1")
    }

    # Check if variables already exist
    if (entry_var %in% names(df_mock) || event_var %in% names(df_mock)) {
      return(NULL)
    }

    if (!is.null(seed)) set.seed(seed)

    # Generate entry dates (uniform distribution)
    entry_range_days <- as.numeric(entry_end - entry_start)
    entry_days <- sample(0:entry_range_days, length, replace = TRUE)
    entry_dates <- entry_start + entry_days

    # Generate follow-up times based on distribution
    if (event_distribution == "uniform") {
      followup_days <- sample(followup_min:followup_max, length, replace = TRUE)

    } else if (event_distribution == "gompertz") {
      # Gompertz: increasing hazard over time
      # Use inverse transform sampling
      u <- runif(length)
      shape <- 0.1
      rate <- 0.01

      # Scale to follow-up range
      range_days <- followup_max - followup_min
      gompertz_days <- (-1/rate) * log(1 - (rate/shape) * log(1 - u))

      # Normalize to desired range
      gompertz_days <- gompertz_days / max(gompertz_days, na.rm = TRUE) * range_days
      followup_days <- pmax(followup_min, pmin(followup_max, followup_min + gompertz_days))

    } else if (event_distribution == "exponential") {
      # Exponential: early events more common
      rate <- 3 / (followup_max - followup_min)
      exp_days <- rexp(length, rate = rate)
      followup_days <- pmax(followup_min, pmin(followup_max, followup_min + exp_days))

    } else {
      stop("event_distribution must be 'uniform', 'gompertz', or 'exponential'")
    }

    # Calculate event dates
    event_dates <- entry_dates + round(followup_days)

    # Create result data frame
    result <- data.frame(
      entry = entry_dates,
      event = event_dates,
      stringsAsFactors = FALSE
    )

    # Add censoring if requested
    if (prop_censored > 0) {
      n_censored <- floor(length * prop_censored)
      censored_indices <- sample(1:length, n_censored, replace = FALSE)

      result$event_status <- 1
      result$event_status[censored_indices] <- 0

      # For censored records, event_date becomes censoring date
      # (administratively censored at random point in follow-up)
      for (i in censored_indices) {
        max_censor_days <- as.numeric(result$event[i] - result$entry[i])
        censor_days <- sample(followup_min:max_censor_days, 1)
        result$event[i] <- result$entry[i] + censor_days
      }
    }

    # Add missing values if requested
    if (!is.null(prop_NA) && prop_NA > 0) {
      n_na <- floor(length * prop_NA)
      na_indices <- sample(1:length, n_na, replace = FALSE)

      # Set both dates to NA for missing records
      result$entry[na_indices] <- NA
      result$event[na_indices] <- NA
    }

    # Rename columns to user-specified names
    names(result)[1] <- entry_var
    names(result)[2] <- event_var

    return(result)
  }
}
