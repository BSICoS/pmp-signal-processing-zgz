function writeMethodsSection(fid)
% writeMethodsSection - Escribe la seccion de metodologia (pipeline de
% procesamiento de senal) en el fichero markdown abierto en 'fid'.
% Usado por compareDatasetVersionsV2.m y reportMhrEvolutionV2.m.

fprintf(fid, '## Metodologia: pipeline de procesamiento de senal\n\n');
fprintf(fid, 'Del PPG crudo a las metricas de HRV nocturnas en cuatro etapas. Cada script lee los `.mat` de la etapa anterior y anade variables.\n\n');

fprintf(fid, '### 1. Troceado nocturno - `segmentNights.m`\n\n');
fprintf(fid, 'Empareja cada PPG de sujeto (`data/<v>/ppg/`, variable `PPG_corrected_resampled` a fs = 25.6 Hz) con su fichero GGIR. Las noches son los tramos contiguos con `GGIR.SleepPeriodTime == 1`, proyectados sobre el tiempo del PPG y limpiados con `lib/cleanGgirNightBounds.m`. Salida: `data/<v>/nights/PMP<id>_night<N>.mat` con `ppg` y `t` (t = 0 al inicio del sueno).\n\n');

fprintf(fid, '### 2. Delineacion de pulso y correccion de interferencia - `extract_HR_main.m` + `estimate_hr_segment2.m`\n\n');
fprintf(fid, '`extract_HR_main.m` recorre cada noche en segmentos de 4 h y delega en `estimate_hr_segment2.m`, que por segmento:\n\n');
fprintf(fid, '1. **Remocion de baseline**: Butterworth paso-bajo de 3er orden a 0.3 Hz; `x = ppg - baseline`.\n');
fprintf(fid, '2. **Correccion de interferencia** (solo v2_1/v2_2; v1 se procesa sin correccion): detecta artefactos en la derivada con umbral robusto `mediana + 4*MAD`, ensancha los tramos malos (convolucion) e interpola las muestras afectadas con pchip.\n');
fprintf(fid, '3. **Delineacion del pulso**: `energyArtifacts` + `pulseDelineation` (biosigmat), con upsampling a 5*fs y periodo refractario de 500 ms. Devuelve tres fiducial points por latido: **nD** (maxima pendiente de subida), **nB** (punto basal) y **nZ** (cruce por cero / onset).\n');
fprintf(fid, '4. **Descarte de fiducials no fiables**: los nD/nB/nZ que caen sobre una muestra interpolada se ponen a NaN (el latido existe, pero su localizacion temporal exacta no es fiable).\n');
fprintf(fid, '5. **HR espectral por subventana de 5 min**: `pwelch` y pico en la banda 0.4-1.7 Hz.\n\n');
fprintf(fid, 'Salida: `nD_all`, `nZ_all`, `nB_all` y `tk` anadidos a cada night file. `compute_HR_spectral.m` rellena ademas `HR_all`, `tHR_all` y `specQuality_all` (HR espectral). `extract_HR_uncorrected_examples.m` repite el proceso con `correctInterference = false` para unos sujetos de ejemplo (variables con sufijo `_uncorr`).\n\n');

fprintf(fid, '### 3. HRV en dominio temporal - `hrvtd.m`\n\n');
fprintf(fid, 'Lee la serie de fiducials elegida (`nD_all`, `nZ_all` o `nB_all`) como serie de tiempos de latido `tk`, trocea la noche en ventanas de W minutos y, por ventana: `dtk = diff(tk)`, elimina intervalos atipicos con `medfiltThreshold` y calcula MHR, SDNN y RMSSD con `tdmetrics`. Filtros de validez: MHR en [40, 180] bpm, SDNN/RMSSD en [5, 140] ms. Salida: `data/<v>/hrvtd/hrvtd_results_<v>_<fiducial>_<W>min.mat`. `run_hrvtd_sweep.m` ejecuta el barrido completo: 3 versiones x 3 fiduciales (nD/nZ/nB) x 4 ventanas (5/10/30/60 min).\n\n');

fprintf(fid, '### 4. Reportes\n\n');
fprintf(fid, '- `compareDatasetVersionsV2.m`: comparativa entre versiones (`data/comparison/comparison_report.md`).\n');
fprintf(fid, '- `reportMhrEvolutionV2.m`: informe por version con sensibilidad fiducial (`data/<v>/hrvtd/mhr_report/`).\n');
fprintf(fid, '- `buildSubjectComparisonPlots.m`: plots por sujeto de HR MATRIX vs HR espectral vs mHR de deteccion (`data/comparison/subject_plots/`).\n\n');
fprintf(fid, 'Orquestadores: `runAllCompute.m` (etapas 2-3) y `runAllReports.m` (etapa 4).\n\n');

fprintf(fid, '### Referencia del dispositivo y dependencias\n\n');
fprintf(fid, '- HR onboard del dispositivo MATRIX por noche: `data/<v>/pr/` (variables `HR`, `t`, `timeStamp`).\n');
fprintf(fid, '- MATLAB Signal Processing Toolbox y la biblioteca [biosigmat](https://github.com/dcajal/biosigmat) (`pulseDelineation`, `energyArtifacts`, `tdmetrics`, `medfiltThreshold`), anadida con `addpath(genpath(...))`.\n\n');
end
