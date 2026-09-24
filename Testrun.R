# Execute the local gcamreport package and load v8.2 or v9.1 data before launching the UI.
gcamreport_run <- function(
  test_ = FALSE,
  gcamreport_version_ = "v8.2",
  gcam_file_version_ = "v8.2",
  db_path_ = paste0("C:/Users/pjhan/Desktop/GCAM/gcam-v", sub("^v", "", gcam_file_version_), "-Windows-Release-Package/output"),
  db_name_ = "database_basexdb",
  prj_name_ = paste0("gcam_v", sub("^v", "", gcam_file_version_), "_report.dat"),
  scen_ = "Reference",
  desired_regions_ = "All",
  run_type_ = "ui",
  Rdata_path_ = paste0(db_path_, "/", "gcam_v", sub("^v", "", gcam_file_version_), "_report_standardized.RData")
) {
  # Work in the package root so devtools::load_all() can find DESCRIPTION.
  if (isTRUE(test_)) {
    setwd("C:/Users/pjhan/Desktop/git/iam_models/GCAM/gcamreport-integrated/gcamreport-temp")
  } else {
    setwd("C:/Users/pjhan/Desktop/git/iam_models/GCAM/gcamreport-integrated/gcamreport")
  }

  devtools::load_all(".", reset = TRUE)

  # Normalize the version string for the package internals.
  resolved_GCAM_report_version <- if (grepl("^v", gcamreport_version_)) gcamreport_version_ else paste0("v", gcamreport_version_)

  # Some UI bootstrap code reads GCAM_version from the global environment.
  assign("GCAM_version", resolved_GCAM_report_version, envir = .GlobalEnv)

  # Avoid reusing a stale empty project file from an earlier run.
  if (file.exists(prj_name_)) {
    file.remove(prj_name_)
  }

  # Generate a report
  if (run_type_ == "report") {
    generate_report(
      db_path = db_path_,
      db_name = db_name_,
      prj_name = prj_name_,
      scenarios = scen_,
      final_year = 2050,
      launch_ui = TRUE,
      save_output = TRUE,
      desired_regions = desired_regions_,
      desired_variables = "All",
      GCAM_version = resolved_GCAM_report_version
    )
    return(invisible(TRUE))
  }

  # Launch the UI using a standardized .RData object.
  if (run_type_ == "ui") {
    launch_gcamreport_ui(
      data_path = Rdata_path_,
      GCAM_version = resolved_GCAM_report_version
    )
    return(invisible(TRUE))
  }

  stop("run_type_ must be one of: 'report' or 'ui'.")
}

##################### TEST ####################################
## 1) Run if "official" & "Test" version of gcamreport can run 8.2 [Succeed]
#gcamreport_run(test_ = TRUE, gcamreport_version_ = "v8.2", gcam_file_version_ = "v8.2", run_type_ = "ui")
#gcamreport_run(test_ = TRUE, gcamreport_version_ = "v9.1", gcam_file_version_ = "v9.1", run_type_ = "ui")


## 2) Test report generation for v9.1 [Succeed]
gcamreport_run(test_ = TRUE, gcamreport_version_ = "v9.1", gcam_file_version_ = "v9.1", run_type_ = "report")
gcamreport_run(test_ = TRUE, gcamreport_version_ = "v9.1", gcam_file_version_ = "v9.1", run_type_ = "ui")
