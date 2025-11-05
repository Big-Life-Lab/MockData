# MockData project-specific AI instructions

## Documentation development workflow

**CRITICAL**: For documentation changes (README, vignettes, guides):

1. **STOP before implementing**
2. **Draft the structure/outline** in a temp file or chat message
3. **Get explicit approval** from user
4. **Then implement** the approved structure
5. **No rewrites without discussion**

**Example approach**:
- User: "Update getting-started.qmd"
- Assistant: *Reads current file, proposes outline, waits for approval*
- User: "Yes, but change X to Y"
- Assistant: *Implements with changes*

## Documentation principles

### Always prefer explicit over magical

**Code examples should show each step**:
- ✅ `create_cat_var()` → `cbind()` (shows steps)
- ❌ `create_mock_data()` wrapper (hides details)
- **Rationale**: Users learn better seeing each step

**When to use each approach**:
- **README, getting-started**: Explicit approach (learning)
- **tutorial-config-files**: Config wrapper (convenience for many variables)
- **Examples (CCHS, CHMS, DemPoRT)**: Use what makes sense for the task

### Divio documentation framework

**Always follow Divio structure**:

- **Tutorials**: Learning-oriented (step-by-step, hand-holding)
  - getting-started.qmd
  - tutorial-config-files.qmd

- **How-to guides**: Task-oriented (solve specific problem)
  - cchs-example.qmd
  - chms-example.qmd
  - demport-example.qmd

- **Reference**: Information-oriented (complete specification)
  - reference-config.qmd
  - Function documentation

- **Explanation**: Understanding-oriented (concepts, decisions)
  - temporal-and-survival-roadmap.md
  - Design documents

### Version references

**Never reference versions in documentation**:
- ❌ "v0.2 format", "legacy v0.1 API"
- ✅ "configuration-based approach", "explicit variable generation"
- **Rationale**: Rapid development, versions tracked in NEWS.md only

### Planning checkpoints

**Check before making major changes**:
- Documentation structure changes → propose outline first
- Example code approaches → confirm philosophy aligns
- File reorganization → get approval
- Breaking changes → discuss impact

## Code development workflow

### When implementing features

1. **Use TodoWrite tool** to track multi-step tasks
2. **Mark tasks in_progress** before starting work
3. **Mark completed** immediately after finishing (don't batch)
4. **Update todos** if scope changes

### Testing changes

**Always test before claiming completion**:
- Run the code you wrote
- Verify output matches expected behavior
- Check for errors in different scenarios
- Don't mark complete until verified

## R package conventions

### Canadian spelling

Use Canadian spelling in all documentation:
- ✅ harmonization, optimization, behavior
- ❌ harmonisation, optimisation, behaviour
- **Exception**: British spelling uses "s" (harmonisation) - we use "z"

### Heading capitalization

**Sentence case for all headings except document title**:
- ✅ Level 1 (title): Title Case
- ✅ Level 2+: Sentence case only
- ❌ Level 2+: Title Case

**Examples**:
- ✅ `## Creating your first dataset`
- ❌ `## Creating Your First Dataset`

### Package metadata

**Never commit version changes without discussion**:
- DESCRIPTION version bumps → user decides
- NEWS.md updates → discuss what to include
- Function deprecations → plan migration path

## Common pitfalls to avoid

1. **Reverting to config-file examples**: Remember explicit > magical for teaching
2. **Adding version labels**: Describe features, not versions
3. **Skipping planning phase**: Propose before implementing documentation changes
4. **Batch completing todos**: Mark complete immediately after each task
5. **Not testing code**: Always run code before marking complete

## Communication style

**When proposing changes**:
```
I see you want to [task]. Let me [read/analyze] first and propose
an approach.

[Analysis]

Proposed structure:
1. [Step 1]
2. [Step 2]
3. [Step 3]

Does this align with your vision? Any changes before I implement?
```

**When uncertain**:
- Ask specific questions
- Propose 2-3 options with rationales
- Wait for clarification before proceeding

**When making assumptions**:
- State the assumption explicitly
- Explain reasoning
- Ask for confirmation

## Project-specific knowledge

### recodeflow ecosystem

MockData is part of the recodeflow package ecosystem:
- **cchsflow**: CCHS harmonization
- **chmsflow**: CHMS harmonization
- **MockData**: Generate test data from recodeflow metadata

### Metadata structure

**Two-file pattern** (inherited from recodeflow):
- `variables.csv`: Variable list (what to generate)
- `variable_details.csv`: Value specifications (how to generate)

### Key design decisions

**Why explicit approach for teaching**:
- Users understand each step
- Easy to debug issues
- Flexible (skip variables, customize)
- No hidden magic

**Why config wrapper exists**:
- Convenience for large datasets
- Batch generation workflows
- Integration with existing recodeflow metadata

Both are valid - use appropriate tool for the task.
