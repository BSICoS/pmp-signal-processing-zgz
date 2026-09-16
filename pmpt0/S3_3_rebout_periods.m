% S3_3_rebout_periods


clear; close all force; clc

repoRoot = fileparts(fileparts(mfilename('fullpath'))); addpath(repoRoot);
p = paths();
addpath(genpath(p.biomedSigProc),'-begin');
% segment_length = seconds(10);

rootDir = "REGISTROS 3 DIAS";

patientDirs = dir(rootDir);
patientDirs = patientDirs([patientDirs.isdir]);
patientDirs = patientDirs(~ismember({patientDirs.name}, {'.', '..'}));

for suj = 1:numel(patientDirs)

    clearvars -except patientDirs suj rootDir

    patientID = patientDirs(suj).name;
    patientPath = fullfile(rootDir, patientID);

    % Load data
    disp(['Processing patient: ' patientID]);
    ggirFilePath = fullfile(patientPath, [patientID '_GGIR.mat']);

    load(ggirFilePath);

    % figure
    % plot(GGIR.timeStamp,GGIR.class_group); hold on
    % yyaxis right
    % plot(GGIR.timeStamp,GGIR.class_id); hold on

    bouts_min = 1*60; %segundos
    fs = 1/5;% GGIR da 1 muestra cada 5 segundos

    seqs = findSequences (double(GGIR.class_id));
    seqs(seqs(:,1)~= find(strcmp(categories(GGIR.class_id),'day_LIG_unbt')) ,:)=[]; % 6 es day_IN_unbout, 7 es day_LIG_unbt
    seqs(seqs(:,4)<bouts_min*fs,:)=[];

    for ii =1:size(seqs,1)
        GGIR.class_id    (seqs(ii,2):seqs(ii,3)) = ['day_LIG_bts_' num2str(bouts_min/60) '_10'];
        GGIR.class_group (seqs(ii,2):seqs(ii,3)) = 'Ligero';

        % GGIR.class_id (seqs(ii,2):seqs(ii,3)) = ['day_IN_bts_' num2str(bouts_min/60) '_30'];
    end

    disp ([num2str( sum (seqs(:,4)./fs)/3600 ) 'h recuperadas de inactivity en bouts de minimo ' num2str(bouts_min/60) 'min'])
  disp ([ 'Segmentos de duracion media: ' num2str( max((seqs(:,4)./fs)/60) ) 'min']);

    % yyaxis left
    % plot(GGIR.timeStamp,GGIR.class_group); hold on

    %save([ sujetoID '\' sujetoID '_GGIR.mat'],'GGIR');
    % save(fullfile(filesdir(suj).folder,[filesdir(suj).name(1:end-4) '.mat']),'GGIR');
end