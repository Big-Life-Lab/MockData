# Model hints for MockData specifications

Model hints are lightweight backend guidance carried by `mock_spec`
objects and variables. They are not generation commands; generation
backends may use them to choose a sensible default path.

## Details

Supported values:

- `auto`:

  Let MockData choose the backend.

- `native`:

  Prefer the native MockData backend.

- `simstudy`:

  Prefer the optional `simstudy` backend.

- `native-postprocess`:

  Generate baseline values natively, then rely on MockData
  post-processing such as date/source-format conversion.

- `simstudy-or-native`:

  Either backend is expected to be suitable.

- `simstudy-advanced`:

  Feature is expected to need advanced `simstudy` support, such as
  correlations or survival durations.

- `diagnostic-required`:

  Generation/post-processing must preserve diagnostics needed to
  interpret the result.
