# Extracted from test_ui_v7p0.R:9

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "gcamreport", path = "..")
attach(test_env, warn.conflicts = FALSE)

# prequel ----------------------------------------------------------------------
library(gcamreport)
library(testthat)
library(magrittr)

# test -------------------------------------------------------------------------
GCAM_version <<- 'v7.0'
generate_report(prj_name = file.path(rprojroot::find_root(rprojroot::is_testthat), "testInputs/v_7.0/test7.dat"),
                  desired_variables = c('Agricultural Demand*','Forestry*','Trade*'), inverse_desired_variables = T,
                  launch_ui = FALSE, GCAM_version = "v7.0")
