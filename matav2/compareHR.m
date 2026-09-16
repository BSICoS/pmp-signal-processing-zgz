
clear
% close all force
% clc

currentPath = pwd; rootIndex = strfind(currentPath, 'OneDrive - unizar.es'); rootPath = fullfile(currentPath(1:rootIndex + length('OneDrive - unizar.es') - 1), 'DOCTORADO');
addpath(genpath(fullfile(rootPath, 'biomedical-signal-processing')),'-begin');


%%

dataDir = 'newFW_prueba7dias';
mataFiles = dir(fullfile(dataDir,'*.mat'));

% figure

for kk = 1:length(mataFiles)
    % for kk = 2
    % for kk = length(mataFiles)

%     close all force
    clearvars -except dataDir mataFiles kk

    filename = mataFiles(kk).name;
    [~, patientID, ~] = fileparts(filename);
    matFilePath = fullfile(dataDir, [mataFiles(kk).name(1:end-4), '.mat']);
    disp([matFilePath, ' - loading...']);
    if ~isfile(matFilePath)
        disp([matFilePath, ' - no existe, continue.']);
        continue;
    end

    load(matFilePath,'HR','timeStamp');
    fs = 25.6;
    
    % plot(timeStamp,HR,'DisplayName',mataFiles(kk).name); hold on

    TT_MATA{kk} = timetable(timeStamp, HR, 'VariableNames', {['PR_MATA' num2str(kk)]});

    segment_length = seconds(10);
    TT_MATA_resampled{kk} = retime(TT_MATA{kk}, 'regular',  @(x) mean(x,'omitnan'), 'TimeStep', segment_length);

end

% legend;

TT_aligned = synchronize(TT_MATA_resampled{1} , TT_MATA_resampled{2} , TT_MATA_resampled{3} , 'intersection');

TT_aligned.Er_MATA_1_2 = 100 * abs((TT_aligned.PR_MATA2 - TT_aligned.PR_MATA1) ./ TT_aligned.PR_MATA1);
TT_aligned.Er_MATA_1_3 = 100 * abs((TT_aligned.PR_MATA3 - TT_aligned.PR_MATA1) ./ TT_aligned.PR_MATA1);

