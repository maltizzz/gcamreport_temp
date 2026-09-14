# Testing `gcamreport`

This directory contains the automated tests for the `gcamreport` R package and the validation workflow for GCAM v9.1.

## At a glance

| Goal | Recommended command |
| --- | --- |
| Run the full automated suite | `devtools::test()` |
| Run one test file | `testthat::test_file("tests/testthat/test_reporter_v7p0.R")` |
| Run tests matching a name | `devtools::test(filter = "v7p0")` |
| Validate a real GCAM v9.1 database | Run the R workflow in [GCAM v9.1 validation](#gcam-v91-validation) |

The automated suite uses small, versioned fixtures and saved expected results.
The v9.1 workflow uses a real GCAM output database and is described in
[GCAM v9.1 validation](#gcam-v91-validation).

## Contents

- [Test concepts](#test-concepts)
- [Repository layout](#repository-layout)
- [Running the automated tests](#running-the-automated-tests)
- [Test flow](#test-flow)
- [GCAM v9.1 validation](#gcam-v91-validation)
- [Troubleshooting](#troubleshooting)
- [Final checklist](#final-checklist)

The tests answer a simple question:

> Does `gcamreport` still produce the right result when the code changes?

They use small GCAM projects and saved expected results. This makes the tests repeatable and helps us find mistakes before they reach users.

## Test concepts

[`testthat`](https://testthat.r-lib.org/) is an R package for writing and running tests.

A test usually has three parts:

1. **Arrange**: prepare input data or load a small test project.
2. **Act**: call a `gcamreport` function.
3. **Check**: compare the result with what we expect.

For example:

```r
test_that("a number is added correctly", {
  result <- 1 + 1
  expect_equal(result, 2)
})
```

`test_that()` gives the test a name. `expect_equal()` checks that two values are the same. Other common checks include:

- `expect_true()` checks that something is true.
- `expect_false()` checks that something is false.
- `expect_error()` checks that code gives the expected error.
- `expect_null()` checks that a value is `NULL`.

If an expectation is correct, the test passes. If it is not correct, testthat reports the test name, the expected value, and the value that was actually returned.

This package uses **testthat edition 3**, as set in `DESCRIPTION`:

```text
Config/testthat/edition: 3
```

## Repository layout

The important structure is:

```text
tests/
├── README.md
├── testthat.R
└── testthat/
    ├── test_reporter_hist.R
    ├── test_reporter_v7p0.R
    ├── test_reporter_v8p2.R
    ├── test_reporter_vScenarioMIPCMIP7.R
    ├── test_ui_v7p0.R
    ├── inst/
    ├── testInputs/
    └── testOutputs/
```

### `tests/README.md`

This document. It explains the test system and the role of each file and folder.

### `tests/testthat.R`

This is the package-level entry point used by package checking tools such as `R CMD check`.

It does three things:

1. Loads `testthat`.
2. Loads the `gcamreport` package.
3. Calls `test_check("gcamreport")`.

`test_check()` tells testthat to find and run the tests belonging to the `gcamreport` package.

This file is intentionally very small. Test setup and test code belong in `tests/testthat/`.

## Test source files

All files below are R scripts. testthat finds them because their names start with `test` and end with `.R`.

### `test_reporter_v7p0.R`

Tests the main reporting workflow for GCAM version 7.0. It checks things such as:

- loading a GCAM project with `load_project()`;
- creating CSV and Excel output with `generate_report()`;
- selecting variables, regions, and continents;
- returning the expected variables and regions;
- reporting the correct model name;
- giving useful errors for missing or invalid variables, regions, scenarios, and parameters.

This is the broadest version-specific reporter test file.

### `test_reporter_v8p2.R`

Tests the `inverse_desired_variables` option for GCAM version 8.2.

It runs `generate_report()` with groups of variables that should be excluded. The test checks that excluded variables do not appear in the final report.

### `test_reporter_vScenarioMIPCMIP7.R`

Tests reporting for the ScenarioMIP/CMIP7 GCAM format.

It creates a report using all requested variables, then compares the returned data with the saved expected report in `testOutputs/v_ScenarioMIPCMIP7/test_report.RData`.

### `test_reporter_hist.R`

Checks historical values for every GCAM version listed in `gcamreport::available_GCAM_versions`.

For each version, it:

1. Chooses the matching small GCAM project from `testInputs/`.
2. Runs `generate_report()`.
3. Loads the matching historical reference data from `testOutputs/historical_data/`.
4. Checks that the newly produced values are inside the expected range.

This test is useful when a code change might alter historical data for one or more GCAM versions.

### `test_ui_v7p0.R`

Tests helper functions used by the user interface, using GCAM version 7.0 test data.

It checks functions for:

- creating and removing variable and region trees;
- collapsing data frames;
- changing styles;
- checking user selections for plots;
- sampling data for a plot;
- calculating UI heights;
- resetting UI state;
- returning expected UI error messages;
- rejecting invalid arguments to `launch_gcamreport_ui()`.

## Test data folders

### `testInputs/`

Contains the inputs used by tests. These include:

- small GCAM project files such as `.dat` files;
- saved `.RData` objects used as function inputs;
- saved UI selections, trees, and sample data.

The folders such as `v_7.0`, `v_7.1`, `v_8.2`, and `v_9.1` group inputs by GCAM version. The ScenarioMIP input has its own folder, `v_ScenarioMIPCMIP7`.

Test scripts read these files instead of depending on a user's personal GCAM installation or personal data files.

### `testOutputs/`

Contains expected results. These are the answers that the tests compare against.

The main groups are:

- `historical_data/`: reference ranges for historical reporter values;
- `v_7.0/`: expected reporter and UI results for GCAM 7.0;
- `v_7.1/`: expected reporter and UI results for GCAM 7.1;
- `v_ScenarioMIPCMIP7/`: the expected ScenarioMIP/CMIP7 report.

File types have different uses:

- `.RData` stores R objects, such as data frames and lists;
- `.csv` stores expected comma-separated output;
- `.xlsx` stores expected Excel output;
- `.xml` stores expected XML output.

A test normally creates a new result, loads the matching saved result, and compares the two.

### `inst/`

Contains test-only package data that can be installed with the test package. In this repository it contains example mapping files under:

```text
inst/extdata/mappings/GCAM7.0/
inst/extdata/mappings/GCAM7.1/
```

These files are supporting data for tests or package behavior. They are not test scripts, so testthat does not run them directly.

### `.Rhistory`

A history file created by an interactive R session. It is not part of the test flow and is not executed by testthat.

## Running the automated tests

There are two common ways to start the tests.

### During development: `devtools::test()`

From the package root, run:

```r
devtools::test()
```

The flow is:

```text
devtools::test()
        |
        v
Find the gcamreport package
        |
        v
Find test files in tests/testthat/
        |
        v
Load gcamreport and testthat
        |
        v
Run each test_that(...) block
        |
        v
Read files from testInputs/ and testOutputs/ when a test asks for them
        |
        v
Print passed, failed, skipped, or errored tests
```

`devtools::test()` is the easiest command while developing. It is also the command used by this repository's build workflow.

### During package checking: `R CMD check`

When R checks the package, it starts with:

```text
R CMD check
    |
    v
tests/testthat.R
    |
    v
library(testthat)
library(gcamreport)
    |
    v
test_check("gcamreport")
    |
    v
Run the test files in tests/testthat/
```

In other words, `testthat.R` is the doorway into the test suite during package checking. The individual `test_*.R` files contain the actual tests.

## Test flow

For a reporter test, the work usually looks like this:

```text
1. testthat starts a test_that(...) block.
2. The test finds the package root with rprojroot.
3. The test loads a small project from testInputs/.
4. The test calls a gcamreport function, often generate_report().
5. gcamreport creates a result in memory or writes an output file.
6. The test loads an expected result from testOutputs/.
7. An expect_*() function compares actual and expected values.
8. testthat records the result and moves to the next test.
```

A test file may contain several `test_that()` blocks. Each block tests one related behavior. testthat reports the block name when something fails.

### Run a specific test file

To run the complete suite:

```r
devtools::test()
```

To run only one file:

```r
testthat::test_file("tests/testthat/test_reporter_v7p0.R")
```

To run only tests whose names match a pattern:

```r
devtools::test(filter = "v7p0")
```

Run the command from the package root. The tests use the package root to find `testInputs/` and `testOutputs/`.

### Test isolation and failure diagnosis

The test files are discovered by testthat. A test should ideally work on its own and should not depend on another test having run first.

Some UI tests intentionally create shared values such as `report`, `sdata`, and `GCAM_version` because several checks use the same prepared data. When changing these tests, be careful about shared state and clean it up when needed.

When a test fails, first look at:

1. the name of the failed `test_that()` block;
2. the `expect_*()` call that failed;
3. the input file used by the test;
4. the expected file in `testOutputs/`;
5. the `gcamreport` function called by the test.


## GCAM v9.1 validation

The automated tests do not currently contain a small GCAM v9.1 fixture. A
successful automated test run therefore does not by itself prove that a full
GCAM v9.1 report works.

### Before you start

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
cd path\to\gcamreport-integrated\<package-root>
```

The directory must contain the package `DESCRIPTION` file.

### Run the automated suite from different environments

#### Option A: Run all tests from R

Open R or RStudio and run:

```r
setwd("path/to/gcamreport-integrated/<package-root>")

devtools::test()
```

`devtools::test()` loads the local package and runs the files in
`tests/testthat/`.

#### Option B: Run all tests from PowerShell

```powershell
Rscript -e "devtools::test('path/to/gcamreport-integrated/<package-root>')"
```

#### Option C: Run the test runner directly

The file [`testthat.R`](testthat.R) is the standard testthat entry point. Run
it with:

```powershell
Rscript -e "testthat::test_dir('tests/testthat')"
```

Use `devtools::test()` in most cases because it loads the package in the same
way that package development normally does.

### Automated test coverage

The current test files cover these areas:

- `test_reporter_v7p0.R`: report generation using GCAM v7.0 test data
- `test_reporter_v8p2.R`: report generation using GCAM v8.2 test data
- `test_reporter_hist.R`: historical-data reporting
- `test_reporter_vScenarioMIPCMIP7.R`: ScenarioMIP and CMIP7 reporting
- `test_ui_v7p0.R`: user-interface behavior using the v7.0 test data

A passing test run should finish without `FAIL`, `ERROR`, or unexpected warning
messages. Warnings that are explicitly expected by a test are normally reported
as expected results.

### Check the GCAM v9.1 package data

Before running a full report, check that the v9.1 package data is present:

```r
setwd("path/to/gcamreport-integrated/<package-root>")

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

### Prepare a GCAM v9.1 validation run

You need a real GCAM v9.1 output directory. It should contain the BaseX output
database, normally named `database_basexdb`.

A convenient layout is:

```text
<package-root>/
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

### Run the full GCAM v9.1 report check

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

The validation workflow is documented as R code above. This checkout does not
include a separate `validate_v9.1.R` runner script.

### Check the validation result

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

### Check the v9.1 Shiny UI

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

## Troubleshooting

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

## Final checklist

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
- [ ] The testthat suite passes after the validation run.
- [ ] The v9.1 Shiny UI launches successfully.

A test is complete only after the result is checked. A command that runs without
an error is useful, but it is not enough to prove that every v9.1 mapping works.
