


figure
load('newFW_pruebaDeporte\DefaultTrial_Session1_Shimmer_68B7_Calibrated_SD_imported.mat');
leadII.tK_timeStamp.TimeZone = 'UTC'; leadII.tK_timeStamp = leadII.tK_timeStamp + hours(1);
leadII.HRV.timeStamp.TimeZone = 'UTC'; leadII.HRV.timeStamp = leadII.HRV.timeStamp + hours(1);
% plot(leadII.tK_timeStamp(2:end),60./diff(leadII.tK) ,'DisplayName','diff tk ECG'); hold on; grid on
plot(leadII.HRV.timeStamp, leadII.HRV.mHR .*60  ,'DisplayName','diff tk ECG','color',[     0    0.4470    0.7410]); hold on; grid on
yyaxis right
plot(TimeStamp+hours(1),table2array(sqrt(sum(ACC.^2,2))),'DisplayName','ENMO ACC shimmer','LineStyle','-','color',[0.4940    0.1840    0.5560]); hold on
yyaxis left
clear
reg = 'MATA00-1004258-20250305-194425';
load(['newFW_pruebaDeporte\' reg '.mat']);
timeStamp.TimeZone = 'UTC';
plot(timeStamp,HR,'DisplayName',reg,'color',[0.8500    0.3250    0.0980])
clear
reg = 'MATA00-2002053-20250305-194352';
load(['newFW_pruebaDeporte\' reg '.mat']);
timeStamp.TimeZone = 'UTC';
plot(timeStamp,HR,'DisplayName',reg,'color',[0.9290    0.6940    0.1250])
legend;
yyaxis right
plot(timeStamp,sqrt(sum(ACC.^2,2)),'DisplayName','ENMO ACC mata','LineStyle','-','color',[0.4660    0.6740    0.1880]);

addSlider(gcf,timeStamp);

