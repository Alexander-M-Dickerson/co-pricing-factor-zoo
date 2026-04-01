#!/usr/bin/env Rscript

get_script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) == 0L) {
    return(normalizePath(getwd(), winslash = "/", mustWork = TRUE))
  }

  normalizePath(dirname(sub("^--file=", "", file_arg[1])), winslash = "/", mustWork = TRUE)
}

get_repo_root <- function() {
  normalizePath(file.path(get_script_dir(), ".."), winslash = "/", mustWork = TRUE)
}

parse_args <- function(args = commandArgs(trailingOnly = TRUE)) {
  opts <- list(
    sim_size = 1000L,
    sample_sizes = c(400L, 1600L),
    prior_pcts = 60L,
    type = "OLS",
    ndraws = 5000L,
    engine = "fast_cpp",
    num_cores = max(1L, parallel::detectCores() - 1L),
    publish = FALSE,
    show_help = FALSE
  )

  for (arg in args) {
    if (identical(arg, "--help") || identical(arg, "-h")) {
      opts$show_help <- TRUE
    } else if (grepl("^--sim-size=", arg)) {
      opts$sim_size <- as.integer(sub("^--sim-size=", "", arg))
    } else if (grepl("^--sample-sizes=", arg)) {
      opts$sample_sizes <- as.integer(strsplit(sub("^--sample-sizes=", "", arg), ",", fixed = TRUE)[[1]])
    } else if (grepl("^--prior-pcts=", arg)) {
      opts$prior_pcts <- as.integer(strsplit(sub("^--prior-pcts=", "", arg), ",", fixed = TRUE)[[1]])
    } else if (grepl("^--type=", arg)) {
      opts$type <- toupper(sub("^--type=", "", arg))
    } else if (grepl("^--ndraws=", arg)) {
      opts$ndraws <- as.integer(sub("^--ndraws=", "", arg))
    } else if (grepl("^--engine=", arg)) {
      opts$engine <- sub("^--engine=", "", arg)
    } else if (grepl("^--num-cores=", arg)) {
      opts$num_cores <- as.integer(sub("^--num-cores=", "", arg))
    } else if (identical(arg, "--publish")) {
      opts$publish <- TRUE
    } else {
      stop("Unknown argument: ", arg, call. = FALSE)
    }
  }

  opts$type <- match.arg(opts$type, c("OLS", "GLS"))
  opts$engine <- match.arg(opts$engine, c("fast_cpp", "reference"))
  opts
}

main <- function() {
  opts <- parse_args()
  if (isTRUE(opts$show_help)) {
    cat(
      "Usage: Rscript tools/run_figure1_simulation.R [options]\n\n",
      "Options:\n",
      "  --sim-size=INT           Number of Monte Carlo repetitions (default: 1000)\n",
      "  --sample-sizes=CSV       Sample sizes T to simulate (default: 400,1600)\n",
      "  --prior-pcts=CSV         Prior Sharpe ratio percentages (default: 60)\n",
      "  --type=OLS|GLS           Weighting scheme (default: OLS)\n",
      "  --ndraws=INT             MCMC draws per simulation (default: 5000)\n",
      "  --engine=fast_cpp|reference\n",
      "                           Estimator engine (default: fast_cpp)\n",
      "  --num-cores=INT          Parallel workers (default: detectCores()-1)\n",
      "  --publish                Publish the paper Figure 1 assets from the generated outputs\n",
      "  --help, -h               Show this help message\n\n",
      "The production Figure 1 regeneration path defaults to the paper settings:\n",
      "  type = OLS, prior = 60, T = 400 and 1600.\n",
      sep = ""
    )
    quit(save = "no", status = 0)
  }

  repo_root <- get_repo_root()
  source(file.path(repo_root, "code_base", "figure1_simulation.R"))

  result <- run_figure1_simulation(
    sim_size = opts$sim_size,
    sample_sizes = opts$sample_sizes,
    prior_pcts = opts$prior_pcts,
    type = opts$type,
    ndraws = opts$ndraws,
    engine = opts$engine,
    num_cores = opts$num_cores,
    project_root = repo_root,
    publish = opts$publish
  )

  cat("Figure 1 simulation outputs written under:\n")
  cat("  ", normalizePath(result$metadata$output_dir, winslash = "/", mustWork = FALSE), "\n", sep = "")
  if (!is.null(result$published)) {
    cat("Paper Figure 1 assets published to:\n")
    cat("  ", normalizePath(result$published$figures_dir, winslash = "/", mustWork = TRUE), "\n", sep = "")
    cat("LaTeX snippet written to:\n")
    cat("  ", normalizePath(result$published$latex_path, winslash = "/", mustWork = TRUE), "\n", sep = "")
  }
}

if (sys.nframe() == 0L) {
  main()
}
