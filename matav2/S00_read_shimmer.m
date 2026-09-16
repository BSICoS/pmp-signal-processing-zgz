
clear
close all force
clc

repoRoot = fileparts(fileparts(mfilename('fullpath'))); addpath(repoRoot);
p = paths();
addpath(genpath(p.biomedSigProc));

%%

dataDir = 'newFW_prueba1dia_shimmer';
% dataDir = 'newFW_pruebaDeporte';

ecgFiles = dir(fullfile(pwd, dataDir, '/', 'DefaultTrial*.mat'));
% ecgFiles = ecgFiles(contains({ecgFiles.name}, 'ECG') & contains({ecgFiles.name}, 'user'));

for kk = 1:length(ecgFiles)
    % for k=6

    filename = fullfile(ecgFiles(kk).folder,ecgFiles(kk).name);
    [dataDir, patientID, fileFormat] = fileparts(filename);

    %     dataSHIMMER = readtable(fullfile(ecgFiles(kk).folder,ecgFiles(kk).name));
    dataSHIMMER = load(fullfile(ecgFiles(kk).folder,ecgFiles(kk).name));
    disp([patientID, '.mat - ECG loaded']);

    %% import dataSHIMMER to mat tables

    ECG     =   table();
    RESP    =   table();
    ACC     =   table();
    %     GYRO    =   table();
    %     MAG     =   table();
    tK      =   table();
    HRV     =   table();

    TimeStamp = datetime(dataSHIMMER.Shimmer_68B7_Timestamp_Unix_CAL./1000,'ConvertFrom','posixtime','TimeZone','Europe/Madrid');

    leadI.sig   = dataSHIMMER.Shimmer_68B7_ECG_LA_RA_24BIT_CAL;
    leadII.sig  = dataSHIMMER.Shimmer_68B7_ECG_LL_RA_24BIT_CAL;
    leadIII.sig = dataSHIMMER.Shimmer_68B7_ECG_LL_LA_24BIT_CAL;
    % Vx.sig      = dataSHIMMER.Shimmer_68B7_ECG_Vx_RL_24BIT_CAL;

    %     RESP.IP = dataSHIMMER.Shimmer_68B7_ECG_RESP_24BIT_CAL;

    ACC.X = dataSHIMMER.Shimmer_68B7_Accel_WR_X_CAL;
    ACC.Y = dataSHIMMER.Shimmer_68B7_Accel_WR_Y_CAL;
    ACC.Z = dataSHIMMER.Shimmer_68B7_Accel_WR_Z_CAL;
    
    %     GYRO.X = dataSHIMMER.Shimmer_68B7_Accel_LN_X_CAL;
    %     GYRO.Y = dataSHIMMER.Shimmer_68B7_Accel_LN_Y_CAL;
    %     GYRO.Z = dataSHIMMER.Shimmer_68B7_Accel_LN_Z_CAL;
    %
    %     MAG.X = dataSHIMMER.Shimmer_68B7_Accel_LN_X_CAL;
    %     MAG.Y = dataSHIMMER.Shimmer_68B7_Accel_LN_Y_CAL;
    %     MAG.Z = dataSHIMMER.Shimmer_68B7_Accel_LN_Z_CAL;


    %% DETECTAR PICOS ECG

    %  comprobar Fs del Shimmer y si no hay paquetes perdidos
    figure
    plot(TimeStamp(2:end),1./seconds(diff(TimeStamp)))
    yyaxis right
    plot(TimeStamp,leadII.sig); grid on; zoom on

    disp ( ['N samples lost: ' num2str( sum( 1./seconds(diff(TimeStamp)) <= 100 ) ) ]);
    disp ( ['% samples lost: ' num2str(100*mean( 1./seconds(diff(TimeStamp)) <= 100 )) '%' ]);


    fs = ceil(mean(1./seconds(diff(TimeStamp)),'omitnan'));

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % falta para mejorar el analsis:
    %   filtrado del EMG,
    %   deteccion en todos los leads,
    %   deteccion multilead?,
    %   asegurar los FID points de wavedet,
    %   SNR code for postprocessing;
    %   compensacion mvto ACC?
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % [bb,aa]     =   butter(4, [5 15]./(fs/2) , 'bandpass');
    % signal      =   filtfilt (bb,aa,ECG.leadII);
    SetupECG.plotflag = true;

    leadI.tK   = delinearECG (leadI.sig  ,fs,SetupECG); leadI.tK_timeStamp   = TimeStamp(round(leadI.tK*fs));
    leadII.tK  = delinearECG (leadII.sig ,fs,SetupECG); leadII.tK_timeStamp  = TimeStamp(round(leadII.tK*fs));
    leadIII.tK = delinearECG (leadIII.sig,fs,SetupECG); leadIII.tK_timeStamp = TimeStamp(round(leadIII.tK*fs));


    %% Calcular HRV a partir de las detecciones, usando el intervalo Rwave-to-Rwave
    fr = 4; % frecuencia de remuestreo para que el HRV este uniformemente muestreado

    Setup.tol = 1.25;
    Setup.IPFM_mode = 'TI';
    Setup.plotflag = true;
    [ leadI.HRV.m , leadI.HRV.HR , leadI.HRV.mHR ]       = computeHRVsignals ( leadI.tK   , fr , Setup );
    [ leadII.HRV.m , leadII.HRV.HR , leadII.HRV.mHR ]    = computeHRVsignals ( leadII.tK  , fr , Setup );
    [ leadIII.HRV.m , leadIII.HRV.HR , leadIII.HRV.mHR ] = computeHRVsignals ( leadIII.tK , fr , Setup );
    t4Hz = (1:1:length(leadII.HRV.m)) ./ fr;
    leadI.HRV.timeStamp = TimeStamp(round(t4Hz*fs));
    leadII.HRV.timeStamp = TimeStamp(round(t4Hz*fs));
    leadIII.HRV.timeStamp = TimeStamp(round(t4Hz*fs));

    figure
    ax(1) = subplot(311);
    plot(TimeStamp,leadII.sig,'DisplayName','ECG lead II'); hold on; grid on
    plot(TimeStamp(round(leadII.tK*fs)),leadII.sig(round(leadII.tK*fs)),'o','DisplayName','Rwaves'); legend;
    ax(2) = subplot(312);
    plot(leadII.HRV.timeStamp,leadII.HRV.HR .* 60,'DisplayName','INSTANTANEOUS HEART RATE');hold on; grid on
    plot(leadII.HRV.timeStamp,leadII.HRV.mHR .* 60,'DisplayName','mean HEART RATE');
    plot(leadII.tK_timeStamp(2:end),60./diff(leadII.tK) ,'DisplayName','diff tk');
    yyaxis right
    plot(TimeStamp,table2array(sqrt(sum(ACC.^2,2))) ,'DisplayName','MAG ACC'); legend;
    ax(3) = subplot(313);
    plot(leadII.HRV.timeStamp,leadII.HRV.m,'DisplayName','HEART RATE VARIABILITY'); grid on
    linkaxes(ax,'x');
    addSlider(gcf,leadII.HRV.timeStamp); legend;

    %% GUARDAR

    filename = fullfile(dataDir,[patientID '_imported.mat']);
    save(filename,'ACC','leadI','leadII','leadIII','TimeStamp');
    disp([patientID, '.mat - ECG saved']);

end

