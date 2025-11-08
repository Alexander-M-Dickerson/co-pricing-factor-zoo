######################
### GMM Estimation ###
######################

gmm_estimation <- function(R, f, W, include.intercept = TRUE) {
  library(proxyC)
  # R: matrix of test assets with dimension t times N, where N is the number of test assets;
  # f: matrix of factors with dimension t times k, where k is the number of factors and t is
  #    the number of periods;
  # W: weighting matrix in GMM estimation.
  R <- t(t(R)/colSds(R))   # standardize returns
  f <- t(t(f)/colSds(f))   # standardize factors
  Sigma_Rf <- cov(R, f)
  ER <- matrix(colMeans(R), ncol=1)
  if (include.intercept == TRUE) {
    N <- dim(R)[2]
    Sigma_Rf <- cbind(matrix(1,ncol=1,nrow=N), Sigma_Rf)
    return(solve(t(Sigma_Rf)%*%solve(W)%*%Sigma_Rf) %*% t(Sigma_Rf)%*%solve(W)%*%ER)
  } else {
    return(solve(t(Sigma_Rf)%*%solve(W)%*%Sigma_Rf) %*% t(Sigma_Rf)%*%solve(W)%*%ER)
  }
}

# gmm_estimation <- function(R, f, W, include.intercept = TRUE) {
#   # R: matrix of test assets with dimension t times N, where N is the number of test assets;
#   # f: matrix of factors with dimension t times k, where k is the number of factors and t is
#   #    the number of periods;
#   # W: weighting matrix in GMM estimation.
#   R <- t(t(R) / ifelse(NCOL(R) > 1, apply(R, 2, sd), sd(R)))   # standardize returns
#   f <- t(t(f) / ifelse(NCOL(f) > 1, apply(f, 2, sd), sd(f))    )   # standardize factors
#   Sigma_Rf <- cov(R, f)
#   ER <- matrix(colMeans(R), ncol=1)
#   if (include.intercept == TRUE) {
#     N <- dim(R)[2]
#     Sigma_Rf <- cbind(matrix(1,ncol=1,nrow=N), Sigma_Rf)
#     return(solve(t(Sigma_Rf)%*%solve(W)%*%Sigma_Rf) %*% t(Sigma_Rf)%*%solve(W)%*%ER)
#   } else {
#     return(solve(t(Sigma_Rf)%*%solve(W)%*%Sigma_Rf) %*% t(Sigma_Rf)%*%solve(W)%*%ER)
#   }
# }