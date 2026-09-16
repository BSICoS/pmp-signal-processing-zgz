clear; close all force; clc

addpath(genpath('C:\Users\user\OneDrive - unizar.es\DOCTORADO\biomedical-signal-processing'),'-begin');
% segment_length = seconds(10);

src_folder = 'ggir_analysis\output_suj01_20_20250401';
% filesdir = dir('ggir_analysis\output\output_pabloA\meta\ms5.outraw\35_100_400\*.csv');
filesdir = dir(fullfile(src_folder,'\output_pabloA\meta\ms5.outraw\35_100_400\*.csv'));

for suj = 1:numel(filesdir)
 
    clearvars -except suj filesdir  src_folder
    close all

    % for suj = 1:11
    sujetoID = sprintf('sujeto%02d', suj);

    % GGIR = load (['ggir_analysis\output_csv_mat\' sujetoID '_GGIR.mat']); GGIR = struct2table (GGIR);  GGIR.timeStamp.TimeZone = 'UTC'; % timeStampGGIR = timeStamp; clear timeStamp;
    % GGIR = load (['ggir_analysis\output_csv_mat\' sujetoID '_GGIR.mat']); 

 
   GGIR_codes = readtable("ggir_analysis\output_suj01_20_20250401\output_pabloA\meta\ms5.outraw\behavioralcodes2025-04-01.csv",'Delimiter',',','ReadVariableNames',true);
     % GGIR_codes = readtable("ggir_analysis\output_suj21_23\output_pabloA\meta\ms5.outraw\behavioralcodes2025-05-13.csv",'Delimiter',',','ReadVariableNames',true);
    
    GGIR.class_id = categorical(GGIR.class_id,GGIR_codes.class_id,GGIR_codes.class_name);

    GGIR.timeStamp =  datetime(GGIR.timenum, 'ConvertFrom', 'posixtime','TimeZone','UTC');


    %% eliminar tramos sin llevar la pulsera
    
    % GGIR.class_id = reordercats(GGIR.class_id, {'spt_sleep','spt_wake_IN','spt_wake_LIG','spt_wake_MOD','spt_wake_VIG',...
    %     'day_IN_unbt', 'day_IN_bts_30_60','day_IN_bts_60', ...
    %     'day_LIG_unbt', 'day_LIG_bts_10', ...
    %     'day_MOD_unbt', 'day_MVPA_bts_1_5', 'day_MVPA_bts_5_10','day_MVPA_bts_10', 'day_VIG_unbt'});
    % 
    % % categories(GGIR.class_id);

    GGIR = renamevars(GGIR,'invalidepoch','non_wear');
    GGIR.class_id (logical(GGIR.non_wear) ) = 'non_wear';    

    %% andir bouts de INACTIVITY a partir de 5 mins

    bouts_min = 1*60; %segundos
    fs = 1/5;% GGIR da 1 muestra cada 5 segundos

    % seqs = findSequences (double(GGIR.class_id));
    % seqs(seqs(:,1)~=6,:)=[]; % 6 es day_IN_unbout
    % seqs(seqs(:,4)<bouts_min*fs,:)=[];

      seqs = findSequences (double(GGIR.class_id));
    seqs(seqs(:,1)~=7,:)=[]; % 7 es day_LIG_unbout
    seqs(seqs(:,4)<bouts_min*fs,:)=[];

    disp ([num2str( sum (seqs(:,4)./fs)/3600 ) 'h recuperadas de LIG en bouts de minimo ' num2str(bouts_min/60) 'min'])

    for ii =1:size(seqs,1)
        GGIR.class_id (seqs(ii,2):seqs(ii,3)) = ['day_IN_bts_' num2str(bouts_min/60) '_30'];
    end


    %% group categories

    grouped_category = strings(size(GGIR.class_id));

    % Groups by activity, eliminating UNBOUTED classes
    grouped_category(ismember(GGIR.class_id, {'spt_sleep','spt_wake_IN','spt_wake_LIG','spt_wake_MOD','spt_wake_VIG'})) = "Sueño";
    grouped_category(ismember(GGIR.class_id, {'day_IN_bts_60', 'day_IN_bts_30_60', 'day_IN_bts_1_30'})) = "Descanso";
    % grouped_category(ismember(GGIR.class_id, {'day_IN_bts_60', 'day_IN_bts_30_60', ['day_IN_bts_' num2str(bouts_min/60) '_30']})) = "Descanso";
    grouped_category(ismember(GGIR.class_id, {'day_LIG_bts_10'})) = "Actividad ligera";
    grouped_category(ismember(GGIR.class_id, {'day_MVPA_bts_10', 'day_MVPA_bts_5_10', 'day_MVPA_bts_1_5'})) = "Moderado/Vigoroso";
    grouped_category(ismember(GGIR.class_id, {'day_IN_unbt', 'day_LIG_unbt','day_VIG_unbt','day_MOD_unbt'})) = "Unbout";
    grouped_category(ismember(GGIR.class_id, {'non_wear'})) = "NonWear";

    grouped_category    =   categorical(grouped_category);    
    exist_cats          =   categories (grouped_category);
    desired_cats        =   {'Sueño','Descanso','Actividad ligera','Moderado/Vigoroso','Unbout','NonWear'};
    valid_cats          =   intersect(desired_cats, exist_cats, 'stable');
    grouped_category    =   reordercats(grouped_category, valid_cats);

    GGIR.class_group    =   grouped_category;
    GGIR                =   movevars(GGIR, "class_group", "After", "class_id");
    GGIR                =   movevars(GGIR, "timeStamp", "Before",1);

    figure
    plot(GGIR.timeStamp,GGIR.class_id);
    yyaxis right
    plot(GGIR.timeStamp,GGIR.class_group);
    grid on; set(gca, 'TickLabelInterpreter', 'none');legend; zoom on
    addSlider ( gcf, GGIR.timeStamp );

    disp([ '% tiempo en UNBOUT: '  num2str(mean(ismember(GGIR.class_group,'Unbout')) *100 ) '%'] );
    disp([ '% tiempo en NONWEAR: ' num2str(mean(ismember(GGIR.class_group,'NonWear'))*100 ) '%'] );

    %save([ sujetoID '\' sujetoID '_GGIR.mat'],'GGIR');
    save(fullfile(filesdir(suj).folder,[filesdir(suj).name(1:end-4) '.mat']),'GGIR');
end