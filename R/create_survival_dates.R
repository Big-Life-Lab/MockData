#' Create paired survival dates for cohort studies
#'
#' Generates entry and event dates with guaranteed temporal ordering (entry < event).
#' Useful for survival analysis, cohort studies, and time-to-event modeling.
#'
#' @param entry_var character. Name for entry date variable
#' @param event_var character. Name for event date variable
#' @param entry_start Date. Start of entry period
#' @param entry_end Date. End of entry period
#' @param followup_min integer. Minimum follow-up days
#' @param followup_max integer. Maximum follow-up days
#' @param length integer. Number of records to generate
#' @param df_mock data.frame. Existing mock data (for duplicate checking)
#' @param event_distribution character. Distribution for time-to-event: "uniform", "gompertz", "exponential"
#' @param prop_censored numeric. Proportion of records to censor (0-1)
#' @param prop_NA numeric. Proportion of missing values (0-1)
#' @param seed integer. Random seed for reproducibility
#'
#' @return data.frame with entry_date, event_date, and optionally event_status columns
#'
#' @details
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
#' # Basic mortality study
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
#' # With censoring
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
create_survival_dates <- function(entry_var, event_var,
                                   entry_start, entry_end,
                                   followup_min, followup_max,
                                   length, df_mock,
                                   event_distribution = "uniform",
                                   prop_censored = 0,
                                   prop_NA = NULL,
                                   seed = 100) {

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

  set.seed(seed)

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
