# Extracted from test_reporter_vScenarioMIPCMIP7.R:13

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "gcamreport", path = "..")
attach(test_env, warn.conflicts = FALSE)

# prequel ----------------------------------------------------------------------
library(gcamreport)
library(testthat)
library(magrittr)

# test -------------------------------------------------------------------------
GCAMv = 'vScenarioMIPCMIP7'
generate_report(prj_name = file.path(rprojroot::find_root(rprojroot::is_testthat), "testInputs/v_ScenarioMIPCMIP7/db_exp_scenarioMIPcmip7.dat"),
                            desired_variables = 'All',
                            launch_ui = FALSE, GCAM_version = GCAMv, save_output = FALSE,
                            ignore = c('bio-ceiling','coal-elec-constraint',
                                       'CO2_NearTerm','wind_offshore-trial-supply',
                                       'CO2_LTG','globalCO2_LTG','enh_wew_ceiling'))
