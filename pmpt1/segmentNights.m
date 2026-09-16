clear;
clc;

addpath('lib');

datasetVersions = {'v1', 'v2_1', 'v2_2'};
clearOutputDir = true;

for versionIdx = 1:numel(datasetVersions)
    datasetVersion = datasetVersions{versionIdx};
    ppgDir = fullfile('data', datasetVersion, 'ppg');
    ggirDir = fullfile('data', datasetVersion, 'ggir');
    outputDir = fullfile('data', datasetVersion, 'nights');

    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    elseif clearOutputDir
        delete(fullfile(outputDir, 'PMP*_night*.mat'));
    end

    ppgFiles = dir(fullfile(ppgDir, '*_ppg_wojumps.mat'));
    exported = 0;

    fprintf('\nSegmenting PPG nights for %s (%d subjects)\n', datasetVersion, numel(ppgFiles));

    for fileIdx = 1:numel(ppgFiles)
        subjectId = extractSubjectId(ppgFiles(fileIdx).name);
        ggirFile = findMatchingGgirFile(ggirDir, subjectId);
        if strlength(subjectId) == 0 || strlength(ggirFile) == 0
            warning('Skipping %s: missing subject id or GGIR file', ppgFiles(fileIdx).name);
            continue;
        end

        ppgData = load(fullfile(ppgFiles(fileIdx).folder, ppgFiles(fileIdx).name), ...
            'PPG_corrected_resampled', 't_resampled');
        ggirData = load(ggirFile, 'GGIR');
        [nightBounds, nightInfo] = cleanGgirNightBounds(ggirData.GGIR);

        ppgSignal = ppgData.PPG_corrected_resampled(:);
        ppgTime = ppgData.t_resampled(:);
        subjectExported = 0;

        for nightIdx = 1:size(nightBounds, 1)
            nightStart = nightBounds(nightIdx, 1);
            nightEndExclusive = nightBounds(nightIdx, 2);
            mask = ppgTime >= nightStart & ppgTime < nightEndExclusive;
            if ~any(mask)
                continue;
            end

            ppg = ppgSignal(mask);
            tSegment = ppgTime(mask);
            t = seconds(tSegment - tSegment(1));
            save(fullfile(outputDir, sprintf('PMP%s_night%d.mat', subjectId, nightIdx)), 'ppg', 't');
            subjectExported = subjectExported + 1;
        end

        exported = exported + subjectExported;
        fprintf('PMP%s: %d clean nights exported (%d rejected)\n', ...
            subjectId, subjectExported, sum(nightInfo.status ~= "ok"));
    end

    fprintf('Finished %s: %d PPG nights exported\n', datasetVersion, exported);
end

function subjectId = extractSubjectId(fileName)
tokens = regexp(fileName, '(\d+)', 'tokens', 'once');
if isempty(tokens)
    subjectId = "";
else
    subjectId = string(tokens{1});
end
end

function ggirFile = findMatchingGgirFile(ggirDir, subjectId)
subjectId = char(subjectId);
matches = dir(fullfile(ggirDir, ['PMP' subjectId '*.mat']));
if isempty(matches)
    ggirFile = "";
else
    ggirFile = string(fullfile(matches(1).folder, matches(1).name));
end
end
