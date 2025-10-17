# Template 1: Analysis & Foundation

## Objective
Analyze the current mock data generation system to understand its architecture and identify how to integrate simstudy for PUMP categorical→continuous reverse engineering.

## Context
This system generates mock CCHS data for code development outside Statistics Canada's secure environment. The key challenge is recreating continuous variables (like age) from categorized PUMP data while preserving exact categorical proportions for code compatibility.

## Prompt Template

```
Analyze the current mock data generation system in this R project:

## Tasks

1. **Map the PUMP reverse engineering flow**: 
   - How do CSV specifications in Worksheets/ convert to mock data?
   - What is the relationship between variables.csv and variable_details.csv?
   - How does the cycle-based generation work?
   - Which variables are categorized in PUMP but continuous in the secure environment?

2. **Identify categorical→continuous challenges**: 
   - Which variables need continuous values generated from categorical proportions?
   - How are PUMP proportions currently specified in the CSV files?
   - What continuous distributions would be realistic within each category?
   - How do missing data patterns from cchs_missing_data.yaml apply?

3. **Identify simstudy equivalents**: 
   - For each custom function (create_cat_var, create_con_var), what simstudy functions would replace them?
   - How would simstudy handle conditional generation (continuous within categorical)?
   - What simstudy distribution types map to the current uniform/normal approach?
   - How can simstudy generate both categorical and continuous versions of the same variable?

4. **Document the interface**: 
   - What are the input/output contracts that must be preserved?
   - What data structures does the downstream analysis expect?
   - Which parts of the current approach should be kept vs replaced?
   - How should the system validate that generated continuous data matches PUMP proportions?

## Focus Areas
- Understanding the PUMP categorization constraints
- Preserving the valuable CCHS domain expertise in CSV specifications
- Identifying conditional generation patterns for categorical→continuous
- Maintaining exact PUMP proportion matching for code compatibility

## Expected Output
- Clear mapping of current functions to simstudy equivalents
- Documentation of categorical→continuous requirements
- Identification of variables needing conditional generation
- Recommendations for PUMP-preserving refactoring approach
```

## Usage Notes
- Run this analysis first before attempting any code changes
- Focus on understanding the PUMP reverse engineering challenge
- Document findings for reference during refactoring phases
- Pay special attention to variables that exist in both categorical and continuous forms