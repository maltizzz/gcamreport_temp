setwd("C:/Users/pjhan/Desktop/git/iam_models/GCAM/gcamreport_temp")

devtools::load_all(".", reset = TRUE)

source("inst/extdata/saveDataFiles_constants.R")
source("inst/extdata/saveDataFiles_GCAM9.1.R")

available_GCAM_versions()
"v9.1" %in% available_GCAM_versions

available_regions(
  print = FALSE,
  GCAM_version = "v9.1"
)

available_variables(
  print = FALSE,
  GCAM_version = "v9.1"
)

exists("reg_cont_v9.1", envir = asNamespace("gcamreport")) # asNamespace() is needed to access the internal data of the package, it is "gcamreport" in this case because the package name is "gcamreport"
exists("template_v9.1", envir = asNamespace("gcamreport"))
exists("var_fun_map_v9.1", envir = asNamespace("gcamreport"))
exists("queries_general_v9.1", envir = asNamespace("gcamreport"))
