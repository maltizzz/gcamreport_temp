#!/usr/bin/env Rscript

# Full-data validation for GCAM v9.1 support.
# Run from PowerShell:
#   Rscript tests/validate_v9.1.R
# Or provide a database path:
#   Rscript tests/validate_v9.1.R --db-path="C:/path/to/output"
# Add --run-testthat to run the package testthat suite after report validation.
# Add --launch-ui after a successful report to start the Shiny app.

options(warn = 1)

script_path <- commandArgs(trailingOnly = FALSE)
script_path <- sub("^--file=", "", script_path[grepl("^--file=", script_path)])
if (length(script_path) == 0 || !nzchar(script_path[[1]])) {
  script_path <- file.path(getwd(), "tests", "validate_v9.1.R")
}

package_root <- normalizePath(file.path(dirname(script_path[[1]]), ".."), winslash = "/")
setwd(package_root)

parse_arguments <- function(arguments) {
  values <- list(launch_ui = FALSE, `run-testthat` = FALSE)
  for (argument in arguments) {
    if (identical(argument, "--launch-ui")) {
      values$launch_ui <- TRUE
    } else if (identical(argument, "--run-testthat")) {
      values$`run-testthat` <- TRUE
    } else if (grepl("^--[^=]+=", argument)) {
      key <- sub("^--([^=]+)=.*$", "\\1", argument)
      value <- sub("^--[^=]+=", "", argument)
      values[[key]] <- value
    } else {
      stop("Unknown argument: ", argument)
    }
  }
  values
}

`%||%` <- function(value, fallback) {
  if (is.null(value) || !nzchar(value)) fallback else value
}

arguments <- parse_arguments(commandArgs(trailingOnly = TRUE))
db_path <- arguments[["db-path"]] %||% file.path(package_root, "gcam-v9.1-Windows-Release-Package", "output")
db_name <- arguments[["db-name"]] %||% "database_basexdb"
scenario <- arguments[["scenario"]] %||% "Reference"
final_year <- as.numeric(arguments[["final-year"]] %||% "2050")
output_prefix <- arguments[["output"]] %||% file.path(db_path, "gcam_v9.1_validation")

fail <- function(message) {
  stop(paste0("v9.1 validation failed: ", message), call. = FALSE)
}

if (!dir.exists(file.path(package_root, "inst", "extdata", "mappings", "GCAM9.1"))) {
  fail("GCAM9.1 mapping directory is missing")
}
if (!dir.exists(file.path(package_root, "inst", "extdata", "template", "GCAM9.1"))) {
  fail("GCAM9.1 template directory is missing")
}
if (!file.exists(file.path(package_root, "inst", "extdata", "saveDataFiles_GCAM9.1.R"))) {
  fail("saveDataFiles_GCAM9.1.R is missing")
}
if (!dir.exists(db_path)) {
  fail(paste0("database directory does not exist: ", db_path))
}
if (!file.exists(file.path(db_path, db_name))) {
  fail(paste0("database was not found: ", file.path(db_path, db_name)))
}
if (!is.finite(final_year)) {
  fail("final-year must be numeric")
}

if (!requireNamespace("devtools", quietly = TRUE)) {
  fail("the devtools package is not installed")
}

message("Loading local package from: ", package_root)
devtools::load_all(package_root, reset = TRUE, quiet = TRUE)

available_versions <- get("available_GCAM_versions", envir = asNamespace("gcamreport"))
if (!"v9.1" %in% available_versions) {
  fail("v9.1 is not in available_GCAM_versions")
}

output_prefix <- normalizePath(output_prefix, winslash = "/", mustWork = FALSE)
output_rdata <- paste0(output_prefix, ".RData")
project_file <- file.path(db_path, "gcam_v9.1_validation.dat")

if (file.exists(project_file)) {
  file.remove(project_file)
}
if (file.exists(output_rdata)) {
  file.remove(output_rdata)
}

message("Running full-region GCAM v9.1 report validation...")
gcamreport::generate_report(
  db_path = db_path,
  db_name = db_name,
  prj_name = project_file,
  scenarios = scenario,
  final_year = final_year,
  desired_regions = "All",
  desired_variables = "All",
  GCAM_version = "v9.1",
  launch_ui = FALSE,
  save_output = FALSE,
  output_file = output_prefix
)

if (!file.exists(output_rdata)) {
  fail(paste0("expected report output was not created: ", output_rdata))
}

saved_objects <- load(output_rdata)
if (length(saved_objects) != 1L) {
  fail(paste0("expected one saved report object, found ", length(saved_objects)))
}
report <- get(saved_objects[[1]], envir = .GlobalEnv)
if (!is.data.frame(report)) {
  fail("saved report is not a data frame")
}

required_columns <- c("Model", "Region", "Variable", "Unit")
missing_columns <- setdiff(required_columns, names(report))
if (length(missing_columns) > 0L) {
  fail(paste0("report is missing required columns: ", paste(missing_columns, collapse = ", ")))
}
if (nrow(report) == 0L || length(unique(report$Region)) == 0L) {
  fail("report contains no region data")
}
if (length(unique(report$Variable)) == 0L) {
  fail("report contains no variables")
}
if (!as.character(final_year) %in% names(report)) {
  fail(paste0("report does not contain the requested final year: ", final_year))
}
if (all(is.na(report[[as.character(final_year)]]))) {
  fail(paste0("all values for the requested final year are missing: ", final_year))
}

numeric_values <- report[vapply(report, is.numeric, logical(1))]
na_count <- sum(vapply(numeric_values, function(column) sum(is.na(column)), numeric(1)))
inf_count <- sum(vapply(numeric_values, function(column) sum(is.infinite(column)), numeric(1)))
if (na_count > 0L) {
  fail(paste0("report contains ", na_count, " missing numeric values"))
}
if (inf_count > 0L) {
  fail(paste0("report contains ", inf_count, " infinite numeric values"))
}
if ("Model" %in% names(report) && !any(grepl("GCAM 9\\.1", report$Model, fixed = FALSE))) {
  fail("Model column does not identify GCAM 9.1")
}

message("GCAM v9.1 validation passed")
message("Rows: ", nrow(report))
message("Columns: ", ncol(report))
message("Output: ", output_rdata)
message("NA values in numeric columns: ", na_count)
message("Inf values in numeric columns: ", inf_count)

if (isTRUE(arguments$`run-testthat`)) {
  if (!requireNamespace("testthat", quietly = TRUE)) {
    fail("the testthat package is not installed")
  }
  message("Running the package testthat suite...")
  testthat::test_dir(file.path(package_root, "tests", "testthat"), reporter = "progress")
  message("testthat suite completed")
}

if (isTRUE(arguments$launch_ui)) {
  message("Launching the GCAM v9.1 Shiny UI...")
  gcamreport::launch_gcamreport_ui(
    data_path = output_rdata,
    GCAM_version = "v9.1"
  )
}
