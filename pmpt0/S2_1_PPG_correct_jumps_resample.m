
clear
close all force
clc

%% Define the root directory to search for patient folders
rootDir = "REGISTROS 3 DIAS";

patientDirs = dir(rootDir); patientDirs = patientDirs([patientDirs.isdir]); patientDirs = patientDirs(~ismember({patientDirs.name}, {'.', '..'}));

% Loop over each patient directory
for p = 15
% for p = 1:length(patientDirs)

    clearvars -except patientDirs p rootDir

    patientID = patientDirs(p).name;
    patientPath = fullfile(rootDir, patientID);

    fileDir = dir(fullfile(patientPath ,[patientID '_reloj.mat']));
    disp(['Processing patient: ' patientID]);
    filePath = fullfile(fileDir.folder, fileDir.name);
    load(filePath,'PPG','timeStamp');

    %% interpol

    % % % Load the data
    % % % load('ppg_pruebas_diff.mat');
    % % load("REGISTROS 3 DIAS/<subjID>/<subjID>_reloj.mat");

    % Plot the raw PPG signal
    % figure;
    % plot(ppg_signal);
    % title('Raw PPG Signal');
    % xlabel('Sample Index');
    % ylabel('Amplitude');

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
    threshold_new = mean_diff_interpolated + 3 * std_diff_interpolated;

    % Identify jumps
    jumps_new = find(abs(ppg_diff_interpolated) > threshold_new);

    % Adjust the signal by aligning after jumps
    PPG_corrected = adjust_signal_after_jumps(ppg_signal_interpolated, jumps_new, 1);

    % Plot the interpolated and adjusted signals
    figure;
    plot(ppg_signal_interpolated);
    yyaxis right
    plot(PPG_corrected);
    title('Interpolated vs Adjusted PPG Signal');
    xlabel('Sample Index');
    ylabel('Amplitude');
    legend('Interpolated PPG Signal', 'Adjusted PPG Signal');

    % Plot the differences
    figure;
    plot(ppg_diff_interpolated);
    hold on;
    plot(diff(PPG_corrected));
    title('Difference of Interpolated vs Adjusted PPG Signal');
    xlabel('Sample Index');
    ylabel('Amplitude Difference');
    legend('Difference of Interpolated PPG Signal', 'Difference of Adjusted PPG Signal');

    figure;
    plot(timeStamp,PPG_corrected);
    yyaxis right;
    plot(timeStamp(2:end),ppg_diff_interpolated);
    addSlider(gcf,timeStamp);

    %% resample at exactly 25.6Hz
    fs = 25.6;
    t_ini = timeStamp(1);
    t_fin = timeStamp(end);
    t_resampled = t_ini : seconds(1/fs) : t_fin;

    % Resample PPG signal
    PPG_corrected_resampled = interp1(timeStamp, PPG_corrected, t_resampled, 'pchip');


    %%

    % Save the data to a .mat file
    save(fullfile(patientPath, [patientID '_ppg_wojumps.mat']), "PPG_corrected","PPG_corrected_resampled","t_resampled");

end




%% Function to adjust the signal after jumps

function signal_adjusted = adjust_signal_after_jumps(signal, jump_indices, iterations)
signal_adjusted = signal;
for i = 1:iterations
    for idx = jump_indices'
        if idx + 1 <= length(signal_adjusted)
            adjustment = signal_adjusted(idx) - signal_adjusted(idx + 1);
            signal_adjusted(idx + 1:end) = signal_adjusted(idx + 1:end) + adjustment;
        end
    end
end

%
%     % Plot the interpolated and adjusted signals
%     figure;
%     plot(signal);
%     hold on;
%     plot(signal_adjusted);
%     title('Interpolated vs Adjusted PPG Signal');
%     xlabel('Sample Index');
%     ylabel('Amplitude');
%     legend('Interpolated PPG Signal', 'Adjusted PPG Signal');

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


