function [HR, tHR, qualityFlag, specQuality, nD, nZ, nB, x_clean] = ...
    estimate_hr_segment3(segment, fs, correctInterference, plotflag, ...
                         specWindowSeconds, specOverlap)
% ESTIMATE_HR_SEGMENT3  Delineacion de pulso PPG y HR espectral de un segmento.
%
%   [HR, tHR, qualityFlag, specQuality, nD, nZ, nB, x_clean] = ...
%       estimate_hr_segment3(segment, fs, correctInterference, plotflag, ...
%                            specWindowSeconds, specOverlap)
%
%   Igual que estimate_hr_segment2, pero la HR espectral no se calcula sobre
%   subventanas contiguas de 5 min, sino sobre una VENTANA DESLIZANTE de
%   specWindowSeconds con un solapamiento specOverlap (fraccion 0-1). Cada
%   ventana se estima con un periodograma de Welch de un solo segmento
%   (ventana de Hamming), que da mejor resolucion frecuencial que el Welch
%   por defecto en ventanas cortas.
%
%   correctInterference  true  -> corrige la interferencia del PPG (firmware v2):
%                                 detecta artefactos en la derivada e interpola.
%                        false -> senal limpia (v1): solo se elimina el baseline,
%                                 x_clean = x. Por defecto true.
%   plotflag             activa/desactiva todo el ploteo. Por defecto true.
%   specWindowSeconds    tamano de la ventana espectral (s). Por defecto 60.
%   specOverlap          solapamiento entre ventanas (0-1). Por defecto 0.5.
%
%   Salidas por ventana espectral deslizante (vectores columna):
%     HR           HR espectral (bpm); NaN si cae fuera de [40, 120].
%     tHR          centro temporal de la ventana (s, relativo al segmento).
%     qualityFlag  true si |HR espectral - HR de deteccion| supera el umbral.
%     specQuality  picudez del pico espectral (potencia en banda estrecha
%                  alrededor del pico / potencia total). Mayor = pico mas limpio.
%   Salidas sobre todo el segmento:
%     nD, nZ, nB   fiducial points (s). x_clean: senal usada en la delineacion.

    if nargin < 3 || isempty(correctInterference)
        correctInterference = true;
    end
    if nargin < 4 || isempty(plotflag)
        plotflag = true;
    end
    if nargin < 5 || isempty(specWindowSeconds)
        specWindowSeconds = 60;
    end
    if nargin < 6 || isempty(specOverlap)
        specOverlap = 0.5;
    end

    segment = segment(:);

    %% ---- 1) REMOCION DE BASELINE (MEJOR QUE DETREND) ----

    % filtro paso bajo para extraer baseline (<0.5 Hz)
    [b_lp, a_lp] = butter(3, 0.3/(fs/2), 'low');
    xvlf = filtfilt(b_lp, a_lp, segment);

    % senal sin baseline
    x = segment - xvlf;

    %% ---- 2-3) CORRECCION DE INTERFERENCIA (solo v2) ----

    x_clean = x;

    % mascara de muestras interpoladas para corregir la interferencia
    interpMask = false(numel(segment), 1);

    if correctInterference

        % deteccion de artefactos en la derivada
        dx = diff(x);
        dx = [dx(1); dx];
        dx_abs = abs(dx);

        med = median(dx_abs);
        mad_val = median(abs(dx_abs - med));
        threshold = med + 4 * mad_val;

        idx_bad_dx = dx_abs > threshold;

        % cerrar huecos (clave)
        idx_bad_dx = conv(double(idx_bad_dx), ones(3,1), 'same') > 0;

        % interpolacion de las muestras malas
        good_idx = find(~idx_bad_dx);
        bad_idx = find(idx_bad_dx);

        if length(good_idx) > 10
            x_clean(bad_idx) = interp1(good_idx, x(good_idx), bad_idx, 'pchip');
            interpMask(bad_idx) = true;
        end

    end

    %% ---- DELINEACION DEL PULSO ----

    setup.wdwMedian = 30*60;
    setup.plotflag = plotflag;
    isArtifact = energyArtifacts(x_clean, fs, setup);

    setup.isArtifact = isArtifact;       % maximo de 120 bpm
    setup.refractPeriod = 500e-03;       % maximo de 120 bpm
    setup.wdw_nA = 450e-3;
    setup.wdw_nB = 350e-3;
    setup.wdw_nZ = 350e-3;
    setup.fsi = 5*fs;
    setup.plotflag = true;
    [nD, nB, ~, ~, ~, ~, ~, nZ] = pulseDelineation(x_clean, fs, setup);

    nD = nD(:);
    nB = nB(:);
    nZ = nZ(:);

    % % % los fiducial points que caen sobre una muestra interpolada se ponen a
    % % % NaN: el pulso existe, pero su localizacion exacta no es fiable
    % % if any(interpMask)
    % %     nD = discardInterpFiducials(nD, interpMask, fs);
    % %     nZ = discardInterpFiducials(nZ, interpMask, fs);
    % %     nB = discardInterpFiducials(nB, interpMask, fs);
    % % end

    if plotflag
        figure
        plot(nD(1:end-1), 60./diff(nD)); hold on
        plot(nZ(1:end-1), 60./diff(nZ))
        plot(nB(1:end-1), 60./diff(nB))
    end

    %% ---- FILTRADO PASO BANDA ----

    [b, a] = butter(3, [0.5 5]/(fs/2));
    x_final = filtfilt(b, a, x_clean);

    %% ---- HR ESPECTRAL POR VENTANA DESLIZANTE ----
    %  Ventanas de specWindowSeconds con un solapamiento specOverlap, en vez
    %  de subventanas contiguas de 5 min.

    Wsamp    = round(specWindowSeconds * fs);
    stepSamp = max(1, round(Wsamp * (1 - specOverlap)));

    lastStart = length(x_final) - Wsamp + 1;
    if lastStart < 1
        winStarts = 1;                       % senal mas corta que la ventana
    else
        winStarts = 1:stepSamp:lastStart;
    end
    numSub = numel(winStarts);

    HR          = nan(numSub, 1);
    tHR         = nan(numSub, 1);
    qualityFlag = false(numSub, 1);
    specQuality = nan(numSub, 1);

    hrLimits = [40 120];
    discrepancyThreshold = 10;           % bpm; parametro a refinar

    % deteccion de referencia del ritmo (nZ); el ritmo medio es practicamente
    % independiente del fiducial elegido
    detPoints = nZ(~isnan(nZ));

    for w = 1:numSub

        idx_a = winStarts(w);
        idx_b = min(idx_a + Wsamp - 1, length(x_final));
        sub = x_final(idx_a:idx_b);

        t0 = (idx_a-1)/fs;
        t1 = idx_b/fs;
        tHR(w) = (t0 + t1) / 2;

        % --- HR espectral de la ventana ---
        % periodograma de Welch de un solo segmento (ventana de Hamming sobre
        % toda la ventana): mejor resolucion frecuencial en ventanas cortas
        [Pxx, F] = pwelch(sub, hamming(numel(sub)), 0, [], fs);

        idx_band = (F >= 0.4 & F <= 1.7);
        if sum(idx_band) < 5
            continue;
        end

        F_band = F(idx_band);
        Pxx_band = Pxx(idx_band);

        [~, idx_max] = max(Pxx_band);
        f_peak = F_band(idx_max);
        hrSpec = f_peak * 60;

        % --- calidad de la estimacion espectral: picudez del pico ---
        % potencia en banda estrecha alrededor del pico / potencia total
        peakBand = abs(F - f_peak) <= 0.1;
        totalPower = sum(Pxx);
        if totalPower > 0
            specQuality(w) = sum(Pxx(peakBand)) / totalPower;
        end

        % --- validacion de limites de HR ---
        if hrSpec >= hrLimits(1) && hrSpec <= hrLimits(2)
            HR(w) = hrSpec;
        end

        % --- HR de deteccion en la ventana y flag de discrepancia ---
        subDet = detPoints(detPoints >= t0 & detPoints < t1);
        if numel(subDet) > 2
            dtk = diff(subDet);
            dtkThreshold = median(dtk) + 3 * median(abs(dtk - median(dtk)));
            dtk = dtk(dtk <= dtkThreshold);
            if ~isempty(dtk)
                hrDet = 60 / median(dtk);
                qualityFlag(w) = abs(hrSpec - hrDet) > discrepancyThreshold;
            end
        end

    end

    if plotflag
        plot(tHR, HR, 'k-o', 'LineWidth', 2);
        yyaxis right
        plot(tHR, specQuality)
        legend('nD', 'nZ', 'nB', 'HR espectral', 'spectral quality');
    end

end

function fid = discardInterpFiducials(fid, interpMask, fs) %#ok<DEFNU>
% DISCARDINTERPFIDUCIALS  Pone a NaN los fiducial points que caen sobre una
% muestra interpolada (marcada en interpMask). fid en segundos.
    valid = find(~isnan(fid));
    if isempty(valid)
        return;
    end
    sampleIdx = round(fid(valid) * fs) + 1;
    sampleIdx = min(max(sampleIdx, 1), numel(interpMask));
    fid(valid(interpMask(sampleIdx))) = NaN;
end
