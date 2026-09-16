
clear
close all force
clc

currentPath = pwd; rootIndex = strfind(currentPath, 'OneDrive - unizar.es'); rootPath = fullfile(currentPath(1:rootIndex + length('OneDrive - unizar.es') - 1), 'DOCTORADO');
addpath(genpath(fullfile(rootPath, 'biomedical-signal-processing')),'-begin');


%% Define the root directory to search for patient folders
rootDir = "REGISTROS 3 DIAS";

rootDir = "C:\path\to\werpermed\prueba3dias";

% Get a list of all subdirectories (patients) in the root directory
patientDirs = dir(rootDir);
patientDirs = patientDirs([patientDirs.isdir]); % Keep only directories
patientDirs = patientDirs(~ismember({patientDirs.name}, {'.', '..'})); % Remove . and .. directories

% Loop over each patient directory
for p = 1:20
    % for p = 21:length(patientDirs)

    clearvars -except patientDirs p rootDir

    patientID = patientDirs(p).name;
    patientPath = fullfile(rootDir, patientID);

    % Get a list of the CSV file in the patient's directory and subdirectories
    %     fileDir = dir(fullfile(patientPath ,[patientID '_reloj.mat']));
    fileDir = dir(fullfile(patientPath ,[patientID '_holter.mat']));

    disp(['Processing patient: ' patientID]);

    % Construct the full file path
    filePath = fullfile(fileDir.folder, fileDir.name);

    disp(['Processing file: ' filePath]);

    load(filePath)

    tK  = table();
    HRV = table();
    NN  = table();

    fs = 1000;

    %%

    % ECG(fs*60*30:end)=[];
    % timeStamp(fs*60*30:end)=[];
    % timeStamp.Format = "dd-MMM-uuuu HH:mm:ss.SSS";

    SetupECG.plotflag   =   false;
    tK.tK               =   delinearECG (ECG,fs,SetupECG);
    tK.i_tK             =   1+round(tK.tK*fs);
    tK.timeStamp        =   timeStamp(tK.i_tK);


    %% comprobacion

    % % figure
    % % plot(timeStamp,ECG); hold on;
    % % plot(timeStamp(1+round(tK.tK*fs)),ECG(1+round(tK.tK*fs)),'*'); hold on;
    % 
    % ds_factor = 5;
    % fs_ds = fs / ds_factor;
    % ECG_ds = downsample (ECG,ds_factor); %clear ECG;
    % tS_ds = downsample (timeStamp,ds_factor);% clear timeStamp;
    % 
    % % idx_R = 1+round(tK.tK*fs_ds);
    % 
    % % plot(tS_ds,ECG_ds);
    % % plot(tS_ds(idx_R),ECG_ds(idx_R),'o');
    % % title(patientID); zoom on;
    % % addSlider(gcf,tS_ds);
    % 
    % % ahora quiero plotear solo los resultados de una sequencia
    % 
    % % Definir ventana de tiempo de interés usando los intervalos proporcionados
    % tS_ini_GGIR = datetime('02-Feb-2024 22:46:45.000', 'InputFormat', 'dd-MMM-yyyy HH:mm:ss.SSS', 'TimeZone', 'UTC');
    % tS_fin_GGIR = datetime('03-Feb-2024 08:21:15.000', 'InputFormat', 'dd-MMM-yyyy HH:mm:ss.SSS', 'TimeZone', 'UTC');
    % 
    % % Extraer segmento de señal original
    % [ECG_seq_orig, timeStamp_seq_orig, tK_seq_samples_orig, tK_seq_timestamp_orig] = ...
    %     extractSegment(ECG, timeStamp, tK.timeStamp, tS_ini_GGIR, tS_fin_GGIR);
    % 
    % % Extraer segmento de señal submuestreada
    % [ECG_seq_ds, timeStamp_seq_ds, tK_seq_samples_ds, tK_seq_timestamp_ds] = ...
    %     extractSegment(ECG_ds, tS_ds, tK.timeStamp, tS_ini_GGIR, tS_fin_GGIR);
    % 
    % % % Comprobación con plotting
    % figure
    % plot(timeStamp,ECG,'LineWidth',2); hold on; grid on
    % plot(timeStamp(1+round(tK.tK*fs)),ECG(1+round(tK.tK*fs)), '*');
    % plot(timeStamp_seq_orig, ECG_seq_orig); hold on;
    % plot(timeStamp_seq_orig(tK_seq_samples_orig), ECG_seq_orig(tK_seq_samples_orig), 'o');
    % xlabel('Time'); ylabel('ECG'); grid on;
    % % plot(timeStamp_seq_ds, ECG_seq_ds); hold on;
    % % plot(timeStamp_seq_ds(tK_seq_samples_ds), ECG_seq_ds(tK_seq_samples_ds), 'x');  
    % xlabel('Time'); ylabel('ECG'); grid on;
    % legend('ECG', 'R peaks','ECG seq', 'R peaks seq', 'ECG downsampled seq', 'R peaks seq', 'Location', 'best');
    % 

    %% HRV

    Setup.plotflag = false;
    [HRV.m , HRV.HR , HRV.mHR, NN.NN , NN.tNN, ~ , ~, HRV.t] = computeHRVsignals(tK.tK,4,Setup);

    HRV.timeStamp = timeStamp(1+round(HRV.t*fs));
    NN.timeStamp  = timeStamp(1+round(NN.tNN*fs));


    %% Save the data to a .mat file
    save(fullfile(patientPath, [patientID '_tK.mat']), 'tK' ,'HRV', 'NN');


end


