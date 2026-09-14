# Extracted from test_reporter_v8p2.R:18

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "gcamreport", path = "..")
attach(test_env, warn.conflicts = FALSE)

# prequel ----------------------------------------------------------------------
library(gcamreport)
library(testthat)
library(magrittr)

# test -------------------------------------------------------------------------
GCAMv = 'v8.2'
list_all_vars <- gcamreport::available_variables(print = F, GCAM_version = GCAMv)
list_header_vars <- paste0(unique(sub("\\|.*", "", list_all_vars)),'*')[c(1,10,20,30,40)]
for (missing_var in list_header_vars) {
    print(missing_var)
    generate_report(prj_name = file.path(rprojroot::find_root(rprojroot::is_testthat), "testInputs/v_8.2/gcamreport_onboard8p2_Ctax_260210.dat"),
                    desired_variables = c('Investment*',missing_var), inverse_desired_variables = TRUE,
                    launch_ui = FALSE, GCAM_version = GCAMv, save_output = FALSE,
                    ignore = c('bio-ceiling','coal-elec-constraint',
                                'CO2_NearTerm','wind_offshore-trial-supply',
                                'CO2_LTG','globalCO2_LTG'))

    testthat::expect_equal(sum(grepl(paste0("^", missing_var), unique(report$Variable))), 0)
    rm(list = setdiff(ls(), c('GCAMv', 'list_header_vars')))
    gc()
  }
