clear
close all force
clc

currentPath = pwd; rootIndex = strfind(currentPath, 'OneDrive - unizar.es'); rootPath = fullfile(currentPath(1:rootIndex + length('OneDrive - unizar.es') - 1), 'DOCTORADO');
addpath(genpath(fullfile(rootPath, 'biomedical-signal-processing')),'-begin');


%% Define the root directory to search for patient folders
rootDir = "REGISTROS 3 DIAS";

% Get a list of all subdirectories (patients) in the root directory
patientDirs = dir(rootDir);
patientDirs = patientDirs([patientDirs.isdir]); % Keep only directories
patientDirs = patientDirs(~ismember({patientDirs.name}, {'.', '..'})); % Remove . and .. directories

% Loop over each patient directory
for p = 19:numel(patientDirs)
    % for p = 21:length(patientDirs)

    clearvars -except patientDirs p

    sujetoID = patientDirs(p).name;
    disp(['Processing patient: ' sujetoID]);


    load (['REGISTROS 3 DIAS\' sujetoID '\' sujetoID '_tK.mat'],'HRV','NN','tK');

    HRV.timeStamp = fixFarosTime(HRV.timeStamp);
    NN.timeStamp = fixFarosTime(NN.timeStamp);
    tK.timeStamp = fixFarosTime(tK.timeStamp);

    MATA = load (['REGISTROS 3 DIAS\' sujetoID '\' sujetoID '_reloj.mat'],'timeStamp','HR');
    figure
    plot(MATA.timeStamp,MATA.HR); hold on
    plot(HRV.timeStamp,HRV.HR.*60)
    addSlider(gcf,MATA.timeStamp);

    % 
    % HRV.timeStamp = fixFarosTime(HRV.timeStamp);
    % NN.timeStamp = fixFarosTime(NN.timeStamp);
    % tK.timeStamp = fixFarosTime(tK.timeStamp);
    offset = -hours(str2num(input('delay en horas?' , 's')));

    HRV.timeStamp = fixDelayManual(HRV.timeStamp, offset);
    NN.timeStamp = fixDelayManual(NN.timeStamp, offset);
    tK.timeStamp = fixDelayManual(tK.timeStamp, offset);

    plot(HRV.timeStamp,HRV.HR.*60)
    legend('MATA','HOLTER','Holter delayed')

    keyboard

    save(['REGISTROS 3 DIAS\' sujetoID '\' sujetoID '_tK.mat'],'-append','HRV','NN','tK');

    clearvars -except patientDirs p sujetoID offset

    load (['REGISTROS 3 DIAS\' sujetoID '\' sujetoID '_holter.mat'],'timeStamp');    
    % timeStamp = fixFarosTime(timeStamp);

    timeStamp = fixDelayManual(timeStamp, offset);

    save(['REGISTROS 3 DIAS\' sujetoID '\' sujetoID '_holter.mat'],'-append','timeStamp');


end

function ts_Faros = fixFarosTime(ts_Faros)
% Reinterpreta un timestamp del Holter Faros que se leyó como UTC
% aunque en realidad era hora local (Europe/Madrid).
%
% Devuelve la serie en UTC real, con el desfase CET/CEST absorbido.

if ~isa(ts_Faros, 'datetime')
    error('Las entradas deben ser datetime');
end

ts_Faros.TimeZone = 'UTC';
offset = tzoffset(datetime(ts_Faros(1), 'TimeZone', 'Europe/Madrid'));
ts_Faros = ts_Faros - offset;

% disp(offset)
end




function ts_Faros = fixDelayManual(ts_Faros , offset)


ts_Faros = ts_Faros - offset;

% disp(offset)
end

