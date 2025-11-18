#' Create date variable for MockData
#'
#' Generates a date mock variable based on specifications from metadata.
#'
#' @param var character. Variable name to generate (column name in output)
#' @param databaseStart character. Database/cycle identifier for filtering metadata
#'   (e.g., "cchs2001_p", "minimal-example"). Used to filter variables and
#'   variable_details to the specified database.
#' @param variables data.frame or character. Variable-level metadata containing:
#'   \itemize{
#'     \item \code{variable}: Variable names
#'     \item \code{database}: Database identifier (optional, for filtering)
#'     \item \code{sourceFormat}: Output format ("analysis"/"csv"/"sas")
#'     \item \code{distribution}: Distribution type (uniform/gompertz/exponential)
#'     \item \code{followup_min}, \code{followup_max}: Followup period parameters
#'     \item \code{event_prop}: Proportion experiencing event
#'     \item \code{garbage_high_prop}, \code{garbage_high_range}: Garbage data parameters
#'   }
#'   Can also be a file path (character) to variables.csv.
#' @param variable_details data.frame or character. Detail-level metadata containing:
#'   \itemize{
#'     \item \code{variable}: Variable name (for joining)
#'     \item \code{recStart}: Date range (e.g., [01JAN2001,31DEC2020]) or followup period
#'     \item \code{recEnd}: Classification (copy, NA::a, NA::b)
#'     \item \code{proportion}: Category proportion for missing codes
#'   }
#'   Can also be a file path (character) to variable_details.csv.
#' @param df_mock data.frame. Optional. Existing mock data (to check if variable already exists).
#'   For survival variables, may contain anchor_date column for computing event dates.
#' @param prop_missing numeric. Proportion of missing values (0-1). Default 0 (no missing).
#' @param n integer. Number of observations to generate.
#' @param seed integer. Optional. Random seed for reproducibility.
#'
#' @return data.frame with one column (the generated date variable), or NULL if:
#'   \itemize{
#'     \item Variable not found in metadata
#'     \item Variable already exists in df_mock
#'     \item No valid date range found in variable_details
#'   }
#'
#' @details
#' **v0.3.0 API**: This function now accepts full metadata data frames and filters
#' internally for the specified variable and database. This is the "recodeflow pattern"
#' where filtering is handled inside the function.
#'
#' **Generation process**:
#' \enumerate{
#'   \item Filter metadata: Extract rows for specified var + database
#'   \item Extract date parameters: Read from variables.csv and variable_details
#'   \item Generate population: Based on distribution type (uniform/gompertz/exponential)
#'   \item Apply missing codes: If proportions specified in metadata
#'   \item Apply garbage: Read garbage parameters from variables.csv
#'   \item Apply sourceFormat: Convert to specified format (analysis/csv/sas)
#' }
#'
#' **Output format (sourceFormat)**:
#' The sourceFormat column in variables.csv controls output data type:
#' \itemize{
#'   \item \code{"analysis"}: R Date objects (default)
#'   \item \code{"csv"}: Character ISO strings (e.g., "2001-01-15")
#'   \item \code{"sas"}: Numeric days since 1960-01-01
#' }
#'
#' **Distribution types**:
#' \itemize{
#'   \item \code{"uniform"}: Uniform distribution over date range
#'   \item \code{"gompertz"}: Gompertz survival distribution (for time-to-event data)
#'   \item \code{"exponential"}: Exponential distribution (events concentrated near start)
#' }
#'
#' **Survival data generation**:
#' For variables with followup_min/followup_max/event_prop in variables.csv:
#' \itemize{
#'   \item Requires anchor_date column in df_mock (cohort entry/baseline date)
#'   \item Generates event times within followup window
#'   \item event_prop controls proportion experiencing event (vs. censored)
#'   \item Distribution controls event timing (Gompertz typical for survival)
#' }
#'
#' **Missing data**:
#' Missing codes are identified by recEnd containing "NA::":
#' \itemize{
#'   \item \code{NA::a}: Skip codes (not applicable)
#'   \item \code{NA::b}: Missing codes (don't know, refusal, not stated)
#' }
#'
#' **Garbage data**:
#' Garbage parameters are read from variables.csv:
#' \itemize{
#'   \item \code{garbage_high_prop}, \code{garbage_high_range}: Future dates (temporal violations)
#' }
#'
#' @examples
#' \dontrun{
#' # Basic usage with metadata data frames
#' interview_date <- create_date_var(
#'   var = "interview_date",
#'   databaseStart = "minimal-example",
#'   variables = variables,
#'   variable_details = variable_details,
#'   n = 1000,
#'   seed = 123
#' )
#'
#' # Expected output: data.frame with 1000 rows, 1 column ("interview_date")
#' # Values: R Date objects (if sourceFormat="analysis" in metadata)
#' # Distribution: Based on distribution in metadata (uniform/gompertz)
#'
#' # Survival data generation (requires anchor_date in df_mock)
#' death_date <- create_date_var(
#'   var = "death_date",
#'   databaseStart = "minimal-example",
#'   variables = variables,
#'   variable_details = variable_details,
#'   df_mock = df_mock,  # Must contain anchor_date column
#'   n = 1000,
#'   seed = 456
#' )
#' }
#'
#' @family generators
#' @export
create_date_var <- function(var,
                             databaseStart,
                             variables,
                             variable_details,
                             df_mock = NULL,
                             prop_missing = 0,
                             n,
                             seed = NULL) {

  # ========== PARAMETER VALIDATION ==========

  # Load metadata from file paths if needed
  if (is.character(variables) && length(variables) == 1) {
    variables <- read.csv(variables, stringsAsFactors = FALSE, check.names = FALSE)
  }
  if (is.character(variable_details) && length(variable_details) == 1) {
    variable_details <- read.csv(variable_details, stringsAsFactors = FALSE, check.names = FALSE)
  }

  # ========== INTERNAL FILTERING (recodeflow pattern) ==========

  # Filter variables for this var
  var_row <- variables[variables$variable == var, ]

  if (nrow(var_row) == 0) {
    warning(paste0("Variable '", var, "' not found in variables metadata"))
    return(NULL)
  }

  # Take first row if multiple matches
  if (nrow(var_row) > 1) {
    var_row <- var_row[1, ]
  }

  # Filter variable_details for this var AND database (using databaseStart)
  # databaseStart is a recodeflow core column containing comma-separated database identifiers
  if ("databaseStart" %in% names(variable_details)) {
    details_subset <- variable_details[
      variable_details$variable == var &
      (is.na(variable_details$databaseStart) |
       variable_details$databaseStart == "" |
       grepl(databaseStart, variable_details$databaseStart, fixed = TRUE)),
    ]
  } else {
    # Fallback: no databaseStart filtering (for simple configs)
    details_subset <- variable_details[variable_details$variable == var, ]
  }

  # ========== CHECK IF VARIABLE ALREADY EXISTS ==========

  if (!is.null(df_mock) && var %in% names(df_mock)) {
    return(NULL)
  }

  # ========== SET SEED ==========

  if (!is.null(seed)) set.seed(seed)

  # ========== EXTRACT PARAMETERS FROM METADATA ==========

  # Extract sourceFormat from variables.csv (controls output type)
  source_format <- if ("sourceFormat" %in% names(var_row) && !is.na(var_row$sourceFormat)) {
    var_row$sourceFormat
  } else {
    "analysis"  # default: R Date objects
  }

  # Extract distribution from variables.csv
  distribution_type <- if ("distribution" %in% names(var_row) && !is.na(var_row$distribution)) {
    var_row$distribution
  } else {
    "uniform"  # default
  }

  # Check if this is a survival variable (has followup parameters)
  is_survival <- "followup_min" %in% names(var_row) &&
                 "followup_max" %in% names(var_row) &&
                 "event_prop" %in% names(var_row) &&
                 !is.na(var_row$followup_min) && var_row$followup_min != "" &&
                 !is.na(var_row$followup_max) && var_row$followup_max != "" &&
                 !is.na(var_row$event_prop) && var_row$event_prop != ""

  # ========== FALLBACK MODE: Default date range if no details ==========

  if (nrow(details_subset) == 0) {
    # Default range: 2000-01-01 to 2025-12-31
    date_start <- as.Date("2000-01-01")
    date_end <- as.Date("2025-12-31")

    values <- sample(seq(date_start, date_end, by = "day"), size = n, replace = TRUE)

    # Apply source format conversion
    values <- convert_date_format(values, source_format)

    col <- data.frame(
      new = values,
      stringsAsFactors = FALSE
    )
    names(col)[1] <- var
    return(col)
  }

  # ========== EXTRACT DATE RANGE FROM variable_details ==========

  # For survival variables, use followup period from variables.csv
  # For calendar date variables, parse from variable_details recStart

  if (is_survival) {
    # ========== SURVIVAL DATA GENERATION ==========

    # Check for anchor_date in df_mock
    if (is.null(df_mock) || !"anchor_date" %in% names(df_mock)) {
      warning(paste0(
        "Variable '", var, "' is a survival variable (has followup_min/max/event_prop), ",
        "but df_mock does not contain 'anchor_date' column. ",
        "Cannot generate survival dates without anchor dates."
      ))
      return(NULL)
    }

    if (nrow(df_mock) != n) {
      warning(paste0(
        "Variable '", var, "': df_mock has ", nrow(df_mock), " rows but n=", n, ". ",
        "For survival variables, df_mock row count must match n."
      ))
      return(NULL)
    }

    # Extract followup parameters
    followup_min <- as.numeric(var_row$followup_min)  # days
    followup_max <- as.numeric(var_row$followup_max)  # days
    event_prop <- as.numeric(var_row$event_prop)      # proportion

    if (is.na(followup_min) || is.na(followup_max) || is.na(event_prop)) {
      warning(paste0(
        "Variable '", var, "': followup_min, followup_max, or event_prop is NA. ",
        "Cannot generate survival dates."
      ))
      return(NULL)
    }

    # Extract anchor dates from df_mock
    anchor_dates <- as.Date(df_mock$anchor_date)

    if (any(is.na(anchor_dates))) {
      warning(paste0(
        "Variable '", var, "': Some anchor_date values are NA. ",
        "Cannot compute event dates."
      ))
      return(NULL)
    }

    # Generate event times using specified distribution
    # Extract proportions to determine events vs. censored
    props <- extract_proportions(details_subset, variable_name = var)
    n_valid <- floor(n * props$valid)
    n_events <- floor(n_valid * event_prop)
    n_censored <- n_valid - n_events

    # Create event indicator (TRUE = event occurs, FALSE = censored)
    is_event <- c(rep(TRUE, n_events), rep(FALSE, n_censored))

    # Shuffle event indicator to randomize which observations get events
    shuffled_indices <- sample(n_valid)
    is_event <- is_event[shuffled_indices]

    # Generate event times only for events (in days from anchor)
    if (n_events > 0) {
      if (distribution_type == "gompertz") {
        # Gompertz distribution: typical for survival/mortality
        shape <- if ("shape" %in% names(var_row) && !is.na(var_row$shape)) {
          as.numeric(var_row$shape)
        } else {
          0.1  # default shape parameter
        }

        rate <- if ("rate" %in% names(var_row) && !is.na(var_row$rate)) {
          as.numeric(var_row$rate)
        } else {
          0.0001  # default rate parameter
        }

        # Generate Gompertz-distributed event times
        u <- runif(n_events)
        event_times_days <- (1/shape) * log(1 - (shape/rate) * log(1 - u))
        event_times_days <- pmax(followup_min, pmin(followup_max, event_times_days))

      } else if (distribution_type == "exponential") {
        # Exponential distribution: constant hazard
        rate_exp <- 1 / ((followup_max - followup_min) / 3)
        event_times_days <- rexp(n_events, rate = rate_exp) + followup_min
        event_times_days <- pmin(event_times_days, followup_max)

      } else {
        # Uniform distribution (default)
        event_times_days <- runif(n_events, min = followup_min, max = followup_max)
      }
    } else {
      event_times_days <- numeric(0)
    }

    # Initialize all dates as NA
    event_dates <- rep(as.Date(NA), n_valid)

    # Assign dates only to observations with events
    if (n_events > 0) {
      anchor_dates_valid <- anchor_dates[seq_len(n_valid)]
      event_dates[is_event] <- anchor_dates_valid[is_event] + event_times_days
    }

    # Create all_assignments for missing code application
    all_assignments <- rep("valid", n)

  } else {
    # ========== CALENDAR DATE GENERATION ==========

    # Parse date range from variable_details recStart
    # Format: [01JAN2001,31DEC2020] or similar
    if ("recEnd" %in% names(details_subset)) {
      # Filter out rows where recEnd contains "NA" (missing data codes)
      rec_start_values <- details_subset$recStart[
        !grepl("NA", details_subset$recEnd, fixed = TRUE)
      ]
    } else {
      # No recEnd column - use all recStart values (for simple configs)
      rec_start_values <- details_subset$recStart
    }

    if (length(rec_start_values) == 0) {
      warning(paste0("Variable '", var, "': No valid date range found in variable_details"))
      return(NULL)
    }

    # Use parse_range_notation() to parse date ranges (supports inf for fixed dates)
    parsed_range <- parse_range_notation(rec_start_values[1], range_type = "date")

    if (is.null(parsed_range) || parsed_range$type != "date") {
      warning(paste0(
        "Variable '", var, "': Cannot parse date range from recStart. ",
        "Expected format: [01JAN2001,31DEC2020], [2001-01-01,2020-12-31], or [2017-03-31,inf]"
      ))
      return(NULL)
    }

    date_start <- parsed_range$min
    date_end <- parsed_range$max

    # Handle infinity case (fixed date): [2017-03-31,inf] means all dates = 2017-03-31
    is_fixed_date <- is.infinite(date_end)

    # Generate dates based on distribution
    props <- extract_proportions(details_subset, variable_name = var)
    n_valid <- floor(n * props$valid)

    if (is_fixed_date) {
      # Fixed date (inf pattern): all dates are the same
      event_dates <- rep(date_start, n_valid)

    } else if (distribution_type == "uniform") {
      # Uniform distribution over date range
      valid_dates <- seq(date_start, date_end, by = "day")
      event_dates <- sample(valid_dates, size = n_valid, replace = TRUE)

    } else if (distribution_type == "exponential") {
      # Exponential: more dates near start
      n_days <- as.numeric(difftime(date_end, date_start, units = "days"))
      rate_exp <- 1 / (n_days / 3)
      days_from_start <- rexp(n_valid, rate = rate_exp)
      days_from_start <- pmin(days_from_start, n_days)
      event_dates <- date_start + days_from_start

    } else {
      # Gompertz or other: default to uniform for calendar dates
      valid_dates <- seq(date_start, date_end, by = "day")
      event_dates <- sample(valid_dates, size = n_valid, replace = TRUE)
    }
  }

  # ========== STEP 2: Apply missing codes ==========

  n_missing <- n - length(event_dates)

  if (n_missing > 0 && length(props$missing) > 0) {
    # Generate missing assignments
    missing_assignments <- sample(
      names(props$missing),
      size = n_missing,
      replace = TRUE,
      prob = unlist(props$missing)
    )

    # For dates, missing codes are typically NA
    # Create placeholder values for missing
    missing_values <- rep(as.Date(NA), n_missing)

    # Combine valid and missing
    all_values <- c(event_dates, missing_values)
    all_assignments <- c(rep("valid", length(event_dates)), missing_assignments)

    # Apply missing codes (for dates, this typically sets to NA)
    # But we'll use apply_missing_codes for consistency
    missing_map <- list()
    for (miss_cat in names(props$missing)) {
      # For dates, missing codes are R NA
      missing_map[[miss_cat]] <- as.Date(NA)
    }

    values <- apply_missing_codes(
      values = all_values,
      category_assignments = all_assignments,
      missing_code_map = missing_map
    )
  } else {
    # No missing codes needed
    values <- event_dates
  }

  # ========== STEP 3: Apply garbage data if specified in variables.csv ==========

  # Convert to character temporarily for apply_garbage
  # (apply_garbage may work with dates, but safer to handle explicitly)
  values_char <- as.character(values)

  # Extract missing codes from missing_map (metadata-based)
  # For dates, missing codes are typically NA (not numeric codes like 997)
  missing_codes_vec <- NULL
  if (exists("missing_map") && length(missing_map) > 0) {
    # Flatten missing_map - will be NA for dates, but pass it anyway
    missing_codes_vec <- unique(as.character(unlist(missing_map)))
  }

  values_char <- apply_garbage(
    values = values_char,
    var_row = var_row,
    variable_type = "date",
    missing_codes = missing_codes_vec,  # Pass metadata-based missing codes
    seed = NULL  # Already set globally if needed
  )

  # Convert back to Date
  values <- as.Date(values_char)

  # ========== STEP 4: Apply sourceFormat conversion ==========

  values <- convert_date_format(values, source_format)

  # ========== RETURN AS DATA FRAME ==========

  col <- data.frame(
    new = values,
    stringsAsFactors = FALSE
  )
  names(col)[1] <- var

  return(col)
}

# Helper function to convert dates to specified source format
convert_date_format <- function(date_vector, format) {
  if (format == "csv") {
    # CSV format: character ISO strings (e.g., "2001-01-15")
    return(as.character(date_vector))
  } else if (format == "sas") {
    # SAS format: numeric days since 1960-01-01
    sas_epoch <- as.Date("1960-01-01")
    return(as.numeric(date_vector - sas_epoch))
  } else {
    # "analysis" or default: keep as R Date objects
    return(date_vector)
  }
}
