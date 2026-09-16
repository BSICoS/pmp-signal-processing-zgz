clear;
clc;

addpath('lib');

datasetVersions = {'v1', 'v2_1', 'v2_2'};
nasRoot = '\\smb2.i3a.es\nas2\bsicos01\__comun\ecg\PMP_T1\PMP_T1_biosignals';
clearOutputDir = true;

if ~exist(nasRoot, 'dir')
    error('NAS root not found: %s. No HR output was cleared or exported.', nasRoot);
end

for versionIdx = 1:numel(datasetVersions)
    datasetVersion = datasetVersions{versionIdx};
    ppgDir = fullfile('data', datasetVersion, 'ppg');
    ggirDir = fullfile('data', datasetVersion, 'ggir');
    outputDir = fullfile('data', datasetVersion, 'hr_nights');

    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    elseif clearOutputDir
        delete(fullfile(outputDir, 'PMP*_night*.mat'));
    end

    ppgFiles = dir(fullfile(ppgDir, '*_ppg_wojumps.mat'));
    exported = 0;

    fprintf('\nSegmenting device HR nights for %s (%d subjects)\n', datasetVersion, numel(ppgFiles));

    for fileIdx = 1:numel(ppgFiles)
        subjectId = extractSubjectId(ppgFiles(fileIdx).name);
        ggirFile = findMatchingGgirFile(ggirDir, subjectId);
        hrFile = findWristHrFile(nasRoot, subjectId);
        if strlength(subjectId) == 0 || strlength(ggirFile) == 0 || strlength(hrFile) == 0
            warning('Skipping PMP%s: missing GGIR or wrist HR file', subjectId);
            continue;
        end

        ggirData = load(ggirFile, 'GGIR');
        hrData = load(hrFile, 'HR', 'timeStamp');
        [nightBounds, nightInfo] = cleanGgirNightBounds(ggirData.GGIR);

        hr = hrData.HR(:);
        hrTime = hrData.timeStamp(:);
        if ~isdatetime(hrTime)
            hrTime = datetime(hrTime, 'ConvertFrom', 'datenum');
        end

        subjectExported = 0;
        for nightIdx = 1:size(nightBounds, 1)
            nightStart = nightBounds(nightIdx, 1);
            nightEndExclusive = nightBounds(nightIdx, 2);
            mask = hrTime >= nightStart & hrTime < nightEndExclusive;
            if ~any(mask)
                continue;
            end

            HR = hr(mask);
            timeStamp = hrTime(mask);
            t = seconds(timeStamp - timeStamp(1));
            sourceFile = char(hrFile);
            save(fullfile(outputDir, sprintf('PMP%s_night%d.mat', subjectId, nightIdx)), ...
                'HR', 'timeStamp', 't', 'nightStart', 'nightEndExclusive', 'sourceFile');
            subjectExported = subjectExported + 1;
        end

        exported = exported + subjectExported;
        fprintf('PMP%s: %d clean HR nights exported (%d rejected) from %s\n', ...
            subjectId, subjectExported, sum(nightInfo.status ~= "ok"), hrFile);
    end

    fprintf('Finished %s: %d HR nights exported\n', datasetVersion, exported);
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

function hrFile = findWristHrFile(nasRoot, subjectId)
subjectId = char(subjectId);
folders = dir(fullfile(nasRoot, ['PMP' subjectId '*']));
folders = folders([folders.isdir]);
if isempty(folders)
    hrFile = "";
    return;
end

[~, order] = sort({folders.name});
folders = folders(order);
mats = dir(fullfile(folders(1).folder, folders(1).name, '*.mat'));
scores = zeros(numel(mats), 1);
for i = 1:numel(mats)
    name = mats(i).name;
    low = lower(name);
    if contains(low, 'ggir') || contains(low, 'ppg_wojumps') || contains(low, 'holter')
        continue;
    end
    scores(i) = 100 * ~isempty(regexp(name, '_W\d+_M(?=(_|\.|-|$))', 'once')) + ...
        90 * ~isempty(regexpi(name, 'mu.*eca', 'once'));
end

[scores, order] = sort(scores, 'descend');
hrFile = "";
for i = 1:numel(order)
    if scores(i) <= 0
        return;
    end
    candidate = fullfile(mats(order(i)).folder, mats(order(i)).name);
    vars = {whos('-file', candidate).name};
    if all(ismember({'HR', 'timeStamp'}, vars))
        hrFile = string(candidate);
        return;
    end
end
end
