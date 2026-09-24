# create_wide_survival_data() warns once per session that it is deprecated
# (ADR v05-survival-dates D9). Mark the warning as already shown so the
# legacy survival tests do not each gain an unrelated warning; the
# deprecation test in test-survival-vars.R resets the flag to exercise it.
assign("wide_survival_warned", TRUE, envir = MockData:::.mockdata_state)
