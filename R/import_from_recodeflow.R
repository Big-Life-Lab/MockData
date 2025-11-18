#' Import and convert recodeflow variables and variable details metadata files to MockData configuration format
#'
#' @description
#' Converts recodeflow variables.csv and variable_details.csv files into
#' MockData configuration format (mock_data_config.csv and
#' mock_data_config_details.csv). Filters variables by role and optionally
#' by database.
#'
#' @param variables_path Character. Path to recodeflow variables.csv file.
#' @param variable_details_path Character. Path to recodeflow variable_details.csv file.
#' @param role_filter Character. Role value to filter variables by. Only variables
#'   with this role will be imported. Default is "mockdata". Use regex word boundary
#'   matching to avoid partial matches (e.g., "mockdata" won't match "mockdata_test").
#' @param database Character vector or NULL. Database identifier(s) to filter by.
#'   If NULL (default), extracts all unique databases from variables.csv databaseStart
#'   column. If specified, only imports variables that exist in the specified database(s).
#' @param output_dir Character. Directory where output CSV files will be written.
#'   Default is "inst/extdata/". Files will be named mock_data_config.csv and
#'   mock_data_config_details.csv.
#'
#' @return Invisible list with two data frames: config and details
#'
#' @details
#' ## Column Mapping
#'
#' ### variables.csv -> mock_data_config.csv
#' Direct copy: variable, role, label, labelLong, section, subject, variableType,
#' units, version, description (to notes)
#'
#' Generated:
#' - uid: v_001, v_002, v_003, ...
#' - position: 10, 20, 30, ...
#' - source_database: extracted from databaseStart based on database filter
#' - source_spec: basename of variables_path
#' - last_updated: current date
#' - mockDataLastUpdated: current date
#' - seed: NA
#' - rType: NA (user must fill in: integer/double/factor/date/logical/character)
#' - corrupt_low_prop, corrupt_low_range, corrupt_high_prop, corrupt_high_range: NA
#' - mockDataVersion, mockDataVersionNotes: NA
#'
#' ### variable_details.csv -> mock_data_config_details.csv
#' Direct copy: variable, dummyVariable, catStartLabel (to catLabel),
#' catLabelLong, units, notes
#'
#' Mapped:
#' - recStart: copied from input recStart
#' - recEnd: initialized to input recStart (user updates to: valid, distribution, mean, etc.)
#'
#' Generated:
#' - uid: looked up from config by variable name
#' - uid_detail: d_001, d_002, d_003, ...
#' - proportion: NA (user fills in - must sum to 1.0 per variable)
#' - value: NA (user fills in distribution parameters)
#' - sourceFormat: NA (user fills in for date variables)
#'
#' ## Database Filtering
#' When database parameter is specified, the function:
#' 1. Filters variables.csv rows where databaseStart contains the specified database(s)
#' 2. Filters variable_details.csv rows where databaseStart contains the specified database(s)
#' 3. Sets source_database to the filtered database(s) in mock_data_config.csv
#'
#' @examples
#' \dontrun{
#' # Import all variables with role "mockdata" from all databases
#' import_from_recodeflow(
#'   variables_path = "inst/extdata/cchs/variables_cchsflow_sample.csv",
#'   variable_details_path = "inst/extdata/cchs/variable_details_cchsflow_sample.csv",
#'   role_filter = "mockdata"
#' )
#'
#' # Import only from specific database
#' import_from_recodeflow(
#'   variables_path = "inst/extdata/cchs/variables_cchsflow_sample.csv",
#'   variable_details_path = "inst/extdata/cchs/variable_details_cchsflow_sample.csv",
#'   role_filter = "mockdata",
#'   database = "cchs2015_2016_p"
#' )
#'
#' # Import from multiple databases
#' import_from_recodeflow(
#'   variables_path = "inst/extdata/cchs/variables_cchsflow_sample.csv",
#'   variable_details_path = "inst/extdata/cchs/variable_details_cchsflow_sample.csv",
#'   role_filter = "mockdata",
#'   database = c("cchs2015_2016_p", "cchs2017_2018_p")
#' )
#' }
#'
#' @export
import_from_recodeflow <- function(
  variables_path,
  variable_details_path,
  role_filter = "mockdata",
  database = NULL,
  output_dir = "inst/extdata/"
) {

  # Input validation
  if (!file.exists(variables_path)) {
    stop("variables_path file does not exist: ", variables_path)
  }
  if (!file.exists(variable_details_path)) {
    stop("variable_details_path file does not exist: ", variable_details_path)
  }
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
    message("Created output directory: ", output_dir)
  }

  # Read input files
  message("Reading variables from: ", variables_path)
  variables <- read.csv(variables_path, stringsAsFactors = FALSE, check.names = FALSE)

  message("Reading variable_details from: ", variable_details_path)
  variable_details <- read.csv(variable_details_path, stringsAsFactors = FALSE, check.names = FALSE)

  # Validate required columns in variables.csv
  required_vars_cols <- c("variable", "role", "variableType", "databaseStart")
  missing_vars_cols <- setdiff(required_vars_cols, names(variables))
  if (length(missing_vars_cols) > 0) {
    stop("Missing required columns in variables.csv: ", paste(missing_vars_cols, collapse = ", "))
  }

  # Validate required columns in variable_details.csv
  required_details_cols <- c("variable", "recStart", "databaseStart")
  missing_details_cols <- setdiff(required_details_cols, names(variable_details))
  if (length(missing_details_cols) > 0) {
    stop("Missing required columns in variable_details.csv: ", paste(missing_details_cols, collapse = ", "))
  }

  # Filter variables by role (word boundary matching)
  role_pattern <- paste0("\\b", role_filter, "\\b")
  variables_filtered <- variables[grepl(role_pattern, variables$role, ignore.case = TRUE), ]

  if (nrow(variables_filtered) == 0) {
    stop("No variables found with role '", role_filter, "' in variables.csv")
  }

  message("Found ", nrow(variables_filtered), " variables with role '", role_filter, "'")

  # Determine database filter
  if (is.null(database)) {
    # Extract all unique databases from databaseStart
    all_databases <- unique(unlist(strsplit(variables_filtered$databaseStart, ",\\s*")))
    database <- all_databases
    message("No database specified. Using all databases found: ", paste(database, collapse = ", "))
  } else {
    message("Filtering to database(s): ", paste(database, collapse = ", "))
  }

  # Filter variables by database
  database_pattern <- paste(database, collapse = "|")
  variables_filtered <- variables_filtered[grepl(database_pattern, variables_filtered$databaseStart), ]

  if (nrow(variables_filtered) == 0) {
    stop("No variables found for database(s): ", paste(database, collapse = ", "))
  }

  message("After database filtering: ", nrow(variables_filtered), " variables")

  # Filter variable_details by the selected variables AND database
  details_filtered <- variable_details[
    variable_details$variable %in% variables_filtered$variable &
    grepl(database_pattern, variable_details$databaseStart),
  ]

  if (nrow(details_filtered) == 0) {
    warning("No detail rows found for filtered variables. This may be expected for continuous variables.")
  } else {
    message("Found ", nrow(details_filtered), " detail rows for filtered variables")
  }

  # Build mock_data_config.csv
  message("\nBuilding mock_data_config.csv...")

  config <- data.frame(
    uid = paste0("v_", sprintf("%03d", seq_len(nrow(variables_filtered)))),
    variable = variables_filtered$variable,
    role = variables_filtered$role,
    label = if ("label" %in% names(variables_filtered)) variables_filtered$label else NA,
    labelLong = if ("labelLong" %in% names(variables_filtered)) variables_filtered$labelLong else NA,
    section = if ("section" %in% names(variables_filtered)) variables_filtered$section else NA,
    subject = if ("subject" %in% names(variables_filtered)) variables_filtered$subject else NA,
    variableType = variables_filtered$variableType,
    rType = NA,  # MockData: R data type (integer/double/factor/logical/character/date) - user fills in
    units = if ("units" %in% names(variables_filtered)) variables_filtered$units else NA,
    position = seq(10, by = 10, length.out = nrow(variables_filtered)),
    source_database = paste(database, collapse = ", "),
    source_spec = basename(variables_path),
    version = if ("version" %in% names(variables_filtered)) variables_filtered$version else NA,
    last_updated = as.character(Sys.Date()),
    notes = if ("description" %in% names(variables_filtered)) variables_filtered$description else NA,
    seed = NA,
    # MockData extension fields for contamination
    corrupt_low_prop = NA,
    corrupt_low_range = NA,
    corrupt_high_prop = NA,
    corrupt_high_range = NA,
    # MockData versioning
    mockDataVersion = NA,
    mockDataLastUpdated = as.character(Sys.Date()),
    mockDataVersionNotes = NA,
    stringsAsFactors = FALSE
  )

  # Build mock_data_config_details.csv
  message("Building mock_data_config_details.csv...")

  if (nrow(details_filtered) > 0) {
    # Create uid lookup table
    uid_lookup <- setNames(config$uid, config$variable)

    details <- data.frame(
      uid = uid_lookup[details_filtered$variable],
      uid_detail = paste0("d_", sprintf("%03d", seq_len(nrow(details_filtered)))),
      variable = details_filtered$variable,
      dummyVariable = if ("dummyVariable" %in% names(details_filtered)) details_filtered$dummyVariable else NA,
      recStart = details_filtered$recStart,  # Keep original recStart
      recEnd = details_filtered$recStart,  # Also map to recEnd for categorization
      catLabel = if ("catStartLabel" %in% names(details_filtered)) details_filtered$catStartLabel else NA,
      catLabelLong = if ("catLabelLong" %in% names(details_filtered)) details_filtered$catLabelLong else NA,
      units = if ("units" %in% names(details_filtered)) details_filtered$units else NA,
      proportion = NA,  # Leave empty for user specification
      value = NA,
      sourceFormat = NA,  # For date formatting specifications
      notes = if ("notes" %in% names(details_filtered)) details_filtered$notes else NA,
      stringsAsFactors = FALSE
    )
  } else {
    # Create empty details file with correct structure
    details <- data.frame(
      uid = character(0),
      uid_detail = character(0),
      variable = character(0),
      dummyVariable = character(0),
      recStart = character(0),
      recEnd = character(0),
      catLabel = character(0),
      catLabelLong = character(0),
      units = character(0),
      proportion = numeric(0),
      value = numeric(0),
      sourceFormat = character(0),
      notes = character(0),
      stringsAsFactors = FALSE
    )
  }

  # Write output files
  config_path <- file.path(output_dir, "mock_data_config.csv")
  details_path <- file.path(output_dir, "mock_data_config_details.csv")

  message("\nWriting output files...")
  message("  ", config_path)
  write.csv(config, config_path, row.names = FALSE, na = "")

  message("  ", details_path)
  write.csv(details, details_path, row.names = FALSE, na = "")

  message("\nImport complete!")
  message("  Variables imported: ", nrow(config))
  message("  Detail rows imported: ", nrow(details))
  message("\nNext steps:")
  message("  1. Review ", config_path)
  message("     - Fill in 'rType' for each variable (integer/double/factor/date/logical/character)")
  message("     - Optionally add contamination parameters (corrupt_low_prop, corrupt_low_range, etc.)")
  message("     - Add mockDataVersion and mockDataVersionNotes")
  message("  2. Review ", details_path)
  message("     - Fill in 'proportion' values (must sum to 1.0 per variable)")
  message("     - Add distribution parameters in 'value' column (mean, sd, rate, shape)")
  message("     - Use interval notation [min,max] in recStart for ranges")
  message("     - Specify recEnd values: valid, distribution, mean, sd, event, followup_min, etc.")

  invisible(list(config = config, details = details))
}
