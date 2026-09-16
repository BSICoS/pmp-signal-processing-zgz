versions = {'v1', 'v2_1', 'v2_2'};
windowsMin = [5 10 30 60];
referenceWindow = 30;

outDir = fullfile('data', 'comparison');
figDir = fullfile(outDir, 'figures');
reportFile = fullfile(outDir, 'comparison_report.md');

if ~exist(outDir, 'dir'); mkdir(outDir); end
if ~exist(figDir, 'dir'); mkdir(figDir); end

allData = repmat(emptyEntry(), numel(versions), numel(windowsMin));
for vi = 1:numel(versions)
    for wi = 1:numel(windowsMin)
        v = versions{vi};
        w = windowsMin(wi);
        resultsFile = fullfile('data', v, 'hrvtd', sprintf('hrvtd_results_%s_%dmin.mat', v, w));

        if ~exist(resultsFile, 'file')
            warning('Missing results file %s. Skipping (%s, %d min).', resultsFile, v, w);
            continue;
        end

        nightSummaryVarName = sprintf('nightSummary_%dmin', w);
        nightEvolutionVarName = sprintf('nightEvolution_%dmin', w);
        loaded = load(resultsFile, nightSummaryVarName, nightEvolutionVarName);
        nightSummary = loaded.(nightSummaryVarName);
        nightEvolution = loaded.(nightEvolutionVarName);

        allData(vi, wi) = computeEntry(v, w, nightSummary, nightEvolution);
    end
end

generateCoverageFigure(allData, versions, windowsMin, fullfile(figDir, 'coverage.png'));
generateQualityFigure(allData, versions, windowsMin, fullfile(figDir, 'quality_metrics.png'));
generateDistributionFigure(allData, versions, windowsMin, referenceWindow, fullfile(figDir, 'mhr_distribution.png'));
generatePopulationTrajectoryFigure(allData, versions, windowsMin, referenceWindow, fullfile(figDir, 'population_trajectory.png'));
generateBetweenSubjectFigure(allData, versions, windowsMin, fullfile(figDir, 'between_subjects.png'));

writeComparisonReport(reportFile, allData, versions, windowsMin, referenceWindow, figDir);

fprintf('Saved comparison figures to %s\n', figDir);
fprintf('Saved comparison report to %s\n', reportFile);


function entry = emptyEntry()
entry = struct( ...
    'version', '', ...
    'window', NaN, ...
    'nightSummary', table(), ...
    'nightEvolution', struct([]), ...
    'nSubjects', 0, ...
    'nNights', 0, ...
    'nValidTrajectories', 0, ...
    'pctNoTrajectory', NaN, ...
    'nSubjectsNoData', 0, ...
    'nSubjectsArtifact', 0, ...
    'pctSubjectsArtifact', NaN, ...
    'flaggedSubjectsList', {{}}, ...
    'noDataSubjectsList', {{}}, ...
    'nightlyMeans', [], ...
    'nightlyMedians', [], ...
    'nightlyRanges', [], ...
    'nightlyStds', [], ...
    'nightlyDeltas', [], ...
    'subjectMeans', [], ...
    'subjectStds', [], ...
    'subjectBetweenNightStds', [], ...
    'globalStats', emptyMhrStats(), ...
    'populationTimeHours', [], ...
    'populationMeanMhr', [], ...
    'populationMedianMhr', [], ...
    'populationStdMhr', [], ...
    'populationCount', [] ...
);
end

function entry = computeEntry(version, windowMinutes, nightSummary, nightEvolution)
entry = emptyEntry();
entry.version = version;
entry.window = windowMinutes;
entry.nightSummary = nightSummary;
entry.nightEvolution = nightEvolution;

allMhr = collectAllMhrValues(nightEvolution);
entry.globalStats = mhrStats(allMhr);

nNights = numel(nightEvolution);
nightlyMeans = nan(nNights, 1);
nightlyMedians = nan(nNights, 1);
nightlyRanges = nan(nNights, 1);
nightlyStds = nan(nNights, 1);
nightlyDeltas = nan(nNights, 1);
nightlyValid = false(nNights, 1);

for ni = 1:nNights
    v = nightEvolution(ni).mhr(:);
    v = v(~isnan(v));
    if numel(v) >= 2
        nightlyMeans(ni) = mean(v);
        nightlyMedians(ni) = median(v);
        nightlyRanges(ni) = max(v) - min(v);
        nightlyStds(ni) = std(v);
        nightlyDeltas(ni) = v(end) - v(1);
        nightlyValid(ni) = true;
    elseif isscalar(v)
        nightlyMeans(ni) = v;
        nightlyMedians(ni) = v;
    end
end

entry.nightlyMeans = nightlyMeans;
entry.nightlyMedians = nightlyMedians;
entry.nightlyRanges = nightlyRanges;
entry.nightlyStds = nightlyStds;
entry.nightlyDeltas = nightlyDeltas;

entry.nNights = nNights;
entry.nValidTrajectories = sum(nightlyValid);
entry.pctNoTrajectory = 100 * (nNights - entry.nValidTrajectories) / max(1, nNights);

subjectIds = unique(nightSummary.subjectId, 'stable');
entry.nSubjects = numel(subjectIds);

subjectMeans = nan(numel(subjectIds), 1);
subjectStds = nan(numel(subjectIds), 1);
subjectBetweenNightStds = nan(numel(subjectIds), 1);
flagged = false(numel(subjectIds), 1);
noData = false(numel(subjectIds), 1);
flaggedList = {};
noDataList = {};

for si = 1:numel(subjectIds)
    sid = subjectIds{si};
    mask = strcmp({nightEvolution.subjectId}, sid);
    subjEvo = nightEvolution(mask);
    subjMhr = collectAllMhrValues(subjEvo);
    subjStat = mhrStats(subjMhr);

    subjectMeans(si) = subjStat.mean;
    subjectStds(si) = subjStat.std;

    if subjStat.n == 0
        noData(si) = true;
        noDataList{end+1, 1} = sid; %#ok<AGROW>
        continue;
    end

    isArtifact = false;
    if ~isnan(subjStat.median) && subjStat.median > 90
        isArtifact = true;
    end
    if ~isnan(subjStat.max) && subjStat.max > 130
        isArtifact = true;
    end
    if ~isnan(subjStat.mean) && ~isnan(subjStat.median) && abs(subjStat.mean - subjStat.median) > 10
        isArtifact = true;
    end
    if isArtifact
        flagged(si) = true;
        flaggedList{end+1, 1} = sid; %#ok<AGROW>
    end

    nightlyMeansForSubject = arrayfun(@(e) meanSafe(e.mhr(~isnan(e.mhr))), subjEvo);
    nightlyMeansForSubject = nightlyMeansForSubject(~isnan(nightlyMeansForSubject));
    if numel(nightlyMeansForSubject) >= 2
        subjectBetweenNightStds(si) = std(nightlyMeansForSubject);
    end
end

entry.subjectMeans = subjectMeans;
entry.subjectStds = subjectStds;
entry.subjectBetweenNightStds = subjectBetweenNightStds;
entry.nSubjectsNoData = sum(noData);
entry.nSubjectsArtifact = sum(flagged);
entry.pctSubjectsArtifact = 100 * sum(flagged) / max(1, numel(subjectIds));
entry.flaggedSubjectsList = flaggedList;
entry.noDataSubjectsList = noDataList;

[entry.populationTimeHours, entry.populationMeanMhr, entry.populationMedianMhr, entry.populationStdMhr, entry.populationCount] = buildPopulationTrajectory(nightEvolution);
end

function [timeHours, meanMhr, medianMhr, stdMhr, count] = buildPopulationTrajectory(nightEvolution)
allTimes = [];
for ni = 1:numel(nightEvolution)
    allTimes = [allTimes; nightEvolution(ni).twindow(:)]; %#ok<AGROW>
end
timeSeconds = unique(allTimes);

meanMhr = nan(numel(timeSeconds), 1);
medianMhr = nan(numel(timeSeconds), 1);
stdMhr = nan(numel(timeSeconds), 1);
count = zeros(numel(timeSeconds), 1);

for ti = 1:numel(timeSeconds)
    samples = nan(numel(nightEvolution), 1);
    for ni = 1:numel(nightEvolution)
        nt = nightEvolution(ni).twindow(:);
        nm = nightEvolution(ni).mhr(:);
        idx = find(nt == timeSeconds(ti), 1);
        if ~isempty(idx) && ~isnan(nm(idx))
            samples(ni) = nm(idx);
        end
    end
    valid = ~isnan(samples);
    count(ti) = sum(valid);
    if any(valid)
        meanMhr(ti) = mean(samples(valid));
        medianMhr(ti) = median(samples(valid));
    end
    if sum(valid) >= 2
        stdMhr(ti) = std(samples(valid));
    end
end

timeHours = timeSeconds ./ 3600;
end

function values = collectAllMhrValues(nightEvolution)
values = [];
for ni = 1:numel(nightEvolution)
    v = nightEvolution(ni).mhr(:);
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

function s = emptyMhrStats()
s = struct('n', 0, 'min', NaN, 'p10', NaN, 'p25', NaN, 'mean', NaN, 'median', NaN, 'p75', NaN, 'p90', NaN, 'max', NaN, 'std', NaN);
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

function m = meanSafe(values)
v = values(~isnan(values));
if isempty(v); m = NaN; else; m = mean(v); end
end


function generateCoverageFigure(allData, versions, windowsMin, plotFile)
fig = figure('Visible', 'off', 'Position', [100 100 1200 500]);
colors = lines(numel(versions));

ax1 = subplot(1, 2, 1);
hold(ax1, 'on');
xPos = 1:numel(windowsMin);
barWidth = 0.25;
for vi = 1:numel(versions)
    pct = arrayfun(@(wi) allData(vi, wi).pctNoTrajectory, 1:numel(windowsMin));
    bar(ax1, xPos + (vi - 2) * barWidth, pct, barWidth, 'FaceColor', colors(vi, :), 'DisplayName', formatVersion(versions{vi}));
end
title(ax1, '% of nights without valid trajectory');
xlabel(ax1, 'Window (min)');
ylabel(ax1, '% nights');
set(ax1, 'XTick', xPos, 'XTickLabel', compose('%d', windowsMin));
legend(ax1, 'Location', 'best');
grid(ax1, 'on');

ax2 = subplot(1, 2, 2);
hold(ax2, 'on');
for vi = 1:numel(versions)
    pct = arrayfun(@(wi) allData(vi, wi).pctSubjectsArtifact, 1:numel(windowsMin));
    bar(ax2, xPos + (vi - 2) * barWidth, pct, barWidth, 'FaceColor', colors(vi, :), 'DisplayName', formatVersion(versions{vi}));
end
title(ax2, '% of subjects flagged as artifact-suspect');
xlabel(ax2, 'Window (min)');
ylabel(ax2, '% subjects');
set(ax2, 'XTick', xPos, 'XTickLabel', compose('%d', windowsMin));
legend(ax2, 'Location', 'best');
grid(ax2, 'on');

sgtitle('Cross-version data quality coverage');
saveas(fig, plotFile);
close(fig);
end

function generateQualityFigure(allData, versions, windowsMin, plotFile)
fig = figure('Visible', 'off', 'Position', [100 100 1400 800]);

ax1 = subplot(2, 2, 1);
plotMetricBox(ax1, allData, versions, windowsMin, 'nightlyRanges', 'Intra-night MHR range (bpm)');

ax2 = subplot(2, 2, 2);
plotMetricBox(ax2, allData, versions, windowsMin, 'nightlyStds', 'Intra-night MHR std (bpm)');

ax3 = subplot(2, 2, 3);
plotMetricBox(ax3, allData, versions, windowsMin, 'nightlyDeltas', 'Last minus first valid MHR (bpm)');
yline(ax3, 0, '--k', 'HandleVisibility', 'off');

ax4 = subplot(2, 2, 4);
plotMetricBox(ax4, allData, versions, windowsMin, 'subjectBetweenNightStds', 'Per-subject between-night std (bpm)');

sgtitle('Cross-version intra-night and between-night variability');
saveas(fig, plotFile);
close(fig);
end

function plotMetricBox(ax, allData, versions, windowsMin, fieldName, ylabelText)
hold(ax, 'on');
allValues = [];
groupVersion = {};
groupWindow = [];
for vi = 1:numel(versions)
    for wi = 1:numel(windowsMin)
        v = allData(vi, wi).(fieldName);
        v = v(~isnan(v));
        allValues = [allValues; v]; %#ok<AGROW>
        groupVersion = [groupVersion; repmat({formatVersion(versions{vi})}, numel(v), 1)]; %#ok<AGROW>
        groupWindow = [groupWindow; repmat(windowsMin(wi), numel(v), 1)]; %#ok<AGROW>
    end
end

if isempty(allValues); return; end

boxplot(ax, allValues, {groupWindow, groupVersion}, 'FactorGap', [10 1], 'ColorGroup', groupVersion, 'Symbol', '.');
thickenBoxplotMedians(ax);
title(ax, ylabelText);
xlabel(ax, 'Window (min) | Version');
ylabel(ax, ylabelText);
grid(ax, 'on');
end

function generateDistributionFigure(allData, versions, windowsMin, referenceWindow, plotFile)
wi = find(windowsMin == referenceWindow, 1);
if isempty(wi); wi = 1; end

fig = figure('Visible', 'off', 'Position', [100 100 1100 500]);
ax1 = subplot(1, 2, 1);
hold(ax1, 'on');
nightData = cell(numel(versions), 1);
nightLabels = cell(numel(versions), 1);
for vi = 1:numel(versions)
    v = allData(vi, wi).nightlyMeans;
    v = v(~isnan(v));
    nightData{vi} = v;
    nightLabels{vi} = sprintf('%s (n=%d)', formatVersion(versions{vi}), numel(v));
end
boxplotMultiSet(ax1, nightData, nightLabels);
title(ax1, sprintf('Night mean MHR (%d min window)', referenceWindow));
ylabel(ax1, 'MHR (bpm)');
grid(ax1, 'on');

ax2 = subplot(1, 2, 2);
hold(ax2, 'on');
subjData = cell(numel(versions), 1);
subjLabels = cell(numel(versions), 1);
for vi = 1:numel(versions)
    v = allData(vi, wi).subjectMeans;
    v = v(~isnan(v));
    subjData{vi} = v;
    subjLabels{vi} = sprintf('%s (n=%d)', formatVersion(versions{vi}), numel(v));
end
boxplotMultiSet(ax2, subjData, subjLabels);
title(ax2, sprintf('Per-subject mean MHR (%d min window)', referenceWindow));
ylabel(ax2, 'MHR (bpm)');
grid(ax2, 'on');

linkaxes([ax1, ax2], 'y');
ylim(ax1, [40 140]);

sgtitle('MHR distribution per version (reference window)');
saveas(fig, plotFile);
close(fig);
end

function boxplotMultiSet(ax, data, labels)
allValues = [];
groups = {};
for i = 1:numel(data)
    allValues = [allValues; data{i}]; %#ok<AGROW>
    groups = [groups; repmat(labels(i), numel(data{i}), 1)]; %#ok<AGROW>
end
if isempty(allValues); return; end
boxplot(ax, allValues, groups);
thickenBoxplotMedians(ax);
end

function generatePopulationTrajectoryFigure(allData, versions, windowsMin, referenceWindow, plotFile)
wi = find(windowsMin == referenceWindow, 1);
if isempty(wi); wi = 1; end

fig = figure('Visible', 'off', 'Position', [100 100 1100 650]);
hold on;
colors = lines(numel(versions));
for vi = 1:numel(versions)
    e = allData(vi, wi);
    label = sprintf('%s (n=%d nights, %d subjects)', formatVersion(versions{vi}), e.nNights, e.nSubjects);
    drawMeanStdBand(gca, e.populationTimeHours, e.populationMeanMhr, e.populationStdMhr, ...
        colors(vi, :), label, 0.18);
end
xlabel('Time from sleep onset (h)');
ylabel('Population mean MHR (bpm)');
title(sprintf('Nocturnal population mean MHR per version (mean +/- std across nights, %d min window)', referenceWindow));
legend('Location', 'best');
grid on;
xlim([0 12]);
saveas(fig, plotFile);
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

function generateBetweenSubjectFigure(allData, versions, windowsMin, plotFile)
fig = figure('Visible', 'off', 'Position', [100 100 1200 500]);

ax1 = subplot(1, 2, 1);
plotMetricBox(ax1, allData, versions, windowsMin, 'subjectMeans', 'Per-subject mean MHR (bpm)');

ax2 = subplot(1, 2, 2);
plotMetricBox(ax2, allData, versions, windowsMin, 'subjectStds', 'Per-subject intra-std MHR (bpm)');

sgtitle('Between-subject distribution by version and window');
saveas(fig, plotFile);
close(fig);
end


function writeComparisonReport(reportFile, allData, versions, windowsMin, referenceWindow, figDir)
fid = fopen(reportFile, 'w');
if fid == -1
    error('Cannot write report file: %s', reportFile);
end
cleanupObj = onCleanup(@() fclose(fid));
assert(isobject(cleanupObj));

reportDir = fileparts(reportFile);
timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS'); %#ok<TNOW1,DATST>

fprintf(fid, '# Comparativa entre versiones del dataset PMP\n\n');
fprintf(fid, 'Generado automaticamente el %s con `compareDatasetVersions.m`.\n\n', timestamp);
fprintf(fid, 'Este informe compara la calidad y los resultados del analisis de MHR nocturna entre las tres versiones del dataset (`v1`, `v2_1`, `v2_2`). El objetivo es cuantificar si los dispositivos PPG de las versiones v2 introducen una degradacion suficiente como para descartar esos datos, o si los resultados siguen siendo utilizables. Pipeline base: `segmentNights.m` -> `pulseDetection.m` -> `hrvtd.m` -> `analyzeHrvtdResults.m` -> `reportMhrEvolution.m` (por version) -> `compareDatasetVersions.m`.\n\n');

% --- Cobertura ---
fprintf(fid, '## 1. Cobertura y descarte\n\n');
fprintf(fid, '| Version | Ventana (min) | Sujetos | Noches | Trayectorias validas | %% sin trayectoria | Sujetos sin datos | Sujetos flagged artefacto | %% flagged |\n');
fprintf(fid, '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |\n');
for vi = 1:numel(versions)
    for wi = 1:numel(windowsMin)
        e = allData(vi, wi);
        fprintf(fid, '| %s | %d | %d | %d | %d | %.1f | %d | %d | %.1f |\n', ...
            formatVersion(e.version), e.window, e.nSubjects, e.nNights, e.nValidTrajectories, ...
            e.pctNoTrajectory, e.nSubjectsNoData, e.nSubjectsArtifact, e.pctSubjectsArtifact);
    end
end
fprintf(fid, '\n');
fprintf(fid, '![Cobertura](%s)\n\n', toMarkdownPath(fullfile(figDir, 'coverage.png'), reportDir));

% --- Sujetos problematicos ---
fprintf(fid, '## 2. Sujetos sin datos o con artefactos en la deteccion\n\n');
fprintf(fid, 'Detectados con la ventana de referencia (%d min). Un sujeto esta marcado como "artefacto" si su mediana > 90 bpm, su max > 130 bpm o |media - mediana| > 10 bpm.\n\n', referenceWindow);
refWi = find(windowsMin == referenceWindow, 1);
if isempty(refWi); refWi = 1; end
fprintf(fid, '| Version | Sujetos sin datos | Sujetos artefacto |\n');
fprintf(fid, '| --- | --- | --- |\n');
for vi = 1:numel(versions)
    e = allData(vi, refWi);
    nodataStr = strjoinSafe(e.noDataSubjectsList);
    flaggedStr = strjoinSafe(e.flaggedSubjectsList);
    fprintf(fid, '| %s | %s | %s |\n', formatVersion(e.version), nodataStr, flaggedStr);
end
fprintf(fid, '\n');

% --- Distribucion global de MHR ---
fprintf(fid, '## 3. Distribucion global de MHR\n\n');
fprintf(fid, 'Estadisticos calculados sobre todas las ventanas validas, todas las noches y todos los sujetos por version y ventana:\n\n');
fprintf(fid, '| Version | Ventana (min) | n | min | p10 | p25 | mediana | media | p75 | p90 | max | std |\n');
fprintf(fid, '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |\n');
for vi = 1:numel(versions)
    for wi = 1:numel(windowsMin)
        e = allData(vi, wi);
        s = e.globalStats;
        fprintf(fid, '| %s | %d | %d | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f |\n', ...
            formatVersion(e.version), e.window, s.n, s.min, s.p10, s.p25, s.median, s.mean, s.p75, s.p90, s.max, s.std);
    end
end
fprintf(fid, '\n');
fprintf(fid, '![MHR distribution](%s)\n\n', toMarkdownPath(fullfile(figDir, 'mhr_distribution.png'), reportDir));

% --- Variabilidad ---
fprintf(fid, '## 4. Variabilidad intra-noche y entre noches\n\n');
fprintf(fid, '| Version | Ventana | Rango medio (bpm) | Rango mediana (bpm) | Std intra-noche media (bpm) | Std intra-noche mediana (bpm) | Std entre noches medio (bpm) | Std entre noches mediano (bpm) |\n');
fprintf(fid, '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |\n');
for vi = 1:numel(versions)
    for wi = 1:numel(windowsMin)
        e = allData(vi, wi);
        ranges = e.nightlyRanges(~isnan(e.nightlyRanges));
        stds = e.nightlyStds(~isnan(e.nightlyStds));
        bnStds = e.subjectBetweenNightStds(~isnan(e.subjectBetweenNightStds));
        fprintf(fid, '| %s | %d | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f |\n', ...
            formatVersion(e.version), e.window, ...
            meanOrNaN(ranges), medianOrNaN(ranges), ...
            meanOrNaN(stds), medianOrNaN(stds), ...
            meanOrNaN(bnStds), medianOrNaN(bnStds));
    end
end
fprintf(fid, '\n');
fprintf(fid, '![Quality metrics](%s)\n\n', toMarkdownPath(fullfile(figDir, 'quality_metrics.png'), reportDir));

% --- Trayectoria nocturna ---
fprintf(fid, '## 5. Trayectoria nocturna\n\n');
fprintf(fid, '| Version | Ventana | Delta fin-inicio medio (bpm) | Delta mediana (bpm) |\n');
fprintf(fid, '| --- | ---: | ---: | ---: |\n');
for vi = 1:numel(versions)
    for wi = 1:numel(windowsMin)
        e = allData(vi, wi);
        d = e.nightlyDeltas(~isnan(e.nightlyDeltas));
        fprintf(fid, '| %s | %d | %.2f | %.2f |\n', formatVersion(e.version), e.window, meanOrNaN(d), medianOrNaN(d));
    end
end
fprintf(fid, '\n');
fprintf(fid, '![Population trajectory](%s)\n\n', toMarkdownPath(fullfile(figDir, 'population_trajectory.png'), reportDir));

% --- Comparativa entre sujetos ---
fprintf(fid, '## 6. Distribucion entre sujetos\n\n');
fprintf(fid, '![Between subjects](%s)\n\n', toMarkdownPath(fullfile(figDir, 'between_subjects.png'), reportDir));

% --- Veredicto ---
writeVerdict(fid, allData, versions, referenceWindow, windowsMin);
end

function writeVerdict(fid, allData, versions, referenceWindow, windowsMin)
wi = find(windowsMin == referenceWindow, 1);
if isempty(wi); wi = 1; end

fprintf(fid, '## 7. Veredicto sobre la usabilidad de v2\n\n');
fprintf(fid, 'Comparativa rapida en la ventana de referencia (%d min):\n\n', referenceWindow);

baselineEntry = allData(strcmp(versions, 'v1'), wi);
if isempty(baselineEntry) || isempty(baselineEntry.version)
    baselineEntry = allData(1, wi);
end

baselineRange = meanOrNaN(baselineEntry.nightlyRanges);
baselineFlaggedPct = baselineEntry.pctSubjectsArtifact;

fprintf(fid, '| Indicador | v1 | v2_1 | v2_2 | Cambio v2_1 vs v1 | Cambio v2_2 vs v1 |\n');
fprintf(fid, '| --- | ---: | ---: | ---: | ---: | ---: |\n');

vIdx_v21 = find(strcmp(versions, 'v2_1'), 1);
vIdx_v22 = find(strcmp(versions, 'v2_2'), 1);

writeIndicator(fid, 'Sujetos con datos validos (%)', allData, wi, versions, vIdx_v21, vIdx_v22, ...
    @(e) 100 * (e.nSubjects - e.nSubjectsNoData) / max(1, e.nSubjects), '%');
writeIndicator(fid, '%% sujetos artefacto', allData, wi, versions, vIdx_v21, vIdx_v22, ...
    @(e) e.pctSubjectsArtifact, '%');
writeIndicator(fid, '%% noches sin trayectoria', allData, wi, versions, vIdx_v21, vIdx_v22, ...
    @(e) e.pctNoTrajectory, '%');
writeIndicator(fid, 'Rango intra-noche medio (bpm)', allData, wi, versions, vIdx_v21, vIdx_v22, ...
    @(e) meanOrNaN(e.nightlyRanges), 'bpm');
writeIndicator(fid, 'Std intra-noche media (bpm)', allData, wi, versions, vIdx_v21, vIdx_v22, ...
    @(e) meanOrNaN(e.nightlyStds), 'bpm');
writeIndicator(fid, 'Std entre noches por sujeto (bpm)', allData, wi, versions, vIdx_v21, vIdx_v22, ...
    @(e) meanOrNaN(e.subjectBetweenNightStds), 'bpm');
fprintf(fid, '\n');

% Recomendacion automatica
v21 = allData(vIdx_v21, wi);
v22 = allData(vIdx_v22, wi);

fprintf(fid, '### Heuristicas de decision\n\n');
fprintf(fid, '- **OK**: %% sujetos artefacto < 15%% y rango intra-noche medio < 1.5 x baseline.\n');
fprintf(fid, '- **Usable con cuidado**: %% sujetos artefacto entre 15%% y 30%%, o rango intra-noche entre 1.5 x y 2 x baseline.\n');
fprintf(fid, '- **Descartar**: %% sujetos artefacto > 30%% o rango intra-noche > 2 x baseline.\n\n');

fprintf(fid, '### Resultado para v2_1 vs v1\n\n');
writeJudgement(fid, 'v2_1', v21, baselineFlaggedPct, baselineRange);

fprintf(fid, '### Resultado para v2_2 vs v1\n\n');
writeJudgement(fid, 'v2_2', v22, baselineFlaggedPct, baselineRange);

fprintf(fid, '### Caveats\n\n');
fprintf(fid, '- El umbral de %% sujetos artefacto incluye un componente que en v1 ya esta presente (PMP1074, PMP1022). Una v2 que reproduzca proporciones similares no es necesariamente peor: lo que indica degradacion adicional es un %% notablemente mas alto.\n');
fprintf(fid, '- El rango intra-noche y la std intra-noche aumentan con ruido en la deteccion de pulsos. Si v2 muestra rangos significativamente mas amplios sin que las medias cambien, es probable que el sensor PPG sea mas ruidoso.\n');
fprintf(fid, '- La std entre noches dentro del sujeto es sensible al numero de noches: la comparacion solo es justa si los sujetos tienen un numero similar de noches por version.\n');
fprintf(fid, '- Antes de descartar v2 conviene revisar visualmente los plots por sujeto en `data/<version>/hrvtd/mhr_report/subject_plots/` para los sujetos flagged.\n');
end

function writeIndicator(fid, label, allData, wi, versions, vIdx_v21, vIdx_v22, fn, unit)
v1Idx = find(strcmp(versions, 'v1'), 1);
v1Val = fn(allData(v1Idx, wi));
v21Val = fn(allData(vIdx_v21, wi));
v22Val = fn(allData(vIdx_v22, wi));
fprintf(fid, '| %s | %.2f | %.2f | %.2f | %s | %s |\n', label, v1Val, v21Val, v22Val, ...
    formatChange(v1Val, v21Val, unit), formatChange(v1Val, v22Val, unit));
end

function s = formatChange(baseline, value, unit)
if isnan(baseline) || isnan(value)
    s = '-';
    return;
end
delta = value - baseline;
if strcmp(unit, '%')
    s = sprintf('%+.1f pp', delta);
else
    relPct = 100 * delta / max(abs(baseline), eps);
    s = sprintf('%+.2f %s (%+.1f%%)', delta, unit, relPct);
end
end

function writeJudgement(fid, name, entry, baselineFlaggedPct, baselineRange)
flaggedPct = entry.pctSubjectsArtifact;
nightRange = meanOrNaN(entry.nightlyRanges);

if flaggedPct > 30 || (~isnan(nightRange) && ~isnan(baselineRange) && nightRange > 2 * baselineRange)
    verdict = 'descartar';
elseif flaggedPct > 15 || (~isnan(nightRange) && ~isnan(baselineRange) && nightRange > 1.5 * baselineRange)
    verdict = 'usable con cuidado';
else
    verdict = 'usable';
end

fprintf(fid, '- Veredicto automatico: **%s**.\n', verdict);
fprintf(fid, '- Sujetos flagged en %s: %.1f%% (vs %.1f%% en v1).\n', name, flaggedPct, baselineFlaggedPct);
if ~isnan(nightRange) && ~isnan(baselineRange)
    fprintf(fid, '- Rango intra-noche medio en %s: %.2f bpm (%.2f x el de v1).\n', name, nightRange, nightRange / max(baselineRange, eps));
end
fprintf(fid, '\n');
end


function s = formatVersion(v)
s = strrep(v, '_', '.');
end

function s = strjoinSafe(items)
if isempty(items)
    s = '-';
else
    s = strjoin(items(:)', ', ');
end
end

function m = meanOrNaN(values)
v = values(~isnan(values));
if isempty(v); m = NaN; else; m = mean(v); end
end

function m = medianOrNaN(values)
v = values(~isnan(values));
if isempty(v); m = NaN; else; m = median(v); end
end

function markdownPath = toMarkdownPath(filePath, reportDir)
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
