if ~exist('datasetVersion', 'var') || isempty(datasetVersion)
    datasetVersion = 'v1';
end
if ~exist('analysisWindowMinutes', 'var') || isempty(analysisWindowMinutes)
    analysisWindowMinutes = 60;
end

resultsDir = fullfile('data', datasetVersion, 'hrvtd');
resultsFile = fullfile(resultsDir, sprintf('hrvtd_results_%s_%dmin.mat', datasetVersion, analysisWindowMinutes));
plotsDir = fullfile(resultsDir, sprintf('subject_plots_%dmin', analysisWindowMinutes));

nightSummaryVarName = sprintf('nightSummary_%dmin', analysisWindowMinutes);
nightEvolutionVarName = sprintf('nightEvolution_%dmin', analysisWindowMinutes);
subjectSummaryVarName = sprintf('subjectSummary_%dmin', analysisWindowMinutes);
subjectPlotFilesVarName = sprintf('subjectPlotFiles_%dmin', analysisWindowMinutes);

if ~exist(resultsFile, 'file')
    error('Results file not found: %s. Run hrvtd.m first.', resultsFile);
end

if ~exist(plotsDir, 'dir')
    mkdir(plotsDir);
end

loadedResults = load(resultsFile, nightSummaryVarName, nightEvolutionVarName);
nightSummary = loadedResults.(nightSummaryVarName);
nightEvolution = loadedResults.(nightEvolutionVarName);

subjectIds = unique(nightSummary.subjectId, 'stable');
subjectSummaryRows = repmat(emptySubjectSummaryEntry(), 0, 1);
subjectPlotFiles = repmat(struct('subjectId', '', 'plotPath', ''), 0, 1);

for subjectIdx = 1:numel(subjectIds)
    subjectId = subjectIds{subjectIdx};
    summaryMask = strcmp(nightSummary.subjectId, subjectId);
    evolutionMask = strcmp({nightEvolution.subjectId}, subjectId);

    subjectNightSummary = sortrows(nightSummary(summaryMask, :), 'nightNumber');
    subjectEvolution = nightEvolution(evolutionMask);
    [~, sortIdx] = sort([subjectEvolution.nightNumber]);
    subjectEvolution = subjectEvolution(sortIdx);

    plotFile = fullfile(plotsDir, sprintf('%s_evolution_%dmin.fig', subjectId, analysisWindowMinutes));
    plotSubjectEvolution(subjectId, subjectEvolution, plotFile);

    subjectPlotFiles(end + 1, 1) = struct( ...
        'subjectId', subjectId, ...
        'plotPath', plotFile ...
    );

    subjectSummaryRows(end + 1, 1) = buildSubjectSummary(subjectId, subjectNightSummary, subjectEvolution, analysisWindowMinutes);
end

subjectSummary = struct2table(subjectSummaryRows);

saveData = struct();
saveData.(subjectSummaryVarName) = subjectSummary;
saveData.(subjectPlotFilesVarName) = subjectPlotFiles;
save(resultsFile, '-struct', 'saveData', '-append');

fprintf('Saved subject summary to %s (%s)\n', resultsFile, subjectSummaryVarName);
fprintf('Saved subject plots to %s\n', plotsDir);

function entry = emptySubjectSummaryEntry()
entry = struct( ...
    'subjectId', '', ...
    'numNights', NaN, ...
    'nightNumbers', '', ...
    'validWindows', NaN, ...
    'meanNightDurationHours', NaN, ...
    'mhrMean', NaN, ...
    'mhrMedian', NaN, ...
    'mhrMin', NaN, ...
    'mhrMax', NaN, ...
    'mhrStd', NaN, ...
    'sdnnMean', NaN, ...
    'sdnnMedian', NaN, ...
    'sdnnMin', NaN, ...
    'sdnnMax', NaN, ...
    'sdnnStd', NaN, ...
    'rmssdMean', NaN, ...
    'rmssdMedian', NaN, ...
    'rmssdMin', NaN, ...
    'rmssdMax', NaN, ...
    'rmssdStd', NaN ...
);
end

function plotSubjectEvolution(subjectId, subjectEvolution, plotFile)
metrics = {'mhr', 'sdnn', 'rmssd'};
labels = {'MHR (bpm)', 'SDNN (ms)', 'RMSSD (ms)'};

fig = figure('Visible', 'off');

for metricIdx = 1:numel(metrics)
    subplot(numel(metrics), 1, metricIdx);
    hold on;
    for nightIdx = 1:numel(subjectEvolution)
        nightData = subjectEvolution(nightIdx);
        if isnan(nightData.nightNumber)
            nightLabel = erase(nightData.fileName, '.mat');
        else
            nightLabel = sprintf('night%d', nightData.nightNumber);
        end
        plot(nightData.twindow ./ 3600, nightData.(metrics{metricIdx}), 'DisplayName', nightLabel);
    end
    ylabel(labels{metricIdx});
    grid on;
    if metricIdx == 1 && ~isempty(subjectEvolution)
        legend('Location', 'best');
    end
end

xlabel('Time from sleep onset (h)');
sgtitle(sprintf('%s: nightly evolution', subjectId));
saveas(fig, plotFile);
close(fig);
end

function entry = buildSubjectSummary(subjectId, subjectNightSummary, subjectEvolution, analysisWindowMinutes)
mhrValues = collectMetricValues(subjectEvolution, 'mhr');
sdnnValues = collectMetricValues(subjectEvolution, 'sdnn');
rmssdValues = collectMetricValues(subjectEvolution, 'rmssd');

mhrStats = calcMetricStats(mhrValues);
sdnnStats = calcMetricStats(sdnnValues);
rmssdStats = calcMetricStats(rmssdValues);
nightDurationsHours = arrayfun(@(nightData) numel(nightData.twindow) * analysisWindowMinutes / 60, subjectEvolution);
nightNumbers = [subjectEvolution.nightNumber];
nightNumbers = nightNumbers(~isnan(nightNumbers));

entry = struct( ...
    'subjectId', subjectId, ...
    'numNights', numel(subjectEvolution), ...
    'nightNumbers', strjoin(compose('%d', nightNumbers), ','), ...
    'validWindows', sum(subjectNightSummary.validWindows), ...
    'meanNightDurationHours', mean(nightDurationsHours), ...
    'mhrMean', mhrStats.mean, ...
    'mhrMedian', mhrStats.median, ...
    'mhrMin', mhrStats.min, ...
    'mhrMax', mhrStats.max, ...
    'mhrStd', mhrStats.std, ...
    'sdnnMean', sdnnStats.mean, ...
    'sdnnMedian', sdnnStats.median, ...
    'sdnnMin', sdnnStats.min, ...
    'sdnnMax', sdnnStats.max, ...
    'sdnnStd', sdnnStats.std, ...
    'rmssdMean', rmssdStats.mean, ...
    'rmssdMedian', rmssdStats.median, ...
    'rmssdMin', rmssdStats.min, ...
    'rmssdMax', rmssdStats.max, ...
    'rmssdStd', rmssdStats.std ...
);
end

function values = collectMetricValues(subjectEvolution, metricName)
values = [];
for nightIdx = 1:numel(subjectEvolution)
    values = [values; subjectEvolution(nightIdx).(metricName)(:)]; %#ok<AGROW>
end
end

function stats = calcMetricStats(values)
validValues = values(~isnan(values));

if isempty(validValues)
    stats = struct('mean', NaN, 'median', NaN, 'min', NaN, 'max', NaN, 'std', NaN);
    return;
end

stats = struct( ...
    'mean', mean(validValues), ...
    'median', median(validValues), ...
    'min', min(validValues), ...
    'max', max(validValues), ...
    'std', std(validValues) ...
);
end