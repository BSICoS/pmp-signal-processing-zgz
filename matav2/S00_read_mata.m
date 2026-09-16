
clear
close all force
clc

repoRoot = fileparts(fileparts(mfilename('fullpath'))); addpath(repoRoot);
p = paths();
addpath(genpath(p.biomedSigProc));

%%

% dataDir = 'registros';
% dataDir = 'newFW_prueba1';
% dataDir = 'newFW_prueba2';
% dataDir = 'newFW_prueba7dias';
% dataDir = 'newFW_prueba1dia_shimmer';
dataDir = 'newFW_pruebaDeporte';

mataFiles = dir(fullfile(dataDir,'*.csv'));
% mataFiles = mataFiles(contains({mataFiles.name}, 'W1_M'));


for kk = 1:length(mataFiles)

%     close all force
    clearvars -except dataDir mataFiles kk 

    filename = mataFiles(kk).name;
    [~, patientID, ~] = fileparts(filename);

%     % Verifica si el archivo .mat ya existe
%     matFilePath = fullfile(dataDir, [mataFiles(kk).name(1:end-4), '.mat']);
%     disp([matFilePath, ' - loading...']);
%     if isfile(matFilePath)
%         disp([matFilePath, ' - ya existe, continue.']);
%         continue;
%     end

    data = readtable(fullfile(mataFiles(kk).folder,mataFiles(kk).name));

    % Extracting data from the table
    PPG = data.hr_raw;
    HR = data.hr;
    ACC = [data.acc_x, data.acc_y, data.acc_z];
    GYR = [data.gyr_x, data.gyr_y, data.gyr_z];
    Tbody = data.bodySurface_temp;
    Tamb = data.ambient_temp;


    if isnumeric(data.dateTime) && all(data.dateTime > 1e12)
        timeStamp = datetime(data.dateTime / 1000, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
        %timeStamp = datetime(data.dateTime./1000,'ConvertFrom','epochtime','TimeZone','UTC') + hours(2);%    timeStamp.TimeZone = 'UTC';
    elseif isdatetime(data.dateTime)
        timeStamp = data.dateTime;
    else
        error('El formato de data.dateTime no es reconocido.');
    end

    clear data

    figure
%     plot(timeStamp,PPG,'DisplayName','PPG');
%     yyaxis right
    plot(timeStamp,HR,'DisplayName','HR-MATA');
    legend
    title(patientID)

    addSlider(gcf,timeStamp);

%     savefig(fullfile('figures',[patientID '_HR_PPG.fig']));

    % % %     figure
    % % %     % plot(timeStamp,PPG)
    % % %     % yyaxis right
    % % %     plot(timeStamp(2:end),diff(PPG))

    save(fullfile(dataDir,[patientID '.mat']),"PPG", "HR", "ACC", "GYR", "Tbody", "Tamb", 'timeStamp', 'patientID');
    disp([patientID, '.mat - MATA data saved.']);

end
