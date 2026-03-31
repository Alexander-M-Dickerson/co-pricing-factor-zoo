#!/usr/bin/env Rscript

get_script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) == 0) {
    return(normalizePath(getwd(), winslash = "/", mustWork = TRUE))
  }

  normalizePath(dirname(sub("^--file=", "", file_arg[1])), winslash = "/", mustWork = TRUE)
}

get_repo_root <- function() {
  normalizePath(file.path(get_script_dir(), ".."), winslash = "/", mustWork = TRUE)
}

read_text <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

run_entrypoint_check <- function(rscript_path, repo_root, script, arg) {
  output_file <- tempfile(fileext = ".log")
  on.exit(unlink(output_file), add = TRUE)

  old_wd <- getwd()
  on.exit(setwd(old_wd), add = TRUE)
  setwd(repo_root)

  status <- system2(
    rscript_path,
    args = c(script, arg),
    stdout = output_file,
    stderr = output_file
  )

  list(
    status = status,
    output = paste(readLines(output_file, warn = FALSE), collapse = "\n")
  )
}

repo_root <- get_repo_root()
problems <- character()

pass <- function(message) {
  cat("[OK]   ", message, "\n", sep = "")
}

fail <- function(message) {
  problems <<- c(problems, message)
  cat("[FAIL] ", message, "\n", sep = "")
}

expect_true <- function(condition, success_message, failure_message) {
  if (isTRUE(condition)) {
    pass(success_message)
  } else {
    fail(failure_message)
  }
}

public_docs <- c(
  "README.md",
  "QUICKSTART.md",
  "README_PAPER_PIPELINE.md",
  "AGENTS.md",
  "CLAUDE.md",
  ".claude/paper-context.md",
  ".github/copilot-instructions.md",
  file.path(
    "docs",
    "agent-context",
    list.files(file.path(repo_root, "docs", "agent-context"), pattern = "\\.md$", full.names = FALSE)
  ),
  file.path(
    ".agents",
    "skills",
    list.files(file.path(repo_root, ".agents", "skills"), pattern = "SKILL\\.md$", recursive = TRUE, full.names = FALSE)
  ),
  file.path(
    ".claude",
    "skills",
    list.files(file.path(repo_root, ".claude", "skills"), pattern = "SKILL\\.md$", recursive = TRUE, full.names = FALSE)
  )
)
public_docs <- unique(file.path(repo_root, public_docs[file.exists(file.path(repo_root, public_docs))]))

combined_docs <- paste(vapply(public_docs, read_text, character(1)), collapse = "\n")
front_door_docs <- file.path(repo_root, c("README.md", "QUICKSTART.md", "README_PAPER_PIPELINE.md"))
front_door_text <- paste(vapply(front_door_docs, read_text, character(1)), collapse = "\n")

expect_true(
  file.exists(file.path(repo_root, "tools", "bootstrap_packages.R")),
  "tools/bootstrap_packages.R exists.",
  "tools/bootstrap_packages.R is missing."
)
expect_true(
  file.exists(file.path(repo_root, "tools", "doctor.R")),
  "tools/doctor.R exists.",
  "tools/doctor.R is missing."
)
expect_true(
  file.exists(file.path(repo_root, "docs", "manifests", "data-files.csv")),
  "docs/manifests/data-files.csv exists.",
  "docs/manifests/data-files.csv is missing."
)
expect_true(
  file.exists(file.path(repo_root, "docs", "manifests", "exhibits.csv")),
  "docs/manifests/exhibits.csv exists.",
  "docs/manifests/exhibits.csv is missing."
)

expect_true(
  !grepl("co-pricing-factor-zoo-jfe", combined_docs, fixed = TRUE),
  "Stale repo name is absent from public docs.",
  "Found stale repo name 'co-pricing-factor-zoo-jfe' in public docs."
)

expect_true(
  !grepl("5 IA models|ALL 5 IA models", combined_docs, ignore.case = TRUE),
  "Stale five-model IA wording is absent from public docs.",
  "Found stale five-model IA wording in public docs."
)

expect_true(
  !grepl("mkdir -p|nohup|disown", front_door_text),
  "Front-door docs avoid Unix-only background command defaults.",
  "Front-door docs still contain Unix-only background command defaults."
)

expect_true(
  !grepl("Use RStudio Terminal instead of PowerShell", front_door_text, fixed = TRUE),
  "Front-door docs no longer depend on the RStudio Terminal workaround.",
  "Front-door docs still tell Windows users to avoid PowerShell."
)

expect_true(
  !grepl("install\\.packages\\(c\\(", front_door_text),
  "Front-door docs no longer duplicate the package list inline.",
  "Front-door docs still duplicate package installation vectors."
)

coverage_targets <- file.path(repo_root, c("README.md", "AGENTS.md", "CLAUDE.md", "docs/agent-context/replication-pipeline.md"))
coverage_ok <- vapply(
  coverage_targets,
  function(path) {
    text <- read_text(path)
    grepl("all main paper tables and figures", text, ignore.case = TRUE) &&
      grepl("Appendix tables and figures", text, ignore.case = TRUE) &&
      grepl("some IA results|some Internet Appendix results", text, ignore.case = TRUE)
  },
  logical(1)
)
expect_true(
  all(coverage_ok),
  "Coverage wording is consistent across primary docs.",
  "Coverage wording is missing or inconsistent in one or more primary docs."
)

readme_text <- read_text(file.path(repo_root, "README.md"))
quickstart_text <- read_text(file.path(repo_root, "QUICKSTART.md"))
expect_true(
  grepl("tools/bootstrap_packages.R", readme_text, fixed = TRUE) &&
    grepl("tools/doctor.R", readme_text, fixed = TRUE) &&
    grepl("docs/manifests/exhibits.csv", readme_text, fixed = TRUE),
  "README points to the new tooling and manifest surfaces.",
  "README does not point to the new tooling and manifest surfaces."
)
expect_true(
  grepl("tools/bootstrap_packages.R", quickstart_text, fixed = TRUE) &&
    grepl("tools/doctor.R", quickstart_text, fixed = TRUE),
  "QUICKSTART uses the shared bootstrap and doctor scripts.",
  "QUICKSTART does not use the shared bootstrap and doctor scripts."
)

agents_text <- read_text(file.path(repo_root, "AGENTS.md"))
paper_method_text <- read_text(file.path(repo_root, "docs", "agent-context", "paper-method.md"))
expect_true(
  grepl("Prior calibration:", agents_text, fixed = TRUE) &&
    grepl("Sampler dispatch:", agents_text, fixed = TRUE) &&
    grepl("Prior calibration:", paper_method_text, fixed = TRUE) &&
    grepl("Sampler dispatch:", paper_method_text, fixed = TRUE),
  "Kappa guidance now distinguishes prior calibration from sampler dispatch.",
  "Kappa guidance is still missing the prior-calibration versus sampler-dispatch distinction."
)

data_manifest <- utils::read.csv(file.path(repo_root, "docs", "manifests", "data-files.csv"), stringsAsFactors = FALSE)
required_data_rows <- c(
  "data/nontraded.csv",
  "data/traded_bond_excess.csv",
  "data/traded_equity.csv",
  "data/bond_insample_test_assets_50_excess.csv",
  "data/equity_anomalies_composite_33.csv",
  "data/variance_decomp_results_vuol.rds"
)
expect_true(
  all(required_data_rows %in% data_manifest$path),
  "Data manifest contains the required core inputs.",
  "Data manifest is missing one or more required core inputs."
)

exhibit_manifest <- utils::read.csv(file.path(repo_root, "docs", "manifests", "exhibits.csv"), stringsAsFactors = FALSE)
required_exhibits <- c(
  "Table 1",
  "Table 6 Panel B",
  "Figure 2",
  "Figure 13",
  "Table IA.6",
  "Table IA.7",
  "Treasury Posterior Probabilities",
  "Sparse Pricing",
  "ISOS Switch Posterior Probabilities"
)
expect_true(
  all(required_exhibits %in% exhibit_manifest$exhibit_id),
  "Exhibit manifest contains the main and IA anchor exhibits.",
  "Exhibit manifest is missing one or more anchor exhibits."
)

skill_files <- c(
  list.files(file.path(repo_root, ".agents", "skills"), pattern = "SKILL\\.md$", recursive = TRUE, full.names = TRUE),
  list.files(file.path(repo_root, ".claude", "skills"), pattern = "SKILL\\.md$", recursive = TRUE, full.names = TRUE)
)
required_skill_sections <- c(
  "## Use When",
  "## Do Not Use When",
  "## Inputs",
  "## Outputs",
  "## Example Prompts",
  "## Failure Boundaries"
)
skills_ok <- vapply(
  skill_files,
  function(path) {
    text <- read_text(path)
    all(vapply(required_skill_sections, grepl, logical(1), x = text, fixed = TRUE))
  },
  logical(1)
)
expect_true(
  all(skills_ok),
  "All repo skills include the richer routing sections.",
  "One or more repo skills are missing the richer routing sections."
)

rscript_name <- if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"
rscript_path <- file.path(R.home("bin"), rscript_name)
entrypoints <- list(
  list(script = "_run_full_replication.R", arg = "--help"),
  list(script = "_run_all_unconditional.R", arg = "--list"),
  list(script = "_run_all_conditional.R", arg = "--help"),
  list(script = "ia/_run_ia_estimation.R", arg = "--list")
)

for (entry in entrypoints) {
  check <- run_entrypoint_check(rscript_path, repo_root, entry$script, entry$arg)
  success <- sprintf("%s %s exits cleanly.", entry$script, entry$arg)
  failure <- sprintf("%s %s failed.\n%s", entry$script, entry$arg, check$output)
  expect_true(check$status == 0, success, failure)
}

if (length(problems) > 0) {
  cat("\nValidation failed with ", length(problems), " problem(s).\n", sep = "")
  quit(save = "no", status = 1)
}

cat("\nRepo documentation validation passed.\n")
