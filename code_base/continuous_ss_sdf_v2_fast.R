continuous_ss_sdf_v2_fast_code_dir <- local({
  cached_dir <- NULL

  function() {
    if (!is.null(cached_dir) && dir.exists(cached_dir)) {
      return(cached_dir)
    }

    frame_ids <- rev(seq_along(sys.frames()))
    for (idx in frame_ids) {
      candidate <- sys.frames()[[idx]]$ofile
      if (!is.null(candidate) && file.exists(candidate)) {
        cached_dir <<- dirname(normalizePath(candidate, winslash = "/", mustWork = TRUE))
        return(cached_dir)
      }
    }

    fallback <- normalizePath(file.path(getwd(), "code_base"), winslash = "/", mustWork = FALSE)
    if (dir.exists(fallback)) {
      cached_dir <<- fallback
      return(cached_dir)
    }

    stop("Could not determine code_base directory for continuous_ss_sdf_v2_fast.")
  }
})

continuous_ss_sdf_v2_fast_cpp_state <- local({
  state <- new.env(parent = emptyenv())
  state$attempted <- FALSE
  state$compiled <- FALSE
  state$last_error <- NULL
  state$cpp_name <- "continuous_ss_sdf_v2_fast_cpp_impl"
  state$cpp_env <- new.env(parent = baseenv())
  state
})

prepare_continuous_ss_sdf_v2_fast_cpp_inputs <- function(f1,
                                                          f2,
                                                          R,
                                                          psi0 = 1,
                                                          r = 0.001,
                                                          intercept = TRUE) {
  f <- cbind(f1, f2)
  k1 <- ncol(f1)
  k2 <- ncol(f2)
  k <- k1 + k2
  N <- ncol(R) + k2
  t <- nrow(R)
  p <- k1 + N
  Y <- cbind(f, R)

  Sigma_ols <- stats::cov(Y)
  Corr_ols <- stats::cor(Y)
  sd_ols <- matrixStats::colSds(Y)
  mu_ols <- matrix(colMeans(Y), ncol = 1)

  BayesianFactorZoo:::check_input2(f, cbind(R, f2))

  ones_N <- matrix(1, nrow = N, ncol = 1)
  if (intercept) {
    beta_ols <- cbind(ones_N, Corr_ols[(k1 + 1):p, 1:k, drop = FALSE])
  } else {
    beta_ols <- Corr_ols[(k1 + 1):p, 1:k, drop = FALSE]
  }
  a_ols <- mu_ols[(1 + k1):p, , drop = FALSE] / sd_ols[(k1 + 1):p]
  beta_ols_xtx_inv <- chol2inv(chol(t(beta_ols) %*% beta_ols))
  Lambda_ols <- beta_ols_xtx_inv %*% t(beta_ols) %*% a_ols

  omega_init <- rep(0.5, k)
  gamma_init <- rbinom(prob = omega_init, n = k, size = 1)
  sigma2_init <- as.numeric(
    (1 / N) * t(a_ols - beta_ols %*% Lambda_ols) %*% (a_ols - beta_ols %*% Lambda_ols)
  )

  rho <- Corr_ols[(k1 + 1):p, 1:k, drop = FALSE]
  if (intercept) {
    rho.demean <- rho - ones_N %*% matrix(colMeans(rho), nrow = 1)
  } else {
    rho.demean <- rho
  }

  psi <- if (k == 1) {
    psi0 * c(t(rho.demean) %*% rho.demean)
  } else {
    psi0 * diag(t(rho.demean) %*% rho.demean)
  }

  list(
    f = f,
    k1 = k1,
    k2 = k2,
    mu_ols = as.numeric(mu_ols),
    Sigma_ols = Sigma_ols,
    psi = as.numeric(psi),
    f_sd = as.numeric(matrixStats::colSds(f)),
    omega_init = as.numeric(omega_init),
    gamma_init = as.numeric(gamma_init),
    sigma2_init = sigma2_init
  )
}

load_continuous_ss_sdf_v2_fast_cpp <- function(force_rebuild = FALSE) {
  state <- continuous_ss_sdf_v2_fast_cpp_state

  if (!force_rebuild &&
      isTRUE(state$compiled) &&
      exists(state$cpp_name, envir = state$cpp_env, inherits = FALSE)) {
    return(TRUE)
  }

  if (isTRUE(state$attempted) && !force_rebuild) {
    return(FALSE)
  }

  state$attempted <- TRUE
  state$compiled <- FALSE
  state$last_error <- NULL

  if (!requireNamespace("Rcpp", quietly = TRUE) ||
      !requireNamespace("RcppArmadillo", quietly = TRUE)) {
    state$last_error <- "Rcpp and RcppArmadillo are required for the C++ backend."
    return(FALSE)
  }

  old_path <- Sys.getenv("PATH")
  on.exit(Sys.setenv(PATH = old_path), add = TRUE)

  if (.Platform$OS.type == "windows") {
    candidate_paths <- c(
      "C:/rtools45/usr/bin",
      "C:/rtools45/x86_64-w64-mingw32.static.posix/bin"
    )
    existing_paths <- candidate_paths[dir.exists(candidate_paths)]
    if (length(existing_paths) > 0) {
      Sys.setenv(PATH = paste(c(existing_paths, old_path), collapse = .Platform$path.sep))
    }
  }

  cpp_file <- file.path(continuous_ss_sdf_v2_fast_code_dir(), "continuous_ss_sdf_v2_fast.cpp")
  if (!file.exists(cpp_file)) {
    state$last_error <- paste("C++ backend file not found:", cpp_file)
    return(FALSE)
  }

  compiled_ok <- tryCatch({
    Rcpp::sourceCpp(
      file = cpp_file,
      env = state$cpp_env,
      rebuild = force_rebuild,
      showOutput = FALSE,
      verbose = FALSE
    )
    exists(state$cpp_name, envir = state$cpp_env, inherits = FALSE)
  }, error = function(e) {
    state$last_error <- conditionMessage(e)
    FALSE
  })

  state$compiled <- compiled_ok
  if (!compiled_ok && is.null(state$last_error)) {
    state$last_error <- "C++ backend compiled without exporting continuous_ss_sdf_v2_fast_cpp_impl."
  }

  compiled_ok
}

continuous_ss_sdf_v2_fast_cpp_error <- function() {
  continuous_ss_sdf_v2_fast_cpp_state$last_error
}

continuous_ss_sdf_v2_fast_cpp_function <- function() {
  state <- continuous_ss_sdf_v2_fast_cpp_state
  if (!exists(state$cpp_name, envir = state$cpp_env, inherits = FALSE)) {
    stop("continuous_ss_sdf_v2_fast_cpp_impl is not loaded.", call. = FALSE)
  }

  get(state$cpp_name, envir = state$cpp_env, inherits = FALSE)
}

continuous_ss_sdf_v2_fast_backend_status <- function() {
  state <- continuous_ss_sdf_v2_fast_cpp_state
  list(
    attempted = isTRUE(state$attempted),
    compiled = isTRUE(state$compiled),
    last_error = state$last_error
  )
}

continuous_ss_sdf_v2_fast_r <- function(f1,
                                        f2,
                                        R,
                                        sim_length,
                                        psi0 = 1,
                                        r = 0.001,
                                        aw = 1,
                                        bw = 1,
                                        type = "OLS",
                                        intercept = TRUE) {
  f <- cbind(f1, f2)
  k1 <- ncol(f1)
  k2 <- ncol(f2)
  k <- k1 + k2
  N <- ncol(R) + k2
  t <- nrow(R)
  p <- k1 + N
  Y <- cbind(f, R)

  Sigma_ols <- stats::cov(Y)
  Corr_ols <- stats::cor(Y)
  sd_ols <- matrixStats::colSds(Y)
  mu_ols <- matrix(colMeans(Y), ncol = 1)

  BayesianFactorZoo:::check_input2(f, cbind(R, f2))

  if (intercept) {
    lambda_path <- matrix(0, ncol = 1 + k, nrow = sim_length)
  } else {
    lambda_path <- matrix(0, ncol = k, nrow = sim_length)
  }
  gamma_path <- matrix(0, ncol = k, nrow = sim_length)
  sdf_path <- matrix(0, ncol = t, nrow = sim_length)

  ones_N <- matrix(1, nrow = N, ncol = 1)
  if (intercept) {
    beta_ols <- cbind(ones_N, Corr_ols[(k1 + 1):p, 1:k, drop = FALSE])
  } else {
    beta_ols <- Corr_ols[(k1 + 1):p, 1:k, drop = FALSE]
  }
  a_ols <- mu_ols[(1 + k1):p, , drop = FALSE] / sd_ols[(k1 + 1):p]
  beta_ols_xtx_inv <- chol2inv(chol(t(beta_ols) %*% beta_ols))
  Lambda_ols <- beta_ols_xtx_inv %*% t(beta_ols) %*% a_ols
  omega <- rep(0.5, k)
  gamma <- rbinom(prob = omega, n = k, size = 1)
  sigma2 <- as.vector(
    (1 / N) * t(a_ols - beta_ols %*% Lambda_ols) %*% (a_ols - beta_ols %*% Lambda_ols)
  )
  r_gamma <- ifelse(gamma == 1, 1, r)

  rho <- Corr_ols[(k1 + 1):p, 1:k, drop = FALSE]
  if (intercept) {
    rho.demean <- rho - ones_N %*% matrix(colMeans(rho), nrow = 1)
  } else {
    rho.demean <- rho
  }

  if (k == 1) {
    psi <- psi0 * c(t(rho.demean) %*% rho.demean)
  } else {
    psi <- psi0 * diag(t(rho.demean) %*% rho.demean)
  }

  f_sd <- matrixStats::colSds(f)
  is_gls <- identical(type, "GLS")
  lambda_dim <- if (intercept) (k + 1) else k
  sigma_shape <- if (intercept) {
    (N + k + 1) / 2
  } else {
    (N + k) / 2
  }
  wishart_scale_inv <- solve(t * Sigma_ols)
  wishart_scale_chol <- chol(wishart_scale_inv)
  chi_df <- (t - 1):(t - p)
  upper_idx <- if (p > 1) {
    pseq <- 1:(p - 1)
    rep(p * pseq, pseq) + unlist(lapply(pseq, seq))
  } else {
    integer(0)
  }

  for (i in seq_len(sim_length)) {
    set.seed(i)

    Z <- matrix(0, p, p)
    diag(Z) <- sqrt(stats::rchisq(p, chi_df))
    if (p > 1) {
      Z[upper_idx] <- stats::rnorm(p * (p - 1) / 2)
    }
    Sigma <- solve(crossprod(Z %*% wishart_scale_chol))
    Var_mu_half <- chol(Sigma / t)
    mu <- mu_ols + t(Var_mu_half) %*% matrix(stats::rnorm(p), ncol = 1)
    sd_Y <- matrix(sqrt(diag(Sigma)), ncol = 1)
    corr_Y <- Sigma / (sd_Y %*% t(sd_Y))
    C_f <- corr_Y[(k1 + 1):p, 1:k, drop = FALSE]
    a <- mu[(1 + k1):p, 1, drop = FALSE] / sd_Y[(1 + k1):p]
    if (intercept) {
      beta <- cbind(ones_N, C_f)
    } else {
      beta <- matrix(C_f, nrow = N)
    }
    corrR <- corr_Y[(k1 + 1):p, (k1 + 1):p, drop = FALSE]

    if (intercept) {
      D <- diag(c(1 / 100000, 1 / (r_gamma * psi)))
    } else if (k == 1) {
      D <- matrix(1 / (r_gamma * psi))
    } else {
      D <- diag(1 / (r_gamma * psi))
    }

    if (is_gls) {
      corrR_inv <- solve(corrR)
      beta_D_inv <- chol2inv(chol(t(beta) %*% corrR_inv %*% beta + D))
      cov_Lambda <- sigma2 * beta_D_inv
      Lambda_hat <- beta_D_inv %*% t(beta) %*% corrR_inv %*% a
    } else {
      beta_D_inv <- chol2inv(chol(t(beta) %*% beta + D))
      cov_Lambda <- sigma2 * beta_D_inv
      Lambda_hat <- beta_D_inv %*% t(beta) %*% a
    }

    Lambda <- Lambda_hat + t(chol(cov_Lambda)) %*% matrix(stats::rnorm(lambda_dim), ncol = 1)

    if (intercept) {
      Lambda_factors <- Lambda[2:(k + 1)]
      log.odds <- log(omega / (1 - omega)) +
        0.5 * log(r) +
        0.5 * Lambda_factors^2 * (1 / r - 1) / (sigma2 * psi)
    } else {
      Lambda_factors <- Lambda
      log.odds <- log(omega / (1 - omega)) +
        0.5 * log(r) +
        0.5 * c(Lambda)^2 * (1 / r - 1) / (sigma2 * psi)
    }

    odds <- exp(log.odds)
    odds <- ifelse(odds > 1000, 1000, odds)
    prob <- odds / (1 + odds)
    gamma <- rbinom(prob = prob, n = k, size = 1)
    r_gamma <- ifelse(gamma == 1, 1, r)
    gamma_path[i, ] <- gamma

    omega <- rbeta(k, aw + gamma, bw + 1 - gamma)

    resid <- a - beta %*% Lambda
    penalty <- t(Lambda) %*% D %*% Lambda
    if (is_gls) {
      sigma2 <- MCMCpack::rinvgamma(
        1,
        shape = sigma_shape,
        scale = (t(resid) %*% corrR_inv %*% resid + penalty) / 2
      )
    } else {
      sigma2 <- MCMCpack::rinvgamma(
        1,
        shape = sigma_shape,
        scale = (t(resid) %*% resid + penalty) / 2
      )
    }

    lambda_path[i, ] <- as.vector(Lambda)
    sdf_row <- as.vector(1 - f %*% (Lambda_factors / f_sd))
    sdf_path[i, ] <- 1 + sdf_row - mean(sdf_row)
  }

  list(
    gamma_path = gamma_path,
    lambda_path = lambda_path,
    sdf_path = sdf_path,
    bma_sdf = colMeans(sdf_path)
  )
}

continuous_ss_sdf_v2_fast_cpp <- function(f1,
                                          f2,
                                          R,
                                          sim_length,
                                          psi0 = 1,
                                          r = 0.001,
                                          aw = 1,
                                          bw = 1,
                                          type = "OLS",
                                          intercept = TRUE,
                                          force_rebuild = FALSE) {
  if (!load_continuous_ss_sdf_v2_fast_cpp(force_rebuild = force_rebuild)) {
    error_message <- continuous_ss_sdf_v2_fast_cpp_error()
    if (is.null(error_message) || length(error_message) == 0) {
      error_message <- "C++ backend failed to compile or load."
    }
    stop(error_message, call. = FALSE)
  }

  cpp_inputs <- prepare_continuous_ss_sdf_v2_fast_cpp_inputs(
    f1 = f1,
    f2 = f2,
    R = R,
    psi0 = psi0,
    r = r,
    intercept = intercept
  )
  cpp_impl <- continuous_ss_sdf_v2_fast_cpp_function()

  result <- cpp_impl(
    f = cpp_inputs$f,
    R = R,
    mu_ols = cpp_inputs$mu_ols,
    Sigma_ols = cpp_inputs$Sigma_ols,
    psi = cpp_inputs$psi,
    f_sd = cpp_inputs$f_sd,
    omega_init = cpp_inputs$omega_init,
    gamma_init = cpp_inputs$gamma_init,
    sigma2_init = cpp_inputs$sigma2_init,
    k1 = cpp_inputs$k1,
    k2 = cpp_inputs$k2,
    sim_length = sim_length,
    r = r,
    aw = aw,
    bw = bw,
    type = type,
    intercept = intercept
  )
  attr(result, "backend_used") <- "cpp"
  result
}

continuous_ss_sdf_v2_fast <- function(f1,
                                      f2,
                                      R,
                                      sim_length,
                                      psi0 = 1,
                                      r = 0.001,
                                      aw = 1,
                                      bw = 1,
                                      type = "OLS",
                                      intercept = TRUE,
                                      backend = c("auto", "cpp", "r"),
                                      force_rebuild = FALSE) {
  backend <- match.arg(backend)

  if (!identical(backend, "r")) {
    cpp_result <- tryCatch(
      continuous_ss_sdf_v2_fast_cpp(
        f1 = f1,
        f2 = f2,
        R = R,
        sim_length = sim_length,
        psi0 = psi0,
        r = r,
        aw = aw,
        bw = bw,
        type = type,
        intercept = intercept,
        force_rebuild = force_rebuild
      ),
      error = function(e) {
        continuous_ss_sdf_v2_fast_cpp_state$last_error <- conditionMessage(e)
        NULL
      }
    )
    if (!is.null(cpp_result)) {
      return(cpp_result)
    }
    if (identical(backend, "cpp")) {
      error_message <- continuous_ss_sdf_v2_fast_cpp_error()
      if (is.null(error_message) || length(error_message) == 0) {
        error_message <- "C++ backend failed to compile or load."
      }
      stop(error_message, call. = FALSE)
    }
  }

  result <- continuous_ss_sdf_v2_fast_r(
    f1 = f1,
    f2 = f2,
    R = R,
    sim_length = sim_length,
    psi0 = psi0,
    r = r,
    aw = aw,
    bw = bw,
    type = type,
    intercept = intercept
  )
  attr(result, "backend_used") <- "r"
  result
}
