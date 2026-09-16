clear
close all force
clc

%%

% Define the root directory to search for patient folders
repoRoot = fileparts(fileparts(mfilename('fullpath'))); addpath(repoRoot);
p = paths();
rootDir = p.dataRootT0;

% Get a list of all subdirectories (patients) in the root directory
patientDirs = dir(rootDir);
patientDirs = patientDirs([patientDirs.isdir]); % Keep only directories
patientDirs = patientDirs(~ismember({patientDirs.name}, {'.', '..'})); % Remove . and .. directories

% Sampling rate
fs = 1000;

% Loop over each patient directory
for p = 20
% for p = 1:length(patientDirs)
    patientID = patientDirs(p).name;
    patientPath = fullfile(rootDir, patientID);
    
    % Get a list of all EDF files in the patient's directory and subdirectories
    fileList = dir(fullfile(patientPath, '**', '*.EDF'));
    
    disp(['Processing patient: ' patientID]);

    % Initialize cell arrays to store data before final concatenation
    ECG = cell(length(fileList), 1);
    timeStamp = cell(length(fileList), 1);
    
    for i = 1:length(fileList)
        % Construct the full file path
        filePath = fullfile(fileList(i).folder, fileList(i).name);        

        disp(['Processing file: ' filePath]);

        % Get the EDF file information
        info = edfinfo(filePath);
        
        % Extract start time and date
        t_ini_Str = info.StartDate + " " + info.StartTime;
        t_ini = datetime(t_ini_Str, 'InputFormat', 'dd.MM.yy HH.mm.ss', 'TimeZone', 'UTC');
        
        % Load the EDF data into a timetable
        data = edfread(filePath);
        
        % Concatenate all ECG data
        ECG_aux = vertcat(data.ECG{:});
        
        % Generate the time vector for this segment
        N_samples = length(ECG_aux);
        t = (0:N_samples-1)' / fs;
        timeStamp_aux = t_ini + seconds(t);
        
        % Store the ECG data and timestamps in cell arrays
        ECG{i} = ECG_aux;
        timeStamp{i} = timeStamp_aux;
    end
    
    % Concatenate all stored data at once
    ECG = vertcat(ECG{:});
    timeStamp = vertcat(timeStamp{:});
    
    % Save the concatenated data to a .mat file
    save(fullfile(patientPath, [patientID '_holter.mat']), "ECG", 'timeStamp');
    
    % Clear variables
    clearvars -except rootDir patientDirs fs
    
end
