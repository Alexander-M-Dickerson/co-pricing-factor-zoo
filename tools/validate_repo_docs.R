#!/usr/bin/env Rscript
###############################################################################
## validate_repo_docs.R
## ---------------------------------------------------------------------------
##
## Paper role:
##   Drift guard for the repo's public human/AI replication contract.
##
## Paper refs:
##   - validated setup and execution surfaces for the main paper and IA subset
##   - exhibit/manuscript coverage claims exposed to Codex and Claude
###############################################################################

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
  file.exists(file.path(repo_root, "docs", "acceptance", "README.md")) &&
    file.exists(file.path(repo_root, "docs", "acceptance", "agent_acceptance_template.md")) &&
    file.exists(file.path(repo_root, "docs", "acceptance", "prompt_harness.csv")),
  "Acceptance harness docs exist.",
  "One or more acceptance harness docs are missing under docs/acceptance/."
)
expect_true(
  file.exists(file.path(repo_root, "docs", "validation", "README.md")) &&
    file.exists(file.path(repo_root, "docs", "validation", "validated_runs.csv")) &&
    file.exists(file.path(repo_root, "docs", "validation", "agent_acceptance_log.csv")),
  "Validation ledger docs exist.",
  "One or more validation ledger docs are missing under docs/validation/."
)
latex_smoke_files <- c(
  "testing/latex_smoke/README.md",
  "testing/latex_smoke/main/djm_main.tex",
  "testing/latex_smoke/main/tables.tex",
  "testing/latex_smoke/main/figures.tex",
  "testing/latex_smoke/main/app_tables.tex",
  "testing/latex_smoke/main/smoke_refs.bib",
  "testing/latex_smoke/ia/ia_main.tex",
  "testing/latex_smoke/ia/ia_tables.tex",
  "testing/latex_smoke/ia/ia_figures.tex"
)
expect_true(
  all(file.exists(file.path(repo_root, latex_smoke_files))),
  "Tracked LaTeX smoke fixtures exist for main and IA builds.",
  "One or more tracked LaTeX smoke fixture files are missing."
)
latex_smoke_workflow_path <- file.path(repo_root, ".github", "workflows", "latex-smoke.yml")
expect_true(
  file.exists(latex_smoke_workflow_path),
  "GitHub Actions latex-smoke workflow exists.",
  ".github/workflows/latex-smoke.yml is missing."
)
if (file.exists(latex_smoke_workflow_path)) {
  latex_smoke_workflow_text <- read_text(latex_smoke_workflow_path)
  expect_true(
    grepl("r-lib/actions/setup-tinytex@v2", latex_smoke_workflow_text, fixed = TRUE),
    "LaTeX smoke workflow installs TinyTeX.",
    "LaTeX smoke workflow does not install TinyTeX."
  )
  expect_true(
    grepl("bash tools/build_paper.sh --fixture-dir=testing/latex_smoke/main", latex_smoke_workflow_text, fixed = TRUE) &&
      grepl("bash tools/build_ia_paper.sh --fixture-dir=testing/latex_smoke/ia", latex_smoke_workflow_text, fixed = TRUE),
    "LaTeX smoke workflow exercises the fixture-based build wrappers.",
    "LaTeX smoke workflow is missing the fixture-based build wrapper calls."
  )
  expect_true(
    grepl("testing/latex_smoke/main/djm_main.pdf", latex_smoke_workflow_text, fixed = TRUE) &&
      grepl("testing/latex_smoke/ia/ia_main.pdf", latex_smoke_workflow_text, fixed = TRUE),
    "LaTeX smoke workflow checks the expected PDF artifacts.",
    "LaTeX smoke workflow does not check the expected fixture PDF artifacts."
  )
}

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
pipeline_readme_text <- read_text(file.path(repo_root, "README_PAPER_PIPELINE.md"))
agents_text <- read_text(file.path(repo_root, "AGENTS.md"))
claude_text <- read_text(file.path(repo_root, "CLAUDE.md"))
expect_true(
  grepl("Use Claude Code Or Codex", readme_text, fixed = TRUE) &&
    grepl("/onboard", readme_text, fixed = TRUE) &&
    grepl("/replicate-paper", readme_text, fixed = TRUE) &&
    grepl("/explain-paper", readme_text, fixed = TRUE) &&
    grepl("$replication-onboard", readme_text, fixed = TRUE) &&
    grepl("$replicate-paper", readme_text, fixed = TRUE) &&
    grepl("$explain-paper", readme_text, fixed = TRUE) &&
    grepl("docs/agent-context/prompt-recipes.md", readme_text, fixed = TRUE),
  "README includes the Claude-first and Codex-second agent bridge block.",
  "README is missing the Claude/Codex bridge block or one of the expected skill prompts."
)
expect_true(
  grepl("Run This Repo As A Human", readme_text, fixed = TRUE) &&
    grepl("Fastest Validated Main-Paper Path", readme_text, fixed = TRUE) &&
    grepl("Fastest Validated IA Path", readme_text, fixed = TRUE) &&
    grepl("output/paper/latex/djm_main.pdf", readme_text, fixed = TRUE) &&
    grepl("ia/output/paper/latex/ia_main.pdf", readme_text, fixed = TRUE) &&
    grepl("For Codex / Claude", readme_text, fixed = TRUE),
  "README now exposes a balanced human-first front door plus a separate AI section.",
  "README is missing the human-first run path or the separate AI section."
)
agent_bridge_pos <- regexpr("## Use Claude Code Or Codex", readme_text, fixed = TRUE)[1]
human_section_pos <- regexpr("## Run This Repo As A Human", readme_text, fixed = TRUE)[1]
expect_true(
  agent_bridge_pos > 0 && human_section_pos > 0 && agent_bridge_pos < human_section_pos,
  "README places the agent bridge block before the human run section.",
  "README does not place the Claude/Codex bridge block before the human run section."
)
expect_true(
  grepl("docs/acceptance/prompt_harness.csv", readme_text, fixed = TRUE) &&
    grepl("docs/validation/validated_runs.csv", readme_text, fixed = TRUE) &&
    grepl("docs/validation/agent_acceptance_log.csv", readme_text, fixed = TRUE) &&
    grepl("docs/acceptance/prompt_harness.csv", agents_text, fixed = TRUE) &&
    grepl("docs/validation/validated_runs.csv", agents_text, fixed = TRUE) &&
    grepl("docs/validation/agent_acceptance_log.csv", agents_text, fixed = TRUE) &&
    grepl("docs/acceptance/prompt_harness.csv", claude_text, fixed = TRUE) &&
    grepl("docs/validation/validated_runs.csv", claude_text, fixed = TRUE) &&
    grepl("docs/validation/agent_acceptance_log.csv", claude_text, fixed = TRUE),
  "README and the agent docs point at the acceptance harness and validation ledgers.",
  "README, AGENTS.md, or CLAUDE.md is missing the acceptance harness or validation ledger surfaces."
)
expect_true(
  grepl("Using Posit/RStudio Terminal", quickstart_text, fixed = TRUE) &&
    grepl("tools\\\\run_full_replication\\.ps1 -Quick", quickstart_text) &&
    grepl("tools\\\\run_full_replication\\.cmd -Quick", quickstart_text) &&
    grepl("bash tools/run_full_replication.sh --quick", quickstart_text, fixed = TRUE) &&
    grepl("Rscript _run_full_replication.R --quick", quickstart_text, fixed = TRUE) &&
    grepl("Rscript _run_full_replication.R", quickstart_text, fixed = TRUE) &&
    grepl("Rscript ia/_run_ia_full.R", quickstart_text, fixed = TRUE) &&
    grepl("output/paper/latex/djm_main.pdf", quickstart_text, fixed = TRUE) &&
    grepl("ia/output/paper/latex/ia_main.pdf", quickstart_text, fixed = TRUE),
  "QUICKSTART now supports humans directly with Posit guidance, wrappers first, and raw Rscript equivalents.",
  "QUICKSTART is missing the Posit guidance, wrapper-first path, or raw Rscript equivalents."
)
expect_true(
  grepl("Main Smoke Boundary", pipeline_readme_text, fixed = TRUE) &&
    grepl("Main Full Boundary", pipeline_readme_text, fixed = TRUE) &&
    grepl("IA Smoke Boundary", pipeline_readme_text, fixed = TRUE) &&
    grepl("IA Full Boundary", pipeline_readme_text, fixed = TRUE) &&
    grepl("output/paper/latex/djm_main.pdf", pipeline_readme_text, fixed = TRUE) &&
    grepl("ia/output/paper/latex/ia_main.pdf", pipeline_readme_text, fixed = TRUE),
  "README_PAPER_PIPELINE now acts as a concise human boundary map.",
  "README_PAPER_PIPELINE is missing the short human boundary map structure."
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
  "docs/agent-context/exhibits/ia-implemented-subset.md",
  "docs/agent-context/exhibits/ia-pead-robustness.md"
)
expect_true(
  all(file.exists(file.path(repo_root, required_dossiers))),
  "Key exhibit dossiers exist for explanation tasks.",
  "One or more required exhibit dossiers are missing."
)
required_factor_docs <- c(
  "docs/agent-context/factor-interpretation.md",
  "docs/agent-context/factors/README.md",
  "docs/agent-context/factors/pead.md",
  "docs/agent-context/factors/peadb.md",
  "docs/agent-context/factors/ivol.md",
  "docs/agent-context/factors/credit.md",
  "docs/agent-context/factors/ysp.md"
)
expect_true(
  all(file.exists(file.path(repo_root, required_factor_docs))),
  "Factor interpretation guide and top-factor dossiers exist.",
  "One or more factor interpretation docs or top-factor dossiers are missing."
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
expect_true(
  grepl("Explain Factor Inclusion", prompt_recipes_text, fixed = TRUE) &&
    grepl("Explain Gamma Versus MPR", prompt_recipes_text, fixed = TRUE) &&
    grepl("Fully Explain PEAD", prompt_recipes_text, fixed = TRUE) &&
    grepl("Explain PEAD Robustness", prompt_recipes_text, fixed = TRUE) &&
    grepl("Explain Dense SDF", prompt_recipes_text, fixed = TRUE),
  "Prompt recipes include the factor-interpretation and PEAD robustness prompts.",
  "Prompt recipes are missing the factor-interpretation or PEAD robustness prompts."
)

prompt_harness <- utils::read.csv(
  file.path(repo_root, "docs", "acceptance", "prompt_harness.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
required_prompt_harness_columns <- c(
  "prompt_id",
  "category",
  "canonical_prompt",
  "success_mode",
  "required_routes",
  "required_refs",
  "required_outputs_or_commands",
  "required_statements",
  "forbidden_statements",
  "coverage_expectation",
  "validated_boundary",
  "notes"
)
expect_true(
  all(required_prompt_harness_columns %in% names(prompt_harness)),
  "Prompt harness exposes the required acceptance columns.",
  "Prompt harness is missing one or more required acceptance columns."
)
required_prompt_ids <- c(
  "fresh_clone_setup",
  "replicate_main_text",
  "replicate_internet_appendix",
  "explain_table_1",
  "explain_figure_1",
  "explain_factor_inclusion",
  "explain_gamma_vs_mpr",
  "explain_pead",
  "pead_microcap",
  "implemented_ia_coverage"
)
expect_true(
  all(required_prompt_ids %in% prompt_harness$prompt_id),
  "Prompt harness includes the required onboarding, execution, and explanation prompts.",
  "Prompt harness is missing one or more required prompt ids."
)
pead_microcap_row <- subset(prompt_harness, prompt_id == "pead_microcap")
expect_true(
  nrow(pead_microcap_row) == 1 &&
    identical(pead_microcap_row$coverage_expectation[[1]], "paper-only") &&
    grepl("ia-pead-robustness.md", pead_microcap_row$required_routes[[1]], fixed = TRUE),
  "Prompt harness routes the PEAD micro-cap prompt through the paper-only appendix dossier.",
  "Prompt harness misroutes the PEAD micro-cap prompt or no longer marks it paper-only."
)
replicate_main_text_row <- subset(prompt_harness, prompt_id == "replicate_main_text")
expect_true(
  nrow(replicate_main_text_row) == 1 &&
    !identical(replicate_main_text_row$coverage_expectation[[1]], "paper-only"),
  "Prompt harness does not mislabel the main replication prompt as paper-only.",
  "Prompt harness incorrectly marks the main replication prompt as paper-only."
)
factor_inclusion_row <- subset(prompt_harness, prompt_id == "explain_factor_inclusion")
expect_true(
  nrow(factor_inclusion_row) == 1 &&
    grepl("factor-interpretation.md", factor_inclusion_row$required_routes[[1]], fixed = TRUE),
  "Prompt harness routes factor-inclusion questions through the factor interpretation guide.",
  "Prompt harness is missing the factor interpretation route for factor-inclusion questions."
)

validated_runs <- utils::read.csv(
  file.path(repo_root, "docs", "validation", "validated_runs.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
required_validated_runs_columns <- c(
  "validation_id",
  "surface",
  "platform",
  "validated_at_utc",
  "boundary",
  "command_or_wrapper",
  "status",
  "evidence_path",
  "notes"
)
expect_true(
  all(required_validated_runs_columns %in% names(validated_runs)),
  "Validated-runs ledger exposes the required columns.",
  "Validated-runs ledger is missing one or more required columns."
)
required_validation_ids <- c(
  "main_conditional_5000",
  "main_full_replication_5000",
  "main_build_paper",
  "ia_smoke_500",
  "ia_full_5000",
  "ia_build_paper"
)
expect_true(
  all(required_validation_ids %in% validated_runs$validation_id),
  "Validated-runs ledger includes the seeded main and IA boundaries.",
  "Validated-runs ledger is missing one or more seeded validation ids."
)

agent_acceptance_log <- utils::read.csv(
  file.path(repo_root, "docs", "validation", "agent_acceptance_log.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
required_agent_acceptance_columns <- c(
  "run_id",
  "agent",
  "prompt_id",
  "clone_state",
  "data_state",
  "result",
  "transcript_or_notes",
  "validated_at_utc"
)
expect_true(
  all(required_agent_acceptance_columns %in% names(agent_acceptance_log)),
  "Agent acceptance log exposes the required columns.",
  "Agent acceptance log is missing one or more required columns."
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
    needles = c("tools/bootstrap_data.R", "docs/manifests/data-sources.csv", "docs/validation/validated_runs.csv")
  ),
  list(
    path = file.path(repo_root, ".agents", "skills", "replicate-paper", "SKILL.md"),
    needles = c("docs/manifests/manuscript_exhibits.csv", "docs/agent-context/prompt-recipes.md", "docs/validation/validated_runs.csv")
  ),
  list(
    path = file.path(repo_root, ".agents", "skills", "explain-paper", "SKILL.md"),
    needles = c("docs/manifests/manuscript_exhibits.csv", "docs/manifests/paper_claims.csv", "docs/agent-context/exhibits/README.md", "docs/agent-context/factor-interpretation.md", "docs/agent-context/factors/", "docs/acceptance/prompt_harness.csv")
  ),
  list(
    path = file.path(repo_root, ".claude", "skills", "onboard", "SKILL.md"),
    needles = c("tools/bootstrap_data.R", "docs/manifests/data-sources.csv", "docs/validation/validated_runs.csv")
  ),
  list(
    path = file.path(repo_root, ".claude", "skills", "replicate-paper", "SKILL.md"),
    needles = c("docs/manifests/manuscript_exhibits.csv", "docs/agent-context/prompt-recipes.md", "docs/validation/validated_runs.csv")
  ),
  list(
    path = file.path(repo_root, ".claude", "skills", "explain-paper", "SKILL.md"),
    needles = c("docs/manifests/manuscript_exhibits.csv", "docs/manifests/paper_claims.csv", "docs/agent-context/exhibits/README.md", "docs/agent-context/factor-interpretation.md", "docs/agent-context/factors/", "docs/acceptance/prompt_harness.csv")
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
claim11_row <- subset(paper_claims_manifest, claim_id == 11)
expect_true(
  nrow(claim11_row) == 1 &&
    identical(claim11_row$repo_coverage_status[[1]], "paper-only") &&
    grepl("ia-pead-robustness.md", claim11_row$notes[[1]], fixed = TRUE),
  "Paper claims manifest routes PEAD robustness through the paper-only dossier.",
  "PEAD robustness claim routing is missing or no longer marked paper-only."
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
