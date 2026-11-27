# Fixed-opponent threshold comparison (2026-11-05)

Research only. No changes to App, production evaluator, physical engine, or bundled bank.

Nine original bank layouts: prior F01–F05, earlier D/A as F06/F07, and two central-position anchor selections as F08/F09. Layout selection does not inspect score. These are deliberate diagnostic strata, not a representative bank sample. Positions remain unchanged, particularly opponent9.

## Reproduce

From repository root, with Python 3 and Xcode (managed simulator role must be available):

```sh
python3 research/defense-threshold-comparison-20261105/prepare.py
python3 research/defense-threshold-comparison-20261105/modify_solver.py
python3 scripts/local_test_lifecycle.py run --task defense-threshold-comparison-20261105 -- python3 research/defense-threshold-comparison-20261105/run.py
python3 research/defense-threshold-comparison-20261105/audit.py
# Run render.py in a disposable environment with numpy and matplotlib.
```

Prepare checks previous production source hashes before reusing static maps. The run freezes production and research Swift sources. Original maps and bank IDs are preserved. A second execution should be archived before overwriting evidence if earlier results are needed.

## Search contract

- Real XZ metres, Y up, landscape +X right/+Z down; actual table/jaws/pockets and ball radius. Six exact fixed-target pocket windows cached for scoring only.
- Shared candidate pool for thresholds 70/80/90. Do not require the no-blocker map to qualify before evaluating the moved8 blocker.
- Region seeds: up to 24 nearest sampled-block seeds from the >=70 map. Blocker seeds: 12 closest final8-to-cue9-segment seeds plus 12 highest final-score seeds. Distance and score ranks are separated because their units differ. Finite heuristic coverage, not a global optimizer.
- Cut seeds 15/30/45/60 degrees, both sides, actual cut within 0.5 degree. Coarse speed sweep and two local refinements. Reuse physical strike-access and legality checks.
- Escalate from centre ball to mild vertical, stronger vertical, then side spin only while the >=90 diagnostic target lacks a robust preserving candidate. Lower thresholds share that same final search pool. A stand-alone 70-target search could stop earlier; this is not a runtime comparison between separate threshold policies.
- Before perturbations, spatial/event coarse dedup includes score band and blocking flag. For each threshold/pathway, shortlist up to12 low-effort and12 high-own-window candidates; merge by stroke. Not all candidates are probed; missing probes are unknown, not failed.
- Four separate probes: aim +/-0.1 degrees and speed +/-5%; no target-position, simultaneous multi-variable or tip-error perturbations. Recheck cue access, legality, opponent no-contact/no-movement, final defense score and own-window preservation. 4/4 is not a success probability.
- Intrinsic versus blocking-added is threshold-dependent: no-blocker score >=threshold versus below it. This is an eligibility explanation, not a claim that the intrinsic candidate has no blocker effect or that blocking-added must be complete snooker.
- Own8 potential: best confirmed positive target-to-pocket angle after subtracting9's infinite forward-ray exclusion cone, independent of current cue position. Unknown pocket coverage is not zero. The metric is a conservative confirmed-window lower bound; it is not future-shot probability.
- Export low-effort and maximum-own-window representatives per threshold/pathway, merged by identical stroke; no quota for spin, cushions, route counts or cut bins. Candidate counts are coarse-dedup diagnostic counts, not numbers of perceptually distinct training routes.

`first-pass/` retains the initial pilot, which mixed distance and score seed ranks. Final pass uses separate rankings with the same total blocker-refinement budget. Both have independent frozen sources and managed run evidence.

## Interpretation

Static-map colours estimate >=70/80/90 areas from sampled cell centres; they are not certified continuous regions. Separate actual blocked, normal formula, zero-width estimate and other estimate branches. A score threshold change cannot calibrate the underlying model. No robust solution found in this bounded search does not prove impossibility. The current study does not change production thresholds.

## Current recommendation policy (user correction, §17)

After `audit.py`, run `select_sufficient.py`. `recommended-gallery.md` and `sufficient-selection.json` are the current recommendation output. The original 15-route PDF remains diagnostic history. Selection requires existing verified own-window preservation but does not maximize it; rank execution effort, actual speed, cushion count as a tie-break. No per-pathway representative quotas. This postprocessing does not change the frozen native search. A universal sufficient-window threshold has not been calibrated; initial-window preservation must not be misrepresented as an absolute comfort standard.
