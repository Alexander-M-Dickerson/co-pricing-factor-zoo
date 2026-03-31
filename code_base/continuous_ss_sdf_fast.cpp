// Paper role: Fast C++ kernel for the baseline no-self-pricing BHJ sampler.
// Paper refs: Eq. (1), Eq. (5), Eq. (7)-(8), Appendix B;
// docs/paper/co-pricing-factor-zoo.ai-optimized.md

// [[Rcpp::depends(RcppArmadillo)]]

#include <RcppArmadillo.h>

namespace {

arma::mat invert_spd(const arma::mat& x, const std::string& label) {
  arma::mat sym_x = 0.5 * (x + x.t());
  arma::mat out;
  if (arma::inv_sympd(out, sym_x)) {
    return out;
  }
  if (arma::inv(out, x)) {
    return out;
  }
  Rcpp::stop("Matrix inversion failed for %s.", label);
}

double rinvgamma_one(double shape, double scale) {
  const double gamma_draw = R::rgamma(shape, 1.0 / scale);
  if (!R_finite(gamma_draw) || gamma_draw <= 0.0) {
    Rcpp::stop("Inverse-gamma draw failed.");
  }
  return 1.0 / gamma_draw;
}

void fill_standard_normals(arma::vec& out) {
  for (arma::uword i = 0; i < out.n_elem; ++i) {
    out[i] = R::rnorm(0.0, 1.0);
  }
}

void fill_upper_bartlett_diag(arma::vec& diag_draws, const arma::vec& chi_df) {
  for (arma::uword i = 0; i < chi_df.n_elem; ++i) {
    diag_draws[i] = std::sqrt(R::rchisq(chi_df[i]));
  }
}

}  // namespace

// [[Rcpp::export]]
Rcpp::List continuous_ss_sdf_fast_cpp_impl(const arma::mat& f,
                                           const arma::mat& R,
                                           const arma::vec& mu_ols,
                                           const arma::mat& Sigma_ols,
                                           const arma::vec& psi,
                                           const arma::vec& f_sd,
                                           arma::vec omega_init,
                                           arma::vec gamma_init,
                                           double sigma2_init,
                                           int sim_length,
                                           double r,
                                           double aw,
                                           double bw,
                                           const std::string& type,
                                           bool intercept) {
  Rcpp::RNGScope scope;

  const int n_periods = R.n_rows;
  const int k = f.n_cols;
  const int N = R.n_cols;
  const int p = k + N;
  const int lambda_dim = intercept ? (k + 1) : k;
  const bool is_gls = (type == "GLS");

  if (mu_ols.n_elem != static_cast<arma::uword>(p)) {
    Rcpp::stop("mu_ols has length %d but expected %d.", static_cast<int>(mu_ols.n_elem), p);
  }
  if (Sigma_ols.n_rows != static_cast<arma::uword>(p) || Sigma_ols.n_cols != static_cast<arma::uword>(p)) {
    Rcpp::stop("Sigma_ols has dimension %d x %d but expected %d x %d.",
               static_cast<int>(Sigma_ols.n_rows), static_cast<int>(Sigma_ols.n_cols), p, p);
  }
  if (psi.n_elem != static_cast<arma::uword>(k)) {
    Rcpp::stop("psi has length %d but expected %d.", static_cast<int>(psi.n_elem), k);
  }
  if (f_sd.n_elem != static_cast<arma::uword>(k)) {
    Rcpp::stop("f_sd has length %d but expected %d.", static_cast<int>(f_sd.n_elem), k);
  }

  arma::mat gamma_path_t(k, sim_length, arma::fill::zeros);
  arma::mat lambda_path_t(lambda_dim, sim_length, arma::fill::zeros);
  arma::mat sdf_path_t(n_periods, sim_length, arma::fill::zeros);

  arma::vec omega = omega_init;
  arma::vec gamma = gamma_init;
  double sigma2 = sigma2_init;
  arma::vec r_gamma = arma::conv_to<arma::vec>::from(gamma == 1.0);
  r_gamma.transform([&](double val) { return (val == 1.0) ? 1.0 : r; });

  const double sigma_shape = intercept ? (N + k + 1.0) / 2.0 : (N + k) / 2.0;

  arma::vec chi_df(p);
  for (int idx = 0; idx < p; ++idx) {
    chi_df[idx] = static_cast<double>(n_periods - idx - 1);
  }

  const arma::mat wishart_scale_inv = invert_spd(static_cast<double>(n_periods) * Sigma_ols, "t * Sigma_ols");
  const arma::mat wishart_scale_chol = arma::chol(wishart_scale_inv);
  const arma::vec ones_N = arma::ones<arma::vec>(N);

  Rcpp::Environment base_env("package:base");
  Rcpp::Function set_seed = base_env["set.seed"];

  // Pre-allocate all loop temporaries
  arma::mat Z(p, p, arma::fill::zeros);
  arma::vec bartlett_diag(p);
  arma::vec z_mu(p);
  arma::vec z_lambda(lambda_dim);
  arma::mat beta(N, lambda_dim);
  arma::mat D(lambda_dim, lambda_dim);
  arma::mat beta_D_inv(lambda_dim, lambda_dim);
  arma::vec Lambda_hat(lambda_dim);
  arma::mat corrR_inv(N, N);

  for (int draw = 0; draw < sim_length; ++draw) {
    if ((draw + 1) % 1000 == 0) {
      Rcpp::checkUserInterrupt();
    }

    set_seed(draw + 1);

    Z.zeros();
    fill_upper_bartlett_diag(bartlett_diag, chi_df);
    Z.diag() = bartlett_diag;
    for (int col = 1; col < p; ++col) {
      for (int row = 0; row < col; ++row) {
        Z(row, col) = R::rnorm(0.0, 1.0);
      }
    }

    const arma::mat W = Z * wishart_scale_chol;
    const arma::mat Sigma = invert_spd(W.t() * W, "Wishart draw");
    const arma::mat Var_mu_half = arma::chol(Sigma / static_cast<double>(n_periods));
    fill_standard_normals(z_mu);
    const arma::vec mu = mu_ols + Var_mu_half.t() * z_mu;
    const arma::vec sd_Y = arma::sqrt(Sigma.diag());
    const arma::mat corr_scale = sd_Y * sd_Y.t();
    const arma::mat corr_Y = Sigma % (1.0 / corr_scale);
    const arma::mat C_f = corr_Y.submat(k, 0, p - 1, k - 1);
    const arma::vec a = mu.subvec(k, p - 1) / sd_Y.subvec(k, p - 1);

    beta.zeros();
    if (intercept) {
      beta.col(0) = ones_N;
      beta.cols(1, k) = C_f;
    } else {
      beta = C_f;
    }

    const arma::mat corrR = corr_Y.submat(k, k, p - 1, p - 1);

    // Paper: D is the diagonal prior precision matrix for lambda. In the
    // baseline kernel it follows Eq. (5) with spike-and-slab scaling r_gamma.
    D.zeros();
    if (intercept) {
      D(0, 0) = 1.0 / 100000.0;
      for (int idx = 0; idx < k; ++idx) {
        D(idx + 1, idx + 1) = 1.0 / (r_gamma[idx] * psi[idx]);
      }
    } else {
      for (int idx = 0; idx < k; ++idx) {
        D(idx, idx) = 1.0 / (r_gamma[idx] * psi[idx]);
      }
    }

    if (is_gls) {
      corrR_inv = invert_spd(corrR, "corrR");
      beta_D_inv = invert_spd(beta.t() * corrR_inv * beta + D, "beta GLS system");
      Lambda_hat = beta_D_inv * beta.t() * corrR_inv * a;
    } else {
      beta_D_inv = invert_spd(beta.t() * beta + D, "beta OLS system");
      Lambda_hat = beta_D_inv * beta.t() * a;
    }

    const arma::mat cov_Lambda = sigma2 * beta_D_inv;
    fill_standard_normals(z_lambda);
    const arma::vec Lambda = Lambda_hat + arma::chol(cov_Lambda).t() * z_lambda;

    arma::vec Lambda_factors;
    arma::vec lambda_for_log_odds;
    if (intercept) {
      Lambda_factors = Lambda.subvec(1, k);
      lambda_for_log_odds = Lambda_factors;
    } else {
      Lambda_factors = Lambda;
      lambda_for_log_odds = Lambda;
    }

    arma::vec log_odds = arma::log(omega / (1.0 - omega)) +
      0.5 * std::log(r) +
      0.5 * arma::square(lambda_for_log_odds) * (1.0 / r - 1.0) / (sigma2 * psi);
    arma::vec odds = arma::exp(log_odds);
    odds.transform([](double value) { return value > 1000.0 ? 1000.0 : value; });
    const arma::vec prob = odds / (1.0 + odds);

    for (int idx = 0; idx < k; ++idx) {
      gamma[idx] = R::rbinom(1.0, prob[idx]);
    }
    r_gamma = arma::conv_to<arma::vec>::from(gamma == 1.0);
    r_gamma.transform([&](double val) { return (val == 1.0) ? 1.0 : r; });
    gamma_path_t.col(draw) = gamma;

    for (int idx = 0; idx < k; ++idx) {
      omega[idx] = R::rbeta(aw + gamma[idx], bw + 1.0 - gamma[idx]);
    }

    const arma::vec resid = a - beta * Lambda;
    const double penalty = arma::as_scalar(Lambda.t() * D * Lambda);
    const double scale_term = is_gls
      ? 0.5 * (arma::as_scalar(resid.t() * corrR_inv * resid) + penalty)
      : 0.5 * (arma::dot(resid, resid) + penalty);
    sigma2 = rinvgamma_one(sigma_shape, scale_term);

    lambda_path_t.col(draw) = Lambda;
    const arma::vec sdf_raw = 1.0 - f * (Lambda_factors / f_sd);
    sdf_path_t.col(draw) = 1.0 + sdf_raw - arma::mean(sdf_raw);
  }

  const arma::mat gamma_path = gamma_path_t.t();
  const arma::mat lambda_path = lambda_path_t.t();
  const arma::mat sdf_path = sdf_path_t.t();

  return Rcpp::List::create(
    Rcpp::Named("gamma_path") = gamma_path,
    Rcpp::Named("lambda_path") = lambda_path,
    Rcpp::Named("sdf_path") = sdf_path,
    Rcpp::Named("bma_sdf") = arma::mean(sdf_path, 0).t()
  );
}
