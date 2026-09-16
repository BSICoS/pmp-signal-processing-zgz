if ~exist('datasetVersion', 'var') || isempty(datasetVersion)
    datasetVersion = 'v1';
end
analysisWindows = [5 10 30 60];
referenceWindowMinutes = 30;

resultsDir = fullfile('data', datasetVersion, 'hrvtd');
reportDir = fullfile(resultsDir, 'mhr_report');
subjectPlotsDir = fullfile(reportDir, 'subject_plots');
windowFiguresDir = fullfile(reportDir, 'window_figures');
summaryFigureFile = fullfile(reportDir, sprintf('mhr_summary_%s.png', datasetVersion));
betweenSubjectFigureFile = fullfile(reportDir, sprintf('mhr_between_subjects_%s.png', datasetVersion));
betweenNightFigureFile = fullfile(reportDir, sprintf('mhr_between_nights_%s.png', datasetVersion));
reportFile = fullfile(reportDir, sprintf('mhr_report_%s.md', datasetVersion));

if ~exist(reportDir, 'dir'); mkdir(reportDir); end
if ~exist(subjectPlotsDir, 'dir'); mkdir(subjectPlotsDir); end
if ~exist(windowFiguresDir, 'dir'); mkdir(windowFiguresDir); end

windowData = repmat(emptyWindowDataEntry(), numel(analysisWindows), 1);

for windowIdx = 1:numel(analysisWindows)
    analysisWindowMinutes = analysisWindows(windowIdx);
    resultsFile = fullfile(resultsDir, sprintf('hrvtd_results_%s_%dmin.mat', datasetVersion, analysisWindowMinutes));
    nightSummaryVarName = sprintf('nightSummary_%dmin', analysisWindowMinutes);
    nightEvolutionVarName = sprintf('nightEvolution_%dmin', analysisWindowMinutes);

    if ~exist(resultsFile, 'file')
        error('Results file not found: %s. Run hrvtd.m for the %d-min window first.', resultsFile, analysisWindowMinutes);
    end

    loadedResults = load(resultsFile, nightSummaryVarName, nightEvolutionVarName);
    nightSummary = loadedResults.(nightSummaryVarName);
    nightEvolution = loadedResults.(nightEvolutionVarName);

    allValues = collectAllMhrValues(nightEvolution);
    globalStats = mhrStats(allValues);

    nightDeltas = nan(numel(nightEvolution), 1);
    nightRanges = nan(numel(nightEvolution), 1);
    nightMeans = nan(numel(nightEvolution), 1);
    nightMedians = nan(numel(nightEvolution), 1);
    nightFirsts = nan(numel(nightEvolution), 1);
    nightLasts = nan(numel(nightEvolution), 1);

    for nightIdx = 1:numel(nightEvolution)
        mhrNight = nightEvolution(nightIdx).mhr(:);
        validMhr = mhrNight(~isnan(mhrNight));
        if numel(validMhr) >= 2
            nightDeltas(nightIdx) = validMhr(end) - validMhr(1);
            nightRanges(nightIdx) = max(validMhr) - min(validMhr);
            nightMeans(nightIdx) = mean(validMhr);
            nightMedians(nightIdx) = median(validMhr);
            nightFirsts(nightIdx) = validMhr(1);
            nightLasts(nightIdx) = validMhr(end);
        elseif isscalar(validMhr)
            nightMeans(nightIdx) = validMhr;
            nightMedians(nightIdx) = validMhr;
        end
    end

    decreasingPct = 100 * mean(nightDeltas(~isnan(nightDeltas)) < 0);

    subjectIds = unique(nightSummary.subjectId, 'stable');
    subjectStats = repmat(emptySubjectStatsEntry(), numel(subjectIds), 1);
    for subjectIdx = 1:numel(subjectIds)
        subjectId = subjectIds{subjectIdx};
        evolutionMask = strcmp({nightEvolution.subjectId}, subjectId);
        subjectEvolution = nightEvolution(evolutionMask);

        subjectMhrAll = collectAllMhrValues(subjectEvolution);
        subjectStat = mhrStats(subjectMhrAll);

        nightlyMeans = nan(numel(subjectEvolution), 1);
        nightlyDeltas = nan(numel(subjectEvolution), 1);
        nightlyRanges = nan(numel(subjectEvolution), 1);
        for ni = 1:numel(subjectEvolution)
            v = subjectEvolution(ni).mhr(:);
            v = v(~isnan(v));
            if numel(v) >= 2
                nightlyMeans(ni) = mean(v);
                nightlyDeltas(ni) = v(end) - v(1);
                nightlyRanges(ni) = max(v) - min(v);
            elseif isscalar(v)
                nightlyMeans(ni) = v;
            end
        end
        validNightlyMeans = nightlyMeans(~isnan(nightlyMeans));

        subjectStats(subjectIdx) = struct( ...
            'subjectId', subjectId, ...
            'numNights', numel(subjectEvolution), ...
            'numValidNights', numel(validNightlyMeans), ...
            'n', subjectStat.n, ...
            'min', subjectStat.min, ...
            'p10', subjectStat.p10, ...
            'p25', subjectStat.p25, ...
            'mean', subjectStat.mean, ...
            'median', subjectStat.median, ...
            'p75', subjectStat.p75, ...
            'p90', subjectStat.p90, ...
            'max', subjectStat.max, ...
            'std', subjectStat.std, ...
            'betweenNightStd', stdSafe(validNightlyMeans), ...
            'betweenNightRange', rangeSafe(validNightlyMeans), ...
            'meanNightDelta', meanSafe(nightlyDeltas), ...
            'meanNightRange', meanSafe(nightlyRanges) ...
        );
    end

    populationTrajectory = buildPopulationTrajectory(analysisWindowMinutes, nightEvolution);

    windowData(windowIdx).windowMinutes = analysisWindowMinutes;
    windowData(windowIdx).nightSummary = nightSummary;
    windowData(windowIdx).nightEvolution = nightEvolution;
    windowData(windowIdx).subjectStats = subjectStats;
    windowData(windowIdx).globalStats = globalStats;
    windowData(windowIdx).nightDeltas = nightDeltas;
    windowData(windowIdx).nightRanges = nightRanges;
    windowData(windowIdx).nightMeans = nightMeans;
    windowData(windowIdx).nightMedians = nightMedians;
    windowData(windowIdx).nightFirsts = nightFirsts;
    windowData(windowIdx).nightLasts = nightLasts;
    windowData(windowIdx).decreasingPct = decreasingPct;
    windowData(windowIdx).populationTrajectory = populationTrajectory;
end

createSummaryFigure(windowData, summaryFigureFile);

commonMaxTimeHours = 0;
for w = 1:numel(windowData)
    commonMaxTimeHours = max(commonMaxTimeHours, max(windowData(w).populationTrajectory.timeHours, [], 'omitnan'));
end

temporalBoxplotFiles = cell(numel(analysisWindows), 1);
for w = 1:numel(analysisWindows)
    plotFile = fullfile(windowFiguresDir, sprintf('mhr_temporal_box_%dmin.png', analysisWindows(w)));
    createTemporalBoxplot(windowData(w).windowMinutes, windowData(w).nightEvolution, plotFile, commonMaxTimeHours);
    temporalBoxplotFiles{w} = plotFile;
end

createBetweenSubjectFigure(windowData, betweenSubjectFigureFile);
createBetweenNightFigure(windowData, betweenNightFigureFile);

subjectIds = unique(windowData(1).nightSummary.subjectId, 'stable');
subjectPlotFiles = repmat(struct('subjectId', '', 'plotPath', ''), 0, 1);
for subjectIdx = 1:numel(subjectIds)
    subjectId = subjectIds{subjectIdx};
    plotFile = fullfile(subjectPlotsDir, sprintf('%s_mhr_windows_%s.png', subjectId, datasetVersion));
    plotSubjectAcrossWindows(subjectId, windowData, plotFile);
    subjectPlotFiles(end + 1, 1) = struct('subjectId', subjectId, 'plotPath', plotFile); %#ok<SAGROW>
end

writeMarkdownReport(reportFile, datasetVersion, windowData, referenceWindowMinutes, ...
    summaryFigureFile, betweenSubjectFigureFile, betweenNightFigureFile, ...
    temporalBoxplotFiles, subjectPlotFiles);

fprintf('Saved MHR summary figure to %s\n', summaryFigureFile);
fprintf('Saved between-subjects figure to %s\n', betweenSubjectFigureFile);
fprintf('Saved between-nights figure to %s\n', betweenNightFigureFile);
fprintf('Saved temporal boxplots to %s\n', windowFiguresDir);
fprintf('Saved subject plots to %s\n', subjectPlotsDir);
fprintf('Saved MHR report to %s\n', reportFile);


function entry = emptyWindowDataEntry()
entry = struct( ...
    'windowMinutes', NaN, ...
    'nightSummary', table(), ...
    'nightEvolution', repmat(emptyNightEvolutionEntry(), 0, 1), ...
    'subjectStats', repmat(emptySubjectStatsEntry(), 0, 1), ...
    'globalStats', emptyMhrStats(), ...
    'nightDeltas', [], ...
    'nightRanges', [], ...
    'nightMeans', [], ...
    'nightMedians', [], ...
    'nightFirsts', [], ...
    'nightLasts', [], ...
    'decreasingPct', NaN, ...
    'populationTrajectory', emptyPopulationTrajectoryEntry() ...
);
end

function entry = emptyNightEvolutionEntry()
entry = struct( ...
    'fileName', '', ...
    'subjectId', '', ...
    'nightNumber', NaN, ...
    'twindow', [], ...
    'mhr', [] ...
);
end

function entry = emptySubjectStatsEntry()
entry = struct( ...
    'subjectId', '', ...
    'numNights', NaN, ...
    'numValidNights', NaN, ...
    'n', NaN, ...
    'min', NaN, 'p10', NaN, 'p25', NaN, ...
    'mean', NaN, 'median', NaN, ...
    'p75', NaN, 'p90', NaN, 'max', NaN, ...
    'std', NaN, ...
    'betweenNightStd', NaN, ...
    'betweenNightRange', NaN, ...
    'meanNightDelta', NaN, ...
    'meanNightRange', NaN ...
);
end

function entry = emptyPopulationTrajectoryEntry()
entry = struct('windowMinutes', NaN, 'timeHours', [], 'meanMhr', [], 'medianMhr', [], 'validNightCount', []);
end

function s = emptyMhrStats()
s = struct('n', 0, 'min', NaN, 'p10', NaN, 'p25', NaN, 'mean', NaN, 'median', NaN, 'p75', NaN, 'p90', NaN, 'max', NaN, 'std', NaN);
end

function values = collectAllMhrValues(nightEvolution)
values = [];
for nightIdx = 1:numel(nightEvolution)
    v = nightEvolution(nightIdx).mhr(:);
    values = [values; v(~isnan(v))]; %#ok<AGROW>
end
end

function s = mhrStats(values)
v = values(~isnan(values));
if isempty(v)
    s = emptyMhrStats();
    return;
end
s = struct( ...
    'n', numel(v), ...
    'min', min(v), ...
    'p10', percentile(v, 10), ...
    'p25', percentile(v, 25), ...
    'mean', mean(v), ...
    'median', median(v), ...
    'p75', percentile(v, 75), ...
    'p90', percentile(v, 90), ...
    'max', max(v), ...
    'std', std(v) ...
);
end

function p = percentile(values, q)
v = sort(values(~isnan(values)));
if isempty(v)
    p = NaN;
elseif isscalar(v)
    p = v;
else
    rank = (q/100) * (numel(v) - 1) + 1;
    lo = floor(rank); hi = ceil(rank);
    if lo == hi
        p = v(lo);
    else
        p = v(lo) + (rank - lo) * (v(hi) - v(lo));
    end
end
end

function s = stdSafe(values)
v = values(~isnan(values));
if numel(v) < 2; s = NaN; else; s = std(v); end
end

function r = rangeSafe(values)
v = values(~isnan(values));
if numel(v) < 2; r = NaN; else; r = max(v) - min(v); end
end

function m = meanSafe(values)
v = values(~isnan(values));
if isempty(v); m = NaN; else; m = mean(v); end
end

function populationTrajectory = buildPopulationTrajectory(windowMinutes, nightEvolution)
allTimes = [];
for nightIdx = 1:numel(nightEvolution)
    allTimes = [allTimes; nightEvolution(nightIdx).twindow(:)]; %#ok<AGROW>
end
timeSeconds = unique(allTimes);

meanMhr = nan(numel(timeSeconds), 1);
medianMhr = nan(numel(timeSeconds), 1);
stdMhr = nan(numel(timeSeconds), 1);
validNightCount = zeros(numel(timeSeconds), 1);

for timeIdx = 1:numel(timeSeconds)
    samples = nan(numel(nightEvolution), 1);
    for nightIdx = 1:numel(nightEvolution)
        nightTime = nightEvolution(nightIdx).twindow(:);
        nightMhr = nightEvolution(nightIdx).mhr(:);
        matchIdx = find(nightTime == timeSeconds(timeIdx), 1);
        if ~isempty(matchIdx)
            samples(nightIdx) = nightMhr(matchIdx);
        end
    end
    validMask = ~isnan(samples);
    validNightCount(timeIdx) = sum(validMask);
    if any(validMask)
        meanMhr(timeIdx) = mean(samples(validMask));
        medianMhr(timeIdx) = median(samples(validMask));
    end
    if sum(validMask) >= 2
        stdMhr(timeIdx) = std(samples(validMask));
    end
end

populationTrajectory = struct( ...
    'windowMinutes', windowMinutes, ...
    'timeHours', timeSeconds ./ 3600, ...
    'meanMhr', meanMhr, ...
    'medianMhr', medianMhr, ...
    'stdMhr', stdMhr, ...
    'validNightCount', validNightCount ...
);
end


function createSummaryFigure(windowData, summaryFigureFile)
fig = figure('Visible', 'off', 'Position', [100 100 1200 800]);
colors = lines(numel(windowData));

nNights = height(windowData(1).nightSummary);
nSubjects = numel(unique(windowData(1).nightSummary.subjectId));

ax1 = subplot(2, 2, 1);
hold(ax1, 'on');
for w = 1:numel(windowData)
    pt = windowData(w).populationTrajectory;
    drawMeanStdBand(ax1, pt.timeHours, pt.meanMhr, pt.stdMhr, colors(w, :), ...
        sprintf('%d min', windowData(w).windowMinutes), 0.10);
end
title(ax1, sprintf('Population mean nocturnal MHR (mean +/- std, N=%d nights, %d subjects)', nNights, nSubjects));
xlabel(ax1, 'Time from sleep onset (h)');
ylabel(ax1, 'MHR (bpm)');
grid(ax1, 'on');
legend(ax1, 'Location', 'best');

ax2 = subplot(2, 2, 2);
[nightMeanValues, nightMeanGroups] = collectGroupedArrays(windowData, 'nightMeans');
boxplot(ax2, nightMeanValues, nightMeanGroups);
thickenBoxplotMedians(ax2);
title(ax2, sprintf('Night mean MHR by window (N=%d nights)', nNights));
xlabel(ax2, 'Window (min)');
ylabel(ax2, 'MHR (bpm)');
ylim(ax2, [40 140]);
grid(ax2, 'on');

ax3 = subplot(2, 2, 3);
[deltaValues, deltaGroups] = collectGroupedArrays(windowData, 'nightDeltas');
boxplot(ax3, deltaValues, deltaGroups);
thickenBoxplotMedians(ax3);
yline(ax3, 0, '--k');
title(ax3, 'Last minus first valid MHR');
xlabel(ax3, 'Window (min)');
ylabel(ax3, 'Delta MHR (bpm)');
ylim(ax3, [-130 130]);
grid(ax3, 'on');

ax4 = subplot(2, 2, 4);
[rangeValues, rangeGroups] = collectGroupedArrays(windowData, 'nightRanges');
boxplot(ax4, rangeValues, rangeGroups);
thickenBoxplotMedians(ax4);
title(ax4, 'Within-night MHR range');
xlabel(ax4, 'Window (min)');
ylabel(ax4, 'Range (bpm)');
ylim(ax4, [0 130]);
grid(ax4, 'on');

ylim(ax1, [40 140]);
sgtitle('MHR overview across analysis windows');
saveas(fig, summaryFigureFile);
close(fig);
end

function drawMeanStdBand(ax, t, meanVals, stdVals, color, label, alpha)
if nargin < 7; alpha = 0.15; end

bothValid = ~isnan(meanVals) & ~isnan(stdVals);
if any(bothValid)
    d = diff([0; bothValid(:); 0]);
    starts = find(d == 1);
    ends = find(d == -1) - 1;
    lengths = ends - starts + 1;
    [~, segIdx] = max(lengths);
    idx = (starts(segIdx):ends(segIdx))';

    patchT = [t(idx); flipud(t(idx))];
    patchY = [meanVals(idx) - stdVals(idx); flipud(meanVals(idx) + stdVals(idx))];
    fill(ax, patchT, patchY, color, 'FaceAlpha', alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
end

mValid = ~isnan(meanVals);
plot(ax, t(mValid), meanVals(mValid), 'LineWidth', 1.8, 'Color', color, 'DisplayName', label);
end

function thickenBoxplotMedians(ax, lineWidth)
if nargin < 2; lineWidth = 2.2; end
hMedians = findobj(ax, 'Tag', 'Median');
set(hMedians, 'LineWidth', lineWidth);
end

function createTemporalBoxplot(windowMinutes, nightEvolution, plotFile, xMaxHours)
allTwindow = [];
allMhr = [];
for nightIdx = 1:numel(nightEvolution)
    tw = nightEvolution(nightIdx).twindow(:);
    mhr = nightEvolution(nightIdx).mhr(:);
    validMask = ~isnan(mhr);
    allTwindow = [allTwindow; tw(validMask)]; %#ok<AGROW>
    allMhr = [allMhr; mhr(validMask)]; %#ok<AGROW>
end
if isempty(allMhr); return; end

timeHours = allTwindow / 3600;
[uniqueTimes, ~, groupIdx] = unique(timeHours);
counts = accumarray(groupIdx, 1);

nNightsTotal = numel(nightEvolution);
nSubjects = numel(unique({nightEvolution.subjectId}));

boxWidth = (windowMinutes / 60) * 0.7;
if nargin < 4 || isempty(xMaxHours) || xMaxHours <= 0
    xMaxHours = max(uniqueTimes);
end
xLimits = [-boxWidth, xMaxHours + boxWidth];

figWidth = max(900, min(2400, 130 * xMaxHours));

fig = figure('Visible', 'off', 'Position', [100 100 figWidth 640]);
layout = tiledlayout(fig, 4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

axBox = nexttile(layout, 1, [3 1]);
boxplot(axBox, allMhr, groupIdx, 'positions', uniqueTimes, 'widths', boxWidth, 'symbol', '.');
thickenBoxplotMedians(axBox, 2.5);
ylabel(axBox, 'MHR (bpm)');
title(axBox, sprintf('MHR distribution across nights and subjects, %d min window (N=%d nights, %d subjects)', ...
    windowMinutes, nNightsTotal, nSubjects));
grid(axBox, 'on');
ylim(axBox, [30 130]);
set(axBox, 'XTickLabel', []);

axCount = nexttile(layout, 4);
bar(axCount, uniqueTimes, counts, 0.85 * (windowMinutes / 60), 'FaceColor', [0.5 0.5 0.5], 'EdgeColor', 'none');
xlabel(axCount, 'Time from sleep onset (h)');
ylabel(axCount, 'N nights');
grid(axCount, 'on');

hourTicks = 0:floor(xMaxHours);
set(axCount, 'XTick', hourTicks, 'XTickLabel', compose('%d', hourTicks));

xlim(axBox, xLimits);
xlim(axCount, xLimits);
linkaxes([axBox, axCount], 'x');

saveas(fig, plotFile);
close(fig);
end

function createBetweenSubjectFigure(windowData, plotFile)
nSubjects = numel(unique(windowData(1).nightSummary.subjectId));
fig = figure('Visible', 'off', 'Position', [100 100 1100 500]);
ax1 = subplot(1, 2, 1);
[subjectMeanValues, subjectMeanGroups] = collectSubjectStat(windowData, 'mean');
boxplot(ax1, subjectMeanValues, subjectMeanGroups);
thickenBoxplotMedians(ax1);
title(ax1, sprintf('Per-subject mean MHR by window (N=%d subjects)', nSubjects));
xlabel(ax1, 'Window (min)');
ylabel(ax1, 'MHR (bpm)');
ylim(ax1, [40 140]);
grid(ax1, 'on');

ax2 = subplot(1, 2, 2);
[subjectStdValues, subjectStdGroups] = collectSubjectStat(windowData, 'std');
boxplot(ax2, subjectStdValues, subjectStdGroups);
thickenBoxplotMedians(ax2);
title(ax2, sprintf('Per-subject MHR std (intra) by window (N=%d subjects)', nSubjects));
xlabel(ax2, 'Window (min)');
ylabel(ax2, 'MHR std (bpm)');
ylim(ax2, [0 50]);
grid(ax2, 'on');

sgtitle('Between-subject distribution of MHR statistics');
saveas(fig, plotFile);
close(fig);
end

function createBetweenNightFigure(windowData, plotFile)
fig = figure('Visible', 'off', 'Position', [100 100 1100 500]);
ax1 = subplot(1, 2, 1);
[stdValues, stdGroups] = collectSubjectStat(windowData, 'betweenNightStd');
boxplot(ax1, stdValues, stdGroups);
thickenBoxplotMedians(ax1);
nWithMultipleNights = sum(~isnan([windowData(1).subjectStats.betweenNightStd]));
title(ax1, sprintf('Std of nightly mean MHR within subject (N=%d subjects with >=2 valid nights)', nWithMultipleNights));
xlabel(ax1, 'Window (min)');
ylabel(ax1, 'Between-night std (bpm)');
ylim(ax1, [0 50]);
grid(ax1, 'on');

ax2 = subplot(1, 2, 2);
[rangeValues, rangeGroups] = collectSubjectStat(windowData, 'betweenNightRange');
boxplot(ax2, rangeValues, rangeGroups);
thickenBoxplotMedians(ax2);
title(ax2, 'Range of nightly mean MHR within subject');
xlabel(ax2, 'Window (min)');
ylabel(ax2, 'Between-night range (bpm)');
ylim(ax2, [0 90]);
grid(ax2, 'on');

sgtitle('Within-subject between-night variability of mean MHR');
saveas(fig, plotFile);
close(fig);
end

function [values, groups] = collectGroupedArrays(windowData, fieldName)
values = [];
groups = [];
for w = 1:numel(windowData)
    v = windowData(w).(fieldName);
    mask = ~isnan(v);
    values = [values; v(mask)]; %#ok<AGROW>
    groups = [groups; repmat(windowData(w).windowMinutes, sum(mask), 1)]; %#ok<AGROW>
end
end

function [values, groups] = collectSubjectStat(windowData, statField)
values = [];
groups = [];
for w = 1:numel(windowData)
    v = [windowData(w).subjectStats.(statField)]';
    mask = ~isnan(v);
    values = [values; v(mask)]; %#ok<AGROW>
    groups = [groups; repmat(windowData(w).windowMinutes, sum(mask), 1)]; %#ok<AGROW>
end
end

function plotSubjectAcrossWindows(subjectId, windowData, plotFile)
fig = figure('Visible', 'off', 'Position', [100 100 1200 800]);
t = tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

for w = 1:numel(windowData)
    ax = nexttile(t);
    hold(ax, 'on');
    subjectEvolution = windowData(w).nightEvolution(strcmp({windowData(w).nightEvolution.subjectId}, subjectId));
    if ~isempty(subjectEvolution)
        [~, sortIdx] = sort([subjectEvolution.nightNumber]);
        subjectEvolution = subjectEvolution(sortIdx);
    end

    for nightIdx = 1:numel(subjectEvolution)
        nightData = subjectEvolution(nightIdx);
        if isnan(nightData.nightNumber)
            nightLabel = erase(nightData.fileName, '.mat');
        else
            nightLabel = sprintf('night%d', nightData.nightNumber);
        end
        plot(ax, nightData.twindow ./ 3600, nightData.mhr, 'LineWidth', 1.0, 'DisplayName', nightLabel);
    end

    title(ax, sprintf('%d min', windowData(w).windowMinutes));
    xlabel(ax, 'Time from sleep onset (h)');
    ylabel(ax, 'MHR (bpm)');
    grid(ax, 'on');
    if w == 1 && ~isempty(subjectEvolution)
        legend(ax, 'Location', 'best');
    end
end

sgtitle(sprintf('%s - MHR nightly evolution', subjectId));
saveas(fig, plotFile);
close(fig);
end


function writeMarkdownReport(reportFile, datasetVersion, windowData, referenceWindowMinutes, ...
    summaryFigureFile, betweenSubjectFile, betweenNightFile, temporalBoxplotFiles, subjectPlotFiles)

fid = fopen(reportFile, 'w');
if fid == -1
    error('Could not open report file for writing: %s', reportFile);
end
cleanupObj = onCleanup(@() fclose(fid));
assert(isobject(cleanupObj));

timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS'); %#ok<TNOW1,DATST>
upperVersion = upper(datasetVersion);

fprintf(fid, '# Informe de resultados MHR nocturna - %s\n\n', upperVersion);
fprintf(fid, 'Generado automaticamente el %s con `reportMhrEvolution.m`.\n\n', timestamp);
fprintf(fid, 'Este informe se centra exclusivamente en **MHR** (mean heart rate). El eje temporal `t` es siempre el tiempo desde el inicio del Sleep Period Time de cada noche (t = 0 al inicio de la noche, todas las noches alineadas en t = 0). ');
fprintf(fid, 'Cada ventana de %d, %d, %d y %d minutos contiene su propio bin temporal centrado en `windowSeconds/2`, `3*windowSeconds/2`, etc. ', ...
    windowData(1).windowMinutes, windowData(2).windowMinutes, windowData(3).windowMinutes, windowData(4).windowMinutes);
fprintf(fid, 'Los valores fuera del rango [40, 180] bpm se descartan como NaN antes de cualquier estadistico.\n\n');

% --- Cobertura ---
fprintf(fid, '## 1. Cobertura del analisis\n\n');
fprintf(fid, '| Ventana (min) | Sujetos | Noches | Ventanas validas | Trayectorias validas (>=2 ventanas) | Noches sin trayectoria valida |\n');
fprintf(fid, '| ---: | ---: | ---: | ---: | ---: | ---: |\n');
for w = 1:numel(windowData)
    wd = windowData(w);
    nNights = height(wd.nightSummary);
    nValidTraj = sum(~isnan(wd.nightDeltas));
    fprintf(fid, '| %d | %d | %d | %d | %d | %d |\n', ...
        wd.windowMinutes, ...
        numel(unique(wd.nightSummary.subjectId)), ...
        nNights, ...
        sum(wd.nightSummary.validWindows), ...
        nValidTraj, ...
        nNights - nValidTraj);
end
fprintf(fid, '\n');

% --- Estadisticas globales por ventana ---
fprintf(fid, '## 2. Estadisticos globales de MHR por ventana\n\n');
fprintf(fid, 'Distribucion de todas las ventanas validas (todos los sujetos, todas las noches, todos los segmentos):\n\n');
fprintf(fid, '| Ventana (min) | n | min | p10 | p25 | mediana | media | p75 | p90 | max | std |\n');
fprintf(fid, '| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |\n');
for w = 1:numel(windowData)
    s = windowData(w).globalStats;
    fprintf(fid, '| %d | %d | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f |\n', ...
        windowData(w).windowMinutes, s.n, s.min, s.p10, s.p25, s.median, s.mean, s.p75, s.p90, s.max, s.std);
end
fprintf(fid, '\n');

% --- Estadisticos a nivel de noche ---
fprintf(fid, '## 3. Estadisticos a nivel de noche por ventana\n\n');
fprintf(fid, 'Distribucion del MHR medio nocturno (un valor por noche, calculado como la media de las ventanas validas de esa noche):\n\n');
fprintf(fid, '| Ventana (min) | n noches | min | p10 | p25 | mediana | media | p75 | p90 | max | std |\n');
fprintf(fid, '| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |\n');
for w = 1:numel(windowData)
    s = mhrStats(windowData(w).nightMeans);
    fprintf(fid, '| %d | %d | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f |\n', ...
        windowData(w).windowMinutes, s.n, s.min, s.p10, s.p25, s.median, s.mean, s.p75, s.p90, s.max, s.std);
end
fprintf(fid, '\n');

% --- Trayectoria nocturna ---
fprintf(fid, '## 4. Trayectoria nocturna (descenso y rango)\n\n');
fprintf(fid, '| Ventana (min) | Delta fin-inicio medio (bpm) | Mediana delta (bpm) | Noches con descenso (%%) | Rango medio nocturno (bpm) | Rango mediana (bpm) |\n');
fprintf(fid, '| ---: | ---: | ---: | ---: | ---: | ---: |\n');
for w = 1:numel(windowData)
    wd = windowData(w);
    deltas = wd.nightDeltas(~isnan(wd.nightDeltas));
    ranges = wd.nightRanges(~isnan(wd.nightRanges));
    fprintf(fid, '| %d | %.2f | %.2f | %.1f | %.2f | %.2f |\n', ...
        wd.windowMinutes, mean(deltas), median(deltas), wd.decreasingPct, mean(ranges), median(ranges));
end
fprintf(fid, '\n');

fprintf(fid, '![Resumen MHR](%s)\n\n', toMarkdownPath(summaryFigureFile, reportFile));

% --- Boxplots temporales por ventana ---
fprintf(fid, '## 5. Distribucion temporal de MHR por ventana\n\n');
fprintf(fid, 'Para cada ventana, el boxplot muestra la distribucion de MHR en cada bin temporal (eje x = horas desde el inicio del SPT) considerando todas las noches y todos los sujetos. Los bins finales tienen menos muestras porque pocas noches duran tantas horas.\n\n');
for w = 1:numel(windowData)
    fprintf(fid, '### Ventana %d min\n\n', windowData(w).windowMinutes);
    fprintf(fid, '![MHR temporal %d min](%s)\n\n', windowData(w).windowMinutes, toMarkdownPath(temporalBoxplotFiles{w}, reportFile));
end

% --- Comparativa entre sujetos ---
fprintf(fid, '## 6. Comparativa entre sujetos\n\n');
fprintf(fid, '![MHR entre sujetos](%s)\n\n', toMarkdownPath(betweenSubjectFile, reportFile));

refIdx = find([windowData.windowMinutes] == referenceWindowMinutes, 1);
if isempty(refIdx); refIdx = 1; end
refStats = windowData(refIdx).subjectStats;
means = [refStats.mean];
[~, sortIdx] = sort(means, 2, 'descend', 'MissingPlacement', 'last');
refStatsSorted = refStats(sortIdx);

fprintf(fid, 'Distribucion del MHR por sujeto, ordenado por la media en la ventana de referencia (%d min):\n\n', referenceWindowMinutes);
fprintf(fid, '| Sujeto | n noches | n vent. | min | p10 | p25 | mediana | media | p75 | p90 | max | std intra | std entre noches | rango entre noches | delta medio | rango medio |\n');
fprintf(fid, '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |\n');
for s = 1:numel(refStatsSorted)
    e = refStatsSorted(s);
    fprintf(fid, '| %s | %d | %d | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %s | %s | %s | %s |\n', ...
        e.subjectId, e.numNights, e.n, e.min, e.p10, e.p25, e.median, e.mean, e.p75, e.p90, e.max, e.std, ...
        formatOptional(e.betweenNightStd), formatOptional(e.betweenNightRange), ...
        formatOptional(e.meanNightDelta), formatOptional(e.meanNightRange));
end
fprintf(fid, '\n');
fprintf(fid, 'Notas:\n');
fprintf(fid, '- **std intra**: dispersion total de MHR del sujeto agregando todas sus ventanas validas en todas las noches.\n');
fprintf(fid, '- **std entre noches** y **rango entre noches**: variabilidad de la *media* nocturna entre noches del sujeto. Solo definidas si tiene >=2 noches validas.\n');
fprintf(fid, '- **delta medio** (fin-inicio) y **rango medio** se calculan por noche y se promedian.\n\n');

writeWindowComparisonByGroup(fid, refStatsSorted, windowData);

% --- Variabilidad entre noches dentro del sujeto ---
fprintf(fid, '## 7. Variabilidad entre noches dentro del sujeto\n\n');
fprintf(fid, '![MHR entre noches dentro del sujeto](%s)\n\n', toMarkdownPath(betweenNightFile, reportFile));

fprintf(fid, '| Ventana (min) | Sujetos con >=2 noches validas | std entre noches medio (bpm) | std entre noches mediano (bpm) | rango entre noches medio (bpm) | rango entre noches mediano (bpm) |\n');
fprintf(fid, '| ---: | ---: | ---: | ---: | ---: | ---: |\n');
for w = 1:numel(windowData)
    stats = windowData(w).subjectStats;
    stdsRaw = [stats.betweenNightStd]';
    rangesRaw = [stats.betweenNightRange]';
    stds = stdsRaw(~isnan(stdsRaw));
    ranges = rangesRaw(~isnan(rangesRaw));
    fprintf(fid, '| %d | %d | %.2f | %.2f | %.2f | %.2f |\n', ...
        windowData(w).windowMinutes, numel(stds), ...
        mean(stds), median(stds), mean(ranges), median(ranges));
end
fprintf(fid, '\n');

% --- Observaciones de calidad ---
writeQualityObservations(fid, windowData, referenceWindowMinutes);

% --- Detalle por sujeto ---
fprintf(fid, '## 9. Detalle por sujeto\n\n');
fprintf(fid, 'Cada figura muestra la evolucion nocturna del sujeto en las cuatro ventanas, con cada noche superpuesta y alineada en t = 0 (inicio del SPT):\n\n');
for idx = 1:numel(subjectPlotFiles)
    fprintf(fid, '- [%s](%s)\n', subjectPlotFiles(idx).subjectId, toMarkdownPath(subjectPlotFiles(idx).plotPath, reportFile));
end
fprintf(fid, '\n');

% --- Lectura sintetica ---
windowMinutesAll = [windowData.windowMinutes];
globalMeans = arrayfun(@(wd) wd.globalStats.mean, windowData);
globalMedians = arrayfun(@(wd) wd.globalStats.median, windowData);
meanRanges = arrayfun(@(wd) mean(wd.nightRanges, 'omitnan'), windowData);
meanDeltas = arrayfun(@(wd) mean(wd.nightDeltas, 'omitnan'), windowData);
decreasing = arrayfun(@(wd) wd.decreasingPct, windowData);

[~, hiIdx] = max([refStatsSorted.mean]);
[~, loIdx] = min([refStatsSorted.mean]);
hiSubject = refStatsSorted(hiIdx);
loSubject = refStatsSorted(loIdx);

fprintf(fid, '## 10. Lectura sintetica\n\n');
fprintf(fid, '- Cobertura identica en las cuatro ventanas: %d sujetos y %d noches.\n', ...
    numel(unique(windowData(1).nightSummary.subjectId)), height(windowData(1).nightSummary));
fprintf(fid, '- La mediana global de MHR es estable entre ventanas (%.2f-%.2f bpm) y la media tambien (%.2f-%.2f bpm), indicando que el centrado de la distribucion no depende del tamano de ventana.\n', ...
    min(globalMedians), max(globalMedians), min(globalMeans), max(globalMeans));
fprintf(fid, '- Entre %.1f%% y %.1f%% de las noches presentan descenso de MHR (delta fin-inicio < 0).\n', min(decreasing), max(decreasing));
fprintf(fid, '- El descenso medio fin-inicio se mueve entre %.2f y %.2f bpm.\n', min(meanDeltas), max(meanDeltas));
fprintf(fid, '- El rango medio intranocturno cae de %.2f bpm (%d min) a %.2f bpm (%d min): ventanas mas largas suavizan la trayectoria pero conservan el patron.\n', ...
    meanRanges(1), windowMinutesAll(1), meanRanges(end), windowMinutesAll(end));
fprintf(fid, '- En la ventana de referencia (%d min) el MHR medio mas alto es **%s** (%.2f bpm) y el mas bajo **%s** (%.2f bpm).\n', ...
    referenceWindowMinutes, hiSubject.subjectId, hiSubject.mean, loSubject.subjectId, loSubject.mean);
fprintf(fid, '\n');

fprintf(fid, '## 11. Notas sobre el procesado\n\n');
fprintf(fid, '- Pipeline base: `segmentNights.m` -> `pulseDetection.m` -> `hrvtd.m` -> `analyzeHrvtdResults.m` -> `reportMhrEvolution.m`.\n');
fprintf(fid, '- En cada ventana de la noche se calcula `dtk = diff(tk)`, se eliminan latidos atipicos por umbral de mediana movil y se obtiene MHR via `tdmetrics`.\n');
fprintf(fid, '- Para los casos especificos a tener en cuenta por dataset (sujetos sin noches, noches anormales) consultar el README.md de la raiz del repo.\n');
end

function writeQualityObservations(fid, windowData, referenceWindowMinutes)
fprintf(fid, '## 8. Observaciones de calidad y casos a revisar\n\n');
fprintf(fid, 'Detectados automaticamente sobre la ventana de referencia (%d min). Los umbrales son heuristicos:\n\n', referenceWindowMinutes);
fprintf(fid, '- **0 ventanas validas**: el sujeto no aporta ningun MHR valido tras filtrar por [40, 180] bpm.\n');
fprintf(fid, '- **mediana intra-sujeto > 90 bpm** o **max > 130 bpm** o **|media - mediana| > 10 bpm**: sospecha de saturacion artefactual o doubling de pulsos en la deteccion (la distribucion suele ser bimodal con una pila cerca del techo).\n');
fprintf(fid, '- **rango entre noches > 25 bpm**: variabilidad nocturna muy alta dentro del sujeto, conviene revisar visualmente sus plots.\n\n');

refIdx = find([windowData.windowMinutes] == referenceWindowMinutes, 1);
if isempty(refIdx); refIdx = 1; end
stats = windowData(refIdx).subjectStats;

zeroFlag = false(numel(stats), 1);
medianFlag = false(numel(stats), 1);
maxFlag = false(numel(stats), 1);
skewFlag = false(numel(stats), 1);
betweenNightFlag = false(numel(stats), 1);
flagText = repmat({''}, numel(stats), 1);

for s = 1:numel(stats)
    e = stats(s);
    flags = {};
    if e.n == 0
        zeroFlag(s) = true;
        flags{end+1} = '0 vent.'; %#ok<AGROW>
    end
    if ~isnan(e.median) && e.median > 90
        medianFlag(s) = true;
        flags{end+1} = sprintf('mediana=%.1f', e.median); %#ok<AGROW>
    end
    if ~isnan(e.max) && e.max > 130
        maxFlag(s) = true;
        flags{end+1} = sprintf('max=%.1f', e.max); %#ok<AGROW>
    end
    if ~isnan(e.mean) && ~isnan(e.median) && abs(e.mean - e.median) > 10
        skewFlag(s) = true;
        flags{end+1} = sprintf('|media-mediana|=%.1f', abs(e.mean - e.median)); %#ok<AGROW>
    end
    if ~isnan(e.betweenNightRange) && e.betweenNightRange > 25
        betweenNightFlag(s) = true;
        flags{end+1} = sprintf('rango entre noches=%.1f', e.betweenNightRange); %#ok<AGROW>
    end
    flagText{s} = strjoin(flags, '; ');
end

flagged = zeroFlag | medianFlag | maxFlag | skewFlag | betweenNightFlag;

if ~any(flagged)
    fprintf(fid, 'Ningun sujeto activa los flags de calidad en la ventana de %d min.\n\n', referenceWindowMinutes);
else
    fprintf(fid, '| Sujeto | n vent. | mediana | media | max | rango entre noches | Flags |\n');
    fprintf(fid, '| --- | ---: | ---: | ---: | ---: | ---: | --- |\n');
    flaggedIdx = find(flagged);
    for k = 1:numel(flaggedIdx)
        s = flaggedIdx(k);
        e = stats(s);
        fprintf(fid, '| %s | %d | %s | %s | %s | %s | %s |\n', ...
            e.subjectId, e.n, ...
            formatOptional(e.median), formatOptional(e.mean), ...
            formatOptional(e.max), formatOptional(e.betweenNightRange), ...
            flagText{s});
    end
    fprintf(fid, '\n');

    fprintf(fid, '### Interpretacion\n\n');
    fprintf(fid, '- Una distribucion bimodal con pila en torno a 128 bpm sugiere que el detector de pulsos esta contando latidos por duplicado en algunas ventanas (frecuencia real ~64 bpm que se duplica a ~128 bpm). Revisar `pulseDetection.m` o las correcciones manuales en `lib/correctPulseResults.m` para esos sujetos.\n');
    fprintf(fid, '- El limite [40, 180] bpm aplicado en `hrvtd.m` no descarta esos picos artefactuales si caen por debajo de 180. Posibles mitigaciones: bajar el limite superior a, por ejemplo, 110-120 bpm para sueno, o incorporar un filtro adicional sobre la mediana de `dtk` consistente entre ventanas.\n');
    fprintf(fid, '- Un sujeto con 0 ventanas validas (p.ej. PMP1018) probablemente tiene un PPG demasiado ruidoso o una `tk` con latidos espaciados que generan MHR fuera de [40, 180].\n\n');
end

[zeroSubjects, suspectSubjects, betweenNightSubjects] = collectFlagSummary(stats, zeroFlag, medianFlag | maxFlag | skewFlag, betweenNightFlag);

if ~isempty(zeroSubjects) || ~isempty(suspectSubjects) || ~isempty(betweenNightSubjects)
    fprintf(fid, '### Resumen rapido\n\n');
    if ~isempty(zeroSubjects)
        fprintf(fid, '- Sujetos con 0 ventanas validas: %s\n', strjoin(zeroSubjects, ', '));
    end
    if ~isempty(suspectSubjects)
        fprintf(fid, '- Sospecha de artefactos en la deteccion de pulsos: %s\n', strjoin(suspectSubjects, ', '));
    end
    if ~isempty(betweenNightSubjects)
        fprintf(fid, '- Variabilidad entre noches > 25 bpm: %s\n', strjoin(betweenNightSubjects, ', '));
    end
    fprintf(fid, '\n');
end
end

function [zeroSubjects, suspectSubjects, betweenNightSubjects] = collectFlagSummary(stats, zeroFlag, suspectFlag, betweenNightFlag)
zeroSubjects = {stats(zeroFlag).subjectId};
suspectSubjects = {stats(suspectFlag & ~zeroFlag).subjectId};
betweenNightSubjects = {stats(betweenNightFlag & ~suspectFlag & ~zeroFlag).subjectId};
end

function writeWindowComparisonByGroup(fid, refStatsSorted, windowData)
fprintf(fid, '### Comparativa entre ventanas (media MHR por sujeto)\n\n');
windowLabels = arrayfun(@(wd) sprintf('%d min', wd.windowMinutes), windowData, 'UniformOutput', false);
header = ['| Sujeto | ' strjoin(windowLabels, ' | ') ' |'];
divider = ['| --- | ' strjoin(repmat({'---:'}, 1, numel(windowData)), ' | ') ' |'];
fprintf(fid, '%s\n', header);
fprintf(fid, '%s\n', divider);
for s = 1:numel(refStatsSorted)
    subjectId = refStatsSorted(s).subjectId;
    rowParts = {subjectId};
    for w = 1:numel(windowData)
        match = windowData(w).subjectStats(strcmp({windowData(w).subjectStats.subjectId}, subjectId));
        if isempty(match) || isnan(match.mean)
            rowParts{end+1} = '-'; %#ok<AGROW>
        else
            rowParts{end+1} = sprintf('%.2f', match.mean); %#ok<AGROW>
        end
    end
    fprintf(fid, '| %s |\n', strjoin(rowParts, ' | '));
end
fprintf(fid, '\n');
end

function s = formatOptional(value)
if isnan(value)
    s = '-';
else
    s = sprintf('%.2f', value);
end
end

function markdownPath = toMarkdownPath(filePath, reportFile)
reportDir = fileparts(reportFile);
markdownPath = strrep(relativepath(filePath, reportDir), '\', '/');
end

function relativePath = relativepath(targetPath, basePath)
targetParts = splitPathParts(targetPath);
baseParts = splitPathParts(basePath);

commonLength = 0;
maxCommon = min(numel(targetParts), numel(baseParts));
for idx = 1:maxCommon
    if strcmpi(targetParts{idx}, baseParts{idx})
        commonLength = idx;
    else
        break;
    end
end

upParts = repmat({'..'}, 1, numel(baseParts) - commonLength);
downParts = targetParts(commonLength + 1:end);
allParts = [upParts downParts];

if isempty(allParts)
    relativePath = '.';
else
    relativePath = strjoin(allParts, filesep);
end
end

function parts = splitPathParts(filePath)
normalizedPath = strrep(filePath, '/', filesep);
parts = regexp(normalizedPath, ['[^' regexptranslate('escape', filesep) ']+'], 'match');
end
