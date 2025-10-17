# Template 2: Core Refactoring

## Objective
Refactor the R mock data generation functions to use simstudy package with focus on categorical→continuous generation for PUMP reverse engineering.

## Context
The key challenge is generating continuous variables (like age) from PUMP categorical specifications while preserving exact proportions. This requires conditional generation within categorical boundaries.

## Prompt Template

```
Refactor the R mock data generation to use simstudy package for PUMP reverse engineering:

## Tasks

1. **Create PUMP-aware converter function**: 
   - Write `csv_to_defData()` that converts variable specifications to simstudy data definitions
   - Handle both categorical and continuous variables from CSV specs
   - Parse the complex variable mapping syntax (e.g., "cchs2001_p::RACA_6A")
   - Extract category labels and probability distributions from PUMP proportions
   - Identify variables that need both categorical and continuous versions

2. **Implement conditional generation for categorical→continuous**: 
   - Create `create_conditional_var()` for variables like age that are categorical in PUMP but continuous in secure environment
   - Use simstudy's `defCondition()` to generate continuous values within categorical boundaries
   - Handle interval notation from variable_details.yaml ([18,25), [25,35), etc.)
   - Choose appropriate distributions (uniform, normal, gamma) within each category
   - Ensure generated continuous values can be re-categorized to match PUMP proportions exactly

3. **Replace categorical generation**: 
   - Refactor create_cat_var() to use simstudy's categorical distributions
   - Map CSV category specifications to simstudy formula syntax
   - Handle missing data patterns (NA::a, NA::b categories) from cchs_missing_data.yaml
   - Preserve the cycle-specific variable naming

4. **Replace continuous generation**: 
   - Refactor create_con_var() to use simstudy's distribution options
   - Convert range specifications to appropriate simstudy distributions
   - Handle both "normal" and "uniform" distribution types
   - For PUMP-categorized variables, implement conditional generation within boundaries

5. **Preserve existing interface with PUMP validation**: 
   - Ensure the same CSV inputs produce equivalent outputs
   - Maintain the same function signatures and return formats
   - Keep the multi-cycle generation logic intact
   - Add validation that continuous variables match PUMP proportions when re-categorized

## Implementation Guidelines
- Use simstudy::defData() for base variable definitions
- Use simstudy::defCondition() for categorical→continuous conditional generation
- Use simstudy::genData() for data generation
- Maintain backward compatibility with existing CSV format
- Add PUMP proportion validation functions
- Handle missing data patterns from cchs_missing_data.yaml

## Testing Requirements
- Compare old vs new output for sample variables
- Verify categorical probabilities match expected distributions
- Test continuous variable bounds and distributions within categories
- Validate that continuous age re-categorizes to match PUMP proportions
- Ensure multi-cycle generation still works
- Test missing data pattern implementation

## Expected Output
- Refactored R functions using simstudy with conditional generation
- New functions for categorical→continuous reverse engineering
- PUMP proportion validation utilities
- Updated utility functions as needed
- Preserved CSV-to-mock-data pipeline functionality
```

## Usage Notes
- Build on findings from Template 1
- Focus on conditional generation patterns for PUMP reverse engineering
- Test categorical→continuous roundtrip validation
- Prioritize variables like age that are commonly categorized in PUMP