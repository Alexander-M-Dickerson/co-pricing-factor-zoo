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
required_wrapper_files <- c(
  "tools/bootstrap_packages.ps1",
  "tools/bootstrap_packages.cmd",
  "tools/bootstrap_packages.sh",
  "tools/bootstrap_data.ps1",
  "tools/bootstrap_data.cmd",
  "tools/bootstrap_data.sh",
  "tools/doctor.ps1",
  "tools/doctor.cmd",
  "tools/doctor.sh",
  "tools/rebuild_fast_backends.ps1",
  "tools/rebuild_fast_backends.cmd",
  "tools/rebuild_fast_backends.sh",
  "tools/run_conditional_smoke.ps1",
  "tools/run_conditional_smoke.cmd",
  "tools/run_conditional_smoke.sh",
  "tools/run_figure1_simulation.ps1",
  "tools/run_figure1_simulation.cmd",
  "tools/run_figure1_simulation.sh",
  "tools/run_ia_smoke.ps1",
  "tools/run_ia_smoke.cmd",
  "tools/run_ia_smoke.sh",
  "tools/run_full_replication.ps1",
  "tools/run_full_replication.cmd",
  "tools/run_full_replication.sh",
  "tools/run_ia_full.ps1",
  "tools/run_ia_full.cmd",
  "tools/run_ia_full.sh",
  "tools/build_paper.ps1",
  "tools/build_paper.cmd",
  "tools/build_paper.sh",
  "tools/build_ia_paper.ps1",
  "tools/build_ia_paper.cmd",
  "tools/build_ia_paper.sh"
)
expect_true(
  all(file.exists(file.path(repo_root, required_wrapper_files))),
  "Public platform wrappers exist for setup, replication, and paper build.",
  "One or more public platform wrappers are missing under tools/."
)
workflow_path <- file.path(repo_root, ".github", "workflows", "usability-smoke.yml")
expect_true(
  file.exists(workflow_path),
  "GitHub Actions usability-smoke workflow exists.",
  ".github/workflows/usability-smoke.yml is missing."
)
if (file.exists(workflow_path)) {
  workflow_text <- read_text(workflow_path)
  expect_true(
    grepl("macos-latest", workflow_text, fixed = TRUE),
    "Usability smoke workflow covers macOS.",
    "Usability smoke workflow does not include macOS."
  )
  expect_true(
      grepl("bash tools/build_paper.sh --help", workflow_text, fixed = TRUE) &&
      grepl("bash tools/build_ia_paper.sh --help", workflow_text, fixed = TRUE) &&
      grepl("bash tools/run_full_replication.sh --help", workflow_text, fixed = TRUE) &&
      grepl("bash tools/run_figure1_simulation.sh --help", workflow_text, fixed = TRUE) &&
      grepl("bash tools/run_ia_full.sh --help", workflow_text, fixed = TRUE) &&
      grepl("bash tools/run_ia_smoke.sh --help", workflow_text, fixed = TRUE) &&
      grepl("bash tools/bootstrap_data.sh --help", workflow_text, fixed = TRUE),
    "Usability smoke workflow exercises the Unix wrapper surface.",
    "Usability smoke workflow is missing the Unix wrapper smoke surface."
  )
  expect_true(
    grepl("tools\\build_paper.ps1 -Help", workflow_text, fixed = TRUE) &&
      grepl("tools\\build_ia_paper.ps1 -Help", workflow_text, fixed = TRUE) &&
      grepl("tools\\run_full_replication.ps1 -Help", workflow_text, fixed = TRUE) &&
      grepl("tools\\run_figure1_simulation.ps1 -Help", workflow_text, fixed = TRUE) &&
      grepl("tools\\run_ia_full.ps1 -Help", workflow_text, fixed = TRUE) &&
      grepl("tools\\run_ia_smoke.ps1 -Help", workflow_text, fixed = TRUE) &&
      grepl("tools\\bootstrap_data.ps1 --help", workflow_text, fixed = TRUE),
    "Usability smoke workflow exercises the Windows PowerShell wrapper surface.",
    "Usability smoke workflow is missing the Windows PowerShell wrapper smoke surface."
  )
  expect_true(
    grepl("tools\\build_paper.cmd -Help", workflow_text, fixed = TRUE) &&
      grepl("tools\\build_ia_paper.cmd -Help", workflow_text, fixed = TRUE) &&
      grepl("tools\\run_full_replication.cmd -Help", workflow_text, fixed = TRUE) &&
      grepl("tools\\run_figure1_simulation.cmd -Help", workflow_text, fixed = TRUE) &&
      grepl("tools\\run_ia_full.cmd -Help", workflow_text, fixed = TRUE) &&
      grepl("tools\\run_ia_smoke.cmd -Help", workflow_text, fixed = TRUE) &&
      grepl("tools\\bootstrap_data.cmd --help", workflow_text, fixed = TRUE),
    "Usability smoke workflow exercises the Windows Command Prompt wrapper surface.",
    "Usability smoke workflow is missing the Windows Command Prompt wrapper smoke surface."
  )
  expect_true(
    grepl("Rscript tools/bootstrap_data.R --help", workflow_text, fixed = TRUE) &&
      grepl("Rscript tools/run_figure1_simulation.R --help", workflow_text, fixed = TRUE),
    "Usability smoke workflow exercises the R bootstrap and Figure 1 entrypoints.",
    "Usability smoke workflow is missing the R bootstrap or Figure 1 smoke surface."
  )
}
expect_true(
  file.exists(file.path(repo_root, "docs", "manifests", "data-files.csv")),
  "docs/manifests/data-files.csv exists.",
  "docs/manifests/data-files.csv is missing."
)
expect_true(
  file.exists(file.path(repo_root, "docs", "manifests", "data-sources.csv")),
  "docs/manifests/data-sources.csv exists.",
  "docs/manifests/data-sources.csv is missing."
)
expect_true(
  file.exists(file.path(repo_root, "docs", "manifests", "exhibits.csv")),
  "docs/manifests/exhibits.csv exists.",
  "docs/manifests/exhibits.csv is missing."
)
expect_true(
  file.exists(file.path(repo_root, "docs", "manifests", "manuscript_exhibits.csv")),
  "docs/manifests/manuscript_exhibits.csv exists.",
  "docs/manifests/manuscript_exhibits.csv is missing."
)
expect_true(
  file.exists(file.path(repo_root, "docs", "manifests", "paper_claims.csv")),
  "docs/manifests/paper_claims.csv exists.",
  "docs/manifests/paper_claims.csv is missing."
)
expect_true(
  file.exists(file.path(repo_root, "docs", "agent-context", "prompt-recipes.md")),
  "docs/agent-context/prompt-recipes.md exists.",
  "docs/agent-context/prompt-recipes.md is missing."
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
  !grepl("Optional `ia/data/w_all.rds`|optional IA-only data files|weighted-treasury IA outputs remain blocked", combined_docs, fixed = FALSE),
  "Public docs no longer describe ia/data/w_all.rds as optional.",
  "Found stale optional-weighted-treasury wording in public docs."
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
agents_text <- read_text(file.path(repo_root, "AGENTS.md"))
expect_true(
  grepl("tools/bootstrap_packages.R", readme_text, fixed = TRUE) &&
    grepl("tools/bootstrap_data.R", readme_text, fixed = TRUE) &&
    grepl("tools/doctor.R", readme_text, fixed = TRUE) &&
    grepl("docs/manifests/exhibits.csv", readme_text, fixed = TRUE) &&
    grepl("docs/agent-context/prompt-recipes.md", readme_text, fixed = TRUE),
  "README points to the new tooling and manifest surfaces.",
  "README does not point to the new tooling and manifest surfaces."
)
expect_true(
  grepl("tools/bootstrap_packages.R", quickstart_text, fixed = TRUE) &&
    grepl("tools/bootstrap_data.R", quickstart_text, fixed = TRUE) &&
    grepl("tools/doctor.R", quickstart_text, fixed = TRUE) &&
    grepl("tools/build_paper.ps1", quickstart_text, fixed = TRUE) &&
    grepl("tools/build_ia_paper.ps1", quickstart_text, fixed = TRUE) &&
    grepl("tools/build_paper.cmd", quickstart_text, fixed = TRUE) &&
    grepl("tools/build_ia_paper.cmd", quickstart_text, fixed = TRUE) &&
    grepl("tools/build_paper.sh", quickstart_text, fixed = TRUE) &&
    grepl("tools/build_ia_paper.sh", quickstart_text, fixed = TRUE) &&
    grepl("docs/agent-context/prompt-recipes.md", quickstart_text, fixed = TRUE),
  "QUICKSTART uses the shared bootstrap and doctor scripts.",
  "QUICKSTART does not use the shared bootstrap, doctor, and build wrapper surfaces."
)
mac_toolchain_targets <- file.path(repo_root, c(
  "README.md",
  "QUICKSTART.md",
  file.path("docs", "agent-context", "replication-onboarding.md")
))
mac_toolchain_ok <- vapply(
  mac_toolchain_targets,
  function(path) {
    text <- read_text(path)
    grepl("https://cran.r-project.org/bin/macosx/tools/", text, fixed = TRUE) &&
      grepl("https://mac.r-project.org/tools/", text, fixed = TRUE)
  },
  logical(1)
)
expect_true(
  all(mac_toolchain_ok),
  "Primary onboarding docs point to the official macOS toolchain pages.",
  "One or more onboarding docs are missing the official macOS toolchain references."
)
expect_true(
  !grepl("Current freshness caveat", readme_text, fixed = TRUE) &&
    !grepl("Observed freshness caveat", combined_docs, fixed = TRUE) &&
    !grepl("some unconditional paper-output helpers still use cached intermediate", agents_text, fixed = TRUE),
  "Stale freshness caveat wording is absent from repo docs.",
  "Found stale freshness caveat wording in repo docs."
)

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
  "data/variance_decomp_results_vuol.rds",
  "misc/figure1_simulation/pseudo-true.RData",
  "misc/figure1_simulation/simulation400psi60.RData",
  "misc/figure1_simulation/simulation1600psi60.RData",
  "misc/figure1_simulation/monthly_return.csv",
  "misc/figure1_simulation/Fig_01_0_sim_legend.jpeg",
  "misc/figure1_simulation/Fig_01_1_OLS_60_400_BMA_MPR.jpeg",
  "misc/figure1_simulation/Fig_01_2_OLS_60_1600_BMA_MPR.jpeg",
  "misc/figure1_simulation/Fig_01_3_OLS_60_400_factor_MPRs.jpeg",
  "misc/figure1_simulation/Fig_01_4_OLS_60_1600_factor_MPRs.jpeg",
  "misc/figure1_simulation/Fig_01_5_OLS_60_400_factor_probs.jpeg",
  "misc/figure1_simulation/Fig_01_6_OLS_60_1600_factor_probs.jpeg"
)
expect_true(
  all(required_data_rows %in% data_manifest$path),
  "Data manifest contains the required core inputs.",
  "Data manifest is missing one or more required core inputs."
)
expect_true(
  "bootstrap_source_id" %in% names(data_manifest),
  "Data manifest includes bootstrap_source_id for canonical bundle routing.",
  "Data manifest is missing the bootstrap_source_id column."
)
weighted_row <- subset(data_manifest, path == "ia/data/w_all.rds")
expect_true(
  nrow(weighted_row) == 1 &&
    identical(weighted_row$required[[1]], "yes") &&
    identical(weighted_row$bootstrap_source_id[[1]], ""),
  "Data manifest marks ia/data/w_all.rds as required tracked clone data.",
  "Data manifest does not mark ia/data/w_all.rds as required tracked clone data."
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
expect_true(
  "context_dossier" %in% names(exhibit_manifest),
  "Exhibit manifest includes context_dossier paths.",
  "Exhibit manifest is missing the context_dossier column."
)
figure1_row <- subset(exhibit_manifest, exhibit_id == "Figure 1")
expect_true(
  nrow(figure1_row) == 1 &&
    identical(figure1_row$coverage_status[[1]], "implemented") &&
    grepl("code_base/figure1_simulation.R", figure1_row$helper_or_generator[[1]], fixed = TRUE) &&
    grepl("Fig_01_\\*", figure1_row$output_path[[1]]),
  "Figure 1 is marked implemented and points at the production helper/output contract.",
  "Figure 1 is still missing or not marked as a production-generated exhibit."
)

manuscript_exhibit_manifest <- utils::read.csv(file.path(repo_root, "docs", "manifests", "manuscript_exhibits.csv"), stringsAsFactors = FALSE)
figure1_manuscript_row <- subset(manuscript_exhibit_manifest, manuscript_exhibit_id == "Figure 1")
expect_true(
  nrow(figure1_manuscript_row) == 1 &&
    identical(figure1_manuscript_row$repo_coverage_status[[1]], "implemented"),
  "Manuscript exhibit manifest marks Figure 1 as implemented.",
  "Manuscript exhibit manifest still treats Figure 1 as non-generated."
)

paper_claims_manifest <- utils::read.csv(file.path(repo_root, "docs", "manifests", "paper_claims.csv"), stringsAsFactors = FALSE)
claim9_row <- subset(paper_claims_manifest, claim_id == 9)
expect_true(
  nrow(claim9_row) == 1 &&
    !identical(claim9_row$repo_coverage_status[[1]], "paper-only"),
  "Paper claims manifest no longer treats the Figure 1 noisy-proxy claim as paper-only.",
  "Paper claims manifest still treats Figure 1 as paper-only."
)

required_dossiers <- c(
  "docs/agent-context/exhibits/table-1.md",
  "docs/agent-context/exhibits/table-5.md",
  "docs/agent-context/exhibits/figure-7.md",
  "docs/agent-context/exhibits/figure-9.md",
  "docs/agent-context/exhibits/ia-implemented-subset.md"
)
expect_true(
  all(file.exists(file.path(repo_root, required_dossiers))),
  "Key exhibit dossiers exist for explanation tasks.",
  "One or more required exhibit dossiers are missing."
)
prompt_recipes_text <- read_text(file.path(repo_root, "docs", "agent-context", "prompt-recipes.md"))
expect_true(
  grepl("Replicate The Internet Appendix", prompt_recipes_text, fixed = TRUE) &&
    grepl("Build The IA PDF", prompt_recipes_text, fixed = TRUE) &&
    grepl("Regenerate Figure 1", prompt_recipes_text, fixed = TRUE) &&
    grepl("Fully Explain Figure 1", prompt_recipes_text, fixed = TRUE),
  "Prompt recipes include the IA prompts and the Figure 1 prompts.",
  "Prompt recipes are missing the IA prompts or the Figure 1 prompts."
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

skill_expectations <- list(
  list(
    path = file.path(repo_root, ".agents", "skills", "replication-onboard", "SKILL.md"),
    needles = c("tools/bootstrap_data.R", "docs/manifests/data-sources.csv")
  ),
  list(
    path = file.path(repo_root, ".agents", "skills", "replicate-paper", "SKILL.md"),
    needles = c("docs/manifests/manuscript_exhibits.csv", "docs/agent-context/prompt-recipes.md")
  ),
  list(
    path = file.path(repo_root, ".agents", "skills", "explain-paper", "SKILL.md"),
    needles = c("docs/manifests/manuscript_exhibits.csv", "docs/manifests/paper_claims.csv", "docs/agent-context/exhibits/README.md")
  ),
  list(
    path = file.path(repo_root, ".claude", "skills", "onboard", "SKILL.md"),
    needles = c("tools/bootstrap_data.R", "docs/manifests/data-sources.csv")
  ),
  list(
    path = file.path(repo_root, ".claude", "skills", "replicate-paper", "SKILL.md"),
    needles = c("docs/manifests/manuscript_exhibits.csv", "docs/agent-context/prompt-recipes.md")
  ),
  list(
    path = file.path(repo_root, ".claude", "skills", "explain-paper", "SKILL.md"),
    needles = c("docs/manifests/manuscript_exhibits.csv", "docs/manifests/paper_claims.csv", "docs/agent-context/exhibits/README.md")
  )
)
skill_routing_ok <- vapply(
  skill_expectations,
  function(spec) {
    text <- read_text(spec$path)
    all(vapply(spec$needles, grepl, logical(1), x = text, fixed = TRUE))
  },
  logical(1)
)
expect_true(
  all(skill_routing_ok),
  "Codex and Claude skill routing point at the new data, manifest, and exhibit surfaces.",
  "One or more Codex or Claude skills are missing the new data, manifest, or exhibit routing surfaces."
)

rscript_name <- if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"
rscript_path <- file.path(R.home("bin"), rscript_name)
entrypoints <- list(
  list(script = "tools/bootstrap_data.R", arg = "--help"),
  list(script = "tools/run_figure1_simulation.R", arg = "--help"),
  list(script = "_run_full_replication.R", arg = "--help"),
  list(script = "_run_all_unconditional.R", arg = "--list"),
  list(script = "_run_all_conditional.R", arg = "--help"),
  list(script = "ia/_run_ia_estimation.R", arg = "--list"),
  list(script = "ia/_run_ia_results.R", arg = "--help"),
  list(script = "ia/_create_ia_latex.R", arg = "--help"),
  list(script = "ia/_run_ia_full.R", arg = "--help")
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
