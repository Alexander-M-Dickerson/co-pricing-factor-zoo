get_factor_weights <- function(vd, f,
                               type  = c("all", "DR", "CF"),
                               spike = FALSE,
                               allow_negative = TRUE) {
  library(dplyr)
  
  type <- match.arg(type)
  opp  <- if (type == "DR") "CF"
  else if (type == "CF") "DR"
  else NA_character_
  
  # ── 1. Core look-up table --------------------------------------------------
  df_core <- vd %>%
    dplyr::select(factors, DRr, DR_CF)
  
  factor_order <- colnames(f)
  
  df_aligned <- tibble(factors = factor_order) %>%           # preserve order
    left_join(df_core, by = "factors") %>%
    mutate(
      DRr   = coalesce(DRr,   0),
      DR_CF = coalesce(DR_CF, "")
    )
  
  # ── 2. Build signed weights -----------------------------------------------
  if (type == "all") {
    
    ## Long-only weights (unchanged – may not sum to 0)
    total_wt <- sum(df_aligned$DRr[df_aligned$DRr != 0])
    base_wts <- if (total_wt == 0) rep(0, length(factor_order))
    else df_aligned$DRr / total_wt
    
  } else if (allow_negative) {
    
    ## Positive on ‘type’, negative on the opposite; rescale so Σw = 0
    pos_mask <- df_aligned$DR_CF == type & df_aligned$DRr != 0
    neg_mask <- df_aligned$DR_CF == opp  & df_aligned$DRr != 0
    
    signed_vals <- numeric(length(factor_order))
    signed_vals[pos_mask] <-  df_aligned$DRr[pos_mask]       # + side
    signed_vals[neg_mask] <- -df_aligned$DRr[neg_mask]       # – side
    
    pos_total <- sum(signed_vals[signed_vals > 0])
    neg_total <- sum(abs(signed_vals[signed_vals < 0]))
    
    if (pos_total == 0 && neg_total == 0) {
      base_wts <- rep(0, length(factor_order))               # no active weights
    } else if (pos_total == 0 || neg_total == 0) {
      ## One-sided case: keep original scale (cannot reach Σw = 0)
      base_wts <- signed_vals
    } else {
      ## Rescale each side so longs sum to +1 and shorts to –1  → Σw = 0
      base_wts <- signed_vals
      base_wts[base_wts > 0] <-  base_wts[base_wts > 0] /  pos_total
      base_wts[base_wts < 0] <-  base_wts[base_wts < 0] /  neg_total
    }
    
  } else {
    
    ## Previous behaviour: opposite side forced to 0
    df_aligned <- df_aligned %>%
      mutate(DRr = if_else(DR_CF == type, DRr, 0))
    
    total_wt <- sum(df_aligned$DRr[df_aligned$DRr != 0])
    base_wts <- if (total_wt == 0) rep(0, length(factor_order))
    else ifelse(df_aligned$DRr == 0, 0,
                df_aligned$DRr / total_wt)
  }
  
  # ── 3. Optional spike treatment -------------------------------------------
  if (spike && type != "all") {
    spike_mask <- df_aligned$DR_CF == opp   # rows to receive −1
    base_wts[spike_mask] <- -1
  }
  
  # ── 4. Return --------------------------------------------------------------
  setNames(base_wts, factor_order)
}