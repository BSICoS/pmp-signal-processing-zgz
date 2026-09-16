clear
close all force
clc

%% Define the root directory to search for patient folders
rootDir = "D:\OneDrive - unizar.es\DOCTORADO\1_TFGs\user\medicina_personalizada\REGISTROS_COMPLETOS\REGISTROS 3 DIAS";
% rootDir = "C:\Users\user\OneDrive - unizar.es\DOCTORADO\1_TFGs\user\medicina_personalizada\REGISTROS_COMPLETOS\REGISTROS 3 DIAS";


patientDirs = dir(rootDir); 
patientDirs = patientDirs([patientDirs.isdir]); 
patientDirs = patientDirs(~ismember({patientDirs.name}, {'.', '..'}));

% Loop over each patient directory
for suj = 8:length(patientDirs)

    clearvars -except patientDirs suj rootDir

    patientID = patientDirs(suj).name;
    patientPath = fullfile(rootDir, patientID);

    % Load data
    disp(['Processing patient: ' patientID]);
    ppgFilePath = fullfile(patientPath, [patientID '_ppg_wojumps.mat']);
    relojFilePath = fullfile(patientPath, [patientID '_reloj.mat']);
    
    if exist(ppgFilePath, 'file') && exist(relojFilePath, 'file')
        load(ppgFilePath, 'PPG_corrected');
        MATA = load(relojFilePath, 'PPG', 'timeStamp');
        MATA.timeStamp.TimeZone = 'Europe/Madrid'; 
        MATA = struct2table(MATA);
    else
        disp(['Files missing for patient: ' patientID]);
        continue;
    end

    %% HR CON NUESTROS ALGS

    fs = 25.6;
    t_ini = MATA.timeStamp(1);
    t_fin = MATA.timeStamp(end);
    t = t_ini : seconds(1/fs) : t_fin;

    % Resample PPG signal
    PPG_corrected_resampled = interp1(MATA.timeStamp, PPG_corrected, t, 'pchip');

    [bb, aa] = cheby2(4, 60, 0.1/(fs/2), 'high');
    PPG_corrected_resampled = filtfilt(bb,aa,detrend(PPG_corrected_resampled,2));

    clear SetupARTFS
    SetupARTFS.wdwVariance = 10;
    SetupARTFS.wdwMedian = 500;
    SetupARTFS.plotflag = true;
    [ ~ , PPG_corrected_resampled_artifacts ] = energyArtifacts (PPG_corrected_resampled,fs,SetupARTFS);


    SetupLPD.orderLPD = round(7*fs);
    SetupLPD.fpLPD = 7.8;
    SetupLPD.fcLPD = 8.0;
    SetupLPD.plotflag = false;
    LPD_PPG_corrected_resampled = LPDFiltering(PPG_corrected_resampled_artifacts, fs, SetupLPD);

    sigs = [nanzscore(PPG_corrected_resampled_artifacts(:))];%, nanzscore(LPD_PPG_corrected_resampled(:))];

    clearvars -except sigs t fs patientPath patientID patientDirs suj rootDir relojFilePath

    % Setup for peakednessCost
    SetupPN.DT = 1;
    SetupPN.Ts = 10; % interval length of Welch periodograms (s)
    SetupPN.Tm = 10; % interval length of subintervals for Welch periodograms (s)
    SetupPN.Omega_r = [45 185] / 60;
    SetupPN.K = 5;
    SetupPN.d = 0.8;
    SetupPN.b = 0.5;
    SetupPN.a = 0.7;
    Setup.Nfft = 2^14;
    SetupPN.plotflag = true;

    % Initialize vars
    t_aver=[];
    hat_fr=[];
    bar_fr=[];

    % Process data hour by hour
    one_hour = .5 * 3600 * fs; % number of samples in one hour
    num_hours = floor(length(t) / one_hour);

    for ii = 1:num_hours

        % Define the time indices for the current hour
        idx_start = (ii-1) * one_hour + 1;
        idx_end = ii * one_hour;

        % Extract the segment for the current hour
        sigs_hour = sigs(idx_start:idx_end, :);
%         timeStamp_hour = t(idx_start:idx_end);
        t_hour = idx_start/fs : 1/fs : idx_end/fs;

        % Compute the peakedness cost for the current hour
        vars_hour = peakednessCost(sigs_hour, t_hour, fs, SetupPN);

        % Append the results to vars_all
        t_aver = [t_aver; vars_hour.t_aver(:)];
        hat_fr = [hat_fr; vars_hour.hat_fr(:)];
        bar_fr = [bar_fr; vars_hour.bar_fr(:)];

        fprintf('\r%6.2f%% completed', (100 * ii) / num_hours); % Display the progress on the same line

    end

    fprintf('\n'); % Move to the next line after completion

    % Save the results
    save(fullfile(patientPath, [patientID '_peakedness.mat']), 't_aver','hat_fr','bar_fr');
    
%     % Optional: Plot the results for verification
%     figure
%     plot(t_aver, bar_fr .* 60, 'LineWidth', 2);
%     title(['Heart Rate Over Time for Patient: ' patientID]);
%     xlabel('Time');
%     ylabel('Heart Rate (bpm)');
%     grid on; hold on
% 
%  MATA = load(relojFilePath, 'HR', 'timeStamp');
%       
%     t = (0:1:length(MATA.HR)-1)./25.6;
%     plot(t,MATA.HR)
%     
%     % Save the figure
%     saveas(gcf, fullfile(patientPath, [patientID '_heart_rate_plot.png']));
%     close(gcf);

end
