# Prompt Templates for simstudy Refactoring: PUMP Categorical→Continuous Generation

This folder contains structured prompt templates for refactoring the mock data generation system to use the `simstudy` R package with focus on **PUMP reverse engineering** - generating continuous variables from categorical PUMP specifications.

## Context: PUMP Reverse Engineering Challenge

This system generates mock CCHS data for code development outside Statistics Canada's secure environment. The key challenge is **recreating continuous variables (like age) from categorized PUMP data** while preserving exact categorical proportions for code compatibility.

- **Secure Environment**: Real continuous data (age = 34.5 years)
- **PUMP Access**: Only categorized data (age_group = "30-39", proportion = 0.23)  
- **Goal**: Generate realistic continuous values that match PUMP proportions exactly

## Template Overview

### 01-analysis-foundation.md
**Purpose**: Analyze the current system and plan the PUMP reverse engineering approach  
**Focus**: Understanding PUMP categorization constraints and identifying conditional generation patterns  
**Output**: Analysis document and categorical→continuous strategy

### 02-core-refactoring.md  
**Purpose**: Refactor core functions to use simstudy with conditional generation  
**Focus**: Implementing categorical→continuous generation while preserving PUMP proportions  
**Output**: Updated R functions using simstudy with conditional generation

### 03-integration-validation.md
**Purpose**: Integrate changes and validate PUMP proportion matching  
**Focus**: Roundtrip testing and PUMP validation  
**Output**: PUMP-validated simstudy-based mock data generation

### age-example.R
**Purpose**: Complete working example of categorical→continuous generation for age  
**Focus**: Demonstrates PUMP proportion matching with realistic continuous values  
**Output**: Runnable code showing the full approach

## Usage Instructions

### Sequential Execution
Execute templates in order (01 → 02 → 03). Each builds on the previous one.

### Template Usage
Each template contains:
- **Objective**: Clear goal for the phase
- **Context**: PUMP reverse engineering specific context
- **Prompt Template**: Copy-paste ready prompts for AI assistance
- **Usage Notes**: Specific guidance for that phase

### Best Practices
- Complete each template fully before moving to the next
- Test PUMP proportion validation after each phase
- Document findings and decisions for future reference
- Preserve the valuable CSV specifications throughout
- Focus on variables commonly categorized in PUMP (age, income, etc.)

## Benefits of This Approach

### PUMP Compatibility
- Exact categorical proportion matching for code compatibility
- Realistic continuous values for algorithm development
- Proper missing data patterns from cchs_missing_data.yaml

### Incremental Development
- Manageable phases reduce risk of breaking existing functionality
- Clear checkpoints for validation and testing
- Easier to debug issues when they arise

### Preserve Domain Knowledge
- CSV specifications contain valuable CCHS expertise
- Variable mapping logic is maintained
- Existing interfaces are preserved
- YAML schemas provide authoritative specifications

### Future-Ready
- Sets foundation for correlation matrix integration
- Leverages established statistical library
- Improves maintainability and extensibility
- Enables sophisticated health research workflows

## Expected Outcomes

After completing all templates:
- Clean, maintainable code using simstudy with conditional generation
- PUMP-validated categorical→continuous generation
- Preserved CSV-based variable specifications
- Both categorical and continuous versions of variables
- Realistic continuous values within categorical boundaries
- Exact PUMP proportion matching through roundtrip validation
- Ready for secure environment code development

## Key Technical Features

### Conditional Generation
- `simstudy::defCondition()` for generating continuous within categorical boundaries
- Multiple distribution types (uniform, normal, gamma) for realism
- Proper interval boundary handling from variable_details.yaml

### PUMP Validation
- Roundtrip testing: continuous → categorical → proportion matching
- Built-in validation functions for proportion accuracy
- Missing data pattern integration from cchs_missing_data.yaml

### Multi-Cycle Support
- Handles different CCHS survey cycles
- Preserves cycle-specific variable mappings
- Consistent generation across survey years

## Support

If you encounter issues during refactoring:
1. Review the analysis from Template 1
2. Test categorical→continuous generation in Template 2
3. Validate PUMP proportions in Template 3
4. Reference age-example.R for working implementation
5. Refer to simstudy documentation for advanced conditional generation features