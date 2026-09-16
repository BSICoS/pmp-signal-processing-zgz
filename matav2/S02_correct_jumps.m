
clear
% close all force
% clc

repoRoot = fileparts(fileparts(mfilename('fullpath'))); addpath(repoRoot);
p = paths();
addpath(genpath(p.biomedSigProc));

dataDir = 'registros';
mataFiles = dir(fullfile(dataDir,'*.mat'));

for kk = 1:length(mataFiles)
    % for kk = 2
    % for kk = length(mataFiles)

    close all force
    clearvars -except dataDir mataFiles kk

    filename = mataFiles(kk).name;
    [~, patientID, ~] = fileparts(filename);

    matFilePath = fullfile(dataDir, [mataFiles(kk).name(1:end-4), '.mat']);
    disp([matFilePath, ' - loading...']);
    if ~isfile(matFilePath)
        disp([matFilePath, ' - no existe, continue.']);
        continue;
    end

    %     load(matFilePath,'PPG');
    %     sig = PPG;

    load(matFilePath,'PPG_corrected');
    sig = PPG_corrected;

    fs = 25.6;

    %%

    % Interpolate NaNs in the signal
    nan_indices = isnan(sig);
    not_nan_indices = ~nan_indices;
    ppg_signal_interpolated = sig;
    ppg_signal_interpolated(nan_indices) = interp1(find(not_nan_indices), sig(not_nan_indices), find(nan_indices), 'pchip');

    t_25Hz = (0:1:length(ppg_signal_interpolated)-1)./fs;

    %%%%%%%%%%%
    disp('falta eliminar tramos interpolados en la PPG, y no solo muestras sueltas')
    %%%%%%%%%%%

    ppg_diff_interpolated = diff(ppg_signal_interpolated);

    figure
    plot(t_25Hz,ppg_signal_interpolated)
    yyaxis right
    plot(t_25Hz(2:end),ppg_diff_interpolated)

    mean_diff_interpolated = mean(ppg_diff_interpolated, 'omitnan');
    std_diff_interpolated = std(ppg_diff_interpolated, 'omitnan');
    % 0.0435
    % 170.0

    % Define a threshold to identify jumps
    %     threshold_new = mean_diff_interpolated + 3 * std_diff_interpolated; %GAIN
    %     threshold_new = mean_diff_interpolated + .4 * std_diff_interpolated; %MATA02jumps
    %     threshold_new  = 100*threshold_new;
    threshold_new = 40;

    % Identify jumps
    jumps_new = find(abs(ppg_diff_interpolated) > threshold_new);

    figure
    plot(t_25Hz,ppg_signal_interpolated)
    yyaxis right
    plot(t_25Hz(2:end),abs(ppg_diff_interpolated))
    yline(threshold_new)


    figure
    plot(t_25Hz,ppg_signal_interpolated); hold on
    idx=find(abs(ppg_diff_interpolated) >= threshold_new)+1;
    ppg_signal_interpolated(idx)=NaN;
    plot(t_25Hz,ppg_signal_interpolated);

    fsi = 5*fs;
    t = t_25Hz(1) : 1/fsi : t_25Hz(end);
    ppg_interpolated = interp1 ( t_25Hz , ppg_signal_interpolated , t , 'spline' );

    plot(t,ppg_interpolated);

    [bb, aa] = cheby2(4, 60, 0.1/(fsi/2), 'high');
    PPG_wojumps = filtfilt(bb,aa,detrend(ppg_interpolated,2));

    SetupLPD.orderLPD = round(7*fsi);
    SetupLPD.fpLPD = 7.8;
    SetupLPD.fcLPD = 8.0;
    SetupLPD.plotflag = false;
    LPD_PPG_corrected_resampled = LPDFiltering(PPG_wojumps, fsi, SetupLPD);

    %     sigs = [nanzscore(ppg_interpolated(:))];% nanzscore(LPD_PPG_corrected_resampled(:))];
    sigs = [nanzscore(PPG_wojumps(:)) nanzscore(LPD_PPG_corrected_resampled(:))];
    sigs([1:5*fsi, end-5*fsi+1:end], :) = NaN;

    % Setup for peakednessCost
    SetupPN.DT = 1;
    SetupPN.Ts = 10; % interval length of Welch periodograms (s)
    SetupPN.Tm = 10; % interval length of subintervals for Welch periodograms (s)
    SetupPN.Omega_r = [40 130] / 60;
%     SetupPN.Omega_r = [80 150] / 60;
    SetupPN.K = 5;
    SetupPN.d = 0.4;
    SetupPN.b = 0.5;
    SetupPN.a = 0.7;
    SetupPN.Nfft = 2^12;
    SetupPN.plotflag = true;

    resultsPN = peakednessCost ( sigs , t , fsi , SetupPN );

    % %     MATA1 = load('registros\MATA02-1004961-20241202-144154.mat','HR');
    % %
    % %     delay = (13+26);
    % %     %     delay = (10);
    % %
    % %     t_25Hz = (0:1:length(MATA1.HR)-1)./fs;
    % %     plot(t_25Hz-delay,MATA1.HR,'LineWidth',0.5,'DisplayName','HR-MATA1');
    % %
        HR_PN = resultsPN.bar_fr.*60;
        tHR_PN = resultsPN.t_aver;
    % %
    % %     figure
    % %     plot(tHR_PN,HR_PN,'DisplayName','HR-MATA2-CORRECTED-BSICoS'); hold on; grid on
    % %     plot(t_25Hz-delay,MATA1.HR,'DisplayName','HR-MATA1');
    % %     legend
    % %
    % %     keyboard

    %%

%     keyboard

    % Save the data to a .mat file
    save(matFilePath, '-append', "PPG_wojumps","HR_PN","tHR_PN");

end


