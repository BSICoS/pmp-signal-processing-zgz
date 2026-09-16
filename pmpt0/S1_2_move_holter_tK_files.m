% filepath: /D:/OneDrive - unizar.es/DOCTORADO/0_WerPerMed/REGISTROS_COMPLETOS/S3_2_move_and_assign_GGIR_files.m
clear; close all force; clc

src_folder  = 'path/to/source';  % EDIT per use
dest_folder = 'path/to/dest';    % EDIT per use

% Find files matching *_holter.mat and *_tK.mat patterns
files_holter = dir(fullfile(src_folder, '**', '*_holter.mat'));
files_tK = dir(fullfile(src_folder, '**', '*_tK.mat'));

% Combine both file lists
filesdir = [files_holter; files_tK];

for i = 1:numel(filesdir)
    clearvars -except i filesdir src_folder dest_folder
    close all

    src_file = fullfile(filesdir(i).folder, filesdir(i).name);
    
    % Extract subject folder name (assumes subject folder is immediate parent)
    [~, subject_folder] = fileparts(filesdir(i).folder);
    
    % Create destination subfolder for the subject
    dest_subfolder = fullfile(dest_folder, subject_folder);
    dest_file = fullfile(dest_subfolder, filesdir(i).name);

    fprintf('Moving file: %s to %s\n', src_file, dest_file);

    % Copy the file (overwrite if exists)
    copyfile(src_file, dest_file);
end
