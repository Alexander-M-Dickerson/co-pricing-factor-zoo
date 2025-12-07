# CLAUDE.md - Development Guidelines

This project implements Bayesian asset pricing estimation for factor models. All R code should follow these best practices to ensure extensibility, reusability, and maintainability.

## Project Structure

```
co-pricing-factor-zoo/
├── _run_*.R              # Entry point scripts (user configuration)
├── code_base/            # Reusable function modules
│   ├── *_helpers.R       # Utility functions
│   ├── run_*.R           # Main estimation routines
│   └── *.R               # Domain-specific functions
├── data/                 # Data files (gitignored)
└── output/               # Results (gitignored)
```

## R Coding Standards

### Function Design Principles

1. **Single Responsibility**: Each function should do one thing well
2. **Explicit Parameters**: Use named parameters with sensible defaults
3. **Early Returns**: Validate inputs early and fail fast with informative errors
4. **No Side Effects**: Avoid modifying global state; return results explicitly

### Function Documentation

Use roxygen2-style comments for all exported functions:

```r
#' Brief description of what the function does
#'
#' Longer description if needed, explaining the purpose and behavior.
#'
#' @param param1 Description of first parameter
#' @param param2 Description of second parameter (default: value)
#' @param verbose Logical, print progress messages (default: TRUE)
#' @return Description of what the function returns
#'
#' @examples
#' \dontrun{
#'   result <- my_function(data, option = "value")
#' }
my_function <- function(param1, param2 = "default", verbose = TRUE) {
  # Implementation
}
```

### Input Validation

Always validate inputs at function entry:

```r
my_function <- function(data, n_factors, verbose = TRUE) {
  # Validate required inputs

if (is.null(data) || !is.data.frame(data)) {
    stop("'data' must be a non-null data.frame")
  }

  if (!is.numeric(n_factors) || n_factors < 1) {
    stop("'n_factors' must be a positive integer")
  }

  # Proceed with implementation...
}
```

### Error Handling

- Use `stop()` for unrecoverable errors with descriptive messages
- Use `warning()` for recoverable issues the user should know about
- Use `message()` for progress/informational output (respects `verbose` flag)
- Include context in error messages (variable names, expected vs actual values)

```r
if (nrow(data) < min_rows) {
  stop(sprintf("Insufficient data: got %d rows, need at least %d",
               nrow(data), min_rows))
}
```

### Naming Conventions

- **Functions**: `snake_case` verbs describing actions (`load_data`, `validate_dates`, `run_estimation`)
- **Variables**: `snake_case` nouns (`factor_weights`, `date_range`, `n_periods`)
- **Constants**: `UPPER_SNAKE_CASE` (`MAX_ITERATIONS`, `DEFAULT_SEED`)
- **Internal helpers**: Prefix with `.` or keep in local scope (`.parse_date_internal`)

### Code Organization

1. **Group related functions** in single files (e.g., all date utilities in `validate_and_align_dates.R`)
2. **Source dependencies explicitly** at the top of scripts
3. **Use environments** for state that must persist (see `logging_helpers.R` pattern)
4. **Avoid `library()` inside functions** - use `requireNamespace()` or explicit `::` notation

```r
# Good: explicit namespace
result <- dplyr::filter(data, value > 0)

# Good: check availability
if (!requireNamespace("lubridate", quietly = TRUE)) {
  stop("Package 'lubridate' required. Install with: install.packages('lubridate')")
}
```

### Data Handling

- **Date columns**: Always expect first column as date, parse with `lubridate`
- **Missing values**: Check for and handle NA/NaN explicitly
- **Matrix operations**: Prefer matrix algebra for performance in numerical code
- **Data alignment**: Use `validate_and_align_dates()` for multi-source data

### Performance Considerations

- Use `gc()` after large operations to free memory
- Prefer vectorized operations over loops
- Use `parallel` or `foreach` for embarrassingly parallel tasks
- Pre-allocate results vectors/matrices when size is known

## Writing Extensible Code

### Configuration Pattern

Follow the established pattern for user-configurable scripts:

```r
###############################################################################
## SECTION 1: USER CONFIGURATION (EDIT HERE)
###############################################################################

# Paths
main_path <- "/path/to/project"
data_folder <- "data"

# Model settings
model_type <- "stock"  # Options: "bond", "stock", "bond_stock_with_sp"

###############################################################################
## SECTION 2: EXECUTION (DO NOT EDIT BELOW)
###############################################################################
```

### Reusable Helper Pattern

Create focused helper functions that can be composed:

```r
# Helper: specific task
strip_columns <- function(mat, cols_to_remove) {
  if (is.null(mat) || ncol(mat) == 0) return(mat)
  keep <- !colnames(mat) %in% cols_to_remove
  mat[, keep, drop = FALSE]
}

# Main function: composes helpers
process_factors <- function(fac, fac_to_drop, verbose = TRUE) {
  fac$f1 <- strip_columns(fac$f1, fac_to_drop)
  fac$f2 <- strip_columns(fac$f2, fac_to_drop)
  # ... more processing
  fac
}
```

### Logging Pattern

Use the established logger pattern for long-running operations:

```r
source("code_base/logging_helpers.R")

logger <- init_logger("output/logs/my_run.log")
log_message(logger, "Starting process...")

tryCatch({
  # Main work
  log_message(logger, "Step completed successfully")
}, error = function(e) {
  log_message(logger, "ERROR: ", e$message, level = "ERROR")
  close_logger(logger)
  stop(e)
})

close_logger(logger)
```

## Testing Guidelines

- Test edge cases: empty data, single row, missing columns
- Verify date parsing with multiple formats
- Check matrix dimensions after operations
- Validate that frequentist models match expected factors

## Common Pitfalls to Avoid

1. **Don't use `setwd()` in functions** - use `file.path()` for paths
2. **Don't assume column order** - reference by name
3. **Don't ignore warnings** - they often indicate data issues
4. **Don't hardcode paths** - use parameters
5. **Don't skip `drop = FALSE`** - single-column subsetting can silently convert to vector

## Dependencies

Core packages used in this project:
- `lubridate` - Date parsing and manipulation
- `dplyr` - Data transformation
- `parallel` / `doParallel` - Parallel processing
- `MASS` - Statistical functions
- `Matrix` - Sparse matrix operations

Always check package availability before use with `requireNamespace()`.

## MCMC Results Structure

The `.Rdata` files produced by `run_bayesian_mcmc()` contain the following key objects:

### `results` - MCMC Output List

A list with one element per prior shrinkage level (default: 0.20, 0.40, 0.60, 0.80).
Each element contains:

| Field | Description | Dimensions |
|-------|-------------|------------|
| `gamma_path` | Posterior inclusion indicators (0/1) for each factor | `ndraws × N` |
| `lambda_path` | Market prices of risk | `ndraws × (1+N)` or `ndraws × N` |
| `sdf_path` | Stochastic discount factor paths | `ndraws × T` |
| `bma_sdf` | Bayesian model-averaged SDF | `T × 1` |

**gamma_path (Posterior Probabilities)**
- Binary matrix: each row is one MCMC draw, each column is one factor
- `colMeans(gamma_path)` gives the posterior probability that factor j is included
- Always has N columns (one per factor)

**lambda_path (Market Prices of Risk)**
- Continuous matrix: each row is one MCMC draw
- When `intercept = TRUE`: has `1 + N` columns (first column is the intercept/constant)
- When `intercept = FALSE`: has `N` columns (same as gamma)
- `colMeans(lambda_path)` gives posterior mean risk prices
- Typically annualized by multiplying by `sqrt(12)` for monthly data

**sdf_path (SDF Paths)**
- Each row is one MCMC draw, each column is one time period
- Dimensions: `ndraws × T` where T is the number of observations

**bma_sdf (Model-Averaged SDF)**
- Bayesian model-averaged stochastic discount factor
- Vector of length T (one value per time period)

### Shrinkage Levels (SRscale)

The `SRscale` parameter controls the prior Sharpe ratio shrinkage:
- Values like `c(0.20, 0.40, 0.60, 0.80)` represent percentages of the maximum attainable SR
- Lower values = more shrinkage toward zero (more conservative)
- Higher values = less shrinkage (more aggressive factor selection)
- Results are indexed by these levels: `results[[1]]` = 20%, `results[[2]]` = 40%, etc.

### Other Objects in .Rdata

| Object | Description |
|--------|-------------|
| `f1` | Non-traded factors matrix (T × N1) |
| `f2` | Traded factors matrix (T × N2), NULL for treasury models |
| `R_matrix` | Test asset returns matrix |
| `intercept` | Logical: whether intercept was included |
| `IS_AP` | In-sample asset pricing results |
| `kns_out` | Kozak-Nagel-Shanken OOS results |
| `rp_out` | RP-PCA results |

### Example: Extracting Posterior Probabilities

```r
# Load results
load("output/excess_stock_alpha.w=1_beta.w=1_kappa=0_baseline.Rdata")

# Get factor names
factor_names <- colnames(cbind(f1, f2))

# Compute posterior probabilities for each shrinkage level
prob_mat <- sapply(results, function(r) colMeans(r$gamma_path))
rownames(prob_mat) <- factor_names
colnames(prob_mat) <- c("20%", "40%", "60%", "80%")

# Average probability across all shrinkage levels
avg_prob <- rowMeans(prob_mat)
```
