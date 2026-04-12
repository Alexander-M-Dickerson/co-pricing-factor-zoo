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

get_required_tex_packages <- function() {
  # CTAN package names required by base_document.txt and ia/_create_ia_latex.R.
  #
  # Mapping notes (LaTeX name -> CTAN name when different):
  #   \usepackage{tikz}        -> pgf
  #   \usepackage{pifont}      -> psnfss
  #   \usepackage{amsthm}      -> amscls
  #   \usepackage{graphicx}    -> graphics (bundle: also provides color, lscape)
  #   \usepackage{longtable}   -> tools    (bundle: also provides array)
  #   \usepackage{xparse}      -> l3packages
  #   \usepackage[utf8x]{...}  -> ucs
  c(
    # AMS mathematics
    "amsmath", "amsfonts", "amscls", "mathrsfs", "bm",
    # Fonts and encoding (cm-super for T1 Computer Modern, ucs for utf8x)
    "cm-super", "lmodern", "ucs", "psnfss",
    # Document structure
    "geometry", "setspace", "titlesec", "appendix", "etoc",
    "enumitem", "footmisc", "placeins", "chngcntr", "changepage",
    # Tables
    "booktabs", "multirow", "makecell",
    # Figures and graphics
    "pgf", "tikz-3dplot", "xcolor", "float", "wrapfig", "caption",
    # Text formatting
    "hyperref", "natbib", "ulem", "soul", "ragged2e",
    "dirtytalk", "quoting", "alphalph",
    # LaTeX bundles
    "tools",      # provides: array, longtable, calc, etc.
    "graphics",   # provides: graphicx, color, lscape, etc.
    "l3packages", # provides: xparse, xfp, etc.
    # Misc
    "layouts", "apptools"
  )
}

parse_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  opts <- list(
    check_only = FALSE,
    force = FALSE
  )

  for (arg in args) {
    if (identical(arg, "--check")) {
      opts$check_only <- TRUE
    } else if (identical(arg, "--force")) {
      opts$force <- TRUE
    } else if (identical(arg, "--help") || identical(arg, "-h")) {
      cat(
        "Usage: Rscript tools/bootstrap_latex.R [options]\n\n",
        "Options:\n",
        "  --check    Report LaTeX status without installing\n",
        "  --force    Install TinyTeX even if system LaTeX exists\n",
        "  --help     Show this help message\n",
        sep = ""
      )
      quit(save = "no", status = 0)
    } else {
      stop("Unknown argument: ", arg, call. = FALSE)
    }
  }

  opts
}

detect_latex <- function() {
  pdflatex <- Sys.which("pdflatex")
  bibtex <- Sys.which("bibtex")
  is_tinytex <- requireNamespace("tinytex", quietly = TRUE) &&
    tinytex::is_tinytex()

  list(
    pdflatex = unname(pdflatex),
    bibtex = unname(bibtex),
    has_pdflatex = nzchar(pdflatex),
    has_bibtex = nzchar(bibtex),
    is_tinytex = is_tinytex
  )
}

print_status <- function(status) {
  cat("pdflatex:  ",
      if (status$has_pdflatex) status$pdflatex else "not found", "\n", sep = "")
  cat("bibtex:    ",
      if (status$has_bibtex) status$bibtex else "not found", "\n", sep = "")
  cat("TinyTeX:   ",
      if (status$is_tinytex) "installed" else "not installed", "\n", sep = "")
}

main <- function() {
  opts <- parse_args()
  repo_root <- get_repo_root()

  cat("LaTeX bootstrap for The Co-Pricing Factor Zoo\n")
  cat("Repo root: ", repo_root, "\n\n", sep = "")

  # ---- 1. Detect current LaTeX status ----------------------------------------
  status <- detect_latex()
  cat("Current LaTeX status:\n")
  print_status(status)

  if (opts$check_only) {
    if (status$has_pdflatex) {
      cat("\nLaTeX is available.\n")
      quit(save = "no", status = 0)
    }
    cat("\nLaTeX is not available.\n")
    cat("Run `Rscript tools/bootstrap_latex.R` to install TinyTeX.\n")
    quit(save = "no", status = 1)
  }

  # ---- 2. Skip if system LaTeX exists (unless --force) -----------------------
  if (status$has_pdflatex && !opts$force) {
    cat("\nSystem LaTeX found. TinyTeX installation skipped.\n")
    cat("Use --force to install TinyTeX alongside your system LaTeX.\n")
    quit(save = "no", status = 0)
  }

  # ---- 3. Verify tinytex R package is available ------------------------------
  if (!requireNamespace("tinytex", quietly = TRUE)) {
    cat("\nERROR: R package 'tinytex' is not installed.\n")
    cat("Run `Rscript tools/bootstrap_packages.R` first.\n")
    quit(save = "no", status = 1)
  }

  # ---- 4. Install TinyTeX with required LaTeX packages -----------------------
  tex_packages <- get_required_tex_packages()

  if (status$is_tinytex && !opts$force) {
    cat("\nTinyTeX is already installed. Installing missing LaTeX packages...\n")
    cat("Installing ", length(tex_packages), " LaTeX packages...\n", sep = "")
    tryCatch(
      tinytex::tlmgr_install(tex_packages),
      error = function(e) {
        cat("ERROR: LaTeX package installation failed: ", conditionMessage(e), "\n",
            sep = "")
        cat("Check your network connection and try again.\n")
        quit(save = "no", status = 1)
      }
    )
  } else {
    cat("\nInstalling TinyTeX (~150MB download)...\n")
    tryCatch(
      tinytex::install_tinytex(
        force = opts$force,
        extra_packages = tex_packages,
        add_path = TRUE
      ),
      error = function(e) {
        cat("ERROR: TinyTeX installation failed: ", conditionMessage(e), "\n",
            sep = "")
        cat("Check your network connection and disk space, then try again.\n")
        quit(save = "no", status = 1)
      }
    )
  }

  # ---- 5. Verify pdflatex is now available -----------------------------------
  status_after <- detect_latex()
  if (!status_after$has_pdflatex) {
    cat("\nERROR: TinyTeX installed but pdflatex not found on PATH.\n")
    cat("You may need to restart your terminal for PATH changes to take effect.\n")
    sysname <- Sys.info()[["sysname"]]
    if (identical(sysname, "Linux")) {
      cat("Try: source ~/.profile\n")
    } else if (identical(sysname, "Darwin")) {
      cat("Try: source ~/.bash_profile  # or ~/.zprofile for zsh\n")
    } else if (identical(sysname, "Windows")) {
      cat("Try: restart your terminal or run 'refreshenv' if available.\n")
    }
    quit(save = "no", status = 1)
  }

  # ---- 6. Compile smoke test to verify everything works ----------------------
  smoke_tex <- file.path(repo_root, "testing", "latex_smoke", "main", "djm_main.tex")
  if (file.exists(smoke_tex)) {
    cat("\nVerifying: compiling smoke test...\n")
    smoke_dir <- dirname(smoke_tex)
    smoke_pdf <- file.path(smoke_dir, "djm_main.pdf")

    # Clean stale auxiliary files before compiling
    aux_patterns <- c("*.aux", "*.bbl", "*.blg", "*.log", "*.out", "*.pdf")
    for (pat in aux_patterns) {
      stale <- Sys.glob(file.path(smoke_dir, pat))
      if (length(stale) > 0) unlink(stale)
    }

    compile_ok <- tryCatch({
      tinytex::latexmk(
        smoke_tex,
        engine = "pdflatex",
        bib_engine = "bibtex",
        install_packages = TRUE,
        clean = TRUE
      )
      file.exists(smoke_pdf)
    }, error = function(e) {
      cat("  Compile error: ", conditionMessage(e), "\n", sep = "")
      FALSE
    })

    if (compile_ok) {
      cat("  Smoke test compiled successfully.\n")
    } else {
      cat("  WARNING: Smoke test compilation failed.\n")
      cat("  The full paper may still compile. Run tools/build_paper.sh to test.\n")
    }
  }

  # ---- 7. Report success -----------------------------------------------------
  cat("\nLaTeX bootstrap complete.\n")
  print_status(status_after)
}

if (sys.nframe() == 0) {
  main()
}
