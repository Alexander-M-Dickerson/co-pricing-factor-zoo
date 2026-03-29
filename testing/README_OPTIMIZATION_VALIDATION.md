# Optimization Validation Workflow

This folder contains the validation and toolchain checks for `continuous_ss_sdf_v2_fast`.

The rule is simple: do not change the default fast path unless the validation scripts pass.

## Scripts

- `validate_continuous_ss_sdf_v2.R`
  - deterministic kernel-level comparison of `BayesianFactorZoo::continuous_ss_sdf_v2` vs `continuous_ss_sdf_v2_fast`
  - runs a same-seed self-check for both engines before comparing them
  - reports posterior mean gamma gaps, posterior mean lambda gaps, and `bma_sdf` gaps
  - writes detailed CSV reports with 3-decimal and 4-decimal flags

- `validate_unconditional_runner_fast.R`
  - unconditional runner smoke/parity check through `run_bayesian_mcmc()`
  - compares `results` plus an `IS_AP` structure/numeric signature report
  - uses `save_flag = FALSE` and a temporary output folder

- `check_toolchain.R`
  - reports whether `make`, `pkgbuild`, `Rcpp`, and `RcppArmadillo` are available
  - runs a trivial compile probe when the required pieces are present

- `benchmark_continuous_ss_sdf_v2.R`
  - benchmarks `BayesianFactorZoo::continuous_ss_sdf_v2`, `continuous_ss_sdf_v2_fast_r`, and `continuous_ss_sdf_v2_fast_cpp`
  - writes elapsed time, speedup, and max summary gaps versus the package reference
  - skips the C++ row cleanly if the local toolchain cannot compile the backend

## Recommended Workflow

Run these commands from the repo root.

### Step 1: Check the local build toolchain

```bash
Rscript testing/check_toolchain.R
```

This produces a report directory under the system temp folder and prints whether the compile probe succeeded.

### Step 2: Validate the validator at 50 draws

```bash
Rscript testing/validate_continuous_ss_sdf_v2.R 50
Rscript testing/validate_unconditional_runner_fast.R 50
```

Use these runs before any optimization work. They are the fast smoke tests that confirm seed discipline and reporting are working.

### Step 3: Run the full kernel gate at 2000 draws

```bash
Rscript testing/validate_continuous_ss_sdf_v2.R 2000
```

This is the hard gate before promoting an optimization candidate.

### Step 4: Run the runner gate after a candidate passes the kernel gate

```bash
Rscript testing/validate_unconditional_runner_fast.R 50
```

If the candidate changes runner wiring or downstream object construction, rerun this after every meaningful change.

### Step 5: Benchmark the available backends

```bash
Rscript testing/benchmark_continuous_ss_sdf_v2.R 500
```

The wrapper `continuous_ss_sdf_v2_fast()` uses the C++ backend automatically when it compiles cleanly and falls back to the validated pure-R backend otherwise. The direct benchmark script reports which backend actually ran.

## Acceptance Rules

- Kernel self-checks must reproduce identical outputs for repeated runs with the same seed.
- Runner self-checks must reproduce the same 4-decimal summaries and the same `IS_AP` structure/numeric signature for repeated runs with the same seed.
- Kernel validation must pass at 3 decimals for:
  - posterior mean `gamma_path`
  - posterior mean `lambda_path`
  - `bma_sdf`
- Runner validation must pass the same 3-decimal checks on `results`.
- Runner validation must also show no missing paths or structure mismatches in the `IS_AP` signature report.

The detailed CSV reports also include 4-decimal flags. Those are for visibility, not the hard gate.

## Windows Rtools Notes

For R 4.5.x, the matching Windows toolchain is `Rtools45`.

Official CRAN pages:

- Rtools landing page: https://cran.r-project.org/bin/windows/Rtools/
- Rtools45 page: https://cran.r-project.org/bin/windows/Rtools/rtools45/rtools.html

CRAN currently recommends the default installation location `C:\\rtools45`. The `Rtools45` page also states that when R was installed from the standard Windows installer and Rtools is installed in the default location, no extra setup is normally required.

After installing Rtools, rerun:

```bash
Rscript testing/check_toolchain.R
```

If the install finished while your shell or R session was already open, start a fresh session before rerunning the check. The helper also looks for the default `C:\\rtools45` path automatically.

If you want an R-side confirmation and `pkgbuild` is installed:

```r
pkgbuild::has_build_tools(debug = TRUE)
```

## Report Files

Each validation script writes a timestamped report directory in the system temp folder unless you pass a second argument with an explicit report path.

Typical outputs include:

- `*_details.csv`: per-parameter or per-path comparison rows
- `*_summary.csv`: grouped max and mean absolute gaps
- `validation_status.csv`: pass/fail flags
- `run_metadata.csv`: elapsed time and speedup
- `session_info.txt`: R session metadata

Do not commit report outputs. They are runtime artifacts.
