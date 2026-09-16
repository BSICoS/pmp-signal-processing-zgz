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
- **Python 3** with `tqdm` (`.BIN` → `.csv` conversion) and
  `fitparse` + `tzdata` (Garmin `.FIT` import).

## Data (important)

- **No raw recordings are stored in this repo.** Signals contain subject data
  and live on the group NAS / OneDrive folders; scripts currently reference
  them with hard-coded absolute paths that must be adapted per machine.
- Each pipeline stage reads the `.mat` files produced by the previous stage and
  appends new variables — see the per-folder READMEs for the execution order.
- Code comments are mostly in Spanish.

## License

License pending — contact the authors before reuse. Do not commit or share any
patient-derived data.
