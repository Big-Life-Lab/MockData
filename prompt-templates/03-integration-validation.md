# Template 3: Integration & Validation

## Objective
Integrate simstudy-based generation into the main workflow and validate that the refactored system produces PUMP-compatible results with proper categorical→continuous reverse engineering.

## Context
The critical validation is ensuring that continuous variables (like age) can be re-categorized to match PUMP proportions exactly, while enabling code development with realistic continuous values.

## Prompt Template

```
Integrate simstudy-based generation into the main workflow with PUMP validation:

## Tasks

1. **Update main script**: 
   - Modify Generate_mock_data.qmd to use new simstudy-based functions
   - Replace the current generation loops with simstudy conditional generation pipeline
   - Update library imports to include simstudy
   - Ensure the same output data structure is maintained
   - Add both categorical and continuous versions of PUMP-categorized variables

2. **Add PUMP validation**: 
   - Create `validate_pump_proportions()` function to check categorical→continuous roundtrip
   - Compare old vs new output for consistency
   - Verify categorical distributions match expected PUMP proportions exactly
   - Check continuous variable ranges and distributions within categorical boundaries
   - Validate that continuous age re-categorizes to match PUMP age_group proportions
   - Test missing data patterns from cchs_missing_data.yaml

3. **Implement roundtrip testing**: 
   - Generate continuous age values within categorical boundaries
   - Re-categorize continuous age back to age groups
   - Verify proportions match original PUMP specifications
   - Test edge cases and boundary conditions
   - Validate missing data handling in both categorical and continuous forms

4. **Clean up**: 
   - Remove unused custom functions (or mark as deprecated)
   - Update documentation and function comments
   - Clean up any redundant utility functions
   - Update any example usage in comments
   - Document the categorical→continuous approach

5. **Test multi-cycle generation**: 
   - Ensure CCHS cycle handling still works properly
   - Verify variable name mapping across cycles
   - Test that derived variables placeholder still works
   - Validate final combined dataset structure
   - Test conditional generation across different cycles

## Validation Criteria
- Output data has same dimensions and structure
- Categorical variables match PUMP proportions exactly (within tolerance)
- Continuous variables respect specified bounds within categories
- Categorical→continuous roundtrip validation passes
- Multi-cycle data maintains proper cycle identification
- Missing data patterns match cchs_missing_data.yaml specifications
- No regressions in existing functionality

## PUMP-Specific Validation
- Age groups match PUMP proportions when continuous age is re-categorized
- Missing data codes (6,7,8,9 vs 96,97,98,99) are handled correctly
- Interval boundaries are respected ([18,25), [25,35), etc.)
- Realistic distributions within categories (not just uniform)

## Documentation Updates
- Update function documentation for new simstudy approach
- Add examples of categorical→continuous generation
- Document PUMP proportion validation approach
- Document any changes to CSV specification format
- Update README with PUMP reverse engineering context

## Expected Output
- Fully integrated simstudy-based mock data generation
- PUMP-validated system producing compliant categorical and continuous data
- Roundtrip validation utilities
- Updated documentation and examples
- Clean, maintainable codebase ready for secure environment code development
```

## Usage Notes
- Execute after completing Template 2 refactoring
- Focus on PUMP proportion validation and roundtrip testing
- Prioritize age variable as the primary test case
- Prepare for real-world code development scenarios