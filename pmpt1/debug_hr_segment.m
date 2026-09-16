function debug_hr_segment(subject_id, night, segment_idx)

    fs = 25.6;
    
    % ---- rutas ----
    dirFiles = 'data\v2_1\nights\';
    
    filename = sprintf('PMP%d_night%d.mat', subject_id, night);
    data = load([dirFiles filename]);
    
    ppg = data.ppg(:);
    t_full = data.t(:);
    
    % ---- segmentación ----
    segment_duration = 30 * 60;
    Nseg = round(segment_duration * fs);
    
    idx_start = (segment_idx-1)*Nseg + 1;
    idx_end   = segment_idx*Nseg;
    
    if idx_end > length(ppg)
        error('El segmento solicitado no existe');
    end
    
    segment = ppg(idx_start:idx_end);
    t_segment = t_full(idx_start:idx_end);
    
    %% =========================
    % ---- PIPELINE ----
    %% =========================
    
% % % %     % ---- detrend ----
% % % %     x = detrend(segment);

    % ---- baseline (VLF) ----
    [b_lp, a_lp] = butter(3, 0.3/(fs/2), 'low');
    xvlf = filtfilt(b_lp, a_lp, segment);

    % ---- señal sin baseline ----
    x = segment - xvlf;


    % ---- derivada ----
    dx = diff(x);
    dx = [dx(1); dx];
    dx_abs = abs(dx);

    % ---- umbral robusto ----
    med = median(dx_abs);
    mad_val = median(abs(dx_abs - med));
    threshold = med + 4 * mad_val;

    % ---- detección ----
    idx_bad_dx = dx_abs > threshold;

    % ---- cerrar huecos ----
    idx_bad_dx = conv(double(idx_bad_dx), ones(3,1), 'same') > 0;

    % ---- interpolación ----
    x_clean = x;
    good_idx = find(~idx_bad_dx);
    bad_idx = find(idx_bad_dx);

    if length(good_idx) > 10
        x_clean(bad_idx) = interp1(good_idx, x(good_idx), bad_idx, 'pchip');
    end

    % ---- filtrado ----
    [b,a] = butter(3, [0.5 5]/(fs/2));
    x_final = filtfilt(b,a,x_clean);

    % ---- espectro ----
    [Pxx, F] = pwelch(x_final, [], [], [], fs);

    % ---- banda HR ----
    idx_band = (F >= 0.4 & F <= 1.7);
    F_band = F(idx_band);
    Pxx_band = Pxx(idx_band);

    [~, idx_max] = max(Pxx_band);
    f_peak = F_band(idx_max);
    HR = f_peak * 60;

    
%     %% =========================
%     % ---- PLOTS ----
%     %% =========================
% 
%     % -------- 0) baseline --------
%     figure;
%     plot(t_segment, segment, 'k'); hold on;
%     plot(t_segment, xvlf, 'g', 'LineWidth',1.5);
% 
%     legend('Raw','Baseline');
%     title('Estimación de baseline');
% 
    % -------- 1) señal limpia vs original --------
    figure;
    plot(t_segment, x, 'b'); hold on;
    plot(t_segment, x_clean, 'r');

    legend('Baseline removed', 'Clean');
    title(sprintf('Señal - Sujeto %d Noche %d Segmento %d', ...
        subject_id, night, segment_idx));

    xlabel('Tiempo (s)');
    ylabel('Amplitud');
    grid on;
% 
% 
    % -------- 2) derivada y umbral --------
    figure;
    plot(t_segment,dx_abs, 'b'); hold on;
    plot([t_segment(1) t_segment(end)], [threshold threshold], 'r-', 'LineWidth', 1.5);
%     text(length(dx_abs)*0.02, threshold, 'Threshold', 'Color','r');
    title('Derivada absoluta + umbral');
    xlabel('Muestras');
    ylabel('|dx|');
    grid on;

    
    % -------- 3) espectro + pico --------
    figure;
    plot(F, Pxx, 'b'); hold on;
    
    % marcar pico
    plot(f_peak, Pxx_band(idx_max), 'r*', 'MarkerSize', 10);
    
    % marcar banda HR
    yl = ylim;
    plot([0.4 0.4], yl, '--k');
    plot([1.7 1.7], yl, '--k');
    
    % limitar eje X
    xlim([0 3]);
    
    title(sprintf('Espectro (HR = %.2f bpm)', HR));
    xlabel('Frecuencia (Hz)');
    ylabel('PSD');
    grid on;

end