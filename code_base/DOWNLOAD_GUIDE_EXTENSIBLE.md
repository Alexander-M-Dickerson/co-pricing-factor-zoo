# Download Guide - Maximum Extensibility Version

## 🎯 LATEST VERSION - NO HARD-CODING

All files ready for download below. This version has **ZERO hard-coded data** and requires users to provide all inputs.

---

## 📥 Core Files (Download These)

### Main Files

1. **[_run_dfps.R](computer:///mnt/user-data/outputs/_run_dfps.R)** ⭐ NEW (8.2K)
   - User-facing run script
   - All parameters at top
   - Clear examples

2. **[run_bayesian_mcmc.R](computer:///mnt/user-data/outputs/run_bayesian_mcmc.R)** ⭐ NEW (18K)
   - Main estimation function
   - Removed all hard-coding
   - Factor validation before MCMC

3. **[insample_asset_pricing.R](computer:///mnt/user-data/outputs/insample_asset_pricing.R)** (9.5K)
   - Dynamic frequentist models (from previous refactoring)
   - No changes needed

### Helper Files

4. **[validate_and_align_dates.R](computer:///mnt/user-data/outputs/validate_and_align_dates.R)** (6.1K)
   - Date validation and alignment
   - No changes

5. **[logging_helpers.R](computer:///mnt/user-data/outputs/logging_helpers.R)** (1.8K)
   - Clean logging system
   - No changes

6. **[data_loading_helpers.R](computer:///mnt/user-data/outputs/data_loading_helpers.R)** (6.2K)
   - Helper functions (drop_factors, etc.)
   - No changes

---

## 📋 Summary Document

7. **[EXTENSIBILITY_REFACTORING.md](computer:///mnt/user-data/outputs/EXTENSIBILITY_REFACTORING.md)**
   - Complete summary of changes
   - Migration guide
   - Before/after comparisons

---

## 📂 File Organization

Place files in your project:

```
your_project/
├── _run_dfps.R                  ← Main run script (NEW)
├── data/                        ← Your data files go here
│   ├── nontraded_factors.csv
│   ├── traded_factors.csv
│   └── test_assets.csv
├── code_base/                   ← Helper functions
│   ├── run_bayesian_mcmc.R      ← Main function (NEW)
│   ├── insample_asset_pricing.R
│   ├── validate_and_align_dates.R
│   ├── logging_helpers.R
│   ├── data_loading_helpers.R
│   └── [other helper files]
└── output/                      ← Results saved here
    └── logs/
```

---

## 🔧 Quick Setup

### Step 1: Prepare Your Data

Create three CSV files with 'date' as first column:

**nontraded_factors.csv:**
```csv
date,Factor1,Factor2,Factor3
1986-01-31,0.023,0.045,0.012
1986-02-28,0.018,0.052,0.009
...
```

**traded_factors.csv:**
```csv
date,MKT,SMB,HML,RMW,CMA
1986-01-31,0.012,0.008,0.015,0.005,0.003
...
```

**test_assets.csv:**
```csv
date,Portfolio1,Portfolio2,Portfolio3
1986-01-31,0.025,0.018,0.022
...
```

### Step 2: Configure _run_dfps.R

Edit lines 14-67:

```r
# Paths
main_path      <- "/path/to/your/project"
data_folder    <- "data"
code_folder    <- "code_base"

# Model
model_type     <- "bond"
return_type    <- "excess"

# Data files
f1             <- "nontraded_factors.csv"
f2             <- "traded_factors.csv"
R              <- "test_assets.csv"

# Frequentist models (REQUIRED)
frequentist_models <- list(
  CAPM = "MKT",
  FF5  = c("MKT", "SMB", "HML", "RMW", "CMA")
)
```

### Step 3: Run

```r
source("_run_dfps.R")
```

---

## ✅ What's New

### Removed
- ❌ All built-in data logic (paper.data.rr)
- ❌ `f1_custom`, `f2_custom`, `R_custom` parameters
- ❌ `estimation_name` parameter
- ❌ Default frequentist models

### Added
- ✅ Factor validation BEFORE MCMC
- ✅ Clear error messages for missing factors
- ✅ Simplified data loading

### Changed
- 🔄 `f1`, `f2`, `R` now simple filenames (not paths or objects)
- 🔄 `frequentist_models` now REQUIRED (cannot be NULL)
- 🔄 `tag` parameter covers custom labeling

### Kept
- ✅ `model_type` and `return_type`
- ✅ Output naming: `{return_type}_{model_type}_alpha.w={alpha.w}_beta.w={beta.w}_kappa={kappa}_{tag}`
- ✅ All MCMC parameters
- ✅ `n_bond_factors` for bond_stock_with_sp

---

## 📖 Usage Examples

### Example 1: Bond Model
```r
model_type <- "bond"
f1 <- "nontraded_factors.csv"
f2 <- "bond_factors.csv"
R  <- "bond_portfolios.csv"
frequentist_models <- list(
  CAPM = "MKTB",
  HKM  = c("MKTB", "TERM")
)
```

### Example 2: Stock Model
```r
model_type <- "stock"
f1 <- "nontraded_factors.csv"
f2 <- "stock_factors.csv"
R  <- "stock_portfolios.csv"
frequentist_models <- list(
  CAPM = "MKTS",
  FF5  = c("MKTS", "SMB", "HML", "RMW", "CMA")
)
```

### Example 3: Bond + Stock
```r
model_type <- "bond_stock_with_sp"
f1 <- "nontraded_factors.csv"
f2 <- "combined_factors.csv"  # First 8 cols = bonds, rest = stocks
R  <- "combined_portfolios.csv"
n_bond_factors <- 8  # REQUIRED
frequentist_models <- list(
  CAPM_B = "MKTB",
  CAPM_S = "MKTS",
  FF5    = c("MKTS", "SMB", "HML", "RMW", "CMA")
)
```

---

## ⚠️ Important Notes

1. **frequentist_models is REQUIRED**
   - Cannot be NULL
   - All factors must exist in your data
   - Validated before MCMC runs

2. **All data files must have 'date' column**
   - Format: YYYY-MM-DD
   - First column of each CSV

3. **Bond factors come first in f2**
   - For bond_stock_with_sp model
   - Specify split with n_bond_factors

4. **Output naming**
   - Uses `tag` for custom labels
   - Format: `excess_bond_alpha.w=1_beta.w=1_kappa=0_baseline.Rdata`

---

## 🚀 Benefits

✅ **Maximum flexibility** - No assumptions about your data  
✅ **Safe validation** - Checks factors before expensive computation  
✅ **Clear errors** - Helpful messages when something's wrong  
✅ **Reproducible** - All inputs explicit  
✅ **Clean code** - Removed 300+ lines of conditional logic  

---

## 🆘 Troubleshooting

**Error: "frequentist_models is REQUIRED"**
→ You must specify comparison models. Example:
```r
frequentist_models <- list(CAPM = "MKT")
```

**Error: "Missing required factors"**
→ Check factor names match exactly (case-sensitive). The error will list:
- Which models have missing factors
- What the missing factors are
- What factors are available

**Error: "file not found"**
→ Check:
- File is in data_folder
- Filename is spelled correctly (case-sensitive)
- File has .csv extension

**Error: "must have 'date' as first column"**
→ Ensure first column is named "date" (lowercase) in YYYY-MM-DD format

---

Ready to use! 🎉
