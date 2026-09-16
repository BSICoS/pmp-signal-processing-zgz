% hrvtd.m - HRV time-domain por ventana, a partir de los fiducial points
% guardados por extract_HR_main.m en cada night file.
%
% Variables de workspace de entrada (opcionales, con default):
%   datasetVersion - 'v1' | 'v2_1' | 'v2_2'         (default 'v1')
%   segmentSeconds - tamano de ventana en segundos  (default 10)
%   fiducial       - 'nD' | 'nZ' | 'nB'             (default 'nZ').
%                    Lee <fiducial>_all del night file como serie de tk.
%
% Salida:
%   data/<v>/hrvtd/hrvtd_results_<v>_<fid>_<W>min.mat con:
%     analysisWindowMinutes, datasetVersion, fiducial,
%     nightSummary_<W>min, nightEvolution_<W>min.
%
% NB: este script NO hace clearvars: cuando se invoca desde run_hrvtd_sweep
%     u otro wrapper, las variables de iteracion del caller deben sobrevivir.

repoRoot = fileparts(fileparts(mfilename('fullpath'))); addpath(repoRoot);
p = paths();
addpath(genpath(p.biosigmat));
addpath('lib');

if ~exist('datasetVersion', 'var') || isempty(datasetVersion)
    datasetVersion = 'v1';
end
if ~exist('segmentSeconds', 'var') || isempty(segmentSeconds)
    segmentSeconds = 10;
end
if ~exist('fiducial', 'var') || isempty(fiducial)
    fiducial = 'nZ';
end

fiducialVar = sprintf('%s_all', fiducial);

nightsDir = fullfile('data', datasetVersion, 'nights');
resultsDir = fullfile('data', datasetVersion, 'hrvtd');
if ~exist(resultsDir, 'dir'); mkdir(resultsDir); end

analysisWindowMinutes = segmentSeconds / 60;
resultsFile = fullfile(resultsDir, sprintf('hrvtd_results_%s_%s_%dmin.mat', ...
    datasetVersion, fiducial, analysisWindowMinutes));
summaryVarName = sprintf('nightSummary_%dmin', analysisWindowMinutes);
evolutionVarName = sprintf('nightEvolution_%dmin', analysisWindowMinutes);

inputFiles = dir(fullfile(nightsDir, '*.mat'));
fprintf('hrvtd: %s | fiducial=%s | window=%d min | %d night files\n', ...
    datasetVersion, fiducial, analysisWindowMinutes, numel(inputFiles));

nightSummaryRows = repmat(emptyNightSummaryEntry(), 0, 1);
nightEvolution   = repmat(emptyEvolutionEntry(), 0, 1);

for fileIdx = 1:numel(inputFiles)
    inputPath = fullfile(inputFiles(fileIdx).folder, inputFiles(fileIdx).name);
    loadedData = load(inputPath);

    if ~isfield(loadedData, fiducialVar) || ~isfield(loadedData, 't')
        fprintf('  %s: missing %s or t. Skipping.\n', inputFiles(fileIdx).name, fiducialVar);
        continue;
    end

    t  = loadedData.t(:);
    tk = loadedData.(fiducialVar)(:);
    tk = tk(~isnan(tk));
    [subjectId, nightNumber] = parseNightMetadata(inputFiles(fileIdx).name);

    numWindows = floor(t(end) / segmentSeconds);
    twindow = nan(numWindows, 1);
    segments = cell(numWindows, 1);
    for windowIdx = 1:numWindows
        startTime = (windowIdx - 1) * segmentSeconds;
        endTime   = windowIdx * segmentSeconds;
        twindow(windowIdx) = (startTime + endTime) / 2;
        segments{windowIdx} = tk(tk >= startTime & tk < endTime);
    end

    tdm = cell(numWindows, 1);
    for windowIdx = 1:numWindows
        if length(segments{windowIdx}) > 1
            dtk = diff(segments{windowIdx});
            threshold = medfiltThreshold(dtk, 50, 1.5, 1.5);
            dtk = dtk(dtk <= threshold);
            if length(dtk) > 1
                tdm{windowIdx} = tdmetrics(dtk);
            else
                tdm{windowIdx} = struct('mhr', NaN, 'sdnn', NaN, 'rmssd', NaN);
            end
        else
            tdm{windowIdx} = struct('mhr', NaN, 'sdnn', NaN, 'rmssd', NaN);
        end
    end

    mhr   = cellfun(@(x) x.mhr,   tdm);
    sdnn  = cellfun(@(x) x.sdnn,  tdm);
    rmssd = cellfun(@(x) x.rmssd, tdm);

    mhr(mhr < 40 | mhr > 180)     = NaN;
    sdnn(sdnn < 5 | sdnn > 140)   = NaN;
    rmssd(rmssd < 5 | rmssd > 140) = NaN;

    mhrStats   = calcMetricStats(mhr);
    sdnnStats  = calcMetricStats(sdnn);
    rmssdStats = calcMetricStats(rmssd);

    evolution = struct( ...
        'fileName', inputFiles(fileIdx).name, ...
        'subjectId', subjectId, ...
        'nightNumber', nightNumber, ...
        'twindow', twindow, ...
        'mhr', mhr, ...
        'sdnn', sdnn, ...
        'rmssd', rmssd ...
    );

    summary = struct( ...
        'fileName', inputFiles(fileIdx).name, ...
        'subjectId', subjectId, ...
        'nightNumber', nightNumber, ...
        'validWindows', sum(~isnan(mhr) | ~isnan(sdnn) | ~isnan(rmssd)), ...
        'mhrMean', mhrStats.mean, 'mhrMedian', mhrStats.median, ...
        'mhrMin', mhrStats.min, 'mhrMax', mhrStats.max, 'mhrStd', mhrStats.std, ...
        'sdnnMean', sdnnStats.mean, 'sdnnMedian', sdnnStats.median, ...
        'sdnnMin', sdnnStats.min, 'sdnnMax', sdnnStats.max, 'sdnnStd', sdnnStats.std, ...
        'rmssdMean', rmssdStats.mean, 'rmssdMedian', rmssdStats.median, ...
        'rmssdMin', rmssdStats.min, 'rmssdMax', rmssdStats.max, 'rmssdStd', rmssdStats.std ...
    );

    nightSummaryRows(end + 1, 1) = summary;       %#ok<SAGROW>
    nightEvolution(end + 1, 1)   = evolution;     %#ok<SAGROW>
end

nightSummary = struct2table(nightSummaryRows);

resultsToSave = struct();
resultsToSave.analysisWindowMinutes = analysisWindowMinutes;
resultsToSave.datasetVersion = datasetVersion;
resultsToSave.fiducial = fiducial;
resultsToSave.(summaryVarName) = nightSummary;
resultsToSave.(evolutionVarName) = nightEvolution;

save(resultsFile, '-struct', 'resultsToSave');
fprintf('Saved %s (%d nights)\n', resultsFile, numel(nightEvolution));


function entry = emptyNightSummaryEntry()
entry = struct( ...
    'fileName', '', 'subjectId', '', 'nightNumber', NaN, 'validWindows', NaN, ...
    'mhrMean', NaN, 'mhrMedian', NaN, 'mhrMin', NaN, 'mhrMax', NaN, 'mhrStd', NaN, ...
    'sdnnMean', NaN, 'sdnnMedian', NaN, 'sdnnMin', NaN, 'sdnnMax', NaN, 'sdnnStd', NaN, ...
    'rmssdMean', NaN, 'rmssdMedian', NaN, 'rmssdMin', NaN, 'rmssdMax', NaN, 'rmssdStd', NaN);
end

function entry = emptyEvolutionEntry()
entry = struct( ...
    'fileName', '', 'subjectId', '', 'nightNumber', NaN, ...
    'twindow', [], 'mhr', [], 'sdnn', [], 'rmssd', []);
end

function [subjectId, nightNumber] = parseNightMetadata(fileName)
subjectTokens = regexp(fileName, '^(PMP\d+)', 'tokens', 'once');
nightTokens   = regexp(fileName, 'night(\d+)', 'tokens', 'once');
if isempty(subjectTokens); subjectId = erase(fileName, '.mat'); else; subjectId = subjectTokens{1}; end
if isempty(nightTokens); nightNumber = NaN; else; nightNumber = str2double(nightTokens{1}); end
end

function stats = calcMetricStats(values)
validValues = values(~isnan(values));
if isempty(validValues)
    stats = struct('mean', NaN, 'median', NaN, 'min', NaN, 'max', NaN, 'std', NaN); return;
end
stats = struct('mean', mean(validValues), 'median', median(validValues), ...
    'min', min(validValues), 'max', max(validValues), 'std', std(validValues));
end
