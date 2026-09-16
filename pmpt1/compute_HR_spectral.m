% compute_HR_spectral.m - Backfill HR espectral por noche, sin volver a
% correr la delineacion (que ya hizo extract_HR_main.m). Recomputa solo el
% x_clean (baseline removal +- correccion de interferencia) y la HR
% espectral por subventana de 5 min.
%
% Variables de workspace de entrada (opcionales):
%   datasetVersion      - 'v1' | 'v2_1' | 'v2_2'   (default 'v1')
%   correctInterference - true/false               (default: true salvo v1)
%   saveSuffix          - sufijo para los nombres guardados (default '')
%                         '_uncorr' -> HR_all_uncorr, tHR_all_uncorr...
%
% Lee:    data/<v>/nights/PMP*.mat  (ppg, t)
% Anade:  HR_all<suffix>, tHR_all<suffix>, specQuality_all<suffix>
%
% NB: no hace clearvars (preserva el workspace del caller cuando se invoca
%     desde un wrapper que itera sobre versiones).

addpath('lib');

if ~exist('datasetVersion','var') || isempty(datasetVersion)
    datasetVersion = 'v1';
end
if ~exist('correctInterference','var') || isempty(correctInterference)
    correctInterference = ~strcmp(datasetVersion, 'v1');
end
if ~exist('saveSuffix','var')
    saveSuffix = '';
end

fs = 25.6;
segment_duration = 4 * 60 * 60;
min_duration     = 10 * 60;
Nseg = round(segment_duration * fs);
Nmin = round(min_duration * fs);

[b_lp, a_lp] = butter(3, 0.3 /(fs/2), 'low');
[b_bp, a_bp] = butter(3, [0.5 5]/(fs/2));

dirFiles = fullfile('data', datasetVersion, 'nights');
files = dir(fullfile(dirFiles, '*.mat'));

fprintf('compute_HR_spectral: %s | correctInterference=%d | suffix="%s" | %d files\n', ...
    datasetVersion, correctInterference, saveSuffix, numel(files));

HRname = ['HR_all'          saveSuffix];
tHRname = ['tHR_all'        saveSuffix];
sQname = ['specQuality_all' saveSuffix];

for f = 1:numel(files)
    nightPath = fullfile(dirFiles, files(f).name);
    data = load(nightPath, 'ppg', 't');
    if ~isfield(data,'ppg'); fprintf('  skip %s\n', files(f).name); continue; end
    ppg = data.ppg(:);
    if isfield(data,'t'); t = data.t(:); else; t = (0:numel(ppg)-1)'/fs; end
    N = numel(ppg);

    HR_all_local = []; tHR_all_local = []; sQ_all_local = [];

    num_segments = floor(N/Nseg);
    segStarts = ((1:num_segments)-1)*Nseg + 1;
    remaining = N - num_segments*Nseg;
    if remaining >= Nmin; segStarts(end+1) = N - remaining + 1; end %#ok<AGROW>

    for s = 1:numel(segStarts)
        idx_a = segStarts(s);
        idx_b = min(idx_a + Nseg - 1, N);
        segment = ppg(idx_a:idx_b);

        % baseline removal
        xvlf = filtfilt(b_lp, a_lp, segment);
        x = segment - xvlf;

        % interpolacion en muestras malas (interferencia)
        x_clean = x;
        if correctInterference
            dx = diff(x); dx = [dx(1); dx];
            dx_abs = abs(dx);
            med = median(dx_abs);
            mad_val = median(abs(dx_abs - med));
            threshold = med + 4 * mad_val;
            idx_bad = dx_abs > threshold;
            idx_bad = conv(double(idx_bad), ones(3,1), 'same') > 0;
            good_idx = find(~idx_bad); bad_idx = find(idx_bad);
            if length(good_idx) > 10
                x_clean(bad_idx) = interp1(good_idx, x(good_idx), bad_idx, 'pchip');
            end
        end

        % filtrado paso banda
        x_final = filtfilt(b_bp, a_bp, x_clean);

        % subventanas de 5 min
        subWin = 5*60;
        Nsub = round(subWin * fs);
        numSub = max(1, floor(numel(x_final)/Nsub));

        HR  = nan(numSub, 1);
        tHR = nan(numSub, 1);
        sQ  = nan(numSub, 1);

        for w = 1:numSub
            a = (w-1)*Nsub + 1;
            b_ = min(w*Nsub, numel(x_final));
            sub = x_final(a:b_);
            t0 = (a-1)/fs; t1 = b_/fs;
            tHR(w) = (t0 + t1) / 2;

            [Pxx, F] = pwelch(sub, [], [], [], fs);
            idx_band = (F >= 0.4 & F <= 1.7);
            if sum(idx_band) < 5; continue; end

            F_band   = F(idx_band);
            Pxx_band = Pxx(idx_band);
            [~, idx_max] = max(Pxx_band);
            f_peak = F_band(idx_max);
            hrSpec = f_peak * 60;

            peakBand = abs(F - f_peak) <= 0.1;
            totalPower = sum(Pxx);
            if totalPower > 0
                sQ(w) = sum(Pxx(peakBand)) / totalPower;
            end
            if hrSpec >= 40 && hrSpec <= 120
                HR(w) = hrSpec;
            end
        end

        offset = t(idx_a);
        HR_all_local  = [HR_all_local;  HR];          %#ok<AGROW>
        tHR_all_local = [tHR_all_local; tHR + offset]; %#ok<AGROW>
        sQ_all_local  = [sQ_all_local;  sQ];          %#ok<AGROW>
    end

    out = struct();
    out.(HRname)  = HR_all_local;
    out.(tHRname) = tHR_all_local;
    out.(sQname)  = sQ_all_local;
    save(nightPath, '-struct', 'out', '-append');

    fprintf('  %s: %d sub-windows | HR med=%.1f bpm\n', files(f).name, ...
        numel(HR_all_local), median(HR_all_local, 'omitnan'));
end

fprintf('Done %s.\n', datasetVersion);
