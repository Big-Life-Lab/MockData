# Import and convert recodeflow variables and variable details metadata files to MockData configuration format

Converts recodeflow variables.csv and variable_details.csv files into
MockData configuration format (mock_data_config.csv and
mock_data_config_details.csv). Filters variables by role and optionally
by database.

## Usage

``` r
import_from_recodeflow(
  variables_path,
  variable_details_path,
  role_filter = "mockdata",
  database = NULL,
  output_dir = "inst/extdata/"
)
```

## Arguments

- variables_path:

  Character. Path to recodeflow variables.csv file.

- variable_details_path:

  Character. Path to recodeflow variable_details.csv file.

- role_filter:

  Character. Role value to filter variables by. Only variables with this
  role will be imported. Default is "mockdata". Use regex word boundary
  matching to avoid partial matches (e.g., "mockdata" won't match
  "mockdata_test").

- database:

  Character vector or NULL. Database identifier(s) to filter by. If NULL
  (default), extracts all unique databases from variables.csv
  databaseStart column. If specified, only imports variables that exist
  in the specified database(s).

- output_dir:

  Character. Directory where output CSV files will be written. Default
  is "inst/extdata/". Files will be named mock_data_config.csv and
  mock_data_config_details.csv.

## Value

Invisible list with two data frames: config and details

## Details

### Column Mapping

#### variables.csv -\> mock_data_config.csv

Direct copy: variable, role, label, labelLong, section, subject,
variableType, units, version, description (to notes)

Generated:

- uid: v_001, v_002, v_003, ...

- position: 10, 20, 30, ...

- source_database: extracted from databaseStart based on database filter

- source_spec: basename of variables_path

- last_updated: current date

- seed: NA

#### variable_details.csv -\> mock_data_config_details.csv

Direct copy: variable, dummyVariable, recStart (to recEnd),
catStartLabel (to catLabel), catLabelLong, units, notes

Generated:

- uid: looked up from config by variable name

- uid_detail: d_001, d_002, d_003, ...

- proportion: left empty for user specification

### Database Filtering

When database parameter is specified, the function:

1.  Filters variables.csv rows where databaseStart contains the
    specified database(s)

2.  Filters variable_details.csv rows where databaseStart contains the
    specified database(s)

3.  Sets source_database to the filtered database(s) in
    mock_data_config.csv

## Examples

``` r
if (FALSE) { # \dontrun{
# Import all variables with role "mockdata" from all databases
import_from_recodeflow(
  variables_path = "inst/extdata/cchs/variables_cchsflow_sample.csv",
  variable_details_path = "inst/extdata/cchs/variable_details_cchsflow_sample.csv",
  role_filter = "mockdata"
)

# Import only from specific database
import_from_recodeflow(
  variables_path = "inst/extdata/cchs/variables_cchsflow_sample.csv",
  variable_details_path = "inst/extdata/cchs/variable_details_cchsflow_sample.csv",
  role_filter = "mockdata",
  database = "cchs2015_2016_p"
)

# Import from multiple databases
import_from_recodeflow(
  variables_path = "inst/extdata/cchs/variables_cchsflow_sample.csv",
  variable_details_path = "inst/extdata/cchs/variable_details_cchsflow_sample.csv",
  role_filter = "mockdata",
  database = c("cchs2015_2016_p", "cchs2017_2018_p")
)
} # }
```
