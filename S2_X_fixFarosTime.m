clear
close all force
clc

currentPath = pwd; rootIndex = strfind(currentPath, 'OneDrive - unizar.es'); rootPath = fullfile(currentPath(1:rootIndex + length('OneDrive - unizar.es') - 1), 'DOCTORADO');
addpath(genpath(fullfile(rootPath, 'biomedical-signal-processing')),'-begin');


%% Define the root directory to search for patient folders
rootDir = "REGISTROS 3 DIAS";

% rootDir = "C:\path\to\werpermed\prueba3dias";

% Get a list of all subdirectories (patients) in the root directory
patientDirs = dir(rootDir);
patientDirs = patientDirs([patientDirs.isdir]); % Keep only directories
patientDirs = patientDirs(~ismember({patientDirs.name}, {'.', '..'})); % Remove . and .. directories

% Loop over each patient directory
for p = 3:numel(patientDirs)
    % for p = 21:length(patientDirs)

    clearvars -except patientDirs p

    sujetoID = patientDirs(p).name;
    disp(['Processing patient: ' sujetoID]);

    MATA = load (['REGISTROS 3 DIAS\' sujetoID '\' sujetoID '_reloj.mat'],'timeStamp','HR');

    load (['REGISTROS 3 DIAS\' sujetoID '\' sujetoID '_tK.mat'],'HRV','NN','tK');


    fs=1;
    t = min(MATA.timeStamp(1),HRV.timeStamp(1)) : seconds(fs) : max(MATA.timeStamp(end),HRV.timeStamp(end)) ;min(MATA.timeStamp(1),HRV.timeStamp(1)) ;

    MATA_HR = interp1 ( MATA.timeStamp , MATA.HR , t );
    HRV_HR = interp1 ( HRV.timeStamp , HRV.mHR.*60 , t );


    [xc, lags] = xcorr(detrend(fillmissing(MATA_HR,'linear')),detrend(fillmissing(HRV_HR,'linear')));
    len = length(xc);
    lags_3h = lags(len/2-3*3600*fs:len/2+3*3600*fs);
    xc_3h   = xc(len/2-3*3600*fs:len/2+3*3600*fs);
    [~, idx] = max(xc_3h);%3 horas de desfase maximo
    delay_HR_PR = hours(seconds(lags_3h(idx)/fs));

    tx = (0:1:length(MATA_HR)-1)./ (fs*3600);
    ty = (0:1:length(HRV_HR)-1)./ (fs*3600);

    figure;
    ax(1)=subplot(131);
    datatip(plot(lags_3h./fs, xc_3h), lags_3h(idx)./fs, xc_3h(idx));grid on; hold on; % Add a datatip at the maximum cross-correlation point
    xline(0);
    ax(2)=subplot(2,3,[2 3]);
    plot(tx,MATA_HR,'DisplayName','MATA');hold on; grid on;
    plot(ty,HRV_HR,'DisplayName','HOLTER'); legend;
    ax(3)=subplot(2,3,[5 6]);
    plot(tx,MATA_HR,'DisplayName','MATA');hold on; grid on;
    plot(ty+hours(delay_HR_PR),HRV_HR,'DisplayName','HOLTER delayed'); legend;
    linkaxes(ax(2:3),'x');
    addSlider(gcf,tx);

    HRV.timeStamp = fixFarosTime(HRV.timeStamp,MATA.timeStamp);



    NN.timeStamp = fixFarosTime(NN.timeStamp,MATA.timeStamp);
    tK.timeStamp = fixFarosTime(tK.timeStamp,MATA.timeStamp);

    save(['REGISTROS 3 DIAS\' sujetoID '\' sujetoID '_tK.mat'],'HRV','NN','tK');

    clearvars -except patientDirs p sujetoID

    load (['REGISTROS 3 DIAS\' sujetoID '\' sujetoID '_holter.mat'],'ECG','timeStamp');
    timeStamp = fixFarosTime(timeStamp,MATA.timeStamp);

    save(['REGISTROS 3 DIAS\' sujetoID '\' sujetoID '_holter.mat'],'ECG','timeStamp');


end

function ts_Faros = fixFarosTime(ts_Faros, ts_MATA)
% Reinterpreta un timestamp del Holter Faros que se leyó como UTC
% aunque en realidad era hora local (Europe/Madrid).
%
% Devuelve la serie en UTC real, con el desfase CET/CEST absorbido.

if ~isa(ts_Faros, 'datetime') || ~isa(ts_MATA, 'datetime')
    error('Las entradas deben ser datetime');
end

% Asegurar que ambos timestamps tienen zona horaria UTC
ts_Faros.TimeZone = 'UTC';
ts_MATA.TimeZone = 'UTC';

% Calcular el desfase en horas entre la primera muestra de Faros y MATA
% offset_Faros = tzoffset(datetime(ts_Faros(1), 'TimeZone', 'Europe/Madrid'));
% offset_MATA = tzoffset(datetime(ts_MATA(1), 'TimeZone', 'Europe/Madrid'));
% desfase_horas = round(hours(offset_Faros - offset_MATA) * 2) / 2; % Redondear a la media hora más cercana
desfase_horas = round( hours((ts_Faros(1) - ts_MATA(1)) * 2) / 2);

ts_Faros = ts_Faros - desfase_horas;

end
