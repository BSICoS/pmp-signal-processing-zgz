clear;
close all force;
clc;

addpath(genpath('D:\OneDrive - unizar.es\UNIVERSIDAD\POSTDOCTORADO\biosigmat'));
addpath(genpath('C:\Users\user\OneDrive - unizar.es\UNIVERSIDAD\POSTDOCTORADO\biosigmat'));
addpath('lib');

datasetVersion = 'v2_1';
segmentSeconds = 60 * 60;
makePlots = true;

scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end

nightsDir = fullfile(scriptDir, 'data', datasetVersion, 'nights');
hrNightsDir = fullfile(scriptDir, 'data', datasetVersion, 'hr_nights');
analysisWindowMinutes = segmentSeconds / 60;
outputMat = fullfile(hrNightsDir, sprintf('debug_mhr_vs_device_hr_%s_%dmin.mat', ...
    datasetVersion, analysisWindowMinutes));
outputCsv = fullfile(hrNightsDir, sprintf('debug_mhr_vs_device_hr_%s_%dmin.csv', ...
    datasetVersion, analysisWindowMinutes));

if ~exist(nightsDir, 'dir')
    error('Nights directory not found: %s', nightsDir);
end

if ~exist(hrNightsDir, 'dir')
    error('HR nights directory not found: %s', hrNightsDir);
end

nightFiles = dir(fullfile(nightsDir, '*.mat'));
rows = repmat(emptyComparisonRow(), 0, 1);

fprintf('Comparing hrvtd MHR against device HR for %s (%d min windows)\n', ...
    datasetVersion, analysisWindowMinutes);

for fileIdx = 1:numel(nightFiles)
    nightFile = nightFiles(fileIdx);
    nightPath = fullfile(nightFile.folder, nightFile.name);
    hrPath = fullfile(hrNightsDir, nightFile.name);
    [subjectId, nightNumber] = parseNightMetadata(nightFile.name);

    if ~isfile(hrPath)
        fprintf('Skipping %s: no matching HR night file\n', nightFile.name);
        continue;
    end

    nightData = load(nightPath, 'evolution', 't', 'tk');
    hrData = load(hrPath, 'HR', 't');

    [twindow, mhr] = getMhrEvolution(nightData, segmentSeconds);
    if isempty(twindow)
        fprintf('Skipping %s: no evolution.mhr and could not recompute from tk\n', nightFile.name);
        continue;
    end

    deviceHr = hrData.HR(:);
    deviceT = hrData.t(:);

    for windowIdx = 1:numel(twindow)
        startTime = (windowIdx - 1) * segmentSeconds;
        endTime = windowIdx * segmentSeconds;
        sampleMask = deviceT >= startTime & deviceT < endTime;
        windowHr = deviceHr(sampleMask);
        validWindowHr = windowHr(~isnan(windowHr));

        row = emptyComparisonRow();
        row.datasetVersion = string(datasetVersion);
        row.fileName = string(nightFile.name);
        row.subjectId = string(subjectId);
        row.nightNumber = nightNumber;
        row.windowIdx = windowIdx;
        row.twindowHours = twindow(windowIdx) / 3600;
        row.mhrTk = mhr(windowIdx);
        row.deviceHrMean = meanOrNan(validWindowHr);
        row.deviceHrMedian = medianOrNan(validWindowHr);
        row.deviceHrStd = stdOrNan(validWindowHr);
        row.deviceHrSamples = numel(validWindowHr);
        row.deltaMean = row.mhrTk - row.deviceHrMean;
        row.deltaMedian = row.mhrTk - row.deviceHrMedian;
        rows(end + 1, 1) = row; %#ok<SAGROW>
    end
end

comparison = struct2table(rows);
validRows = ~isnan(comparison.mhrTk) & ~isnan(comparison.deviceHrMean);

fprintf('\nValid windows: %d/%d\n', nnz(validRows), height(comparison));
if any(validRows)
    mhrTk = comparison.mhrTk(validRows);
    deviceHrMean = comparison.deviceHrMean(validRows);
    deltaMean = comparison.deltaMean(validRows);

    fprintf('Bias MHR - device HR mean: %.2f bpm\n', mean(deltaMean, 'omitnan'));
    fprintf('Median delta: %.2f bpm\n', median(deltaMean, 'omitnan'));
    fprintf('MAE: %.2f bpm\n', mean(abs(deltaMean), 'omitnan'));
    fprintf('Delta std: %.2f bpm\n', std(deltaMean, 'omitnan'));
    fprintf('Correlation: %.3f\n', corr(mhrTk, deviceHrMean, 'rows', 'complete'));
else
    warning('No valid windows available for comparison.');
end

save(outputMat, 'comparison', 'datasetVersion', 'segmentSeconds', 'analysisWindowMinutes');
writetable(comparison, outputCsv);
fprintf('\nSaved comparison table to:\n  %s\n  %s\n', outputMat, outputCsv);

if makePlots && any(validRows)
    scatterFile = fullfile(hrNightsDir, sprintf('debug_mhr_vs_device_hr_scatter_%s_%dmin.png', ...
        datasetVersion, analysisWindowMinutes));
    deltaFile = fullfile(hrNightsDir, sprintf('debug_mhr_vs_device_hr_delta_%s_%dmin.png', ...
        datasetVersion, analysisWindowMinutes));

    fig = figure('Color', 'w', 'Name', 'MHR vs device HR');
    scatter(deviceHrMean, mhrTk, 18, 'filled', 'MarkerFaceAlpha', 0.45);
    hold on;
    limits = [min([deviceHrMean; mhrTk]), max([deviceHrMean; mhrTk])];
    plot(limits, limits, 'k--', 'LineWidth', 1);
    grid on;
    axis equal;
    xlim(limits);
    ylim(limits);
    xlabel('Device HR mean per window (bpm)');
    ylabel('MHR from tk / hrvtd (bpm)');
    title(sprintf('%s: MHR vs device HR (%d min)', upper(datasetVersion), analysisWindowMinutes));
    exportgraphics(fig, scatterFile, 'Resolution', 150);

    fig = figure('Color', 'w', 'Name', 'MHR minus device HR');
    histogram(deltaMean, 30);
    grid on;
    xlabel('MHR - device HR mean (bpm)');
    ylabel('Windows');
    title(sprintf('%s: window-level delta (%d min)', upper(datasetVersion), analysisWindowMinutes));
    exportgraphics(fig, deltaFile, 'Resolution', 150);

    fprintf('Saved debug figures to:\n  %s\n  %s\n', scatterFile, deltaFile);
end

function row = emptyComparisonRow()
row = struct( ...
    'datasetVersion', "", ...
    'fileName', "", ...
    'subjectId', "", ...
    'nightNumber', NaN, ...
    'windowIdx', NaN, ...
    'twindowHours', NaN, ...
    'mhrTk', NaN, ...
    'deviceHrMean', NaN, ...
    'deviceHrMedian', NaN, ...
    'deviceHrStd', NaN, ...
    'deviceHrSamples', NaN, ...
    'deltaMean', NaN, ...
    'deltaMedian', NaN ...
);
end

function [twindow, mhr] = getMhrEvolution(nightData, segmentSeconds)
if isfield(nightData, 'evolution') && isstruct(nightData.evolution) && ...
        isfield(nightData.evolution, 'twindow') && isfield(nightData.evolution, 'mhr') && ...
        numel(nightData.evolution.twindow) == numel(nightData.evolution.mhr)
    twindow = nightData.evolution.twindow(:);
    mhr = nightData.evolution.mhr(:);
    return;
end

if ~isfield(nightData, 't') || ~isfield(nightData, 'tk')
    twindow = [];
    mhr = [];
    return;
end

t = nightData.t(:);
tk = nightData.tk(:);
tk = tk(~isnan(tk));
numWindows = floor(t(end) / segmentSeconds);
if numWindows == 0
    twindow = [];
    mhr = [];
    return;
end

twindow = nan(numWindows, 1);
tdm = cell(numWindows, 1);
for windowIdx = 1:numWindows
    startTime = (windowIdx - 1) * segmentSeconds;
    endTime = windowIdx * segmentSeconds;
    twindow(windowIdx) = (startTime + endTime) / 2;
    segmentTk = tk(tk >= startTime & tk < endTime);

    if numel(segmentTk) > 1
        dtk = diff(segmentTk);
        threshold = medfiltThreshold(dtk, 50, 1.5, 1.5);
        dtk = dtk(dtk <= threshold);

        if numel(dtk) > 1
            tdm{windowIdx} = tdmetrics(dtk);
        else
            tdm{windowIdx} = struct('mhr', NaN);
        end
    else
        tdm{windowIdx} = struct('mhr', NaN);
    end
end

mhr = cellfun(@(x) x.mhr, tdm);
mhr(mhr < 40 | mhr > 180) = NaN;
end

function [subjectId, nightNumber] = parseNightMetadata(fileName)
subjectTokens = regexp(fileName, '^(PMP\d+)', 'tokens', 'once');
nightTokens = regexp(fileName, 'night(\d+)', 'tokens', 'once');

if isempty(subjectTokens)
    subjectId = erase(fileName, '.mat');
else
    subjectId = subjectTokens{1};
end

if isempty(nightTokens)
    nightNumber = NaN;
else
    nightNumber = str2double(nightTokens{1});
end
end

function value = meanOrNan(values)
if isempty(values)
    value = NaN;
else
    value = mean(values, 'omitnan');
end
end

function value = medianOrNan(values)
if isempty(values)
    value = NaN;
else
    value = median(values, 'omitnan');
end
end

function value = stdOrNan(values)
if isempty(values)
    value = NaN;
else
    value = std(values, 'omitnan');
end
end
