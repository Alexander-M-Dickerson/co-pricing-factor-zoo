args <- commandArgs(trailingOnly = TRUE)
report_dir_arg <- if (length(args) >= 1) args[1] else NULL

get_script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) == 0) {
    return(normalizePath(getwd(), winslash = "/", mustWork = TRUE))
  }

  normalizePath(dirname(sub("^--file=", "", file_arg[1])), winslash = "/", mustWork = TRUE)
}

repo_root <- normalizePath(file.path(get_script_dir(), ".."), winslash = "/", mustWork = TRUE)
source(file.path(repo_root, "testing", "validation_helpers.R"))
repo_root <- get_testing_repo_root()
report_dir <- build_report_dir("check_toolchain", report_dir_arg)

toolchain_status <- collect_toolchain_status()
write_csv_report(toolchain_status, file.path(report_dir, "toolchain_status.csv"))
write_session_info_report(file.path(report_dir, "session_info.txt"))

cat(sprintf("Toolchain report: %s\n", report_dir))
print(toolchain_status, row.names = FALSE)

if (!nzchar(toolchain_status$make_path)) {
  cat("STATUS: make/Rtools not detected on PATH.\n")
} else if (!toolchain_status$compile_probe) {
  cat("STATUS: build tools detected, but compile probe failed.\n")
  cat("NOTE: if you are running inside a restricted or sandboxed environment, rerun this check in a normal PowerShell or R session.\n")
} else {
  cat("STATUS: compile probe succeeded.\n")
}
