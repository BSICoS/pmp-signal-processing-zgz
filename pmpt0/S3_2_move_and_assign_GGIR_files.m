% filepath: /D:/OneDrive - unizar.es/DOCTORADO/0_WerPerMed/REGISTROS_COMPLETOS/S3_2_move_and_assign_GGIR_files.m
clear; close all force; clc


src_folder = 'D:\OneDrive - unizar.es\DOCTORADO\0_WerPerMed\REGISTROS_COMPLETOS\ggir_analysis\output_suj21_23\output_pabloA\meta\ms5.outraw\35_100_400';
% src_folder = 'ggir_analysis\output\output_pabloA\meta\ms5.outraw\35_100_400';
dest_folder = 'D:\OneDrive - unizar.es\DOCTORADO\0_WerPerMed\REGISTROS_COMPLETOS\REGISTROS 3 DIAS\'; % set destination folder

filesdir = dir(fullfile(src_folder, '*.mat'));

for i = 1:numel(filesdir)
    clearvars -except i filesdir src_folder dest_folder
    close all

    src_file = fullfile(src_folder, filesdir(i).name);
    
    % Extract the identifier e.g. "MATA00-1004961-20240209-114234" from the filename
    tokens = regexp(filesdir(i).name, '^(MATA\d+-\d+-\d+-\d+)', 'tokens');
    if isempty(tokens)
        fprintf('Identifier not found in %s\n', filesdir(i).name);
        continue;
    end
    identifier = tokens{1}{1};
    
    % Search in the REGISTROS 3 DIAS folder for the corresponding .BIN file
    registros_folder = 'D:\OneDrive - unizar.es\DOCTORADO\0_WerPerMed\REGISTROS_COMPLETOS\REGISTROS 3 DIAS';
    suj_folders = dir(fullfile(registros_folder));
    targetSuj = '';
    
    for j = 1:numel(suj_folders)
        % Check for possible RELOJ folder names
        possible_reloj_folders = {'RELOJ', 'RELOJ MATA V1', 'RELOJ MATA V2'};
        bin_file = '';
        
        for k = 1:numel(possible_reloj_folders)
            reloj_path = fullfile(registros_folder, suj_folders(j).name, possible_reloj_folders{k});
            bin_file = fullfile(reloj_path, [identifier '.BIN']);
            if exist(bin_file, 'file')
                targetSuj = suj_folders(j).name;
                break;
            end
        end
        
        if ~isempty(targetSuj)
            break;
        end
    end
    
    if isempty(targetSuj)
        fprintf('No matching suj folder found for %s\n', filesdir(i).name);
        continue;
    end
    
    % Rename file: prepend the corresponding sujeto folder name
    new_filename = [targetSuj '_GGIR.mat'];
    dest_file = fullfile(dest_folder, targetSuj, new_filename);
    
    % Create destination directory if it does not exist
    dest_dir = fileparts(dest_file);
    if ~exist(dest_dir, 'dir')
        mkdir(dest_dir);
    end

    fprintf ([identifier '\t' targetSuj '\n']);

    % Copy the file
    copyfile(src_file, dest_file);
%
end
