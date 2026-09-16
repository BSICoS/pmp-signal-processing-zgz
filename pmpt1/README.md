# pmpt1 — T1 (follow-up) cohort pipeline

Structured pipeline for the T1 cohort, organised around **dataset versions**
and a `data/` tree (created by the scripts, not committed):

```text
data/<version>/{ppg, ggir, nights, hr, hr_nights, hrvtd}
data/comparison
```

- `v1` — recordings from the v1 firmware (clean PPG, no interference
  correction).
- `v2_1`, `v2_2` — v2 firmware variants; the PPG has a spurious interference
  that is corrected during delineation.

Signal fs = 25.6 Hz throughout (see [sharedConfig.m](sharedConfig.m)).

## Main pipeline

The full methodology is written into the generated reports by
[writeMethodsSection.m](writeMethodsSection.m) — keep it in sync when the
pipeline changes.

1. **Night segmentation** — [segmentNights.m](segmentNights.m) cuts each
   subject's PPG into nights using `GGIR.SleepPeriodTime` cleaned by
   [cleanGgirNightBounds.m](cleanGgirNightBounds.m); output
   `data/<v>/nights/PMP<id>_night<N>.mat`. [segmentHrNights.m](segmentHrNights.m)
   does the same for the MATRIX onboard HR (read from the NAS).
2. **Pulse delineation + spectral HR** — [extract_HR_main.m](extract_HR_main.m)
   walks each night in 4 h segments and delegates to
   [estimate_hr_segment2.m](estimate_hr_segment2.m) (fixed 5 min spectral
   windows) / [estimate_hr_segment3.m](estimate_hr_segment3.m) (sliding 60 s
   window, 50 % overlap): baseline removal → interference correction (v2 only;
   median + 4·MAD on the derivative, then pchip interpolation) → pulse
   delineation (`energyArtifacts` + `pulseDelineation`, biosigmat) → fiducial
   points `nD`, `nZ`, `nB` + Welch-based HR.
   [compute_HR_spectral.m](compute_HR_spectral.m) backfills
   `HR_all` / `tHR_all` / `specQuality_all` without re-delineating.
3. **Time-domain HRV** — [hrvtd.m](hrvtd.m) computes MHR / SDNN / RMSSD per
   window from a chosen fiducial series; [run_hrvtd_sweep.m](run_hrvtd_sweep.m)
   runs the full sweep (3 versions × 3 fiducials × 4 windows: 5/10/30/60 min).
4. **Reports** — [compareDatasetVersionsV2.m](compareDatasetVersionsV2.m)
   (`data/comparison/comparison_report.md`),
   [reportMhrEvolutionV2.m](reportMhrEvolutionV2.m) (per-version
   `mhr_report_<v>_v2.md`) and subject comparison plots.

### Orchestrators

- [runAllCompute.m](runAllCompute.m) — stages 2–3 (spectral HR for the 3
  versions, uncorrected examples, MATRIX HR nights, HRV sweep). Each step is
  wrapped in try/catch and clears the workspace before delegating.
- [runAllReports.m](runAllReports.m) — stage 4.

## Other tools

| File | Purpose |
|---|---|
| [pmpt1_holter_s1_edf2mat.m](pmpt1_holter_s1_edf2mat.m), [pmpt1_holter_s2_tK_HRV.m](pmpt1_holter_s2_tK_HRV.m) | T1 Holter ingestion (EDF → `.mat`, with `TZ=` parsing from the EDF Recording field) and QRS delineation / HRV. |
| [pulseDetection2.m](pulseDetection2.m) + [correctPulseResults.m](correctPulseResults.m) | Pulse detection with an interactive GUI to move / add / delete detections. |
| [import_fit_garmin.py](import_fit_garmin.py) | Garmin `.FIT` → HR CSV (needs `fitparse`, `tzdata`; reads from the NAS). |
| [piecewiseNormalize.m](piecewiseNormalize.m) | Piecewise (block) normalisation of a signal. |
| [saveFigAll.m](saveFigAll.m) | Saves a figure as `.png` + `.eps` + `.fig` in one call. |
| [extract_HR_uncorrected_examples.m](extract_HR_uncorrected_examples.m) | Re-processes a few subjects with `correctInterference = false` for corrected-vs-uncorrected comparison plots. |
| [analyzeHrvtdResults.m](analyzeHrvtdResults.m), [reportMhrEvolution.m](reportMhrEvolution.m), [compareDatasetVersions.m](compareDatasetVersions.m) | Legacy (v1) analysis/report scripts, superseded by the `V2` versions. |
| `debug_*.m`, [pruebaGGIRsptTime.m](pruebaGGIRsptTime.m), [reportGgirNightTimestamps.m](reportGgirNightTimestamps.m) | Debugging / exploration utilities. |
| `nightTimestamps.mat` | Binary data file tracked in git (candidate for `.gitignore`). |

## Known gaps

- `runAllCompute.m` / `runAllReports.m` expect `lib/` and `plotting/` folders
  (e.g. `plotting/buildSubjectComparisonPlots.m`, `plotting/makePaperFigures.m`)
  that are **not committed** to this repo — step 3 of `runAllReports` fails on
  a fresh clone.
- Several scripts read from the group NAS (`\\smb2.i3a.es\...`) and abort early
  if the share is not mounted.
