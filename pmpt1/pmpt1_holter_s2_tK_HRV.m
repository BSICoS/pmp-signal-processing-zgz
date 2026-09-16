clear
close all force
clc

currentPath = pwd; rootIndex = strfind(currentPath, 'OneDrive - unizar.es'); rootPath = fullfile(currentPath(1:rootIndex + length('OneDrive - unizar.es') - 1), 'DOCTORADO');
addpath(genpath(fullfile(rootPath, 'biomedical-signal-processing')),'-begin');


%% Define the root directory to search for patient folders
repoRoot = fileparts(fileparts(mfilename('fullpath'))); addpath(repoRoot);
p = paths();
rootDir = p.dataRootT1;

% Get a list of all subdirectories (patients) in the root directory
patientDirs = dir(rootDir);
patientDirs = patientDirs([patientDirs.isdir]); % Keep only directories
patientDirs = patientDirs(~ismember({patientDirs.name}, {'.', '..'})); % Remove . and .. directories

% Loop over each patient directory
for p = 1:numel(patientDirs)
    % for p = 21:length(patientDirs)

    clearvars -except patientDirs p rootDir

    patientID = patientDirs(p).name;
    patientPath = fullfile(rootDir, patientID);

    % Get a list of the CSV file in the patient's directory and subdirectories
    %     fileDir = dir(fullfile(patientPath ,[patientID '_reloj.mat']));
    fileDir = dir(fullfile(patientPath ,[patientID '_holter.mat']));

    if isempty(fileDir), disp('NO ECG'); continue; end

    % disp(['Processing patient: ' patientID]);

    % Construct the full file path
    filePath = fullfile(fileDir.folder, fileDir.name);

    disp(['Processing file: ' filePath]);

    load(filePath)

    tK  = table();
    HRV = table();
    NN  = table();

    fs = meta.Fs.ECG;

    %%

    [b, a] = butter(4, [1 45]/(fs/2), 'bandpass');
    ECG_filt = filtfilt(b, a, ECG);

    SetupECG.plotflag   =   true;
    tK.tK               =   delinearECG (ECG,fs,SetupECG);
    tK.i_tK             =   1+round(tK.tK*fs);
    tK.timeStamp        =   timeStamp(tK.i_tK);


    %% HRV

    Setup.plotflag = false;
    [HRV.m , HRV.HR , HRV.mHR, NN.NN , NN.tNN, ~ , ~, HRV.t] = computeHRVsignals(tK.tK,4,Setup);

    HRV.timeStamp = timeStamp(1+round(HRV.t*fs));
    NN.timeStamp  = timeStamp(1+round(NN.tNN*fs));


    %% Save the data to a .mat file
    % save(fullfile(patientPath, [patientID '_tK.mat']), 'tK' ,'HRV', 'NN');


end


