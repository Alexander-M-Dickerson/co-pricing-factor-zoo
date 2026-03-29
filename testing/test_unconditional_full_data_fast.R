# Compatibility wrapper. The canonical kernel validator is:
# testing/validate_continuous_ss_sdf_v2.R

get_script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) == 0) {
    return(normalizePath(getwd(), winslash = "/", mustWork = TRUE))
  }

  normalizePath(dirname(sub("^--file=", "", file_arg[1])), winslash = "/", mustWork = TRUE)
}

repo_root <- normalizePath(file.path(get_script_dir(), ".."), winslash = "/", mustWork = TRUE)
source(file.path(repo_root, "testing", "validate_continuous_ss_sdf_v2.R"), chdir = TRUE)
