# Extracted from test_reporter_v7p0.R:476

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "gcamreport", path = "..")
attach(test_env, warn.conflicts = FALSE)

# prequel ----------------------------------------------------------------------
library(gcamreport)
library(testthat)
library(magrittr)

# test -------------------------------------------------------------------------
generate_report(
    prj_name = file.path(rprojroot::find_root(rprojroot::is_testthat), "testInputs/v_7.0/test7.dat"),
    final_year = 2050,
    scenarios = "Reference",
    desired_variables = "Emissions*",
    launch_ui = FALSE,
    GWP_version = 'AR4',
    GCAM_version = 'v7.0'
  )
testExpect <- get(load(file.path(rprojroot::find_root(rprojroot::is_testthat), "testOutputs/v_7.0/result_test14.1.RData")))
testthat::expect_equal(report, testExpect)
rm(list = ls())
generate_report(
    prj_name = file.path(rprojroot::find_root(rprojroot::is_testthat), "testInputs/v_7.0/test7.dat"),
    final_year = 2050,
    scenarios = "Reference",
    desired_variables = "Emissions*",
    launch_ui = FALSE,
    GWP_version = 'AR5',
    GCAM_version = 'v7.0'
  )
testExpect <- get(load(file.path(rprojroot::find_root(rprojroot::is_testthat), "testOutputs/v_7.0/result_test14.2.RData")))
testthat::expect_equal(report, testExpect)
rm(list = ls())
generate_report(
    prj_name = file.path(rprojroot::find_root(rprojroot::is_testthat), "testInputs/v_7.0/test7.dat"),
    final_year = 2050,
    scenarios = "Reference",
    desired_variables = "Emissions*",
    launch_ui = FALSE,
    GWP_version = 'AR6',
    GCAM_version = 'v7.0'
  )
testExpect <- get(load(file.path(rprojroot::find_root(rprojroot::is_testthat), "testOutputs/v_7.0/result_test14.3.RData")))
testthat::expect_equal(report, testExpect)
expect_error(
    generate_report(
      db_path = file.path(rprojroot::find_root(rprojroot::is_testthat), "testInputs/v_7.0/"),
      db_name = "database_basexdb_ref",
      prj_name = "gcamv7.8_noCreated.dat",
      scenarios = "Reference",
      desired_variables = c("dummy1", "dummy2"),
      launch_ui = FALSE,
      GWP_version = 4,
      GCAM_version = 'v7.0'
    ),
    "GWP_version must be a character string, but you provided a value of type 'numeric'. Please specify the GWP_version as a string, e.g., GWP_version = 'AR5'."
  )
expect_error(
    generate_report(
      db_path = file.path(rprojroot::find_root(rprojroot::is_testthat), "testInputs/v_7.0/"),
      db_name = "database_basexdb_ref",
      prj_name = "gcamv7.8_noCreated.dat",
      scenarios = "Reference",
      desired_variables = c("dummy1", "dummy2"),
      launch_ui = FALSE,
      GWP_version = '4',
      GCAM_version = 'v7.0'
    ),
    "Invalid GWP_version '4'. Available versions are: AR4, AR5, AR6. Please choose one of these versions."
  )
expect_error(
    generate_report(
      db_path = file.path(rprojroot::find_root(rprojroot::is_testthat), "testInputs/v_7.0/"),
      db_name = "database_basexdb_ref",
      prj_name = "gcamv7.8_noCreated.dat",
      scenarios = "Reference",
      desired_variables = c("dummy1", "dummy2"),
      launch_ui = FALSE,
      GCAM_version = 4
    ),
    "Invalid GCAM_version '4'. Available versions are: v7.0, v7.1, v7.2, v8.2, vScenarioMIPCMIP7, vEurope7.2, vEurope8.7. Please choose one of these versions."
  )
