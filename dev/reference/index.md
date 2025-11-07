# Package index

## Main generation functions

Generate categorical, continuous, date, and survival variables. Use
[`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md)
for batch generation or individual functions for fine-grained control.

- [`create_cat_var()`](https://big-life-lab.github.io/MockData/reference/create_cat_var.md)
  : Create categorical variable for MockData
- [`create_con_var()`](https://big-life-lab.github.io/MockData/reference/create_con_var.md)
  : Create continuous variable for MockData
- [`create_date_var()`](https://big-life-lab.github.io/MockData/reference/create_date_var.md)
  : Create date variable for MockData
- [`create_survival_dates()`](https://big-life-lab.github.io/MockData/reference/create_survival_dates.md)
  : Create paired survival dates for cohort studies
- [`create_mock_data()`](https://big-life-lab.github.io/MockData/reference/create_mock_data.md)
  : Create mock data from configuration files

## Configuration

Read and validate v0.2 configuration files. Import existing recodeflow
metadata or create new configurations for mock data generation
workflows.

- [`read_mock_data_config()`](https://big-life-lab.github.io/MockData/reference/read_mock_data_config.md)
  : Read and validate MockData configuration file defining variable
  specifications for mock data generation
- [`read_mock_data_config_details()`](https://big-life-lab.github.io/MockData/reference/read_mock_data_config_details.md)
  : Read and validate MockData configuration details file containing
  distribution parameters and category proportions
- [`validate_mock_data_config()`](https://big-life-lab.github.io/MockData/reference/validate_mock_data_config.md)
  : Validate MockData configuration against schema requirements
  including required columns and unique identifiers
- [`validate_mock_data_config_details()`](https://big-life-lab.github.io/MockData/reference/validate_mock_data_config_details.md)
  : Validate MockData configuration details against schema requirements
  including proportion sums and parameter completeness
- [`import_from_recodeflow()`](https://big-life-lab.github.io/MockData/reference/import_from_recodeflow.md)
  : Import and convert recodeflow variables and variable details
  metadata files to MockData configuration format

## Helper functions

Utilities for metadata processing, proportions, type coercion, and data
quality. Support main generation functions or use directly for custom
workflows.

- [`get_variable_details()`](https://big-life-lab.github.io/MockData/reference/get_variable_details.md)
  : Get variable details for specific variable
- [`extract_proportions()`](https://big-life-lab.github.io/MockData/reference/extract_proportions.md)
  : Extract proportions from details subset
- [`extract_distribution_params()`](https://big-life-lab.github.io/MockData/reference/extract_distribution_params.md)
  : Extract distribution parameters from details
- [`sample_with_proportions()`](https://big-life-lab.github.io/MockData/reference/sample_with_proportions.md)
  : Sample with proportions
- [`apply_missing_codes()`](https://big-life-lab.github.io/MockData/reference/apply_missing_codes.md)
  : Apply missing codes to values
- [`apply_rtype_defaults()`](https://big-life-lab.github.io/MockData/reference/apply_rtype_defaults.md)
  : Apply rType defaults to variable details
- [`determine_proportions()`](https://big-life-lab.github.io/MockData/reference/determine_proportions.md)
  : Determine proportions for categorical variable generation
- [`has_garbage()`](https://big-life-lab.github.io/MockData/reference/has_garbage.md)
  : Check if garbage is specified
- [`make_garbage()`](https://big-life-lab.github.io/MockData/reference/make_garbage.md)
  : Make garbage
- [`generate_garbage_values()`](https://big-life-lab.github.io/MockData/reference/generate_garbage_values.md)
  : Generate garbage values
- [`get_variables_by_role()`](https://big-life-lab.github.io/MockData/reference/get_variables_by_role.md)
  : Get variables by role
- [`get_enabled_variables()`](https://big-life-lab.github.io/MockData/reference/get_enabled_variables.md)
  : Get enabled variables
- [`get_cycle_variables()`](https://big-life-lab.github.io/MockData/reference/get_cycle_variables.md)
  : Get list of variables used in a specific database/cycle
- [`get_raw_variables()`](https://big-life-lab.github.io/MockData/reference/get_raw_variables.md)
  : Get list of unique raw variables for a database/cycle

## Parsers

Parse recodeflow notation for variable specifications and range syntax.
Extract structured information from metadata for mock data generation.

- [`parse_range_notation()`](https://big-life-lab.github.io/MockData/reference/parse_range_notation.md)
  : Parse range notation from variable_details
- [`parse_variable_start()`](https://big-life-lab.github.io/MockData/reference/parse_variable_start.md)
  : Parse variableStart field to extract raw variable name
