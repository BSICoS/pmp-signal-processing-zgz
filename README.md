# pmp-signal-processing-zgz

Signal-processing pipelines of the **WearablePerMed / PMP** project
([BSICoS group](https://github.com/BSICoS), I3A – Universidad de Zaragoza).

MATLAB-first pipelines (plus small R and Python utilities) that convert raw
multi-device wearable recordings into heart-rate (HR), heart-rate-variability
(HRV) and physical-activity / sleep metrics for the project cohorts.

## Repository layout

| Folder | Scope | Docs |
|---|---|---|
| [matav2/](matav2/) | Development & validation of the **MATA v2 firmware** processing: PPG jump correction, robust spectral HR, comparison against MATA v1 and a Shimmer ECG reference | [matav2/README.md](matav2/README.md) |
| [pmpt0/](pmpt0/) | **T0 (baseline) cohort** pipeline: BIN→CSV conversion, Holter ECG → HRV, PPG cleaning → HR/HRV, GGIR activity & sleep bouts | [pmpt0/README.md](pmpt0/README.md) |
| [pmpt1/](pmpt1/) | **T1 (follow-up) cohort** pipeline: night segmentation, PPG pulse delineation + spectral HR, time-domain HRV sweep, report generation | [pmpt1/README.md](pmpt1/README.md) |
| [tools/](tools/) | Shared utilities (e.g. the `.BIN` → `.csv` converter) | — |

## Devices and signals

| Device | Signals used | Native format | fs |
|---|---|---|---|
| MATA / MATRIX wrist device | PPG, 3-axis ACC, 3-axis GYR, skin & ambient temperature, onboard HR | `.BIN` (proprietary, converted to CSV) | 25.6 Hz |
| FAROS Holter | ECG (ACC also in T1 exports) | `.EDF` | 1000 Hz (T0) |
| Shimmer3 (validation reference) | ECG leads I/II/III, ACC | `.mat` (Consensys export) | — |
| Garmin | HR | `.FIT` | — |

Physical-activity and sleep classification is done with the **GGIR** R package
run directly on the wrist `.BIN` files; strict bout detection is refined in
MATLAB post-processing.

## Dependencies

- **MATLAB** with Signal Processing Toolbox.
- Internal MATLAB toolboxes (not in this repo, expected on the MATLAB path):
  `biomedical-signal-processing` and
  [`biosigmat`](https://github.com/dcajal/biosigmat)
  (`pulseDelineation`, `energyArtifacts`, `tdmetrics`, `medfiltThreshold`,
  `peakednessCost`, `delinearECG`).
- **R** with `GGIR` ≥ 3.2-3 and `GGIRread` ≥ 1.0.4 (≥ 1.0.7 recommended) for
  [pmpt0/WearablePerMed_GGIRproc_PabloA_bin.r](pmpt0/WearablePerMed_GGIRproc_PabloA_bin.r).
- **Python 3** with `tqdm` (`.BIN` → `.csv` conversion,
  [tools/bin2csv.py](tools/bin2csv.py)) and `fitparse` + `tzdata` (Garmin
  `.FIT` import).

## Data (important)

- **No raw recordings are stored in this repo.** Signals contain subject data
  and live on the group NAS  (`.gitignore` blocks `*.mat`,
  `*.csv`, `*.edf`, `data/`, …).
- **Machine-specific paths are centralized in `paths.m`** (not committed):
  copy [paths.example.m](paths.example.m) to `paths.m`, edit it for your
  machine, and keep the repo root on the MATLAB path (`pathtool`/`startup.m`).
  A few legacy scripts still carry inline `rootDir` lines and are migrated
  incrementally.
- Each pipeline stage reads the `.mat` files produced by the previous stage and
  appends new variables — see the per-folder READMEs for the execution order.
- Code comments are mostly in Spanish.

## License

[MIT](LICENSE) — Copyright (c) 2026 BSICoS Group, I3A / Universidad de
Zaragoza. The license covers the code only: never commit or share
patient-derived data.
