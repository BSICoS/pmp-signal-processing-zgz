clear;close all force;clc

addpath('SNR_ECG\toolbox\');
addpath('..\validation_metrics\funtions\');

rootDir =  "..\REGISTROS 3 DIAS";
sujDirs = dir(rootDir);sujDirs = sujDirs([sujDirs.isdir]);sujDirs = sujDirs(~ismember({sujDirs.name}, {'.', '..'}));

plotflag = false;

for suj = 1:numel(sujDirs)
    
    clearvars -except sujDirs suj rootDir plotflag*

    close all

    tic;

    sujID = sujDirs(suj).name; disp(sujID);

    load (['..\REGISTROS 3 DIAS\' sujID '\' sujID '_tK.mat']);
    HOLTERo = load (['..\REGISTROS 3 DIAS\' sujID '\' sujID '_holter.mat'],'ECG','timeStamp'); HOLTERo=struct2table(HOLTERo);

    % Align the Holter onto the tK clock for ALL subjects. The _holter.mat was
    % re-timestamped (timezone) AFTER tK was computed -> a whole-hour offset for
    % some subjects (suj01 = +1 h; several suj>=13). This matters because
    % resample_ecg below maps the R-peaks onto the Holter timeline BY TIMESTAMP:
    % if the Holter is offset, the R-peak indices i_tK land on the wrong samples,
    % the SVD beat matrix is built off-beat, and the SNR collapses to ~noise even
    % on excellent ECG (this is exactly why suj01 had a uniformly ~1 dB SNR
    % despite a clean, well-delineated ECG). The offset is the median over beats
    % of (Holter timestamp at the beat sample - tK timestamp): robust to
    % first-beat latency AND to non-uniform/gappy Holter sampling (the old
    % suj>=13-only first-sample formula was fooled by both).
    i_tK0 = 1 + round(tK.tK*1000);  i_tK0 = min(max(i_tK0,1), numel(HOLTERo.timeStamp));
    desfase_ecg = round(hours( median( HOLTERo.timeStamp(i_tK0) - tK.timeStamp ) ));
    HOLTERo.timeStamp = HOLTERo.timeStamp - hours(desfase_ecg);
    fprintf('  Holter->tK offset corrected: %+d h\n', -desfase_ecg);

    % Downsampling parameters
    ds_factor = 2;
    fs = 1000/ds_factor; % 200 Hz sampling rate, for plotting ECG, but original tK are saved for the analysis
    tKr = table();
    HOLTER = table();
    [HOLTER.ECG, HOLTER.timeStamp, tKr.i_tK] = resample_ecg (HOLTERo.ECG, HOLTERo.timeStamp, fs, tK.timeStamp, false );
    % clear HOLTERo;
    tKr.tK = tKr.i_tK./fs;
    tKr.timeStamp = tK.timeStamp;    

    ECG     =   HOLTER.ECG;
    t       =   HOLTER.timeStamp;
    i_tK    =   unique(tKr.i_tK);

    clear HOLTER HOLTERo
    
    % clearvars -except patientDirs p rootDir plotflag;
    % close all force;
    % 
    % sujID = sujDirs(p).name;
    % sujPath = fullfile(rootDir, sujID);
    % 
    % fileDir = dir(fullfile(sujPath ,[sujID '_holter.mat']));
    % filePath = fullfile(fileDir.folder, fileDir.name);
    % 
    % disp(['Processing: ' filePath]);
    % 
    % load(filePath,'ECG','timeStamp');
    % load(fullfile(sujPath, [sujID '_tK.mat']));
    % 
    % fs = 1000;
    % t = (0:1:length(ECG)-1)./fs;
    % t = timeStamp;
    
    % %% downsample
    % 
    % % ds_factor = 4;
    % % fs = fs / ds_factor;
    % % ECG = downsample (ECG,ds_factor); %clear ECG;
    % % t = downsample (timeStamp,ds_factor);% clear timeStamp;
    % 
    % i_tK = 1+round(tK.tK*fs);


    %% Noise estimation & SNR

    [bb, aa] = butter(4, [0.5 40] / (fs / 2), 'bandpass');
    ECG = filtfilt(bb, aa, ECG);
    
    noise_estimate_signal = ecg_estimate_noise(ECG, i_tK, fs);

    stride_length = fs;
    window_radius = 5;
    [ecg_signal_power, ecg_noise_power, ecg_snr, ecg_noise_color, ecg_ccsnr] = ...
        calculate_signal_properties(ECG, noise_estimate_signal, fs, stride_length, window_radius);

    r_peak_dynamics = calculate_peak_dynamics(i_tK, ECG(i_tK), fs, stride_length, window_radius, length(ECG))';

    % min_length = 60*5;
    % max_length = 60*10;
    min_length = 60*1;
    max_length = 60*60;
    min_snr = 5; % en el codigo inicial estaba a 7! pero eso es para sueño. lo he bajado un poco a ver si no eliminamos tanto
    % NOTA (mask de calidad ECG): el SQI guardado abajo (ecg_snr, r_peak_dynamics)
    % es INDEPENDIENTE del umbral. El umbral de aceptacion definitivo se aplica en
    % validation_metrics/ecg_quality_mask_all.m (recalcula snr_ok desde SQI con su
    % propio min_snr, por defecto 7 dB segun METHODS_FOR_PUBLICATION.md). Los
    % 'segments' que se guardan aqui con min_snr=5 quedan como referencia legacy.
    max_peak_dynamic = std(nonnan(r_peak_dynamics)) * 3 + mean(nonnan(r_peak_dynamics));
    features_samplerate = fs / stride_length;
    [segments_start, segments_end] = select_low_noise_segments(fs, features_samplerate, min_length, max_length, ecg_snr(:), min_snr, r_peak_dynamics(:), max_peak_dynamic);

    feature_samplerate_factor = fs / features_samplerate;
    segments_start = max(1,floor(floor(segments_start ./ feature_samplerate_factor) * feature_samplerate_factor));
    segments_end=min(ceil(ceil((segments_end+1) ./ feature_samplerate_factor) * feature_samplerate_factor) - 1, length(ECG));

    %%
    if plotflag

        % t_dt = t;
        % t = posixtime(t_dt); t= t-t(1);

        fig = figure('Visible', 'On', 'SelectionHighlight', 'Off' );
        set(fig, 'PaperType', 'A4', 'PaperOrientation','landscape', 'PaperUnits','normalized', 'PaperPosition', [0 0 1 1]);

        ph = uipanel('Parent',fig,'BorderType','none', 'Visible', 'Off');
        ph.FontSize = 12;
        ph.FontWeight = 'bold';
        set(ph,'BackgroundColor', [1 1 1]);

        zoom(fig, 'xon');
        % pan(h, 'xon');

        colormap_lines = lines();

        subplots_y = 4;
        subplots_x = 1;
        ss = 0;

        ss = ss +1;
        ax(ss) = subplot(subplots_y, subplots_x, ss, 'Parent',ph);
        hold on; grid on; box on;
        plot(t,ECG);
        plot(t(i_tK),ECG(i_tK),'*');% y_min = min(ECG,1)*1.1; % y_max = max(ECG,99)*1.1;
        ylabel('ECG Signal');  % ylim([y_min y_max]);

        ss = ss +1;
        ax(ss) = subplot(subplots_y, subplots_x, ss, 'Parent',ph);hold on; grid on; box on;
        y_min = 0;y_max = max(max(ecg_snr), max(ecg_ccsnr)) * 1.1;        
        for jj=1:length(segments_start)
            % current_x_start = segments_start(jj) / fs;
            % current_x_end = segments_end(jj) / fs;
            current_x_start = t(segments_start(jj));
            current_x_end = t(segments_end(jj));
            current_color=colormap_lines(rem(jj-1, size(colormap_lines,1))+1,:);
            patch([current_x_start;current_x_end;current_x_end;current_x_start], ...
                [y_min; y_min; y_max; y_max;], ...
                current_color, ...
                'FaceAlpha', 0.5, ...
                'FaceColor', current_color, ...
                'EdgeColor', current_color);
        end
        plot( t(1:fs:end), ecg_snr );
        yline(min_snr);
        ylabel('SNR');
        ylim([y_min y_max]);

        ss = ss +1;
        ax(ss) = subplot(subplots_y, subplots_x, ss, 'Parent',ph); hold on; grid on; box on;
        plot( t(1:fs:end) , ecg_ccsnr);
        yline(min_snr);
        ylabel('ccSNR');
        ylim([y_min y_max]);
        linkaxes(ax(ss-1:ss), 'y');

        ss = ss +1;
        ax(ss) = subplot(subplots_y, subplots_x, ss, 'Parent',ph); hold on; grid on; box on;
        %        set(gca, 'YScale', 'log')
        y_min = 1; y_max = max(r_peak_dynamics) * 2;
        plot( t(1:fs:end) , r_peak_dynamics);       
        %        max_peak_dynamic_log = exp(std(log(nonnan(r_peak_dynamics))) * 2 + mean(log(nonnan(r_peak_dynamics))));
        %        line([1 length(ecg_ccsnr)] ./ features_samplerate, [max_peak_dynamic_log max_peak_dynamic_log], 'Color','green');
        ylabel('R-Peak Dynamics'); yline(max_peak_dynamic);   %         set(gca, 'YScale', 'log')
        ylim([min(r_peak_dynamics) max(r_peak_dynamics)]);
        linkaxes(ax, 'x');   xlim([t(1) t(end)]);

        set(ph, 'Visible', 'On');
        drawnow;
        % print(h, '-dpdf', '-r600', figure_filename);
        set(fig, 'Visible', 'on')

    end

    segments.idx(:,1) = segments_start(:);
    segments.idx(:,2) = segments_end(:);

    for jj=1:length(segments_start)
        segments.t(jj,1) = t(segments_start(jj));
        segments.t(jj,2) = t(segments_end(jj));
    end

    segments            =   struct2table(segments);

    ecg_noise           =   noise_estimate_signal (:);

    SQI.t               =   t(1:fs:end);
    SQI.r_peak_dynamics =   r_peak_dynamics (:);
    SQI.ecg_noise_color =   ecg_noise_color(:);
    SQI.ecg_power       =   ecg_signal_power(:);
    SQI.noise_power     =   ecg_noise_power(:);
    SQI.ecg_snr         =   ecg_snr(:);
    SQI.ecg_snr_color   =   ecg_ccsnr(:);
    SQI                 =   struct2table(SQI);

    save(fullfile(sujDirs(suj).folder,sujDirs(suj).name,[sujDirs(suj).name '_qualityECG.mat']),'SQI','segments','ecg_noise');

    elapsed_time = toc; % End timing for this subject
    fprintf('Subject %s completed in %.2f minutes\n', sujID, elapsed_time/60);

end

