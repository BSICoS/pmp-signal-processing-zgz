
clear
% close all force
% clc

currentPath = pwd; rootIndex = strfind(currentPath, 'OneDrive - unizar.es'); rootPath = fullfile(currentPath(1:rootIndex + length('OneDrive - unizar.es') - 1), 'DOCTORADO');
addpath(genpath(fullfile(rootPath, 'biomedical-signal-processing')));

%%

% dataDir = 'registros';
dataDir = 'newFW_prueba1dia_shimmer';

mataFiles = dir(fullfile(dataDir,'MATA*.mat'));


for kk = 1:length(mataFiles)
    % for kk = 2
    % for kk = length(mataFiles)

    close all force
    clearvars -except dataDir mataFiles kk

    filename = mataFiles(kk).name;
    [~, patientID, ~] = fileparts(filename);
    matFilePath = fullfile(dataDir, [mataFiles(kk).name(1:end-4), '.mat']);
    disp([matFilePath, ' - loading...']);
    if ~isfile(matFilePath)
        disp([matFilePath, ' - no existe, continue.']);
        continue;
    end

    load(matFilePath,'PPG');
    fs = 25.6;


    % Interpolate NaNs in the signal
    nan_indices = isnan(PPG);
    not_nan_indices = ~nan_indices;
    ppg_signal_interpolated = PPG;
    ppg_signal_interpolated(nan_indices) = interp1(find(not_nan_indices), PPG(not_nan_indices), find(nan_indices), 'pchip');

    %%%%%%%%%%%
    disp('falta eliminar tramos interpolados en la PPG, y no solo muestras sueltas')
    %%%%%%%%%%%

    % Compute the difference of the interpolated signal
    ppg_diff_interpolated = diff(ppg_signal_interpolated);

    % Compute statistics
    mean_diff_interpolated = mean(ppg_diff_interpolated, 'omitnan');
    std_diff_interpolated = std(ppg_diff_interpolated, 'omitnan');
    % 0.0435
    % 170.0

    % Define a threshold to identify jumps
    threshold_new = mean_diff_interpolated + 2 * std_diff_interpolated;
    threshold_new = 500;

    % Identify jumps
    jumps_new = find(abs(ppg_diff_interpolated) > threshold_new);

    % Adjust the signal by aligning after jumps
    PPG_corrected = adjust_signal_after_jumps(ppg_signal_interpolated, jumps_new, 1, false);

%     % Plot the interpolated and adjusted signals
%     figure;
%     plot(ppg_signal_interpolated);
%     yyaxis right;
%     plot(PPG_corrected);
%     title('Interpolated vs Adjusted PPG Signal');
%     xlabel('Sample Index');
%     ylabel('Amplitude');
%     legend('Interpolated PPG Signal', 'Adjusted PPG Signal');
% 
%     % Plot the differences
%     figure;
%     plot(ppg_diff_interpolated);
%     hold on;
%     plot(diff(PPG_corrected));
%     title('Difference of Interpolated vs Adjusted PPG Signal');
%     xlabel('Sample Index');
%     ylabel('Amplitude Difference');
%     legend('Difference of Interpolated PPG Signal', 'Difference of Adjusted PPG Signal');

    %%

%     keyboard
    % Save the data to a .mat file
    save(matFilePath,'-append', 'PPG_corrected');

end




%% Function to adjust the signal after jumps

function signal_adjusted = adjust_signal_after_jumps(signal, jump_indices, iterations,plotflag)
signal_adjusted = signal;
for i = 1:iterations
    for idx = jump_indices'
        if idx + 1 <= length(signal_adjusted)
            adjustment = signal_adjusted(idx) - signal_adjusted(idx + 1);
            signal_adjusted(idx + 1:end) = signal_adjusted(idx + 1:end) + adjustment;
        end
    end
end

if plotflag
    % Plot the interpolated and adjusted signals
    figure;
    plot(signal);
    hold on;
    plot(signal_adjusted);
    title('Interpolated vs Adjusted PPG Signal');
    xlabel('Sample Index');
    ylabel('Amplitude');
    legend('Interpolated PPG Signal', 'Adjusted PPG Signal');
end
end



% % Smooth the signal
% ppg_signal_smoothed = smooth_jumps(ppg_signal_interpolated, jumps_new, 5);

% % Plot the interpolated and smoothed signals
% figure;
% plot(ppg_signal_interpolated);
% hold on;
% plot(ppg_signal_smoothed);
% title('Interpolated vs Smoothed PPG Signal');
% xlabel('Sample Index');
% ylabel('Amplitude');
% legend('Interpolated PPG Signal', 'Smoothed PPG Signal');
%
% % Plot the differences
% figure;
% plot(ppg_diff_interpolated);
% hold on;
% plot(diff(ppg_signal_smoothed));
% title('Difference of Interpolated vs Smoothed PPG Signal');
% xlabel('Sample Index');
% ylabel('Amplitude Difference');
% legend('Difference of Interpolated PPG Signal', 'Difference of Smoothed PPG Signal');


