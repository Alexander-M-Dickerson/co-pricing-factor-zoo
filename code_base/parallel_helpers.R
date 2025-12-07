#' Parallel Backend Helper Functions
#'
#' Platform-aware parallel backend selection to handle differences between
#' local machines (Windows/Mac/Linux) and server environments (RStudio Server).

#' Detect the Best Parallel Backend for Current Environment
#'
#' Automatically selects the optimal cluster type based on platform and
#' execution environment. Handles the common issue of PSOCK clusters hanging
#' on Windows or in certain IDE configurations.
#'
#' @param num_cores Number of cores requested
#' @param preferred Character: "auto", "PSOCK", "FORK", or "sequential"
#' @param verbose Print diagnostic messages
#' @return List with components:
#'   - type: "FORK", "PSOCK", or "sequential"
#'   - num_cores: Adjusted number of cores
#'   - reason: Explanation for the choice
#'
#' @details
#' Selection logic:
#' - Windows: Always uses PSOCK (FORK not supported)
#' - Linux/macOS + RStudio Server: Uses PSOCK (FORK unsafe in RStudio Server)
#' - Linux/macOS + Local: Uses FORK (fastest, avoids socket issues)
#' - User can override with `preferred` parameter
#'
#' @examples
#' \dontrun{
#'   backend <- detect_parallel_backend(num_cores = 4, verbose = TRUE)
#'   # Returns: list(type = "FORK", num_cores = 4, reason = "Unix local environment")
#' }
detect_parallel_backend <- function(num_cores = 4,
                                    preferred = "auto",
                                    verbose = TRUE) {

 preferred <- match.arg(preferred, c("auto", "PSOCK", "FORK", "sequential"))

  # If user explicitly requests sequential, honor it
 if (preferred == "sequential" || num_cores <= 1) {
    return(list(
      type = "sequential",
      num_cores = 1,
      reason = if (preferred == "sequential") "User requested sequential" else "Single core requested"
    ))
  }

  # Detect platform
  is_windows <- .Platform$OS.type == "windows"

  # Detect if running on RStudio Server
  # RStudio Server sets several environment variables we can check
  is_rstudio_server <- nzchar(Sys.getenv("RSTUDIO_HTTP_REFERER")) ||
                       nzchar(Sys.getenv("RSTUDIO_SESSION_PORT")) ||
                       (nzchar(Sys.getenv("RSTUDIO")) &&
                        !nzchar(Sys.getenv("RSTUDIO_CONSOLE_COLOR")))

  # Detect if running in RStudio Desktop (local)
  is_rstudio_desktop <- nzchar(Sys.getenv("RSTUDIO")) &&
                        nzchar(Sys.getenv("RSTUDIO_CONSOLE_COLOR"))

  # Detect if running in plain R terminal
  is_terminal <- !nzchar(Sys.getenv("RSTUDIO"))

  # Build environment description for diagnostics
  env_desc <- if (is_rstudio_server) {
    "RStudio Server"
  } else if (is_rstudio_desktop) {
    "RStudio Desktop"
  } else if (is_terminal) {
    "R terminal"
  } else {
    "Unknown R environment"
  }

  platform_desc <- if (is_windows) "Windows" else paste0(.Platform$OS.type, " (", Sys.info()["sysname"], ")")

  if (verbose) {
    message(sprintf("Parallel setup: %s on %s, %d cores requested",
                    env_desc, platform_desc, num_cores))
  }

  # User override (if not "auto")
  if (preferred == "FORK") {
    if (is_windows) {
      if (verbose) message("  WARNING: FORK not supported on Windows, using PSOCK")
      return(list(type = "PSOCK", num_cores = num_cores,
                  reason = "FORK requested but not available on Windows"))
    }
    return(list(type = "FORK", num_cores = num_cores,
                reason = "User requested FORK"))
  }

  if (preferred == "PSOCK") {
    return(list(type = "PSOCK", num_cores = num_cores,
                reason = "User requested PSOCK"))
  }

  # Auto-detection logic
  if (is_windows) {
    # Windows: PSOCK is the only option, but warn about potential issues
    if (verbose) {
      message("  Windows detected: using PSOCK (if hangs, try parallel_type='sequential')")
    }
    return(list(type = "PSOCK", num_cores = num_cores,
                reason = "Windows platform (FORK not supported)"))
  }

  # Unix-like systems (Linux, macOS)
  if (is_rstudio_server) {
    # RStudio Server: FORK can cause issues, use PSOCK
    if (verbose) {
      message("  RStudio Server detected: using PSOCK (FORK unsafe in server environment)")
    }
    return(list(type = "PSOCK", num_cores = num_cores,
                reason = "RStudio Server environment (FORK unsafe)"))
  }

  # Local Unix environment: FORK is best
  if (verbose) {
    message("  Local Unix environment: using FORK (fastest, no socket overhead)")
  }
  return(list(type = "FORK", num_cores = num_cores,
              reason = "Local Unix environment"))
}


#' Create Parallel Cluster with Timeout Protection
#'
#' Creates a parallel cluster with timeout protection to prevent infinite hangs.
#' Falls back to sequential execution if cluster creation fails or times out.
#'
#' @param backend Result from detect_parallel_backend()
#' @param timeout_seconds Seconds to wait for cluster creation (default: 30)
#' @param exports Character vector of variable names to export to workers
#' @param export_env Environment containing variables to export
#' @param verbose Print diagnostic messages
#' @return List with components:
#'   - cluster: The cluster object (or NULL if sequential)
#'   - has_cluster: Logical, TRUE if parallel cluster is active
#'   - cleanup: Function to call for cleanup (always call this on exit)
#'
#' @details
#' For PSOCK clusters, uses a timeout mechanism to detect hangs during
#' cluster creation. If the cluster doesn't initialize within timeout_seconds,
#' falls back to sequential execution.
#'
#' @examples
#' \dontrun{
#'   backend <- detect_parallel_backend(num_cores = 4)
#'   cluster_info <- create_parallel_cluster(
#'     backend,
#'     exports = c("my_data", "my_function"),
#'     export_env = environment()
#'   )
#'   on.exit(cluster_info$cleanup(), add = TRUE)
#'
#'   # Use foreach with the cluster...
#' }
create_parallel_cluster <- function(backend,
                                    timeout_seconds = 30,
                                    exports = NULL,
                                    export_env = parent.frame(),
                                    packages = c("BayesianFactorZoo", "MASS"),
                                    verbose = TRUE) {

  # Sequential mode - no cluster needed
  if (backend$type == "sequential") {
    foreach::registerDoSEQ()
    if (verbose) message("Running in sequential mode (", backend$reason, ")")
    return(list(
      cluster = NULL,
      has_cluster = FALSE,
      cleanup = function() invisible(NULL)
    ))
  }

  # Clamp BLAS threads to prevent nested parallelism issues
  Sys.setenv(OMP_NUM_THREADS = "1", MKL_NUM_THREADS = "1",
             OPENBLAS_NUM_THREADS = "1", VECLIB_MAXIMUM_THREADS = "1")

  cl <- NULL
  has_cluster <- FALSE

  # Try to create cluster with timeout protection
  cluster_result <- tryCatch({

    if (backend$type == "FORK") {
      # FORK clusters are fast and don't have socket issues
      if (verbose) message("Creating FORK cluster with ", backend$num_cores, " workers...")
      cl <- parallel::makeCluster(backend$num_cores, type = "FORK")
      has_cluster <- TRUE

    } else if (backend$type == "PSOCK") {
      # PSOCK clusters can hang - use timeout protection
      if (verbose) message("Creating PSOCK cluster with ", backend$num_cores, " workers (timeout: ", timeout_seconds, "s)...")

      # On Unix, we can use setTimeLimit; on Windows, we'll use a simpler approach
      if (.Platform$OS.type == "unix") {
        # Use setTimeLimit for timeout on Unix
        setTimeLimit(elapsed = timeout_seconds, transient = TRUE)
        on.exit(setTimeLimit(elapsed = Inf, transient = FALSE), add = TRUE)
      }

      # Create cluster - outfile=NULL suppresses worker output that can block
      cl <- parallel::makeCluster(
        backend$num_cores,
        type = "PSOCK",
        outfile = NULL  # Suppress output to prevent blocking
      )

      if (.Platform$OS.type == "unix") {
        setTimeLimit(elapsed = Inf, transient = FALSE)
      }

      has_cluster <- TRUE

      # Initialize workers
      if (verbose) message("Initializing workers...")
      parallel::clusterEvalQ(cl, {
        # Clamp threads inside workers too
        Sys.setenv(OMP_NUM_THREADS = "1", MKL_NUM_THREADS = "1",
                   OPENBLAS_NUM_THREADS = "1", VECLIB_MAXIMUM_THREADS = "1")
      })

      # Load packages on workers
      for (pkg in packages) {
        parallel::clusterCall(cl, library, pkg, character.only = TRUE, quietly = TRUE)
      }

      # Export variables to workers
      if (!is.null(exports) && length(exports) > 0) {
        parallel::clusterExport(cl, varlist = exports, envir = export_env)
      }
    }

    list(success = TRUE, error = NULL)

  }, error = function(e) {
    list(success = FALSE, error = e)
  })

  # Handle failure
  if (!cluster_result$success) {
    if (!is.null(cl)) {
      try(parallel::stopCluster(cl), silent = TRUE)
    }
    cl <- NULL
    has_cluster <- FALSE

    error_msg <- if (!is.null(cluster_result$error)) {
      conditionMessage(cluster_result$error)
    } else {
      "Unknown error"
    }

    if (verbose) {
      message("WARNING: Parallel cluster failed to start: ", error_msg)
      message("Falling back to sequential execution")
    }

    foreach::registerDoSEQ()
    return(list(
      cluster = NULL,
      has_cluster = FALSE,
      cleanup = function() invisible(NULL)
    ))
  }

  # Register cluster with doParallel
  doParallel::registerDoParallel(cl)
  if (verbose) message("Parallel backend registered with ", backend$num_cores, " cores (", backend$type, ")")

  # Create cleanup function
  cleanup_fn <- function() {
    if (!is.null(cl)) {
      tryCatch({
        doParallel::stopImplicitCluster()
      }, error = function(e) NULL)
      tryCatch({
        parallel::stopCluster(cl)
      }, error = function(e) NULL)
    }
    invisible(NULL)
  }

  return(list(
    cluster = cl,
    has_cluster = TRUE,
    cleanup = cleanup_fn
  ))
}


#' Restore BLAS Thread Environment Variables
#'
#' Restores BLAS/OpenMP thread environment variables to their original values
#' after parallel execution completes.
#'
#' @param old_threads Named vector from Sys.getenv() before modification
#' @return Invisible NULL
restore_thread_env <- function(old_threads) {
  thread_vars <- c("OMP_NUM_THREADS", "MKL_NUM_THREADS",
                   "OPENBLAS_NUM_THREADS", "VECLIB_MAXIMUM_THREADS")

  for (var in thread_vars) {
    if (!is.na(old_threads[var])) {
      do.call(Sys.setenv, setNames(list(old_threads[var]), var))
    } else {
      Sys.unsetenv(var)
    }
  }
  invisible(NULL)
}
