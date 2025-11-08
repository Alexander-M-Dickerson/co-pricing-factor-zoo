#===========================================================#
# beta_params_auto_sd()  –  minimal input, full output
#-----------------------------------------------------------#
#  expec_fac : expected # of active factors      (must be 0 < expec_fac < tot_fac)
#  tot_fac   : total factor universe size        (default 54)
#
#  Returns a list:
#    $mean_count,  $sd_count                – in factor COUNTS
#    $mean_prop,   $sd_prop,  $var_prop     – proportions
#    $lower2_count, $upper2_count           – ±2 SD thresholds (counts)
#    $alpha, $beta                          – Beta-shape parameters
#===========================================================#
beta_params_auto_sd <- function(expec_fac,
                                tot_fac = 54) {
  
  ## ---- 1. Basic checks ----
  if (length(expec_fac) != 1 || length(tot_fac) != 1)
    stop("Supply scalar values for expec_fac and tot_fac.")
  if (expec_fac <= 0 || expec_fac >= tot_fac)
    stop("expec_fac must lie strictly between 0 and tot_fac.")
  
  ## ---- 2. Choose σ so ±2σ hits the closer boundary ----
  sd_count <- min(expec_fac, tot_fac - expec_fac) / 2      # one-σ in *counts*
  
  ## ---- 3. Convert to proportions ----
  mean_prop <- expec_fac / tot_fac
  sd_prop   <- sd_count / tot_fac
  var_prop  <- sd_prop^2
  
  ## ---- 4. Feasibility check for Beta variance ----
  vmax <- mean_prop * (1 - mean_prop)            # theoretical upper limit
  if (var_prop >= vmax)
    stop("Automatic σ is too wide for a Beta prior; "
         ,"reduce expec_fac or tot_fac.")
  
  ## ---- 5. Solve for (α,β) ----
  s      <- mean_prop * (1 - mean_prop) / var_prop - 1      # α+β
  alpha  <- mean_prop * s
  beta   <- (1 - mean_prop) * s
  
  ## ---- 6. Package results ----
  list(
    ## counts
    mean_count   = expec_fac,
    sd_count     = sd_count,
    lower2_count = expec_fac - 2 * sd_count,       # touches [0, tot_fac]
    upper2_count = expec_fac + 2 * sd_count,
    
    ## proportions
    mean_prop = mean_prop,
    sd_prop   = sd_prop,
    var_prop  = var_prop,
    
    ## Beta parameters
    alpha = alpha,
    beta  = beta
  )
}


## 1) Baseline example from earlier: mean = 5 factors out of 54
# res_5 <- beta_params_auto_sd(5, 38)
# print(res_5)
# 
# ## 2) 10
# res_10 <- beta_params_auto_sd(27, 54)
# print(res_10)
# 
# res_10 <- beta_params_auto_sd(27)
# print(res_10)
# 
# res_10 <- beta_params_auto_sd(40)
# print(res_10)