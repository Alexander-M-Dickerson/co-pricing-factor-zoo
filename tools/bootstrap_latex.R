#!/usr/bin/env Rscript

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || is.na(x)) {
    y
  } else {
    x
  }
}

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
  #   \usepackage{tikz}            -> pgf
  #   \usepackage{pifont}          -> psnfss
  #   \usepackage{amsthm}          -> amscls
  #   \usepackage{mathrsfs}        -> jknapltx (sty) + rsfs (fonts)
  #   \usepackage{graphicx}        -> graphics (bundle: also provides color, lscape)
  #   \usepackage{longtable}       -> tools    (bundle: also provides array)
  #   \usepackage{xparse}          -> l3packages
  #   \usepackage[utf8x]{...}      -> ucs
  #   \usepackage[table]{xcolor}   -> xcolor + colortbl (table option loads colortbl)
  c(
    # AMS mathematics
    "amsmath", "amsfonts", "amscls", "jknapltx", "rsfs", "bm",
    # Fonts and encoding (cm-super for T1 Computer Modern, ucs for utf8x)
    "cm-super", "lmodern", "ucs", "psnfss",
    # Document structure
    "geometry", "setspace", "titlesec", "appendix", "etoc",
    "enumitem", "footmisc", "placeins", "chngcntr", "changepage",
    # Tables
    "booktabs", "multirow", "makecell",
    # Figures and graphics
    "pgf", "tikz-3dplot", "xcolor", "colortbl", "float", "wrapfig", "caption",
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

dir_has_command <- function(path, command_name) {
  any(file.exists(file.path(path, c(command_name, paste0(command_name, ".exe")))))
}

prepend_path_entries <- function(paths) {
  paths <- unique(paths[nzchar(paths)])
  paths <- paths[file.exists(paths)]
  if (length(paths) == 0) {
    return(invisible(FALSE))
  }

  current_path <- Sys.getenv("PATH", unset = "")
  current_entries <- strsplit(current_path, .Platform$path.sep, fixed = TRUE)[[1]]
  current_entries <- current_entries[nzchar(current_entries)]
  new_entries <- paths[!paths %in% current_entries]
  if (length(new_entries) == 0) {
    return(invisible(FALSE))
  }

  Sys.setenv(PATH = paste(c(new_entries, current_entries), collapse = .Platform$path.sep))
  invisible(TRUE)
}

find_tinytex_bin_dirs <- function() {
  appdata_dir <- Sys.getenv("APPDATA", unset = "")
  patterns <- c(
    file.path(path.expand("~"), ".TinyTeX", "bin", "*"),
    file.path(path.expand("~"), "Library", "TinyTeX", "bin", "*"),
    if (nzchar(appdata_dir)) file.path(appdata_dir, "TinyTeX", "bin", "windows")
  )
  dirs <- unlist(lapply(patterns[nzchar(patterns)], Sys.glob), use.names = FALSE)

  if (requireNamespace("tinytex", quietly = TRUE)) {
    tinytex_root <- tryCatch(tinytex::tinytex_root(), error = function(e) "")
    if (nzchar(tinytex_root)) {
      dirs <- c(dirs, Sys.glob(file.path(tinytex_root, "bin", "*")))
    }
  }

  unique(dirs[vapply(dirs, dir_has_command, logical(1), command_name = "pdflatex")])
}

prepend_tinytex_to_path <- function() {
  prepend_path_entries(find_tinytex_bin_dirs())
}

copy_smoke_fixture <- function(repo_root) {
  smoke_dir <- file.path(repo_root, "testing", "latex_smoke", "main")
  if (!dir.exists(smoke_dir)) {
    stop("LaTeX smoke fixture is missing: ", smoke_dir, call. = FALSE)
  }

  target_dir <- tempfile("latex-smoke-")
  dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)
  fixture_files <- list.files(smoke_dir, all.files = TRUE, no.. = TRUE, full.names = TRUE)
  copied <- file.copy(fixture_files, target_dir, recursive = TRUE)
  if (!all(copied)) {
    stop("Failed to copy the LaTeX smoke fixture into a temporary directory.", call. = FALSE)
  }

  target_dir
}

tail_output <- function(text, n = 12L) {
  if (!nzchar(text)) {
    return("")
  }

  lines <- strsplit(text, "\n", fixed = TRUE)[[1]]
  paste(utils::tail(lines[nzchar(lines)], n), collapse = "\n")
}

run_latex_command <- function(command, args, working_dir) {
  old_wd <- getwd()
  on.exit(setwd(old_wd), add = TRUE)
  setwd(working_dir)

  output <- tryCatch(
    system2(command, args = args, stdout = TRUE, stderr = TRUE),
    error = function(e) structure(conditionMessage(e), status = 1L)
  )
  status <- as.integer(attr(output, "status") %||% 0L)
  list(
    ok = identical(status, 0L),
    status = status,
    output = paste(output, collapse = "\n")
  )
}

compile_smoke_fixture <- function(repo_root, status) {
  if (!status$has_pdflatex || !status$has_bibtex) {
    missing <- c(
      if (!status$has_pdflatex) "pdflatex",
      if (!status$has_bibtex) "bibtex"
    )
    return(list(
      ok = FALSE,
      detail = paste("Missing required LaTeX command(s):", paste(missing, collapse = ", "))
    ))
  }

  target_dir <- copy_smoke_fixture(repo_root)
  on.exit(unlink(target_dir, recursive = TRUE, force = TRUE), add = TRUE)

  steps <- list(
    list(name = "pdflatex", command = status$pdflatex, args = c("-interaction=nonstopmode", "-halt-on-error", "djm_main.tex")),
    list(name = "bibtex", command = status$bibtex, args = "djm_main"),
    list(name = "pdflatex", command = status$pdflatex, args = c("-interaction=nonstopmode", "-halt-on-error", "djm_main.tex")),
    list(name = "pdflatex", command = status$pdflatex, args = c("-interaction=nonstopmode", "-halt-on-error", "djm_main.tex"))
  )

  for (step in steps) {
    result <- run_latex_command(step$command, step$args, target_dir)
    if (!result$ok) {
      detail <- paste0(
        step$name, " failed with status ", result$status, "."
      )
      output_tail <- tail_output(result$output)
      if (nzchar(output_tail)) {
        detail <- paste(detail, output_tail, sep = "\n")
      }
      return(list(ok = FALSE, detail = detail))
    }
  }

  pdf_path <- file.path(target_dir, "djm_main.pdf")
  if (!file.exists(pdf_path)) {
    return(list(
      ok = FALSE,
      detail = "The LaTeX smoke fixture finished without producing djm_main.pdf."
    ))
  }

  list(ok = TRUE, detail = "Smoke test compiled successfully.")
}

main <- function() {
  opts <- parse_args()
  repo_root <- get_repo_root()

  prepend_tinytex_to_path()

  cat("LaTeX bootstrap for The Co-Pricing Factor Zoo\n")
  cat("Repo root: ", repo_root, "\n\n", sep = "")

  # ---- 1. Detect current LaTeX status ----------------------------------------
  status <- detect_latex()
  smoke_result <- compile_smoke_fixture(repo_root, status)
  cat("Current LaTeX status:\n")
  print_status(status)
  cat("smoke test:", if (smoke_result$ok) "passed" else "failed", "\n")

  if (opts$check_only) {
    if (smoke_result$ok) {
      cat("\nLaTeX is available and passed the smoke compile.\n")
      quit(save = "no", status = 0)
    }
    cat("\nLaTeX is not ready for final PDF assembly.\n")
    if (nzchar(smoke_result$detail)) {
      cat(smoke_result$detail, "\n", sep = "")
    }
    cat("Run `Rscript tools/bootstrap_latex.R` to install or repair TinyTeX.\n")
    quit(save = "no", status = 1)
  }

  # ---- 2. Skip if system LaTeX exists (unless --force) -----------------------
  if (smoke_result$ok && !opts$force) {
    cat("\nWorking LaTeX installation found. TinyTeX installation skipped.\n")
    if (status$is_tinytex) {
      cat("Use --force to reinstall TinyTeX.\n")
    } else {
      cat("Use --force to install TinyTeX alongside your system LaTeX.\n")
    }
    quit(save = "no", status = 0)
  }

  if ((status$has_pdflatex || status$has_bibtex) && !smoke_result$ok) {
    cat("\nDetected LaTeX commands, but the smoke compile failed.\n")
    if (nzchar(smoke_result$detail)) {
      cat(smoke_result$detail, "\n", sep = "")
    }
    cat("Installing TinyTeX alongside the existing LaTeX distribution.\n")
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
        force = opts$force || (status$has_pdflatex || status$has_bibtex),
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

  prepend_tinytex_to_path()

  # ---- 5. Verify pdflatex and bibtex are now available -----------------------
  status_after <- detect_latex()
  if (!status_after$has_pdflatex || !status_after$has_bibtex) {
    missing <- c(
      if (!status_after$has_pdflatex) "pdflatex",
      if (!status_after$has_bibtex) "bibtex"
    )
    cat("\nERROR: TinyTeX installed but required command(s) were not found on PATH: ",
        paste(missing, collapse = ", "), "\n", sep = "")
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
  cat("\nVerifying: compiling smoke test...\n")
  smoke_after <- compile_smoke_fixture(repo_root, status_after)
  if (!smoke_after$ok) {
    cat("ERROR: The LaTeX smoke compile failed after bootstrap.\n")
    if (nzchar(smoke_after$detail)) {
      cat(smoke_after$detail, "\n", sep = "")
    }
    quit(save = "no", status = 1)
  }
  cat("Smoke test compiled successfully.\n")

  # ---- 7. Report success -----------------------------------------------------
  cat("\nLaTeX bootstrap complete.\n")
  print_status(status_after)
}

if (sys.nframe() == 0) {
  main()
}
