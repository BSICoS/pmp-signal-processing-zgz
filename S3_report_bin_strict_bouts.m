clear; close all force; clc
% Build per-record / per-subject / database summaries + figures from the
% strict-bout post-processed .mat files (output_2026_bin_bt1_agg).
% Exports: report/summary_per_record.csv and report/*.png

this_dir = fileparts(mfilename('fullpath'));
src = fullfile(this_dir, ...
    'output_2026_bin_bt1_agg','output_pabloA','meta','ms5.outraw','45_100_400');
repdir = fullfile(this_dir,'output_2026_bin_bt1_agg','report');
if ~exist(repdir,'dir'); mkdir(repdir); end

% --- record stem -> [subject number, device version] -------------------
% version: 1 = device MATA*-1004961 (primary), 2 = V2 device (2000822/2002053)
map = containers.Map('KeyType','char','ValueType','any');
map('MATA04-1004961-20240202-094632') = {1 ,1};
map('MATA00-1004961-20240312-111412') = {2 ,1};
map('MATA00-1004961-20240216-145815') = {3 ,1};
map('MATA00-1004961-20240306-113720') = {4 ,1};
map('MATA01-1004961-20240610-104619') = {5 ,1};
map('MATA00-1004961-20240425-115116') = {6 ,1};
map('MATA00-1004961-20240209-114234') = {7 ,1};
map('MATA03-1004961-20240223-123701') = {8 ,1};
map('MATA00-1004961-20240319-113436') = {9 ,1};
map('MATA00-1004961-20240212-160047') = {10,1};
map('MATA00-1004961-20240529-113934') = {11,1};
map('MATA00-1004961-20241104-124542') = {12,1};
map('MATA01-1004961-20241029-160023') = {13,1};
map('MATA00-1004961-20240702-101145') = {14,1};
map('MATA00-1004961-20240627-141324') = {15,1};
map('MATA00-1004961-20241216-101410') = {16,1};
map('MATA00-1004961-20241112-150631') = {17,1};
map('MATA00-1004961-20241204-144054') = {18,1};
map('MATA00-1004961-20250218-112155') = {19,1};
map('MATA00-1004961-20250204-130542') = {20,1};
map('MATA00-2002053-20250204-130504') = {20,2};
map('MATA00-1004961-20250320-120546') = {21,1};
map('MATA00-2000822-20250320-120601') = {21,2};
map('MATA00-1004961-20250304-113342') = {22,1};
map('MATA00-2000822-20250304-113328') = {22,2};
map('MATA00-1004961-20250311-123415') = {23,1};
map('MATA00-2000822-20250311-123358') = {23,2};

% class_group codes (order set in strict_bouts.m):
% 1 Sueno | 2 NonWear | 3 Sed | 4 Lig | 5 MVPA | 6 Unbout
cats   = {'Sueno','NonWear','Sed','Lig','MVPA','Unbout'};
colors = [0.20 0.30 0.60;   % Sueno
          0.65 0.65 0.65;   % NonWear
          0.30 0.65 0.80;   % Sed
          0.60 0.80 0.35;   % Lig
          0.90 0.40 0.20;   % MVPA
          0.85 0.80 0.45];  % Unbout

filesdir = dir(fullfile(src,'*.csv'));   % drives the record order (27)
n = numel(filesdir);

rec     = strings(n,1);
subj    = zeros(n,1);
ver     = zeros(n,1);
startdt = NaT(n,1,'TimeZone','Europe/Madrid');
totmin  = zeros(n,1);
cnt     = zeros(n,6);   % minutes per class_group

for k = 1:n
    [~, stem] = fileparts(filesdir(k).name);
    S = load(fullfile(filesdir(k).folder,[stem '.mat']),'GGIR');
    G = S.GGIR;
    key = erase(stem,'_T5A5');
    mv  = map(key);

    rec(k)     = string(key);
    subj(k)    = mv{1};
    ver(k)     = mv{2};
    startdt(k) = G.timeStamp(1);
    totmin(k)  = height(G);

    code = double(G.class_group);
    for i = 1:6
        cnt(k,i) = sum(code==i);
    end
end

% NonWear (col 2) does NOT count: all class percentages are computed over
% WEAR time (total - NonWear). NonWear is reported only as excluded fraction.
wear_min = totmin - cnt(:,2);              % time the watch was worn
wake_min = wear_min - cnt(:,1);            % wear minus Sueno
nonwear_pct_of_total = 100 * cnt(:,2) ./ totmin;   % info only (how much excluded)

% percentages of the 5 worn classes over WEAR time
pct = 100 * cnt ./ wear_min;               % cols 1..6, col2 (NonWear) ~ 0 ref
pct(:,2) = 0;                              % NonWear excluded from composition

% --- per-record summary table -----------------------------------------
T = table(rec, subj, ver, startdt, totmin/60, wear_min/60, nonwear_pct_of_total, ...
          pct(:,1), pct(:,3), pct(:,4), pct(:,5), pct(:,6), ...
          100*cnt(:,5)./wake_min, ...
          'VariableNames', {'record','subject','version','start', ...
          'total_h','wear_h','NonWear_pct_excl','Sueno_pct','Sed_pct', ...
          'Lig_pct','MVPA_pct','Unbout_pct','MVPA_pct_of_waking'});
T = sortrows(T,{'subject','version'});
writetable(T, fullfile(repdir,'summary_per_record.csv'));

% --- database aggregate over UNIQUE subjects (V1 only) ----------------
% Everything over WEAR time; NonWear reported separately as excluded info.
v1 = ver==1;
db_total_h   = sum(totmin(v1))/60;
db_wear_h    = sum(wear_min(v1))/60;
db_nonwear_h = sum(cnt(v1,2))/60;
db_cnt       = sum(cnt(v1,:),1);
db_pct       = 100*db_cnt/sum(wear_min(v1));          % pooled % of WEAR time
db_pct(2)    = 0;                                     % NonWear excluded
db_meanpct   = mean(pct(v1,:),1);                     % mean of per-subject %
db_stdpct    = std(pct(v1,:),0,1);
% keep only the 5 worn classes in the database table
wi = [1 3 4 5 6];                                     % Sueno Sed Lig MVPA Unbout
Tdb = table(cats(wi)', db_cnt(wi)'/60, db_pct(wi)', db_meanpct(wi)', db_stdpct(wi)', ...
    'VariableNames',{'class_group','wear_h','pooled_pct','mean_subject_pct','std_subject_pct'});
writetable(Tdb, fullfile(repdir,'summary_database.csv'));
fprintf('Database: total %.0f h, wear %.0f h, NonWear excluded %.0f h (%.1f%%)\n', ...
    db_total_h, db_wear_h, db_nonwear_h, 100*db_nonwear_h/db_total_h);

% ======================================================================
%  FIGURES
% ======================================================================
% Build labels "sNN" / "sNN-v2"
lab = strings(n,1);
for k=1:n
    if ver(k)==2, lab(k)=sprintf('s%02d-v2',subj(k)); else, lab(k)=sprintf('s%02d',subj(k)); end
end
[~,ord] = sortrows([subj ver]);

% worn-class indices/colors (exclude NonWear)
wi = [1 3 4 5 6];   % Sueno Sed Lig MVPA Unbout
cw = cats(wi); colw = colors(wi,:);

% --- Fig 1: stacked composition per record (% of WEAR time) -----------
f1 = figure('Position',[100 100 1100 650],'Color','w');
b = barh(1:n, pct(ord,wi), 'stacked');
for i=1:numel(wi), b(i).FaceColor = colw(i,:); end
set(gca,'YTick',1:n,'YTickLabel',lab(ord),'YDir','reverse','TickLabelInterpreter','none');
xlabel('% of wear time (NonWear excluded)'); xlim([0 100]);
legend(cw,'Location','eastoutside','Interpreter','none');
title('Strict-bout composition per record (% of wear time)');
grid on; box on;
exportgraphics(f1, fullfile(repdir,'fig1_composition_per_record.png'),'Resolution',150);

% --- Fig 2: database mean composition (bar with error bars) -----------
f2 = figure('Position',[100 100 720 480],'Color','w');
hold on;
for i=1:numel(wi)
    bar(i, db_meanpct(wi(i)), 'FaceColor', colw(i,:));
end
errorbar(1:numel(wi), db_meanpct(wi), db_stdpct(wi), 'k', 'linestyle','none','linewidth',1);
set(gca,'XTick',1:numel(wi),'XTickLabel',cw,'TickLabelInterpreter','none');
ylabel('% of wear time'); title('Database mean composition over wear (23 subjects, mean \pm SD)');
grid on; box on;
exportgraphics(f2, fullfile(repdir,'fig2_database_composition.png'),'Resolution',150);

% --- Fig 3: excluded NonWear fraction (info) --------------------------
f3 = figure('Position',[100 100 900 560],'Color','w');
[nw_sorted, si] = sort(nonwear_pct_of_total,'descend');
bar(nw_sorted,'FaceColor',colors(2,:));
set(gca,'XTick',1:n,'XTickLabel',lab(si),'XTickLabelRotation',60,'TickLabelInterpreter','none');
ylabel('NonWear excluded (% of recording)'); title('Non-wear fraction excluded from analysis (per record)');
yline(50,'r--','50%'); yline(25,'-','25%','Color',[.5 .5 .5]);
grid on; box on;
exportgraphics(f3, fullfile(repdir,'fig3_nonwear_quality.png'),'Resolution',150);

% --- Fig 4: bouted activity per WEAR-day (minutes/day worn) -----------
ndays_wear = wear_min/(60*24);   % days the watch was actually worn
mvpa_perday = cnt(:,5)./ndays_wear;
lig_perday  = cnt(:,4)./ndays_wear;
sed_perday  = cnt(:,3)./ndays_wear;
f4 = figure('Position',[100 100 1100 560],'Color','w');
bb = bar(1:n, [sed_perday(ord) lig_perday(ord) mvpa_perday(ord)], 'stacked');
bb(1).FaceColor=colors(3,:); bb(2).FaceColor=colors(4,:); bb(3).FaceColor=colors(5,:);
set(gca,'XTick',1:n,'XTickLabel',lab(ord),'XTickLabelRotation',60,'TickLabelInterpreter','none');
ylabel('bouted minutes per worn-day'); legend({'Sed','Lig','MVPA'},'Location','northeast','Interpreter','none');
title('Bouted activity per worn-day (strict bands, \geq3 min bouts)');
grid on; box on;
exportgraphics(f4, fullfile(repdir,'fig4_activity_per_day.png'),'Resolution',150);

fprintf('Report assets written to %s\n', repdir);
disp(T);
disp(Tdb);
