clear
close all force
clc

%% Define the root directory to search for patient folders
repoRoot = fileparts(fileparts(mfilename('fullpath'))); addpath(repoRoot);
p = paths();
rootDir = p.dataRootT0;


% Get a list of all subdirectories (patients) in the root directory
patientDirs = dir(rootDir);
patientDirs = patientDirs([patientDirs.isdir]); % Keep only directories
patientDirs = patientDirs(~ismember({patientDirs.name}, {'.', '..'})); % Remove . and .. directories

% Loop over each patient directory
for p = 20:length(patientDirs)
    
    clearvars -except p patientDirs rootDir

    patientID = patientDirs(p).name;
    patientPath = fullfile(rootDir, patientID);

    % Get a list of the CSV file in the patient's directory and subdirectories
    % fileList = dir(fullfile(patientPath, 'RELOJ MATA V1\*.csv'));

    fileList = dir(fullfile(patientPath, 'RELOJ V1\*.csv'));   

    if isempty(fileList)
        disp(['No CSV file found for patient: ' patientID]);
        continue;
    end

    disp(['Processing patient: ' patientID]);

    % Construct the full file path
    filePath = fullfile(fileList.folder, fileList.name);

    disp(['Processing file: ' filePath]);

    % Read the CSV file into a table
    data = readtable(filePath);

    % Extracting data from the table
    % MATA = table();

    PPG = data.hr_raw;
    HR = data.hr;
    ACC = [data.acc_x, data.acc_y, data.acc_z];
    GYR = [data.gyr_x, data.gyr_y, data.gyr_z];
    Tbody = data.bodySurface_temp;
    Tamb = data.ambient_temp;
    timeStamp = data.dateTime;    

    timeStamp.TimeZone = 'UTC';     

    % Save the data to a .mat file
    save(fullfile(patientPath, [patientID '_reloj.mat']), "PPG", "HR", "ACC", "GYR", "Tbody", "Tamb", 'timeStamp');

end
