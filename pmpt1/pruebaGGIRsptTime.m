
datasetVersions = {'v1', 'v2_1', 'v2_2'};
nasRoot = '\\smb2.i3a.es\nas2\bsicos01\__comun\ecg\PMP_T1\PMP_T1_biosignals';

totalExpected = 0;
totalExported = 0;

for versionIdx = 2:numel(datasetVersions)
    datasetVersion = datasetVersions{versionIdx};
    ppgDir = fullfile('data', datasetVersion, 'ppg');
    ggirDir = fullfile('data', datasetVersion, 'ggir');
    nightsDir = fullfile('data', datasetVersion, 'nights');
    outputDir = fullfile('data', datasetVersion, 'hr_nights');

    if ~exist(ppgDir, 'dir')
        warning('PPG directory not found for %s: %s', datasetVersion, ppgDir);
        continue;
    end

    if ~exist(ggirDir, 'dir')
        warning('GGIR directory not found for %s: %s', datasetVersion, ggirDir);
        continue;
    end

    if ~exist(nightsDir, 'dir')
        warning('Nights directory not found for %s: %s', datasetVersion, nightsDir);
        continue;
    end

    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    ppgFiles = dir(fullfile(ppgDir, '*_ppg_wojumps.mat'));
    versionNightFiles = dir(fullfile(nightsDir, '*.mat'));
    versionExpected = numel(versionNightFiles);
    versionExported = 0;
    totalExpected = totalExpected + versionExpected;

    fprintf('\nProcessing %s: %d subjects, %d existing night files\n', ...
        datasetVersion, numel(ppgFiles), versionExpected);

    for fileIdx = 12:numel(ppgFiles)
        ppgFile = ppgFiles(fileIdx);
        subjectId = extractSubjectId(ppgFile.name);
        if strlength(subjectId) == 0
            warning('Skipping PPG file with unrecognized subject id: %s', ppgFile.name);
            continue;
        end

        existingNightIdx = findExistingNightIndices(nightsDir, subjectId);
        if isempty(existingNightIdx)
            fprintf('Subject PMP%s has no existing night files in %s. Skipping.\n', subjectId, nightsDir);
            continue;
        end

        ggirFile = findMatchingGgirFile(ggirDir, subjectId);
        if strlength(ggirFile) == 0
            warning('No GGIR file found for subject PMP%s in %s', subjectId, ggirDir);
            continue;
        end

        hrFile = findWristHrFile(nasRoot, subjectId);
        if strlength(hrFile) == 0
            warning('No wrist HR source file found for subject PMP%s under %s', subjectId, nasRoot);
            continue;
        end

        ggirData = load(ggirFile, 'GGIR');
        if ~isfield(ggirData, 'GGIR') || ~istable(ggirData.GGIR)
            warning('GGIR table missing in %s', ggirFile);
            continue;
        end

        ggir = load(ggirFile);

        figure
        % plot(ggir.GGIR.timeStamp,ggir.GGIR.class_id)
        hold on
        plot(ggir.GGIR.timeStamp,ggir.GGIR.non_wear)
        plot(ggir.GGIR.timeStamp,ggir.GGIR.SleepPeriodTime)
        plot(ggir.GGIR.timeStamp,ggir.GGIR.invalid_sleepperiod)
        legend('non_wear','spt','invalid spt')

        title (subjectId);

    end

end





function subjectId = extractSubjectId(fileName)
tokens = regexp(fileName, '(\d+)', 'tokens', 'once');
if isempty(tokens)
    subjectId = "";
    return;
end

subjectId = string(tokens{1});
end

function ggirFile = findMatchingGgirFile(ggirDir, subjectId)
matches = dir(fullfile(ggirDir, sprintf('PMP%s*.mat', subjectId)));
if isempty(matches)
    ggirFile = "";
    return;
end

if numel(matches) > 1
    warning('Multiple GGIR files found for subject PMP%s. Using %s', subjectId, matches(1).name);
end

ggirFile = string(fullfile(matches(1).folder, matches(1).name));
end

function nightIndices = findExistingNightIndices(nightsDir, subjectId)
matches = dir(fullfile(nightsDir, sprintf('PMP%s_night*.mat', subjectId)));
nightIndices = zeros(numel(matches), 1);
nFound = 0;

for idx = 1:numel(matches)
    tokens = regexp(matches(idx).name, sprintf('^PMP%s_night(\\d+)\\.mat$', subjectId), 'tokens', 'once');
    if isempty(tokens)
        continue;
    end

    nFound = nFound + 1;
    nightIndices(nFound) = str2double(tokens{1});
end

nightIndices = sort(nightIndices(1:nFound));
end

function hrFile = findWristHrFile(nasRoot, subjectId)
subjectMatches = dir(fullfile(nasRoot, sprintf('PMP%s*', subjectId)));
subjectMatches = subjectMatches([subjectMatches.isdir]);
subjectMatches = subjectMatches(~ismember({subjectMatches.name}, {'.', '..'}));

if isempty(subjectMatches)
    hrFile = "";
    return;
end

[~, dirOrder] = sort({subjectMatches.name});
subjectMatches = subjectMatches(dirOrder);

if numel(subjectMatches) > 1
    warning('Multiple NAS folders found for subject PMP%s. Using %s', subjectId, subjectMatches(1).name);
end

subjectFolder = fullfile(subjectMatches(1).folder, subjectMatches(1).name);
matFiles = dir(fullfile(subjectFolder, '*.mat'));
if isempty(matFiles)
    hrFile = "";
    return;
end

scores = -inf(numel(matFiles), 1);
for idx = 1:numel(matFiles)
    fileName = matFiles(idx).name;
    lowerName = lower(fileName);

    if contains(lowerName, 'ggir') || contains(lowerName, 'ppg_wojumps') || ...
            contains(lowerName, 'holter') || contains(lowerName, '_tk') || ...
            startsWith(lowerName, 'tk_')
        continue;
    end

    wristScore = 0;

    if ~isempty(regexp(fileName, '_W\d+_M(?=(_|\.|-|$))', 'once'))
        wristScore = wristScore + 100;
    end

    if ~isempty(regexpi(fileName, 'mu.*eca', 'once'))
        wristScore = wristScore + 90;
    end

    if ~isempty(regexpi(fileName, 'acelerometr.*mu.*eca', 'once'))
        wristScore = wristScore + 95;
    end

    if wristScore == 0
        continue;
    end

    score = wristScore;
    if startsWith(fileName, sprintf('PMP%s_', subjectId))
        score = score + 10;
    end

    scores(idx) = score;
end

[sortedScores, sortedIdx] = sort(scores, 'descend');
hrFile = "";

for orderIdx = 1:numel(sortedIdx)
    if ~isfinite(sortedScores(orderIdx)) || sortedScores(orderIdx) <= 0
        break;
    end

    candidate = fullfile(matFiles(sortedIdx(orderIdx)).folder, matFiles(sortedIdx(orderIdx)).name);
    if matFileHasVariables(candidate, {'HR', 'timeStamp'})
        hrFile = string(candidate);
        return;
    end

    warning('Wrist candidate for PMP%s lacks HR or timeStamp: %s', subjectId, candidate);
end
end

function hasVariables = matFileHasVariables(matFile, variableNames)
try
    info = whos('-file', matFile);
catch readError
    warning('Could not inspect %s: %s', matFile, readError.message);
    hasVariables = false;
    return;
end

availableNames = {info.name};
hasVariables = all(ismember(variableNames, availableNames));
end

function timeStamp = normalizeTimestamp(timeStamp, sourceFile)
if isdatetime(timeStamp)
    return;
end

try
    timeStamp = datetime(timeStamp, 'ConvertFrom', 'datenum');
catch conversionError
    warning('Could not convert timestamps in %s: %s', sourceFile, conversionError.message);
    timeStamp = [];
end
end

function [sleepFlags, ggirTime] = getSleepData(ggirTable, ggirFile)
if ~ismember('SleepPeriodTime', ggirTable.Properties.VariableNames)
    error('GGIR table in %s does not contain SleepPeriodTime', ggirFile);
end

timeCandidates = {'timeStamp', 'timestamp'};
timeColumn = '';
for idx = 1:numel(timeCandidates)
    if ismember(timeCandidates{idx}, ggirTable.Properties.VariableNames)
        timeColumn = timeCandidates{idx};
        break;
    end
end

if isempty(timeColumn)
    error('GGIR table in %s does not contain a recognized timestamp column', ggirFile);
end

sleepFlags = ggirTable.SleepPeriodTime;
ggirTime = ggirTable.(timeColumn);

if ~isdatetime(ggirTime)
    try
        ggirTime = datetime(ggirTime, 'ConvertFrom', 'datenum');
    catch conversionError
        error('Could not convert GGIR timestamps in %s: %s', ggirFile, conversionError.message);
    end
end

sleepFlags = sleepFlags(:);
ggirTime = ggirTime(:);

validRows = ~isnat(ggirTime) & ~isnan(sleepFlags);
sleepFlags = double(sleepFlags(validRows));
ggirTime = ggirTime(validRows);
end

function nightBounds = findNightBounds(sleepFlags, ggirTime)
sleepMask = sleepFlags == 1;
startIdx = find(diff([false; sleepMask]) == 1);
endIdx = find(diff([sleepMask; false]) == -1);

if isempty(startIdx)
    nightBounds = NaT(0, 2);
    return;
end

if numel(ggirTime) > 1
    ggirStep = median(diff(ggirTime));
else
    ggirStep = seconds(0);
end

endExclusive = ggirTime(endIdx) + ggirStep;
hasNext = endIdx < numel(ggirTime);
endExclusive(hasNext) = ggirTime(endIdx(hasNext) + 1);

nightBounds = [ggirTime(startIdx), endExclusive];
end
