# set working directory
setwd("d:/OneDrive - unizar.es/UNIVERSIDAD/DOCTORADO/0_WerPerMed/REGISTROS_COMPLETOS/ggir_analysis")

# Direct .BIN reading via GGIRread::readParmayMatrix (added in GGIRread 1.0.4,
# bug-fix for acc/gyro scaling in 1.0.7). Replaces the bin2csv.py + LOCF-temp
# resample pipeline: readParmayMatrix already interpolates temperature gaps
# between adjacent packets internally.
#
# Requires: GGIR >= 3.2-3, GGIRread >= 1.0.4 (recommended 1.0.7).
#
# CANONICAL CONFIGURATION (see GGIR_PARAMS_EXPLAINED.md §6):
#   - boutdur.* = c(1)  + part5_agg2_60seconds = TRUE
#     -> ms5.outraw has 1 row per minute, class_id encoding intensity band
#   - bout detection / segmentation (>= 3 min, strict intensity bands)
#     is delegated to MATLAB post-processing (strict_bouts.m).
#   - GGIR's own "_bts" labels are NOT used downstream because they:
#       (a) carry no information here (boutdur=1 makes every active min a bout)
#       (b) mix activity classes when the cumulative-threshold bout extends
#           across band boundaries (see Discussion at wadpac/GGIR)

stopifnot(utils::packageVersion("GGIR")     >= "3.2.3")
stopifnot(utils::packageVersion("GGIRread") >= "1.0.4")

dir.create("./output_2026_bin_bt1_agg/", showWarnings = FALSE)

# run GGIR directly on .BIN files
library(GGIR)      # v.3.3-6
library(GGIRread)  # v.1.0.8
GGIR(mode = c(1:5), do.parallel = TRUE,
     datadir = dir("dataset_bin/data/", full.names = TRUE, pattern = "\\.BIN$"),
     outputdir = "output_2026_bin_bt1_agg/",
     studyname = "pabloA",
     idloc = 2,
     # Parmay Matrix reading parameters (replace the rmc.* CSV block)
     interpolationType = 1,
     desiredtz = "Europe/Madrid",
     # Physical activity thresholds (mg) — alineado con el resto del grupo
     mvpathreshold = 100,
     threshold.lig = 45, threshold.mod = 100, threshold.vig = 400,
     # boutdur=1 because strict-band bouts >=3 min are detected in MATLAB
     boutdur.mvpa = c(1), boutdur.in = c(1), boutdur.lig = c(1),
     boutcriter.mvpa = 0.8, boutcriter.in = 0.9, boutcriter.lig = 0.8,
     # Aggregate to 60-s epochs: each ms5.outraw row = 1 min
     part5_agg2_60seconds = TRUE,
     timewindow = c("MM"),
     save_ms5rawlevels = TRUE, save_ms5raw_without_invalid = FALSE,
     save_ms5raw_format = c("csv", "RData"),
     #REPORTS
     do.report = c(2, 4, 5),
     visualreport = TRUE)
