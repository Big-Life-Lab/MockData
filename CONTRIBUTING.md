# Contributing to MockData

Thank you for considering contributing to MockData! This package is part of the recodeflow ecosystem and benefits from community input.

## Getting Started

### Prerequisites

- R (>= 4.2.0)
- RStudio or another R IDE (recommended)
- Git
- Package development tools: `install.packages(c("devtools", "testthat", "roxygen2"))`

### Setting Up Development Environment

1. Fork and clone the repository:
```bash
git clone https://github.com/your-username/MockData.git
cd MockData
```

2. Open in RStudio:
   - Double-click `MockData.Rproj`
   - Or: File → Open Project → Select MockData.Rproj

3. Install development dependencies:
```r
devtools::install_dev_deps()
```

4. Load the package:
```r
devtools::load_all()
```

## Development Workflow

### Making Changes

1. **Create a new branch** for your work:
```bash
git checkout -b feature/your-feature-name
```

2. **Make your changes** following the coding standards below

3. **Document your changes**:
   - Update function documentation (roxygen2 comments)
   - Add examples where appropriate
   - Update NEWS.md with your changes

4. **Write tests** for new functionality:
   - Add tests to `tests/testthat/test-mockdata.R`
   - Ensure all tests pass: `devtools::test()`

5. **Run checks**:
```r
devtools::check()
```

6. **Commit your changes** following commit message guidelines

7. **Push and create a pull request**

### Coding Standards

#### R Code Style

- Use 2 spaces for indentation (not tabs)
- Line length: aim for < 80 characters, max 100
- Use `<-` for assignment, not `=`
- Function names: `snake_case`
- Variable names: `snake_case`
- Constants: `SCREAMING_SNAKE_CASE`

#### Documentation

- All exported functions must have roxygen2 documentation
- Include `@param`, `@return`, `@examples`, `@export` tags
- Examples should be runnable (use `\dontrun{}` sparingly)
- Use Canadian spelling (behaviour, colour, centre)

#### Commit Messages

Follow Canadian Government Digital Standards:
- **Format**: `type: brief description`
- **Types**:
  - `feat`: New feature
  - `fix`: Bug fix
  - `docs`: Documentation changes
  - `test`: Adding or updating tests
  - `refactor`: Code refactoring
  - `style`: Code style changes (formatting, etc.)
  - `chore`: Maintenance tasks

**Examples**:
```
feat: add support for date variable generation
fix: handle missing NA codes in categorical variables
docs: update README with CHMS example
test: add tests for parse_range_notation edge cases
```

**Do not credit AI tools in commit messages** (as per project guidelines).

### Testing

#### Running Tests

```r
# Run all tests
devtools::test()

# Run specific test file
testthat::test_file("tests/testthat/test-mockdata.R")

# Run with coverage
covr::package_coverage()
```

#### Writing Tests

- Place tests in `tests/testthat/test-mockdata.R`
- Use descriptive test names: `test_that("parse_range_notation handles closed intervals", { ... })`
- Test edge cases and error conditions
- Aim for high code coverage

#### Test Data

- Use existing metadata in `inst/extdata/` for tests
- If adding new test data, document its purpose
- Keep test data small and focused

### Validation Tools

Before submitting, run the validation tools:

```bash
# Validate metadata quality
Rscript mockdata-tools/validate-metadata.R

# Test coverage across cycles
Rscript mockdata-tools/test-all-cycles.R
```

## Areas for Contribution

### High Priority

- **Date variable support**: Implement `create_date_var()` for linkage testing
- **Data quality injection**: Add functions to inject realistic data quality issues
- **Performance optimization**: Improve generation speed for large datasets
- **Additional vignettes**: Real-world use cases and workflows

### Medium Priority

- **More survey examples**: Add metadata from other recodeflow projects
- **Validation improvements**: Enhance metadata quality checks
- **Documentation**: Expand README, add pkgdown site

### Low Priority

- **Distribution options**: Add more probability distributions for continuous variables
- **Correlation structure**: Generate correlated variables
- **Time series**: Support for longitudinal data

## Recodeflow Schema Compliance

When adding or modifying parsers:

1. **Check the schema**: See `inst/metadata/schemas/` for authoritative definitions
2. **Test with real metadata**: Use CCHS, CHMS, or DemPoRT examples
3. **Document notation support**: Update README if adding new notation patterns
4. **Coordinate with cchsflow/chmsflow**: Major schema changes should be discussed

## Questions or Issues?

- **Package questions**: Contact Juan Li (juan.li@oahpp.ca) or Doug Manuel (dmanuel@ohri.ca)
- **Bug reports**: Open a GitHub issue
- **Feature requests**: Open a GitHub issue with the "enhancement" label
- **Security issues**: Email maintainers directly (do not open public issue)

## Code of Conduct

### Our Standards

- Be respectful and inclusive
- Focus on constructive feedback
- Prioritize technical accuracy over personal preferences
- Give credit where credit is due

### Unacceptable Behaviour

- Harassment or discriminatory language
- Personal attacks or trolling
- Sharing private information without permission

## License

By contributing to MockData, you agree that your contributions will be licensed under the MIT License.

---

**Thank you for contributing to MockData and the recodeflow ecosystem!**
