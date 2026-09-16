# matav2 — MATA v2 firmware: development & validation

Scripts used to develop and validate the processing of recordings from the
**new MATA firmware (v2)** devices, including comparison against the previous
device version and a Shimmer ECG reference.

The v2 PPG exhibits two artefacts addressed here: coarse **gain jumps**
(S01) and **residual fine jumps + spurious interference** (S02).

## Pipeline order

1. [S00_read_mata.m](S00_read_mata.m) — reads MATA-exported `.csv` files
   (`hr_raw`, `hr`, `acc_*`, `gyr_*`, temperatures, `dateTime`) and saves one
   `.mat` per recording (`PPG`, `HR`, `ACC`, `GYR`, `Tbody`, `Tamb`,
   `timeStamp`; fs = 25.6 Hz).
2. [S00_read_shimmer.m](S00_read_shimmer.m) — imports Shimmer
   `DefaultTrial*.mat` exports into per-signal tables (ECG leads I/II/III,
   RESP, ACC, tK, HRV) with Madrid-timezone timestamps.
3. [S01_correct_GAIN_jumps.m](S01_correct_GAIN_jumps.m) — detects and corrects
   coarse gain jumps in the raw PPG; appends `PPG_corrected`.
4. [S02_correct_jumps.m](S02_correct_jumps.m) — removes residual fine jumps,
   resamples to 128 Hz, high-pass filters and estimates HR robustly with
   `peakednessCost`; appends `PPG_wojumps`, `HR_PN`, `tHR_PN`.
   **See [S02_README.md](S02_README.md) for detailed documentation (Spanish).**

## Validation / exploration scripts

| Script | Purpose |
|---|---|
| [compareHR_MATA2_MATA1_SHIMMER.m](compareHR_MATA2_MATA1_SHIMMER.m) | Overlays HR from MATA v1, MATA v2 and Shimmer-derived HRV, plus ENMO of both ACCs, with a time slider. |
| [compareHR.m](compareHR.m) | Builds synchronised timetables of HR across MATA recordings (10 s segments). |
| [freq_analysisMATA.m](freq_analysisMATA.m) | Welch spectrum of the (jump-corrected) PPG — sanity check. |
| [peakedness_ACCs.m](peakedness_ACCs.m) | WIP: `peakednessCost` tracking on ACC signals. |
| [extractShimmer_withErrorTimestamp.m](extractShimmer_withErrorTimestamp.m) | Rebuilds Shimmer timestamps from the file name when the timestamp channel is corrupt. |
| [asynchro.m](asynchro.m) | Visual sync check between two MATA devices via the gyroscope norm. |

## Notes

- `dataDir` is edited inline per experiment (`registros`, `newFW_prueba*`, …).
- Toolbox paths come from `paths.m` at the repo root (copy
  `paths.example.m` → `paths.m`); a few scripts still auto-detect the
  OneDrive `biomedical-signal-processing` folder from `pwd`.
