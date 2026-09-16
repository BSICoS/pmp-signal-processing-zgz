clearvars -except datasetVersion; clc;

repoRoot = fileparts(fileparts(mfilename('fullpath'))); addpath(repoRoot);
p = paths();
addpath(genpath(p.biosigmat));
addpath(genpath(p.biomedSigProc));

addpath('lib');

if ~exist('datasetVersion', 'var') || isempty(datasetVersion)
    datasetVersion = 'v1';
end

fs = 25.6;

segment_duration = 4 * 60 * 60;
min_duration = 10 * 60;

% --- parametros del HR espectral (estimate_hr_segment3, ventana deslizante) ---
specWindowSeconds = 60;     % tamano de la ventana del espectro (s)
specOverlap       = 0.5;    % solapamiento entre ventanas consecutivas (0-1)

Nseg = round(segment_duration * fs);
Nmin = round(min_duration * fs);

% v1 tiene PPG limpio; v2_1/v2_2 necesitan correccion de interferencia
correctInterference = ~strcmp(datasetVersion, 'v1');

dirFiles = fullfile('data', datasetVersion, 'nights');
outDir   = fullfile('data', datasetVersion, 'hr');

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

files = dir(fullfile(dirFiles, '*.mat'));

fprintf('Procesando %d noches de %s (correctInterference = %d)\n', ...
    numel(files), datasetVersion, correctInterference);

for f = 40:length(files)

    nightPath = fullfile(dirFiles, files(f).name);
    disp(nightPath);

    % ---- cargar sujeto ----
    data = load(nightPath);

    ppg = data.ppg(:);
    if isfield(data, 't')
        t = data.t(:);
    else
        t = (0:numel(ppg)-1)' / fs;
    end
    N = length(ppg);

    % reset por sujeto
    HR_all          = [];
    tHR_all         = [];
    qualityFlag_all = [];
    specQuality_all = [];
    nD_all          = [];
    nZ_all          = [];
    nB_all          = [];

    % ---- lista de inicios de segmento (completos + ultimo parcial) ----
    num_segments = floor(N / Nseg);
    segStarts = ((1:num_segments) - 1) * Nseg + 1;

    remaining = N - num_segments * Nseg;
    if remaining >= Nmin
        segStarts(end+1) = N - remaining + 1; %#ok<SAGROW>
    end

    % ---- procesar cada segmento ----
    for segIdx = 1:numel(segStarts)

        idx_start = segStarts(segIdx);
        idx_end   = min(idx_start + Nseg - 1, N);

        segment = ppg(idx_start:idx_end);

        plotflag = true;
        % try
            [HR, tHR, qFlag, sQ, nD, nZ, nB] = ...
                estimate_hr_segment2(segment, fs, correctInterference, plotflag);
            [HR, tHR, qFlag, sQ, nD, nZ, nB] = ...
                estimate_hr_segment3(segment, fs, correctInterference, plotflag, ...
                                     specWindowSeconds, specOverlap);
        % catch ME
        %     warning('Segmento %d de %s fallo: %s', segIdx, files(f).name, ME.message);
        %     HR = NaN; tHR = NaN; qFlag = NaN; sQ = NaN;
        %     nD = NaN; nZ = NaN; nB = NaN;
        % end

        % offset temporal: tiempo de noche del primer sample del segmento
        offset = t(idx_start);

        HR_all          = [HR_all;          HR(:)];          %#ok<AGROW>
        tHR_all         = [tHR_all;         tHR(:) + offset]; %#ok<AGROW>
        qualityFlag_all = [qualityFlag_all; qFlag(:)];        %#ok<AGROW>
        specQuality_all = [specQuality_all; sQ(:)];           %#ok<AGROW>

        nD_all = [nD_all; nD(:) + offset]; %#ok<AGROW>
        nZ_all = [nZ_all; nZ(:) + offset]; %#ok<AGROW>
        nB_all = [nB_all; nB(:) + offset]; %#ok<AGROW>

    end

    % ---- limpiar y ordenar detecciones ----
    nD_all = sort(nD_all(~isnan(nD_all)));
    nZ_all = sort(nZ_all(~isnan(nZ_all)));
    nB_all = sort(nB_all(~isnan(nB_all)));

    % tk = fiducial consumido por hrvtd.m (provisional: nZ)
    tk = nZ_all;

    % i_tk = 1+round(tk*fs); i_tk=i_tk(~isnan(i_tk));
    % figure
    % plot(t,ppg)
    % hold on
    % plot(t(i_tk),ppg(i_tk),'^');


    % ---- guardar detecciones en el archivo de noche ----
    % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % save(nightPath, 'nD_all', 'nZ_all', 'nB_all', 'tk', '-append');

    % ---- estadisticos de HR ----
    HR_clean = HR_all(~isnan(HR_all));
    if isempty(HR_clean)
        HR_mean = NaN; HR_median = NaN; HR_min = NaN;
    else
        HR_mean   = mean(HR_clean);
        HR_median = median(HR_clean);
        HR_min    = min(HR_clean);
    end

    % ---- guardar HR espectral ----
    [~, name, ~] = fileparts(files(f).name);

    % El fichero guarda tambien specWindowSeconds y specOverlap para saber
    % con que parametros de ventana espectral se calculo este resultado.
    % save(fullfile(outDir, [name '.mat']), ...
    %     'HR_all', 'tHR_all', 'qualityFlag_all', 'specQuality_all', ...
    %     'HR_mean', 'HR_median', 'HR_min', ...
    %     'specWindowSeconds', 'specOverlap');

    % ---- feedback ----
    fprintf('Procesado: %s | HR medio: %.2f bpm | %d detecciones nZ\n', ...
        name, HR_mean, numel(nZ_all));

end

%%%%%%%%%%%%% PLOT
%% 
if ~exist('datasetVersion', 'var') || isempty(datasetVersion)
    datasetVersion = 'v2_1';
end

files = dir(fullfile('data', datasetVersion, 'hr', '*.mat'));

names = {files.name};

% extraer IDs de sujetos (PMPxxxx)
subjects = unique(cellfun(@(x) regexp(x,'PMP\d+','match','once'), ...
    names, 'UniformOutput', false));

for s = 1:length(subjects)
    
    subject_id = subjects{s};
    
    figure;
    
    % -------- subplot 1: HR por segmentos --------
    subplot(2,1,1); hold on;
    
    colors = lines(7); % m�ximo 7 noches
    
    night_min = [];
    night_median = [];
    night_colors = [];
    all_values = [];
    
    night_idx = 0;
    
    for i = 1:length(files)
        
        if contains(files(i).name, subject_id)
            
            night_idx = night_idx + 1;
            
            data = load(fullfile(files(i).folder, files(i).name));
            HR_all = data.HR_all;
            
            c = colors(night_idx,:);
            
            % plot HR
            plot(HR_all, '-o', 'LineWidth',1.5, 'Color', c);
            
            % stats
            HR_clean = HR_all(~isnan(HR_all));
            
            night_min(night_idx) = prctile(HR_clean,10);
            night_median(night_idx) = median(HR_clean);
            night_colors(night_idx,:) = c;
            
            all_values = [all_values; HR_clean];
            
        end
        
    end
    
    % eje Y din�mico
    ymin = min(all_values) - 5;
    ymax = max(all_values) + 5;
    ylim([ymin ymax]);
    
    title(['Sujeto: ' subject_id], 'Interpreter','none');
    ylabel('HR (bpm)');
    grid on;
    
    
    % -------- subplot 2: resumen por noche --------
    subplot(2,1,2); hold on;
    
    x = 1:length(night_min);
    
    % offset din�mico para texto
    offset = 0.05 * (ymax - ymin);
    
    for k = 1:length(x)
        
        c = night_colors(k,:);
        
        % l�nea min ? mediana
        plot([x(k) x(k)], [night_min(k) night_median(k)], ...
            'Color', c, 'LineWidth',1.5);
        
        % puntos
        plot(x(k), night_median(k), 'o', ...
            'Color', c, 'MarkerFaceColor', c);
        
        plot(x(k), night_min(k), 'v', ...
            'Color', c, 'MarkerFaceColor', c);
        
        % texto (mediana)
        text(x(k), night_median(k) + offset, ...
            sprintf('%.1f', night_median(k)), ...
            'HorizontalAlignment','center', ...
            'FontSize',8, ...
            'FontWeight','bold', ...
            'BackgroundColor','w', ...
            'Margin',1);
    end
    
    xlabel('Noche');
    ylabel('HR (bpm)');
    title('Resumen por noche');
    
    xlim([0 length(x)+1]);
    ylim([ymin ymax]);
    
    grid off;
    box on;
    
    pause;
    close all
    
end


% % % 
% % % files = dir('data\v2_1\hr\*.mat');
% % % 
% % % names = {files.name};
% % % subjects = unique(cellfun(@(x) regexp(x,'PMP\d+','match','once'), names, 'UniformOutput', false));
% % % 
% % % for s = 1:length(subjects)
% % %     
% % %     subject_id = subjects{s};
% % %     
% % %     figure;
% % %     
% % %     % -------- subplot 1: HR --------
% % %     subplot(2,1,1); hold on;
% % %     
% % %     all_values = [];
% % %     night_min = [];
% % %     night_median = [];
% % %     
% % %     night_idx = 0;
% % %     
% % %     for i = 1:length(files)
% % %         
% % %         if contains(files(i).name, subject_id)
% % %             
% % %             night_idx = night_idx + 1;
% % %             
% % %             data = load(fullfile(files(i).folder, files(i).name));
% % %             HR_all = data.HR_all;
% % %             
% % %             plot(HR_all, '-o', 'LineWidth',1.5);
% % %             
% % %             % guardar stats
% % %             HR_clean = HR_all(~isnan(HR_all));
% % %             
% % %             night_min(night_idx) = min(HR_clean);
% % %             night_median(night_idx) = median(HR_clean);
% % %             
% % %             all_values = [all_values; HR_clean];
% % %             
% % %         end
% % %         
% % %     end
% % %     
% % %     % eje Y din�mico
% % %     ymin = min(all_values) - 5;
% % %     ymax = max(all_values) + 5;
% % %     ylim([ymin ymax]);
% % %     
% % %     title(['Sujeto: ' subject_id], 'Interpreter','none');
% % %     ylabel('HR (bpm)');
% % %     grid on;
% % %     
% % %     
% % %     % -------- subplot 2: resumen --------
% % %     subplot(2,1,2); hold on;
% % % 
% % %     x = 1:length(night_min);
% % % 
% % %     % l�neas min ? mediana
% % %     for k = 1:length(x)
% % %         plot([x(k) x(k)], [night_min(k) night_median(k)], 'k-');
% % %     end
% % % 
% % %     % puntos
% % %     plot(x, night_median, 'bo', 'MarkerFaceColor','b'); % mediana
% % %     plot(x, night_min, 'rv', 'MarkerFaceColor','r');    % m�nimo
% % % 
% % %     % ---- offset din�mico ----
% % %     offset = 0.05 * (ymax - ymin);
% % % 
% % %     % ---- a�adir texto (mediana) ----
% % %     for k = 1:length(x)
% % %         text(x(k), night_median(k) + offset, ...
% % %             sprintf('%.1f', night_median(k)), ...
% % %             'HorizontalAlignment','center', ...
% % %             'FontSize',8, ...
% % %             'FontWeight','bold', ...
% % %             'BackgroundColor','w', ...
% % %             'Margin',1);
% % %     end
% % % 
% % %     xlabel('Noche');
% % %     ylabel('HR (bpm)');
% % %     title('Resumen por noche');
% % % 
% % %     % eje X con margen
% % %     xlim([0 length(x)+1]);
% % % 
% % %     % mismo rango que arriba
% % %     ylim([ymin ymax]);
% % % 
% % %     % sin grid para mejor legibilidad
% % %     grid off;
% % %     box on;
% % %     
% % %     pause;
% % %     
% % % end
% % % 
% % % 
% % % % % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % % % % files = dir('data\v2_1\hr\*.mat');
% % % % % % 
% % % % % % figure; hold on;
% % % % % % 
% % % % % % for i = 1:length(files)
% % % % % %     
% % % % % %     data = load(fullfile(files(i).folder, files(i).name));
% % % % % %     HR_all = data.HR_all;
% % % % % %     
% % % % % %     plot(HR_all, '-o');
% % % % % %     
% % % % % % end
% % % % % % 
% % % % % % xlabel('Segmento (30 min)');
% % % % % % ylabel('HR (bpm)');
% % % % % % title('HR de todos los sujetos');
% % % % % % ylim([30 110]);
% % % % % % grid on;
% % % % % % 
% % % % % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % % % % figure; hold on;
% % % % % % 
% % % % % % for i = 1:length(files)
% % % % % %     
% % % % % %     data = load(fullfile(files(i).folder, files(i).name));
% % % % % %     HR_all = data.HR_all;
% % % % % %     
% % % % % %     plot(HR_all, '-', 'Color', [0 0 1 0.2]); % azul transparente
% % % % % %     
% % % % % % end
% % % % % % 
% % % % % % xlabel('Segmento (30 min)');
% % % % % % ylabel('HR (bpm)');
% % % % % % title('HR de todos los sujetos');
% % % % % % ylim([30 110]);
% % % % % % grid on;
% % % % % % 
% % % % % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % % % % files = dir('data\v2_1\hr\*.mat');
% % % % % % 
% % % % % % max_len = 0;
% % % % % % 
% % % % % % for i = 1:length(files)
% % % % % %     data = load(fullfile(files(i).folder, files(i).name));
% % % % % %     max_len = max(max_len, length(data.HR_all));
% % % % % % end
% % % % % % 
% % % % % % HR_mat = NaN(length(files), max_len);
% % % % % % 
% % % % % % for i = 1:length(files)
% % % % % %     
% % % % % %     data = load(fullfile(files(i).folder, files(i).name));
% % % % % %     HR = data.HR_all(:)';
% % % % % %     
% % % % % %     HR_mat(i, 1:length(HR)) = HR;
% % % % % %     
% % % % % % end
% % % % % % 
% % % % % % 
% % % % % % mean_HR = nanmean(HR_mat, 1);
% % % % % % std_HR  = nanstd(HR_mat, [], 1);
% % % % % % 
% % % % % % figure; hold on;
% % % % % % 
% % % % % % % sujetos individuales (gris)
% % % % % % for i = 1:size(HR_mat,1)
% % % % % %     plot(HR_mat(i,:), 'Color', [0.7 0.7 0.7]);
% % % % % % end
% % % % % % 
% % % % % % % media (azul)
% % % % % % plot(mean_HR, 'b', 'LineWidth',2);
% % % % % % 
% % % % % % % banda � std
% % % % % % plot(mean_HR + std_HR, '--b');
% % % % % % plot(mean_HR - std_HR, '--b');
% % % % % % 
% % % % % % xlabel('Segmento (30 min)');
% % % % % % ylabel('HR (bpm)');
% % % % % % title('HR global');
% % % % % % ylim([30 110]);
% % % % % % grid on;