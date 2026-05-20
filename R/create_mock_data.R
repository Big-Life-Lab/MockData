#' @noRd
.create_mock_data_v04_database_filter <- function(variables, databaseStart) {
  if (!is.null(databaseStart) && "databaseStart" %in% names(variables)) {
    return(databaseStart)
  }

  NULL
}

#' @noRd
.create_mock_data_v04_unsupported_variables <- function(spec) {
  unsupported <- vapply(spec$variables, function(variable) {
    formula <- variable$formula
    has_formula <- !is.null(formula) &&
      !(is.character(formula) && length(formula) == 1 && (is.na(formula) || trimws(formula) == ""))
    if (has_formula) {
      return(TRUE)
    }

    distribution <- tolower(variable$distribution %||% "uniform")
    if (variable$type == "continuous") {
      return(!distribution %in% c("uniform", "normal"))
    }
    if (variable$type == "categorical") {
      return(FALSE)
    }
    if (variable$type == "date") {
      return(!(distribution == "uniform" && identical(variable$source_format %||% "analysis", "analysis")))
    }

    TRUE
  }, logical(1))

  names(spec$variables)[unsupported]
}

#' @noRd
.create_mock_data_v04_native_supported <- function(spec) {
  length(.create_mock_data_v04_unsupported_variables(spec)) == 0
}

#' @noRd
.create_mock_data_v04 <- function(databaseStart,
                                  variables,
                                  variable_details,
                                  n,
                                  seed,
                                  verbose = FALSE) {
  if (!is.null(databaseStart) &&
      !"databaseStart" %in% names(variables) &&
      "databaseStart" %in% names(variable_details)) {
    if (isTRUE(verbose)) {
      message(
        "v0.4 mock_spec pipeline requires variable-level databaseStart when ",
        "detail-level databaseStart filtering is needed; using legacy ",
        "create_* dispatch."
      )
    }
    return(NULL)
  }

  spec <- mock_spec_from_recodeflow(
    variables = variables,
    variable_details = variable_details,
    databaseStart = .create_mock_data_v04_database_filter(variables, databaseStart),
    role = "enabled"
  )

  unsupported <- .create_mock_data_v04_unsupported_variables(spec)
  if (length(unsupported) > 0) {
    if (isTRUE(verbose)) {
      message(
        "v0.4 mock_spec pipeline does not yet support every requested ",
        "variable; using legacy create_* dispatch. Unsupported variable(s): ",
        paste(unsupported, collapse = ", ")
      )
    }
    return(NULL)
  }

  if (isTRUE(verbose)) {
    message("Generating via v0.4 mock_spec pipeline.")
  }

  baseline <- generate_mock_data_native(spec, n = n, seed = seed)
  # The wrapper uses a second deterministic stream for post-processing so
  # baseline generation and missing/garbage assignment can be reproduced
  # independently from the single public seed.
  postprocess_seed <- if (is.null(seed)) NULL else seed + 1L
  postprocess_mock_data(baseline, spec, seed = postprocess_seed)
}

#' Create mock data from configuration files
#'
#' @description
#' Main orchestrator function that generates complete mock datasets from
#' configuration files. Reads metadata, filters for enabled variables,
#' dispatches to type-specific create_* functions, and assembles results
#' into a complete data frame.
#'
#' @param databaseStart Character. The database identifier (e.g., "cchs2001_p", "minimal-example").
#'   Used to filter variables to those available in the specified database.
#' @param variables data.frame or character. Variable-level metadata containing:
#'   \itemize{
#'     \item \code{variable}: Variable names
#'     \item \code{variableType}: Variable type (Categorical/Continuous/Date)
#'     \item \code{role}: Role tags (enabled, predictor, outcome, etc.)
#'     \item \code{position}: Display order (optional)
#'     \item \code{database}: Database filter (optional)
#'   }
#'   Can also be a file path (character) to variables.csv.
#' @param variable_details data.frame or character. Detail-level metadata containing:
#'   \itemize{
#'     \item \code{variable}: Variable name (for joining)
#'     \item \code{recStart}: Category code/range or date interval
#'     \item \code{recEnd}: Classification (numeric code, "NA::a", "NA::b")
#'     \item \code{proportion}: Category proportion (for categorical)
#'     \item \code{catLabel}: Category label/description
#'   }
#'   Can also be a file path (character) to variable_details.csv.
#'   If NULL, uses simple fallback generation.
#' @param n Integer. Number of observations to generate (default 1000).
#' @param seed Integer. Optional random seed for reproducibility.
#' @param validate Logical. Whether to use strict generation checks (default
#'   TRUE). When TRUE, unsupported variable types and generator errors stop
#'   generation. When FALSE, those errors are converted to warnings and the
#'   affected variable is skipped.
#' @param verbose Logical. Whether to print progress messages (default FALSE).
#'
#' @return Data frame with n rows and one column per enabled variable. When the
#'   v0.4 `mock_spec` path is used, the result also carries a
#'   `mockdata_diagnostics` attribute from [postprocess_mock_data()]. Legacy
#'   fallback paths return plain data frames without that attribute.
#'
#' @details
#' **v0.4.0 transition**: In strict mode, this function first attempts to use
#' the v0.4 `mock_spec` pipeline: [mock_spec_from_recodeflow()],
#' [generate_mock_data_native()], and [postprocess_mock_data()]. If the metadata
#' requests a feature not yet supported by the v0.4 native backend, it falls
#' back to the v0.3 `create_*` dispatch path so existing users can migrate
#' gradually.
#'
#' The wrapper deliberately stays on the legacy path when `validate = FALSE`,
#' when `variable_details = NULL`, when detail-level `databaseStart` filtering is
#' needed but the variables metadata has no `databaseStart` column, or when a
#' variable uses a feature not yet supported by the v0.4 native backend. Set
#' `verbose = TRUE` to see which path was chosen.
#'
#' In the v0.4 path, `seed` is used for baseline generation and `seed + 1` is
#' used for post-processing. This makes both stages deterministic, but generated
#' values may differ from v0.3.x output for the same seed.
#'
#' **v0.3.0 API**: This function follows the "recodeflow pattern" where it passes
#' full metadata data frames to create_* functions, which handle internal
#' filtering.
#'
#' **Generation process**:
#' \enumerate{
#'   \item Load metadata from file paths or accept data frames
#'   \item Filter for enabled variables (role has an exact "enabled" token)
#'   \item Set global seed (if provided)
#'   \item Loop through variables in position order:
#'     - Dispatch to create_cat_var, create_con_var, or create_date_var
#'     - Pass full metadata data frames (functions filter internally)
#'     - Merge result into data frame
#'   \item Return complete dataset
#' }
#'
#' **Fallback mode**: If variable_details = NULL, uses simple default generators
#' for enabled variables (two-category categorical values, continuous values from
#' [0, 100], and dates from 2000-01-01 to 2025-12-31).
#'
#' **Variable types supported**:
#' \itemize{
#'   \item \code{Categorical}: create_cat_var()
#'   \item \code{Continuous}: create_con_var()
#'   \item \code{Date}: create_date_var()
#' }
#'
#' **Configuration schema**: For complete documentation of all configuration columns,
#' see \code{vignette("reference-config", package = "MockData")}.
#'
#' @examples
#' \dontrun{
#' # Basic usage with file paths
#' mock_data <- create_mock_data(
#'   databaseStart = "minimal-example",
#'   variables = "inst/extdata/minimal-example/variables.csv",
#'   variable_details = "inst/extdata/minimal-example/variable_details.csv",
#'   n = 1000,
#'   seed = 123
#' )
#'
#' # With data frames instead of file paths
#' variables <- read.csv("inst/extdata/minimal-example/variables.csv",
#'                       stringsAsFactors = FALSE)
#' variable_details <- read.csv("inst/extdata/minimal-example/variable_details.csv",
#'                               stringsAsFactors = FALSE)
#'
#' mock_data <- create_mock_data(
#'   databaseStart = "minimal-example",
#'   variables = variables,
#'   variable_details = variable_details,
#'   n = 1000,
#'   seed = 123
#' )
#'
#' # Fallback mode (uniform distributions, no variable_details)
#' mock_data <- create_mock_data(
#'   databaseStart = "minimal-example",
#'   variables = "inst/extdata/minimal-example/variables.csv",
#'   variable_details = NULL,
#'   n = 500
#' )
#'
#' # View structure
#' str(mock_data)
#' head(mock_data)
#' }
#'
#' @family generators
#' @family mock generation APIs
#' @seealso [mock_spec_from_recodeflow()], [generate_mock_data_native()],
#'   [postprocess_mock_data()], [generate_mock_data_simstudy()], [mock_spec()]
#' @export
create_mock_data <- function(databaseStart,
                             variables,
                             variable_details = NULL,
                             n = 1000,
                             seed = NULL,
                             validate = TRUE,
                             verbose = FALSE) {

  # ========== LOAD METADATA ==========

  # Load variables from file path if needed
  if (is.character(variables) && length(variables) == 1) {
    if (!file.exists(variables)) {
      stop("Configuration file does not exist: ", variables)
    }
    if (verbose) message("Reading variables file: ", variables)
    variables <- read.csv(variables, stringsAsFactors = FALSE, check.names = FALSE)
  }

  # Load variable_details from file path if needed
  if (!is.null(variable_details)) {
    if (is.character(variable_details) && length(variable_details) == 1) {
      if (!file.exists(variable_details)) {
        stop("Details file does not exist: ", variable_details)
      }
      if (verbose) message("Reading variable_details file: ", variable_details)
      variable_details <- read.csv(variable_details, stringsAsFactors = FALSE, check.names = FALSE)
    }
  } else {
    if (verbose) message("No details file provided - using simple fallback generation")
  }

  variables <- .migrate_garbage_aliases(variables)

  # ========== VALIDATE INPUT ==========

  if (n < 1) {
    stop("n must be at least 1")
  }

  if (!"variable" %in% names(variables)) {
    stop("variables must have a 'variable' column")
  }

  if (!"variableType" %in% names(variables)) {
    stop("variables must have a 'variableType' column")
  }

  # ========== v0.4 PIPELINE PATH ==========

  if (!isTRUE(validate)) {
    if (verbose) {
      message("validate = FALSE requested; using legacy create_* dispatch.")
    }
  } else if (is.null(variable_details)) {
    if (verbose) {
      message("variable_details = NULL; using legacy create_* fallback dispatch.")
    }
  } else {
    v04_result <- .create_mock_data_v04(
      databaseStart = databaseStart,
      variables = variables,
      variable_details = variable_details,
      n = n,
      seed = seed,
      verbose = verbose
    )

    if (!is.null(v04_result)) {
      return(v04_result)
    }
  }

  # ========== FILTER FOR ENABLED VARIABLES ==========

  if (verbose) message("Filtering for enabled variables...")

  # Filter for variables with exact "enabled" role token.
  if ("role" %in% names(variables)) {
    enabled_vars <- variables[.role_matches(variables$role, "enabled", ignore.case = TRUE), ]
  } else {
    # If no role column, assume all variables are enabled
    enabled_vars <- variables
  }

  # Exclude derived variables (identified by DerivedVar:: and Func:: patterns)
  if (!is.null(variable_details)) {
    derived_vars <- identify_derived_vars(enabled_vars, variable_details)

    if (length(derived_vars) > 0) {
      if (verbose) {
        message("Excluding ", length(derived_vars), " derived variable(s): ",
                paste(derived_vars, collapse = ", "))
      }

      # Filter out derived variables
      enabled_vars <- enabled_vars[!enabled_vars$variable %in% derived_vars, ]
    }
  }

  if (nrow(enabled_vars) == 0) {
    stop("No enabled non-derived variables found in configuration. ",
         "Add 'enabled' to the role column for variables you want to generate, ",
         "or ensure derived variables have raw dependencies.")
  }

  # NOTE: Database filtering now happens at detail-level (in create_* functions)
  # using the databaseStart column in variable_details.csv (recodeflow core pattern)

  # Sort by position if available
  if ("position" %in% names(enabled_vars) && any(!is.na(enabled_vars$position))) {
    enabled_vars <- enabled_vars[order(enabled_vars$position), ]
  }

  if (verbose) {
    message("Found ", nrow(enabled_vars), " enabled variable(s) for database '", databaseStart, "': ",
            paste(enabled_vars$variable, collapse = ", "))
  }

  # ========== SET GLOBAL SEED ==========

  if (!is.null(seed)) {
    if (verbose) message("Setting random seed: ", seed)
    set.seed(seed)
  }

  # ========== GENERATE VARIABLES ==========

  if (verbose) message("Generating ", n, " observations...")

  # Initialize empty data frame
  df_mock <- data.frame(row.names = seq_len(n))
  skipped_vars <- character(0)

  # Generate variables in order
  for (i in seq_len(nrow(enabled_vars))) {
    var_row <- enabled_vars[i, ]
    var_name <- var_row$variable

    # Determine variable type for routing using rType (v0.2 schema)
    if ("rType" %in% names(var_row) && !is.na(var_row$rType) && var_row$rType != "") {
      var_type <- tolower(var_row$rType)
    } else {
      msg <- paste0(
        "Variable '", var_name, "' is missing rType column. ",
        "All metadata must use v0.2 schema with rType column."
      )
      if (validate) {
        stop(msg, call. = FALSE)
      }
      warning(msg)
      next
    }

    if (verbose) {
      message("  [", i, "/", nrow(enabled_vars), "] Generating ",
              var_name, " (", var_type, ")")
    }

    supported_rtypes <- c(
      "factor", "character", "logical", "integer", "double", "numeric", "date"
    )

    if (!var_type %in% supported_rtypes) {
      msg <- paste0(
        "Unknown variable type '", var_type, "' for variable: ", var_name,
        "\n  Supported rType values: factor, character, logical, integer, ",
        "double, numeric, date"
      )

      if (validate) {
        stop(msg, call. = FALSE)
      }

      warning(msg)
      skipped_vars <- c(skipped_vars, var_name)
      var_data <- NULL
    } else {
      # Dispatch to type-specific generator
      var_data <- tryCatch({
        switch(var_type,
        # v0.2 schema rType values
        "factor" = create_cat_var(
          var = var_name,
          databaseStart = databaseStart,
          variables = variables,
          variable_details = variable_details,
          df_mock = df_mock,
          n = n,
          seed = NULL  # Global seed already set
        ),
        "character" = create_cat_var(
          var = var_name,
          databaseStart = databaseStart,
          variables = variables,
          variable_details = variable_details,
          df_mock = df_mock,
          n = n,
          seed = NULL
        ),
        "logical" = create_cat_var(
          var = var_name,
          databaseStart = databaseStart,
          variables = variables,
          variable_details = variable_details,
          df_mock = df_mock,
          n = n,
          seed = NULL
        ),
        "integer" = create_con_var(
          var = var_name,
          databaseStart = databaseStart,
          variables = variables,
          variable_details = variable_details,
          df_mock = df_mock,
          n = n,
          seed = NULL
        ),
        "double" = create_con_var(
          var = var_name,
          databaseStart = databaseStart,
          variables = variables,
          variable_details = variable_details,
          df_mock = df_mock,
          n = n,
          seed = NULL
        ),
        "numeric" = create_con_var(
          var = var_name,
          databaseStart = databaseStart,
          variables = variables,
          variable_details = variable_details,
          df_mock = df_mock,
          n = n,
          seed = NULL
        ),
        "date" = create_date_var(
          var = var_name,
          databaseStart = databaseStart,
          variables = variables,
          variable_details = variable_details,
          df_mock = df_mock,
          n = n,
          seed = NULL
        )
        )
      }, error = function(e) {
        msg <- paste0("Error generating variable ", var_name, ": ", e$message)
        if (validate) {
          stop(msg, call. = FALSE)
        }
        warning(msg)
        skipped_vars <<- c(skipped_vars, var_name)
        NULL
      })
    }

    # Merge into dataset if generation succeeded
    if (!is.null(var_data) && is.data.frame(var_data)) {
      # Add columns from var_data to df_mock
      for (col_name in names(var_data)) {
        df_mock[[col_name]] <- var_data[[col_name]]
      }
    }
  }

  # ========== RETURN RESULT ==========

  if (verbose) {
    message("Mock data generation complete!")
    message("  Rows: ", nrow(df_mock))
    message("  Variables: ", ncol(df_mock))
  }

  if (!validate && length(skipped_vars) > 0) {
    skipped_vars <- unique(skipped_vars)
    message("Skipped variables during mock data generation: ",
            paste(skipped_vars, collapse = ", "))
  }

  return(df_mock)
}
