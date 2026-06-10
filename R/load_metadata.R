#' Load metadata from a file path or pass a data frame through
#'
#' Internal helper shared by create_mock_data() and the create_* generators.
#' Accepts a data frame (returned unchanged), NULL (returned unchanged, for
#' optional variable_details), or a single CSV file path (read with
#' check.names = FALSE to preserve recodeflow column names).
#'
#' @param x data.frame, NULL, or length-1 character file path.
#' @param what Character. Argument name used in messages ("variables",
#'   "variable_details").
#' @param verbose Logical. Emit a message when reading from file.
#'
#' @return data.frame or NULL.
#' @noRd
.load_metadata_df <- function(x, what, verbose = FALSE) {
  if (is.null(x) || is.data.frame(x)) {
    return(x)
  }
  if (is.character(x) && length(x) == 1) {
    if (!file.exists(x)) {
      stop(what, " file does not exist: ", x, call. = FALSE)
    }
    if (verbose) message("Reading ", what, " file: ", x)
    return(read.csv(x, stringsAsFactors = FALSE, check.names = FALSE))
  }
  stop("`", what, "` must be a data frame or a single CSV file path",
       call. = FALSE)
}
