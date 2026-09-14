# Tests

This folder contains the automated tests for the `gcamreport` R package.

The tests answer a simple question:

> Does `gcamreport` still produce the right result when the code changes?

They use small GCAM projects and saved expected results. This makes the tests repeatable and helps us find mistakes before they reach users.

## 1. What is testthat?

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

## 2. How the tests are organized

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

## 3. How files are triggered

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

## A typical test flow

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

## Running one test file

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

Run the command from the `gcamreport-fork` package root. The tests use the package root to find `testInputs/` and `testOutputs/`.

## Important detail about order

The test files are discovered by testthat. A test should ideally work on its own and should not depend on another test having run first.

Some UI tests intentionally create shared values such as `report`, `sdata`, and `GCAM_version` because several checks use the same prepared data. When changing these tests, be careful about shared state and clean it up when needed.

When a test fails, first look at:

1. the name of the failed `test_that()` block;
2. the `expect_*()` call that failed;
3. the input file used by the test;
4. the expected file in `testOutputs/`;
5. the `gcamreport` function called by the test.
