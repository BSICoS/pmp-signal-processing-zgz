# pmpt0 — T0 (baseline) cohort pipeline

Processing pipeline for the T0 cohort ("REGISTROS 3 DIAS": 3-day simultaneous
recordings of FAROS Holter ECG + MATA wrist device, one folder per subject).

Per-subject products are stored in the subject's folder and named
`<subjectID>_holter.mat`, `<subjectID>_reloj.mat` (MATA), `<subjectID>_tK.mat`
(Holter beats/HRV), `<subjectID>_ppg_wojumps.mat` (clean PPG) and
`<subjectID>_GGIR.mat` (activity/sleep classes). Each stage reads the previous
stage's files.

## Stage 0 — raw ingestion

| Script | Purpose |
|---|---|
| [tools/bin2csv.py](../tools/bin2csv.py) | Converts the MATA proprietary `.BIN` format (`MDTC` / `MDTCPACK` packets) to CSV. Requires `tqdm`. |
| [WearablePerMed_GGIRproc_PabloA_bin.r](WearablePerMed_GGIRproc_PabloA_bin.r) | Runs GGIR (modes 1–5) directly on `.BIN` via `GGIRread::readParmayMatrix`. Thresholds lig/mod/vig = 45/100/400 mg; `boutdur = 1` with 60 s aggregation — strict bout detection is delegated to MATLAB (S3). Requires GGIR ≥ 3.2-3, GGIRread ≥ 1.0.4. |
| [S0_read_holter_all.m](S0_read_holter_all.m) | Concatenates the Holter `.EDF` segments → `<id>_holter.mat` (ECG @ 1 kHz, UTC timestamps from the EDF header). |
| [S0_read_mata_all.m](S0_read_mata_all.m) | Reads the wrist CSV → `<id>_reloj.mat` (`PPG`, `HR`, `ACC`, `GYR`, `Tbody`, `Tamb`, `timeStamp`; fs = 25.6 Hz). |

## Stage 1 — Holter ECG → beats and HRV

| Script | Purpose |
|---|---|
| [S1_0_ECG_SNR_all.m](S1_0_ECG_SNR_all.m) | ECG quality: beat-aligned SVD-based SNR per segment. Includes a robust Holter↔tK whole-hour timezone realignment (median beat offset). |
| [S1_1_tK_HRV_all.m](S1_1_tK_HRV_all.m) | QRS delineation (`delinearECG`) → beat instants `tK`, plus `HRV` and `NN` series → `<id>_tK.mat`. |
| [S1_2_move_holter_tK_files.m](S1_2_move_holter_tK_files.m) | One-off utility: copies `_holter` / `_tK` files between directory trees. |

## Stage 2 — wrist PPG → clean signal, HR, HRV

| Script | Purpose |
|---|---|
| [S2_1_PPG_correct_jumps_resample.m](S2_1_PPG_correct_jumps_resample.m) | Interpolates isolated NaNs, detects/corrects PPG jumps, resamples → `<id>_ppg_wojumps.mat`. |
| [S2_1X_corregir_tramos_nans_all.m](S2_1X_corregir_tramos_nans_all.m) | Re-marks long NaN stretches (≥ 5 samples) so they are *not* interpolated away. |
| [S2_2_PPG_nD_HRV_all.m](S2_2_PPG_nD_HRV_all.m) | Pulse delineation on the clean PPG (fiducial nD) and PPG-based HRV. |
| [S2_3_MATA_HR_peakedness.m](S2_3_MATA_HR_peakedness.m) | HR from PPG via `peakednessCost` spectral tracking. |
| [S2_X_fixFarosTime.m](S2_X_fixFarosTime.m) / [S2_X_fixFarosTime_v2.m](S2_X_fixFarosTime_v2.m) | Estimate the clock offset between wrist HR and Holter HRV by cross-correlation (±3 h search) and fix timestamps. |

## Stage 3 — GGIR activity / sleep classes

| Script | Purpose |
|---|---|
| [S3_1_extractGGIR_and_group_class_id.m](S3_1_extractGGIR_and_group_class_id.m) | Reads GGIR `ms5.outraw` CSVs + behavioural codes → `GGIR` table with labelled `class_id` / `class_group`; masks non-wear epochs; adds inactivity bouts. |
| [S3_2_move_and_assign_GGIR_files.m](S3_2_move_and_assign_GGIR_files.m) | One-off utility: distributes GGIR `.mat` outputs into subject folders. |
| [S3_3_rebout_periods.m](S3_3_rebout_periods.m) | Re-detects strict bouts per intensity band (e.g. LIG bouts ≥ 1 min) from the GGIR class series. |
| [S3_report_bin_strict_bouts.m](S3_report_bin_strict_bouts.m) | Builds per-record / per-subject / database summaries and figures from the strict-bout output (`output_2026_bin_bt1_agg`). |

## Notes

- Data roots and toolbox paths come from `paths.m` at the repo root (copy
  `paths.example.m` → `paths.m`); the default T0 data root is the relative
  `"REGISTROS 3 DIAS"` folder.
- Requires `biomedical-signal-processing` on the MATLAB path (and the ECG SNR
  toolbox under `SNR_ECG/toolbox/` for S1_0).
