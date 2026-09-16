
clear
close all force
clc

%% Define the root directory to search for patient folders
rootDir = "D:\OneDrive - unizar.es\DOCTORADO\0_WerPerMed\REGISTROS_COMPLETOS\REGISTROS 3 DIAS";

patientDirs = dir(rootDir); patientDirs = patientDirs([patientDirs.isdir]); patientDirs = patientDirs(~ismember({patientDirs.name}, {'.', '..'}));

% Loop over each patient directory
for p = 21:length(patientDirs)

    clearvars -except patientDirs p rootDir

    patientID = patientDirs(p).name;
    patientPath = fullfile(rootDir, patientID);

    fileDir = dir(fullfile(patientPath ,[patientID '_reloj.mat']));
    disp(['Processing patient: ' patientID]);
    filePath = fullfile(fileDir.folder, fileDir.name);
    load(filePath,'PPG','timeStamp');


    %%

    nan_indices = isnan(PPG);

    ppg_signal_interpolated = fillmissing(PPG, 'pchip');

    % Reidentificar tramos largos de NaN y mantenerlos
    nan_threshold = 5; % Umbral en número de muestras

    nan_diff = diff([0; nan_indices; 0]);
    nan_start = find(nan_diff == 1);
    nan_end = find(nan_diff == -1) -1;

    if length(nan_end)<length(nan_start), nan_end(end+1)=length(PPG); end

    % Restaurar los tramos largos de NaN
    indices_nans = false(length(PPG),1);
    for k = 1:length(nan_start)
        if (nan_end(k) - nan_start(k) ) >= nan_threshold
            indices_nans(nan_start(k):nan_end(k)) = true;
            ppg_signal_interpolated(nan_start(k):nan_end(k)) = NaN;
        end
    end

    %%

    figure;
    % plot(t, fillmissing(ppg, 'pchip') ,DisplayName='PPG Interpolada' ); hold on;
    plot(timeStamp, ppg_signal_interpolated,DisplayName='PPG Interpolada corregida');hold on;
    plot(timeStamp, PPG,DisplayName='PPG original'); hold on;
    legend; zoom on

    disp('problema que no pone NaNs cuando no mide asi que la solucion es distinta');

    keyboard;

    %%

    % Save the data to a .mat file
    %     save(fullfile(patientPath, [patientID '_ppg_wojumps.mat']),'-append', "indices_nans");

end



