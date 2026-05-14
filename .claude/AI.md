# MockData - AI Development Guidelines

## R package development with pkgdown + Quarto + renv

### Context: Cutting-edge stack (2024-2025)

This project uses a relatively new combination:
- **pkgdown** for R package documentation sites
- **Quarto .qmd vignettes** (replacing traditional .Rmd)
- **renv** for reproducible dependency management
- **GitHub Actions** for automated deployment

This stack is newer than most online resources, so documented patterns are limited.

### Critical: renv snapshot configuration

**Problem**: Default `renv::snapshot()` only captures packages used in `R/` code, missing:
- DESCRIPTION Suggests field (pkgdown, quarto, devtools, roxygen2)
- Packages used only in vignettes (dplyr, stringr, lubridate)

**Solution**: Configure renv to capture ALL dependencies

```r
# Set snapshot type to "all" (persists in project settings)
renv::settings$snapshot.type("all")

# Snapshot with all DESCRIPTION dependencies
renv::snapshot()
```

**Result**: renv.lock now contains ~124 packages instead of just renv itself.

### Simplified GitHub Actions workflow

With complete renv.lock, the workflow is straightforward:

```yaml
- name: Install renv
  run: Rscript -e "install.packages('renv')"

- name: Restore R packages with renv
  run: Rscript -e "renv::restore(prompt = FALSE)"

- name: Build and install MockData package
  run: |
    Rscript -e "roxygen2::roxygenize()"
    R CMD INSTALL .

- name: Build pkgdown site
  run: Rscript -e 'pkgdown::build_site(new_process = FALSE)'
```

**No manual package installations needed.**
**No R_LIBS_USER path manipulation needed.**

### When to update renv.lock

```r
# After adding packages to DESCRIPTION
renv::snapshot()

# After removing packages from DESCRIPTION
renv::snapshot()

# To check what changed
renv::status()
```

### Known issues with pkgdown + Quarto

From official pkgdown documentation (as of 2025):
- Callouts not currently supported in Quarto vignettes
- Only HTML vignettes work (requires `minimal: true` in Quarto format)
- External files in vignettes/ may not be copied during rendering
- Mermaid diagrams require custom CSS instead of quarto themes

### Debugging tips

If vignettes fail to render:
```r
# Enable Quarto debugging
options(quarto.log.debug = TRUE)
pkgdown::build_site()
```

Check that all vignette dependencies are in DESCRIPTION Suggests and renv.lock.

### Debugging GitHub Actions failures: Lessons learned (2025-01-07)

**Context**: 10+ hour debugging session to fix "System command 'quarto' failed" error in GitHub Actions.

#### Start with minimal examples and successful patterns

**DON'T**: Try to debug complex failures in GitHub Actions directly
**DO**: Build from working examples (chmsflow, popcorn-data) and test locally first

**Minimal working workflow pattern**:

```yaml
name: pkgdown

on:
  push:
    branches: [main]  # Don't include feature branches - causes duplicate runs with PRs
  pull_request:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: write

jobs:
  pkgdown:
    runs-on: ubuntu-latest
    env:
      GITHUB_PAT: ${{ secrets.GITHUB_TOKEN }}

    steps:
      - uses: actions/checkout@v4
      - uses: r-lib/actions/setup-pandoc@v2
      - uses: r-lib/actions/setup-r@v2
        with:
          use-public-rspm: true

      - name: Install Quarto
        uses: quarto-dev/quarto-actions/setup@v2

      - name: Install roxygen2
        run: Rscript -e "install.packages('roxygen2')"

      - name: Generate documentation
        run: Rscript -e "roxygen2::roxygenize()"

      - uses: r-lib/actions/setup-r-dependencies@v2
        with:
          extra-packages: any::pkgdown, local::.
          needs: website

      # Debug step - render single vignette to isolate failures
      - name: Test render single vignette
        run: quarto render vignettes/getting-started.qmd --to html
        continue-on-error: true

      - name: Build pkgdown site
        run: |
          options(rlib_message_verbosity = "verbose")
          pkgdown::build_site_github_pages(new_process = FALSE, install = FALSE, quiet = FALSE)
        shell: Rscript {0}

      - name: Deploy to GitHub Pages
        if: github.event_name != 'pull_request'
        uses: JamesIves/github-pages-deploy-action@v4
        with:
          folder: docs
          branch: gh-pages
          target-folder: .
          clean: false
```

#### Critical debugging principles

1. **Make errors visible**
   - Set `quiet = FALSE` in `build_site_github_pages()`
   - Add `continue-on-error: true` test steps to see actual failures
   - Use `options(rlib_message_verbosity = "verbose")`

2. **Test incrementally**
   - Render one vignette at a time to isolate failures
   - Test locally first: `quarto render vignettes/example.qmd --to html`
   - Compare with working repos (chmsflow, popcorn-data)

3. **Environment differences matter**
   - **Locales**: `en_CA` works on macOS but NOT on Ubuntu GitHub Actions
   - **Solution**: Use `en_US.UTF-8` for cross-platform compatibility
   - **Example**: `lubridate::parse_date_time(..., locale = "en_US.UTF-8")`

4. **Avoid duplicate workflow runs**
   - **DON'T**: `push: branches: [main, feature-branch]`
   - **DO**: `push: branches: [main]`
   - **Why**: PRs already trigger on `pull_request` event

5. **Use r-lib actions for dependency management**
   - Prefer `r-lib/actions/setup-r-dependencies@v2` over manual renv
   - Let `setup-r-dependencies` handle dependency installation
   - **Always generate documentation first** with `roxygen2::roxygenize()`

#### Common pitfalls

1. **Generic error messages**: "System command 'quarto' failed" tells you nothing
   - **Fix**: Add `quiet = FALSE` to see actual errors

2. **Locale issues**: Hardcoded locales fail in CI/CD
   - **Fix**: Use `en_US.UTF-8` instead of `en_CA`

3. **Missing documentation**: pkgdown can't find topics if man/ files don't exist
   - **Fix**: Run `roxygen2::roxygenize()` before building site

4. **Vignette dependencies**: Packages used only in vignettes must be in DESCRIPTION
   - **Fix**: Add to Suggests field, then `renv::snapshot()`

#### Quick diagnostic checklist

When GitHub Actions fails:

- [ ] Test locally: `pkgdown::build_site()`
- [ ] Render vignettes individually: `quarto render vignettes/example.qmd --to html`
- [ ] Check for hardcoded locales (use `en_US.UTF-8`)
- [ ] Verify all vignette packages in DESCRIPTION Suggests
- [ ] Add `quiet = FALSE` to see actual error messages
- [ ] Compare workflow with working repos (chmsflow)
- [ ] Check for duplicate triggers (push + pull_request)

#### GitHub Pages deployment tips

**Start early**: Set up GitHub Pages deployment from the beginning, not as an afterthought.

**Multi-branch deployment pattern**:

```yaml
- name: Determine deployment path
  id: deploy-path
  run: |
    if [[ "${{ github.ref }}" == "refs/heads/main" ]]; then
      echo "target_path=." >> $GITHUB_OUTPUT
    elif [[ "${{ github.ref }}" == "refs/heads/dev" ]]; then
      echo "target_path=dev" >> $GITHUB_OUTPUT
    else
      echo "target_path=preview/${{ github.ref_name }}" >> $GITHUB_OUTPUT
    fi

- name: Deploy to GitHub Pages
  uses: JamesIves/github-pages-deploy-action@v4
  with:
    folder: docs
    branch: gh-pages
    target-folder: ${{ steps.deploy-path.outputs.target_path }}
    clean: false
```

**Result**:
- `main` → https://yoursite.github.io/repo/
- `dev` → https://yoursite.github.io/repo/dev/
- Other branches → https://yoursite.github.io/repo/preview/branch-name/

### References

- [pkgdown Quarto vignettes documentation](https://pkgdown.r-lib.org/articles/quarto.html)
- [renv CI/CD guide](https://rstudio.github.io/renv/articles/ci.html)
- [Quarto with renv discussion](https://github.com/quarto-dev/quarto-cli/discussions/9150)
- [r-lib/actions GitHub repository](https://github.com/r-lib/actions)
