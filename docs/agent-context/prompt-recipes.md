# Prompt Recipes

Use these prompts as the canonical public prompts for Codex or Claude in this
repo.

## Fresh Clone To Ready State

`Set this repo up from a fresh clone. Install missing packages, download the canonical public data bundle, validate readiness, rebuild the fast backends, and stop at the first blocking issue.`

## Replicate The Main Text

`Replicate the main text. If packages or data are missing, bootstrap them automatically first. Use the smallest validated boundary before scaling up, and stop at the first failing step with the exact rerun boundary.`

## Quick Validation Run

`Run a quick validation of the main paper pipeline. Bootstrap packages and data if needed, use the quick or reduced-draw path, and tell me which outputs were actually regenerated.`

## Regenerate Figure 1

`Regenerate Figure 1 from the simulation validation path. Use the fast C++ engine, write the generated outputs under output/simulations/figure1/, and keep the default paper build anchored to the tracked Figure 1 panel fixtures unless I explicitly ask you to refresh them.`

## Fully Explain Figure 1

`Fully explain Figure 1. Cover the simulation design, the six experiments, why noisy proxies matter in this paper, the default tracked panel-fixture path, the optional regeneration path, and the generated output files.`

## Replicate The Internet Appendix

`Replicate the Internet Appendix. Bootstrap what is needed, run the 500-draw IA smoke boundary first, stop at the first failing model if anything breaks, and then tell me the exact next scale-up boundary.`

## Build The IA PDF

`Build the Internet Appendix PDF from fresh IA outputs. Validate that the required IA estimation artifacts are present first, assemble the IA LaTeX tree, and compile the PDF through the public wrapper path.`

## Fully Explain Table 1

`Fully explain Table 1. Cover the empirical question, the three panels, the two reported metrics, the top five co-pricing factors, the paper interpretation, the code path, the saved objects used, and the generated output file.`

## Fully Explain Table 5

`Fully explain Table 5. Cover the economic question, what discount-rate versus cash-flow news means in this paper, how the repo builds the table, which saved input drives the decomposition, and where the result appears in code and output.`

## Explain Figure 7

`Fully explain Figure 7. Cover the trading exercise, the conditional estimation boundary that feeds it, the output file, and how it connects to Table 6 Panel B.`

## Explain What Is Implemented In The IA

`Tell me exactly which Internet Appendix results are implemented in this repo, which are paper-only, and where each implemented IA result is generated.`

## Trace An Equation To Code

`Trace Eq. (10) to the repo. Explain the economic role of the duration-adjusted Treasury decomposition, the outputs that rely on it, and the relevant scripts and helpers.`
