clear;% close all force; clc

repoRoot = fileparts(fileparts(mfilename('fullpath'))); addpath(repoRoot);
p = paths();
addpath(genpath(p.biomedSigProc));

%% Define the root directory to search for patient folders
rootDir =  "REGISTROS 3 DIAS";

% Loop over each patient directory
patientDirs = dir(rootDir);patientDirs = patientDirs([patientDirs.isdir]);patientDirs = patientDirs(~ismember({patientDirs.name}, {'.', '..'}));
for suj = 3:length(patientDirs)

    clearvars -except patientDirs suj rootDir

    patientID = patientDirs(suj).name;
    patientPath = fullfile(rootDir, patientID);

    % Load data
    disp(['Processing patient: ' patientID]);
    ppgFilePath = fullfile(patientPath, [patientID '_ppg_wojumps.mat']);
    relojFilePath = fullfile(patientPath, [patientID '_reloj.mat']);

    if exist(ppgFilePath, 'file') && exist(relojFilePath, 'file')
        load(ppgFilePath);
        MATA = load(relojFilePath, 'PPG', 'timeStamp');
        MATA.timeStamp.TimeZone = 'UTC';
        MATA = struct2table(MATA);
    else
        disp(['Files missing for patient: ' patientID]);
        continue;
    end

    %% PREPROCESS
    
    % resample at 25.6Hz if PPG signal wasn't saved in the database
    fs = 25.6;
    if ~exist('PPG_corrected_resampled','var')
        t_ini = MATA.timeStamp(1);
        t_fin = MATA.timeStamp(end);
        t_resampled = t_ini : seconds(1/fs) : t_fin;
        PPG_corrected_resampled = interp1(MATA.timeStamp, PPG_corrected, t_resampled, 'spline');
    end

    % figure
    % plot(PPG_corrected_resampled)
    % High pass filter
    [bb, aa] = butter(4, [0.5]./(fs/2), 'high');
    PPG_corrected_resampled = filtfilt(bb,aa,detrend(PPG_corrected_resampled,2));
    % yyaxis right
    % plot(PPG_corrected_resampled)
    % xlim([5791289     5791811]);
    
    % % % %% artifact removal
    % % % % clear SetupARTFS
    % % % SetupARTFS.C = 10;
    % % % SetupARTFS.wdwVariance = 3;
    % % % SetupARTFS.wdwMedian = 15*60;
    % % % SetupARTFS.plotflag = false;
    % % % [ ~ , PPG_corrected_resampled ] = energyArtifacts (PPG_corrected_resampled,fs,SetupARTFS);
    % % % % PPG_corrected_resampled_artifacts = false(length(PPG_corrected_resampled_artifacts),1);

    %% Pulse Delineation
    pulses = table();
    clear SetupDELINEATION    
    % SetupDELINEATION.computeLPDFiltering = false;
    % SetupDELINEATION.signalLPD = [NaN; diff(PPG_corrected_resampled(:))]; SetupDELINEATION.signalLPD = SetupDELINEATION.signalLPD(10000:100000);
    SetupDELINEATION.fsi = 5*fs; % UPSAMPLING FREQUENCY for detection
    SetupDELINEATION.plotflag = true;
    [ pulses.nD , pulses.nA , pulses.nB ] = pulseDelineation ( PPG_corrected_resampled , fs , SetupDELINEATION );

    fprintf('\n'); % Move to the next line after completion

    % Save the results
    % save(fullfile(patientPath, [patientID '_prv.mat']), 'pulses');

    %%
    idx = 1+round(pulses.nD.*fs);
    % idx(isnan(idx))=[];
    pulses.timeStamp_nD= t_resampled(idx)';
    % load(fullfile(patientPath, [patientID '_GGIR_2.mat']));

    %%
    figure
    plot(t_resampled,PPG_corrected_resampled,'Color',0.15*[1 1 1]);hold on; grid on; box on
    plot(t_resampled(idx-1),PPG_corrected_resampled(idx-1),'Color',[0.47 0.67 0.19],'Marker','.','MarkerSize',20,'LineStyle','none');hold on
    ax(1)=gca;zoom on
    % yyaxis right
    figure
    stairs(GGIR.timeStamp,GGIR.class_id); zoom on
    ax(2)=gca;
    linkaxes(ax,'x');
    set(ax(1),'XMinorGrid','on','YMinorGrid','on','YTickLabel',[]);

    %% HRV
    PRV = table();

    fr = 4;
    clear SetupHRV
    SetupHRV.tol = 2;
    SetupHRV.T = 25;
    SetupHRV.plotflag = true;

    [PRV.HRV,PRV.HR,PRV.mHR,~,~,~,~,PRV.t] = computeHRVsignals ( pulses.nB, fr , SetupHRV );

    idx = 1+round(PRV.t*25.6);
    PRV.timeStamp = t_resampled(idx)'; 


    %% HRV gap filling
    


    
    %% TF
    TF=table();
    % Setup.plotflag = false;
    % [pLF, pHF, pVLF] = computeTF ( PRV.HR, 4 , Setup );
    % TF.pLF = pLF(:);
    % TF.pHF = pHF(:);
    % TF.pVLF = pVLF(:);
    % TF.timeStamp = PRV.timeStamp; 

    % save(fullfile(patientPath, [patientID '_mata_hrv.mat']), '-append' , 'HRV','HR','mHR');
    save(fullfile(patientPath, [patientID '_prv_nB.mat']), 'pulses','PRV','TF');

end
