#' Create wide survival data for cohort studies
#'
#' Generates wide-format survival data (one row per individual) with up to 5 date
#' variables (entry, event, death, loss-to-follow-up, administrative censoring).
#' Applies temporal ordering constraints and supports garbage data generation for
#' QA testing.
#'
#' @param var_entry_date character. Required. Variable name for entry date (baseline).
#' @param var_event_date character. Optional. Variable name for primary event date
#'   (e.g., "dementia_incid_date"). Set to NULL to skip.
#' @param var_death_date character. Optional. Variable name for death date
#'   (competing risk). Set to NULL to skip.
#' @param var_ltfu character. Optional. Variable name for loss-to-follow-up date.
#'   Set to NULL to skip.
#' @param var_admin_censor character. Optional. Variable name for administrative
#'   censoring date. Set to NULL to skip.
#' @param databaseStart character. Required. Database identifier for filtering metadata
#'   (used with databaseStart column in variable_details).
#' @param variables data.frame. Required. Full variables metadata (not pre-filtered).
#'   Must contain columns: variable, variableType.
#' @param variable_details data.frame. Required. Full variable details metadata
#'   (not pre-filtered). Will be filtered internally using databaseStart column.
#' @param df_mock data.frame. Optional. The current mock data to check if variables
#'   already exist and to use as anchor_date source. Default: NULL.
#' @param n integer. Required. Number of observations to generate.
#' @param seed integer. Optional. Random seed for reproducibility. Default: NULL.
#' @param prop_garbage numeric. **DEPRECATED in v0.3.1**. This parameter is no
#'   longer supported. To generate temporal violations for QA testing, use the
#'   `garbage_high_prop` and `garbage_high_range` parameters in variables.csv
#'   for individual date variables. See Details section for migration guidance.
#'   Default: NULL.
#'
#' @return data.frame with 1-5 date columns (depending on which variables are
#'   specified), or NULL if variables already exist in df_mock.
#'
#' @details
#' This function implements v0.3.0 "recodeflow pattern" API:
#' - Accepts full metadata data frames (not pre-filtered subsets)
#' - Accepts variable names (not variable rows)
#' - Filters metadata internally using databaseStart column
#'
#' **Implementation strategy:**
#' 1. Call create_date_var() once for each non-NULL date variable
#' 2. Each variable configured separately in variables.csv with own event_prop,
#'    distribution, followup_min, followup_max, etc.
#' 3. Combine results into single data frame
#' 4. Apply temporal ordering constraints
#'
#' **Temporal ordering constraints (normal mode):**
#' - Entry date is always baseline (earliest)
#' - All other dates must be >= entry_date
#' - Death can occur before any event
#' - If death < event, set event to NA (censored, not missing)
#' - Observation ends at min(event, death, ltfu, admin_censor)
#'
#' **Temporal violations for QA testing (v0.3.1+):**
#' This function creates clean, temporally-ordered survival data. To generate
#' temporal violations for testing data quality pipelines:
#' - Add `garbage_high_prop` and `garbage_high_range` to individual date variables
#'   in variables.csv (e.g., future death dates beyond 2025)
#' - Use [create_date_var()] to generate date variables with garbage
#' - Test your temporal validation logic separately
#' - This approach separates concerns: date-level garbage vs. survival data generation
#'
#' **Migration from prop_garbage (deprecated in v0.3.1):**
#' ```r
#' # OLD (v0.3.0):
#' surv <- create_wide_survival_data(..., prop_garbage = 0.03)
#'
#' # NEW (v0.3.1+):
#' # Add garbage to date variables in metadata
#' variables$garbage_high_prop[variables$variable == "death_date"] <- 0.03
#' variables$garbage_high_range[variables$variable == "death_date"] <-
#'   "[2025-01-01, 2099-12-31]"
#' # create_date_var() will apply garbage automatically
#' surv <- create_wide_survival_data(..., variables = variables)
#' ```
#'
#' **Configuration in metadata:**
#' Each date variable must be defined in variables.csv and variable_details.csv:
#'
#' variables.csv:
#' ```
#' variable,variableType,role
#' interview_date,Date,enabled
#' dementia_incid_date,Date,enabled
#' death_date,Date,enabled
#' ```
#'
#' variable_details.csv:
#' ```
#' variable,recStart,recEnd,value,proportion
#' interview_date,[2001-01-01,2005-12-31],copy,NA,NA
#' dementia_incid_date,[2002-01-01,2021-01-01],followup_min,365,NA
#' dementia_incid_date,NA,followup_max,7300,NA
#' dementia_incid_date,NA,event_prop,0.15,NA
#' death_date,[2002-01-01,2026-01-01],followup_min,365,NA
#' death_date,NA,followup_max,9125,NA
#' death_date,NA,event_prop,0.40,NA
#' ```
#'
#' @examples
#' \dontrun{
#' # Read metadata
#' variables <- read.csv("inst/extdata/survival/variables.csv")
#' variable_details <- read.csv("inst/extdata/survival/variable_details.csv")
#'
#' # Generate 5-variable survival data
#' surv_data <- create_wide_survival_data(
#'   var_entry_date = "interview_date",
#'   var_event_date = "dementia_incid_date",
#'   var_death_date = "death_date",
#'   var_ltfu = "ltfu_date",
#'   var_admin_censor = "admin_censor_date",
#'   databaseStart = "demport",
#'   variables = variables,
#'   variable_details = variable_details,
#'   n = 1000,
#'   seed = 123
#' )
#'
#' # Generate minimal survival data (entry + event only)
#' surv_data <- create_wide_survival_data(
#'   var_entry_date = "cohort_entry",
#'   var_event_date = "primary_event_date",
#'   var_death_date = NULL,
#'   var_ltfu = NULL,
#'   var_admin_censor = NULL,
#'   database = "study",
#'   variables = variables,
#'   variable_details = variable_details,
#'   n = 500,
#'   seed = 456
#' )
#'
#' # Generate with garbage data for QA testing (v0.3.1+)
#' # Add garbage to death_date in metadata
#' vars_with_garbage <- add_garbage(variables, "death_date",
#'   high_prop = 0.05, high_range = "[2025-01-01, 2099-12-31]")
#'
#' surv_data <- create_wide_survival_data(
#'   var_entry_date = "interview_date",
#'   var_event_date = "dementia_incid_date",
#'   var_death_date = "death_date",
#'   var_ltfu = NULL,
#'   var_admin_censor = NULL,
#'   databaseStart = "demport",
#'   variables = vars_with_garbage,  # Use modified metadata
#'   variable_details = variable_details,
#'   n = 1000,
#'   seed = 789
#' )
#' }
#'
#' @family generators
#' @export
create_wide_survival_data <- function(var_entry_date,
                                       var_event_date = NULL,
                                       var_death_date = NULL,
                                       var_ltfu = NULL,
                                       var_admin_censor = NULL,
                                       databaseStart,
                                       variables,
                                       variable_details,
                                       df_mock = NULL,
                                       n,
                                       seed = NULL,
                                       prop_garbage = NULL) {

  # ========== VALIDATION ==========

  # Check required parameters
  if (missing(var_entry_date) || is.null(var_entry_date)) {
    stop("var_entry_date is required (entry date is baseline for survival data)")
  }
  if (missing(databaseStart) || is.null(databaseStart)) {
    stop("databaseStart parameter is required")
  }
  if (missing(variables) || !is.data.frame(variables)) {
    stop("variables must be a data frame (full metadata, not pre-filtered)")
  }
  if (missing(variable_details) || !is.data.frame(variable_details)) {
    stop("variable_details must be a data frame (full metadata, not pre-filtered)")
  }
  if (missing(n) || is.null(n) || !is.numeric(n) || n <= 0) {
    stop("n must be a positive integer")
  }

  # Deprecation warning for prop_garbage
  if (!is.null(prop_garbage)) {
    warning(
      "The 'prop_garbage' parameter is deprecated as of v0.3.1 and will be ignored.\n",
      "To generate temporal violations for QA testing:\n",
      "1. Add garbage_high_prop and garbage_high_range to individual date variables in variables.csv\n",
      "2. Example: variables$garbage_high_prop[variables$variable == 'death_date'] <- 0.03\n",
      "           variables$garbage_high_range[variables$variable == 'death_date'] <- '[2025-01-01, 2099-12-31]'\n",
      "3. create_date_var() will apply garbage automatically when called by create_wide_survival_data()\n",
      "See ?create_wide_survival_data for migration guidance.",
      call. = FALSE
    )
  }

  # Check if variables already exist in df_mock
  all_vars <- c(var_entry_date, var_event_date, var_death_date, var_ltfu, var_admin_censor)
  all_vars <- all_vars[!is.null(all_vars) & !is.na(all_vars)]

  if (!is.null(df_mock) && nrow(df_mock) > 0) {
    existing_vars <- all_vars[all_vars %in% names(df_mock)]
    if (length(existing_vars) > 0) {
      warning(paste0(
        "Variables already exist in df_mock: ",
        paste(existing_vars, collapse = ", "),
        ". Skipping survival data generation."
      ))
      return(NULL)
    }
  }

  # Set seed if provided
  if (!is.null(seed)) set.seed(seed)

  # ========== STEP 1: Generate each date variable using create_date_var() ==========

  # Collect all date variables to generate
  date_vars <- list()

  # 1. Entry date (REQUIRED)
  date_vars[[var_entry_date]] <- list(
    var = var_entry_date,
    is_entry = TRUE
  )

  # 2. Event date (OPTIONAL)
  if (!is.null(var_event_date) && !is.na(var_event_date)) {
    date_vars[[var_event_date]] <- list(
      var = var_event_date,
      is_entry = FALSE
    )
  }

  # 3. Death date (OPTIONAL)
  if (!is.null(var_death_date) && !is.na(var_death_date)) {
    date_vars[[var_death_date]] <- list(
      var = var_death_date,
      is_entry = FALSE
    )
  }

  # 4. Loss to follow-up (OPTIONAL)
  if (!is.null(var_ltfu) && !is.na(var_ltfu)) {
    date_vars[[var_ltfu]] <- list(
      var = var_ltfu,
      is_entry = FALSE
    )
  }

  # 5. Administrative censoring (OPTIONAL)
  if (!is.null(var_admin_censor) && !is.na(var_admin_censor)) {
    date_vars[[var_admin_censor]] <- list(
      var = var_admin_censor,
      is_entry = FALSE
    )
  }

  # Generate each date variable
  result_list <- list()

  for (var_name in names(date_vars)) {
    var_info <- date_vars[[var_name]]

    # For entry date: df_mock is NULL (no anchor needed)
    # For other dates: df_mock contains entry date renamed as "anchor_date"
    if (var_info$is_entry) {
      current_df_mock <- data.frame()
    } else {
      # For survival variables, create_date_var() expects anchor_date column
      # Use the entry date (first result) as anchor
      if (length(result_list) > 0 && var_entry_date %in% names(result_list[[1]])) {
        # Create df_mock with entry date renamed to "anchor_date"
        current_df_mock <- data.frame(
          anchor_date = result_list[[1]][[var_entry_date]],
          stringsAsFactors = FALSE
        )
      } else {
        current_df_mock <- data.frame()
      }
    }

    # Call create_date_var()
    date_result <- create_date_var(
      var = var_name,
      databaseStart = databaseStart,
      variables = variables,
      variable_details = variable_details,
      df_mock = current_df_mock,
      n = n,
      seed = NULL  # Don't reset seed for each variable
    )

    # Check if generation succeeded
    if (is.null(date_result)) {
      warning(paste0("Failed to generate date variable: ", var_name))
      next
    }

    # Store result
    result_list[[var_name]] <- date_result
  }

  # Combine all date variables into single data frame
  if (length(result_list) == 0) {
    warning("No date variables were generated successfully")
    return(NULL)
  }

  result <- do.call(cbind, result_list)

  # ========== STEP 2: Apply temporal ordering constraints ==========

  # Get entry date column
  entry_col <- result[[var_entry_date]]

  # Process each non-entry date variable
  for (var_name in names(date_vars)) {
    if (date_vars[[var_name]]$is_entry) next  # Skip entry date

    if (var_name %in% names(result)) {
      date_col <- result[[var_name]]

      # Find violations: date < entry_date
      violations <- !is.na(date_col) & !is.na(entry_col) & date_col < entry_col

      if (any(violations)) {
        # Set violations to NA (censored at entry)
        result[[var_name]][violations] <- NA
      }
    }
  }

  # Special rule: If death occurs before event, set event to NA
  if (!is.null(var_event_date) && !is.null(var_death_date)) {
    if (var_event_date %in% names(result) && var_death_date %in% names(result)) {
      event_col <- result[[var_event_date]]
      death_col <- result[[var_death_date]]

      # Find cases where death < event
      death_before_event <- !is.na(event_col) & !is.na(death_col) & death_col < event_col

      if (any(death_before_event)) {
        # Set event to NA (censored at death)
        result[[var_event_date]][death_before_event] <- NA
      }
    }
  }

  # ========== RETURN RESULT ==========

  return(result)
}
