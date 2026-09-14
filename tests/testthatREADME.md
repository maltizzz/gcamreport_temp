# How to test `gcamreport`

This document explains how to run the tests for the local `gcamreport` R
package. It also explains how to check the GCAM v9.1 support.

There are two types of checks:

1. **Automated tests**: quick tests that use the test files already in this
   repository.
2. **GCAM v9.1 validation**: a larger real-data test that uses a GCAM v9.1
   output database.

The automated tests do not currently contain a small GCAM v9.1 test fixture.
Therefore, a successful automated test run does not by itself prove that a full
GCAM v9.1 report works.

## 1. Before you start

Install these programs first:

- R 4.x
- RStudio or VS Code with the R extension
- Git
- A working GCAM installation or a GCAM release package for full validation

Install the R package dependencies from an R console:

```r
install.packages(c(
  "devtools", "testthat", "readr", "dplyr", "tibble", "tidyr",
  "ggplot2", "stringr", "here", "xml2", "shiny", "shinydashboard",
  "shinyjs", "shinyWidgets", "writexl", "readxl", "rrapply",
  "markdown", "rlang", "magrittr", "usethis", "rprojroot", "rmarkdown"
))

remotes::install_github("JGCRI/rgcam")
remotes::install_github("JGCRI/rpackageutils")
```

From PowerShell, move into the package directory:

```powershell
cd path\to\gcamreport-integrated\gcamreport-fork
```

The directory must contain the package `DESCRIPTION` file.

## 2. Run the normal automated tests

### Option A: Run all tests from R

Open R or RStudio and run:

```r
setwd("path/to/gcamreport-integrated/gcamreport-fork")

devtools::test()
```

`devtools::test()` loads the local package and runs the files in
`tests/testthat/`.

### Option B: Run all tests from PowerShell

```powershell
Rscript -e "devtools::test('path/to/gcamreport-integrated/gcamreport-fork')"
```

### Option C: Run the test runner directly

The file [`testthat.R`](testthat.R) is the standard testthat entry point. Run
it with:

```powershell
Rscript -e "testthat::test_dir('tests/testthat')"
```

Use `devtools::test()` in most cases because it loads the package in the same
way that package development normally does.

## 3. What the automated tests cover

The current test files cover these areas:

- `test_reporter_v7p0.R`: report generation using GCAM v7.0 test data
- `test_reporter_v8p2.R`: report generation using GCAM v8.2 test data
- `test_reporter_hist.R`: historical-data reporting
- `test_reporter_vScenarioMIPCMIP7.R`: ScenarioMIP and CMIP7 reporting
- `test_ui_v7p0.R`: user-interface behavior using the v7.0 test data

A passing test run should finish without `FAIL`, `ERROR`, or unexpected warning
messages. Warnings that are explicitly expected by a test are normally reported
as expected results.

## 4. Check the GCAM v9.1 package data

Before running a full report, check that the v9.1 package data is present:

```r
setwd("path/to/gcamreport-integrated/gcamreport-fork")

stopifnot(dir.exists("inst/extdata/mappings/GCAM9.1"))
stopifnot(dir.exists("inst/extdata/template/GCAM9.1"))
stopifnot(file.exists("inst/extdata/saveDataFiles_GCAM9.1.R"))
```

There is no separate `inst/extdata/queries/GCAM9.1` directory in this
checkout. The v9.1 run uses the existing query definitions and the v9.1
mapping/template data.

The package also needs to have v9.1 in its supported-version lists. You can
check this after loading the package:

```r
devtools::load_all(".")

# These should include "v9.1".
print(available_GCAM_versions)
print(deciles_GCAM_versions)
```

If `v9.1` is missing, stop here and fix the package data/version configuration
before testing a report.

## 5. Prepare a GCAM v9.1 validation run

You need a real GCAM v9.1 output directory. It should contain the BaseX output
database, normally named `database_basexdb`.

A convenient layout is:

```text
gcamreport-fork/
  gcam-v9.1-Windows-Release-Package/
    output/
      database_basexdb/
```

If your GCAM release package is somewhere else, use its full path in
`db_path` below.

The validation should use:

- `GCAM_version = "v9.1"`
- A GCAM v9.1 output database
- `desired_regions = "All"`
- `desired_variables = "All"`
- A final year such as `2050`
- A scenario that exists in the database, usually `Reference`

Use all regions for the main validation. A USA-only run can fail at the
 district-heat query when that region has no district-heat rows. That is a
known single-region limitation and does not necessarily indicate a v9.1 error.

## 6. Run the full GCAM v9.1 report check

From the package root, load the local package and run:

```r
library(devtools)
load_all(".")

version <- "v9.1"
db_path <- "./gcam-v9.1-Windows-Release-Package/output"
project_file <- "gcam_v9.1_report.dat"

if (file.exists(project_file)) {
  file.remove(project_file)
}

gcamreport::generate_report(
  db_path = db_path,
  db_name = "database_basexdb",
  prj_name = project_file,
  scenarios = "Reference",
  final_year = 2050,
  desired_regions = "All",
  desired_variables = "All",
  GCAM_version = version,
  launch_ui = FALSE,
  save_output = TRUE
)
```

This run can take several minutes or longer because it reads the complete
GCAM output database.

You can also run the same validation from PowerShell with the included script:

```powershell
Rscript tests/validate_v9.1.R
```

By default, the script expects the GCAM package at
`gcam-v9.1-Windows-Release-Package/output` below the package root. To use a
different database location:

```powershell
Rscript tests/validate_v9.1.R `
  --db-path="C:/path/to/gcam-v9.1-Windows-Release-Package/output"
```

The script checks the v9.1 package data, runs an all-region/all-variable
report, loads the generated `.RData` file, checks the standardized columns and
final year, and stops with an error if numeric `NA` or `Inf` values are found.
Add `--run-testthat` to run the package's existing automated tests after the
v9.1 report check:

```powershell
Rscript tests/validate_v9.1.R --run-testthat
```

Add `--launch-ui` to open the Shiny UI after a successful validation:

```powershell
Rscript tests/validate_v9.1.R --launch-ui
```

## 7. Check the validation result

After the report finishes, check the returned object or saved output. At a
minimum, confirm that:

```r
# Replace `report` with the object name returned by your local workflow.
summary(report)
anyNA(report)
any(is.infinite(as.matrix(report)))
```

The expected checks are:

- The report completes without a strict-join error.
- The result contains data for all requested regions.
- The result contains data for the requested scenario and years.
- There are no unexpected `NA` or `Inf` values.
- The model/version information identifies GCAM 9.1.
- The output includes the expected energy, emissions, price, water, and land
  variables.

In the validated run for this repository, the result had approximately 88,739
rows, 15 columns, 33 regions, and 2,847 variables, with no `NA` or `Inf`
values. Exact row counts can change if the input database changes.

## 8. Check the v9.1 Shiny UI

If the full report succeeds and a standardized `.RData` file was created, load
the package and launch the UI with the v9.1 version:

```r
library(devtools)
load_all(".")

assign("GCAM_version", "v9.1", envir = .GlobalEnv)

launch_gcamreport_ui(
  data_path = "./gcam-v9.1-Windows-Release-Package/output/gcam_v9.1_report_standardized.RData",
  GCAM_version = "v9.1"
)
```

A successful launch should open the Shiny page without an
`object 'GCAM_version' not found` error. If the UI is started from a script,
set `GCAM_version` before calling `launch_gcamreport_ui()`.

## 9. How to understand a failure

### `The query is unavailable`

Check these items first:

1. The database path points to the GCAM v9.1 `output` directory.
2. The database name is `database_basexdb`.
3. The requested scenario exists.
4. The requested region is present.
5. You are not using a USA-only test for a variable that has no USA rows.

### `left_join_strict` or missing mapping errors

This usually means GCAM produced a sector, technology, market, or commodity name
that is missing from a v9.1 mapping CSV. Record the exact missing value and add
the appropriate mapping row under:

```text
inst/extdata/mappings/GCAM9.1/
```

Then rebuild the package data and run the full-region validation again.

### `object 'GCAM_version' not found`

Set the version in the global environment before launching the UI:

```r
assign("GCAM_version", "v9.1", envir = .GlobalEnv)
```

### `non-numeric argument to binary operator`

Check the CSV that was recently edited. A missing newline between appended CSV
rows can make a numeric column become text. Reopen the file and confirm that
each row starts on its own line.

## 10. Final checklist

Before saying that GCAM v9.1 support is working, confirm all of these:

- [ ] The package loads with `devtools::load_all(".")`.
- [ ] `v9.1` is present in the supported-version lists.
- [ ] The GCAM v9.1 mapping and template directories exist; the existing query
  definitions are available.
- [ ] The normal `devtools::test()` suite passes.
- [ ] A full-region, all-variable v9.1 report completes.
- [ ] The generated report has the expected standardized columns and final year.
- [ ] No unexpected `NA` or `Inf` values are present.
- [ ] The result identifies the model as GCAM 9.1.
- [ ] The testthat suite passes (`--run-testthat`).
- [ ] The v9.1 Shiny UI launches successfully.

A test is complete only after the result is checked. A command that runs without
an error is useful, but it is not enough to prove that every v9.1 mapping works.
