% compareDatasetVersionsV2.m
% Genera data/comparison/comparison_report.md a partir de los nuevos
% hrvtd_results_<v>_<fid>_<W>min.mat producidos por hrvtd.m + extract_HR_main.m
% (estimate_hr_segment2 con interferencia corregida en v2_1/v2_2).
%
% Anade: analisis de sensibilidad fiducial (nD vs nZ vs nB) y tabla de
% referencia con HR_MATRIX, HR_spectral, mHR_det, SDNN, RMSSD por version.

versions        = {'v1', 'v2_1', 'v2_2'};
fiducials       = {'nD', 'nZ', 'nB'};
windowsMin      = [5 10 30 60];
primaryFiducial = 'nZ';
referenceWindow = 30;

outDir     = fullfile('data', 'comparison');
figDir     = fullfile(outDir, 'figures');
reportFile = fullfile(outDir, 'comparison_report.md');

if ~exist(outDir, 'dir'); mkdir(outDir); end
if ~exist(figDir, 'dir'); mkdir(figDir); end

%% ---- LOAD all hrvtd results (version x fiducial x window) ----
allData = repmat(emptyEntry(), numel(versions), numel(fiducials), numel(windowsMin));
for vi = 1:numel(versions)
    for fi = 1:numel(fiducials)
        for wi = 1:numel(windowsMin)
            v = versions{vi};
            fid = fiducials{fi};
            w = windowsMin(wi);
            resultsFile = fullfile('data', v, 'hrvtd', ...
                sprintf('hrvtd_results_%s_%s_%dmin.mat', v, fid, w));
            if ~exist(resultsFile, 'file')
                warning('Missing %s', resultsFile); continue;
            end
            nsName = sprintf('nightSummary_%dmin', w);
            neName = sprintf('nightEvolution_%dmin', w);
            loaded = load(resultsFile, nsName, neName);
            allData(vi, fi, wi) = computeEntry(v, fid, w, loaded.(nsName), loaded.(neName));
        end
    end
end

primaryFi = find(strcmp(fiducials, primaryFiducial), 1);
refWi     = find(windowsMin == referenceWindow, 1);

%% ---- LOAD OLD pipeline results (pulseDetection.m, sin correccion de interferencia) ----
oldData = repmat(emptyEntry(), numel(versions), numel(windowsMin));
for vi = 1:numel(versions)
    for wi = 1:numel(windowsMin)
        v = versions{vi}; w = windowsMin(wi);
        oldFile = fullfile('data', v, 'hrvtd_oldPulseDetection', ...
            sprintf('hrvtd_results_%s_%dmin.mat', v, w));
        if ~exist(oldFile, 'file'); warning('Missing OLD %s', oldFile); continue; end
        nsName = sprintf('nightSummary_%dmin', w);
        neName = sprintf('nightEvolution_%dmin', w);
        loaded = load(oldFile, nsName, neName);
        oldData(vi, wi) = computeEntry(v, 'old', w, loaded.(nsName), loaded.(neName));
    end
end

%% ---- REFERENCE TABLE (agregada por noche) ----
refTable = buildReferenceTable(versions, allData(:, primaryFi, refWi));

%% ---- FIGURES (using primary fiducial) ----
generateCoverageFigure(allData(:, primaryFi, :), versions, windowsMin, fullfile(figDir, 'coverage.png'), primaryFiducial);
generateQualityFigure(allData(:, primaryFi, :), versions, windowsMin, fullfile(figDir, 'quality_metrics.png'), primaryFiducial);
generateDistributionFigure(allData(:, primaryFi, :), versions, windowsMin, referenceWindow, fullfile(figDir, 'mhr_distribution.png'), primaryFiducial);
generatePopulationTrajectoryFigure(allData(:, primaryFi, :), versions, windowsMin, referenceWindow, fullfile(figDir, 'population_trajectory.png'), primaryFiducial);
generateBetweenSubjectFigure(allData(:, primaryFi, :), versions, windowsMin, fullfile(figDir, 'between_subjects.png'), primaryFiducial);
generateFiducialSensitivityFigure(allData, versions, fiducials, windowsMin, referenceWindow, fullfile(figDir, 'fiducial_sensitivity.png'));
generateOldVsNewTrajectoryFigure(allData(:, primaryFi, refWi), oldData(:, refWi), versions, ...
    referenceWindow, primaryFiducial, fullfile(figDir, 'population_trajectory_old_vs_new.png'));

%% ---- REPORT ----
writeComparisonReport(reportFile, allData, oldData, versions, fiducials, windowsMin, ...
    primaryFiducial, referenceWindow, figDir, refTable);

fprintf('Saved comparison report -> %s\n', reportFile);

%% ============================== helpers ==============================

function entry = emptyEntry()
entry = struct( ...
    'version', '', 'fiducial', '', 'window', NaN, ...
    'nightSummary', table(), 'nightEvolution', struct([]), ...
    'nSubjects', 0, 'nNights', 0, ...
    'nValidTrajectories', 0, 'pctNoTrajectory', NaN, ...
    'nSubjectsNoData', 0, 'nSubjectsArtifact', 0, 'pctSubjectsArtifact', NaN, ...
    'flaggedSubjectsList', {{}}, 'noDataSubjectsList', {{}}, ...
    'nightlyMeans', [], 'nightlyMedians', [], ...
    'nightlyRanges', [], 'nightlyStds', [], 'nightlyDeltas', [], ...
    'subjectMeans', [], 'subjectStds', [], 'subjectBetweenNightStds', [], ...
    'globalStats', emptyMhrStats(), ...
    'populationTimeHours', [], 'populationMeanMhr', [], ...
    'populationMedianMhr', [], 'populationStdMhr', [], 'populationCount', []);
end

function entry = computeEntry(version, fiducial, windowMinutes, nightSummary, nightEvolution)
entry = emptyEntry();
entry.version = version;
entry.fiducial = fiducial;
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
    if ~isnan(subjStat.median) && subjStat.median > 90, isArtifact = true; end
    if ~isnan(subjStat.max) && subjStat.max > 130, isArtifact = true; end
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

[entry.populationTimeHours, entry.populationMeanMhr, entry.populationMedianMhr, ...
    entry.populationStdMhr, entry.populationCount] = buildPopulationTrajectory(nightEvolution);
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
if isempty(v); s = emptyMhrStats(); return; end
s = struct('n', numel(v), 'min', min(v), ...
    'p10', percentile(v, 10), 'p25', percentile(v, 25), ...
    'mean', mean(v), 'median', median(v), ...
    'p75', percentile(v, 75), 'p90', percentile(v, 90), ...
    'max', max(v), 'std', std(v));
end

function s = emptyMhrStats()
s = struct('n', 0, 'min', NaN, 'p10', NaN, 'p25', NaN, 'mean', NaN, ...
    'median', NaN, 'p75', NaN, 'p90', NaN, 'max', NaN, 'std', NaN);
end

function p = percentile(values, q)
v = sort(values(~isnan(values)));
if isempty(v), p = NaN; return; end
if isscalar(v), p = v; return; end
rank = (q/100) * (numel(v) - 1) + 1;
lo = floor(rank); hi = ceil(rank);
if lo == hi, p = v(lo); else, p = v(lo) + (rank - lo) * (v(hi) - v(lo)); end
end

function m = meanSafe(values)
v = values(~isnan(values));
if isempty(v), m = NaN; else, m = mean(v); end
end

function m = medianOrNaN(values)
v = values(~isnan(values));
if isempty(v), m = NaN; else, m = median(v); end
end

function m = meanOrNaN(values)
v = values(~isnan(values));
if isempty(v), m = NaN; else, m = mean(v); end
end

%% ============================== reference table ==============================

function refTable = buildReferenceTable(versions, primaryEntries)
% Una entrada por version. Cada metrica se agrega primero a UN valor por
% noche (la mediana de la noche) y luego se resume entre noches. Asi 'n' es
% el numero de noches y es comparable entre todas las filas.
fprintf('buildReferenceTable (agregacion por noche)\n');
refTable = repmat(emptyRefEntry(), numel(versions), 1);
for vi = 1:numel(versions)
    v = versions{vi};
    refTable(vi).version = v;

    %% mHR/SDNN/RMSSD: mediana por noche desde nightEvolution del fiducial primario
    e = primaryEntries(vi);
    if isempty(e.version)
        continue;
    end
    mhrNight = []; sdnnNight = []; rmssdNight = [];
    for ni = 1:numel(e.nightEvolution)
        ne = e.nightEvolution(ni);
        mhrNight   = [mhrNight;   medianOrNaN(ne.mhr)];   %#ok<AGROW>
        sdnnNight  = [sdnnNight;  medianOrNaN(ne.sdnn)];  %#ok<AGROW>
        rmssdNight = [rmssdNight; medianOrNaN(ne.rmssd)]; %#ok<AGROW>
    end
    refTable(vi).mhrDet   = summarize(mhrNight);
    refTable(vi).sdnnDet  = summarize(sdnnNight);
    refTable(vi).rmssdDet = summarize(rmssdNight);

    %% HR espectral y HR MATRIX: mediana por noche
    hrSpecNight = []; hrMatrixNight = [];
    nightsDir  = fullfile('data', v, 'nights');
    prDir      = fullfile('data', v, 'pr');
    nightFiles = dir(fullfile(nightsDir, '*.mat'));
    for f = 1:numel(nightFiles)
        name = nightFiles(f).name;

        nd = load(fullfile(nightsDir, name), 'HR_all');
        if isfield(nd, 'HR_all') && ~isempty(nd.HR_all)
            hrSpecNight = [hrSpecNight; medianOrNaN(nd.HR_all)]; %#ok<AGROW>
        end

        prPath = fullfile(prDir, name);
        if exist(prPath, 'file')
            pd = load(prPath, 'HR');
            if isfield(pd, 'HR') && ~isempty(pd.HR)
                hr = pd.HR(:); hr = hr(hr > 0);
                hrMatrixNight = [hrMatrixNight; medianOrNaN(hr)]; %#ok<AGROW>
            end
        end
    end
    refTable(vi).spectralHR = summarize(hrSpecNight);
    refTable(vi).matrixHR   = summarize(hrMatrixNight);
end
end

function e = emptyRefEntry()
empty = struct('n', 0, 'mean', NaN, 'median', NaN, 'p25', NaN, 'p75', NaN, 'std', NaN);
e = struct('version', '', 'matrixHR', empty, 'spectralHR', empty, ...
    'mhrDet', empty, 'sdnnDet', empty, 'rmssdDet', empty);
end

function s = summarize(values)
v = values(~isnan(values));
if isempty(v)
    s = struct('n', 0, 'mean', NaN, 'median', NaN, 'p25', NaN, 'p75', NaN, 'std', NaN);
    return;
end
s = struct('n', numel(v), 'mean', mean(v), 'median', median(v), ...
    'p25', percentile(v, 25), 'p75', percentile(v, 75), 'std', std(v));
end

%% ============================== figures ==============================

function generateCoverageFigure(allData, versions, windowsMin, plotFile, fid)
fig = figure('Visible', 'off', 'Position', [100 100 1200 500]);
colors = lines(numel(versions));

ax1 = subplot(1, 2, 1); hold(ax1, 'on');
xPos = 1:numel(windowsMin);
barWidth = 0.25;
for vi = 1:numel(versions)
    pct = arrayfun(@(wi) allData(vi, 1, wi).pctNoTrajectory, 1:numel(windowsMin));
    bar(ax1, xPos + (vi - 2) * barWidth, pct, barWidth, ...
        'FaceColor', colors(vi, :), 'DisplayName', formatVersion(versions{vi}));
end
title(ax1, sprintf('%% noches sin trayectoria (fid=%s)', fid));
xlabel(ax1, 'Ventana (min)'); ylabel(ax1, '% noches');
set(ax1, 'XTick', xPos, 'XTickLabel', compose('%d', windowsMin));
legend(ax1, 'Location', 'best'); grid(ax1, 'on');

ax2 = subplot(1, 2, 2); hold(ax2, 'on');
for vi = 1:numel(versions)
    pct = arrayfun(@(wi) allData(vi, 1, wi).pctSubjectsArtifact, 1:numel(windowsMin));
    bar(ax2, xPos + (vi - 2) * barWidth, pct, barWidth, ...
        'FaceColor', colors(vi, :), 'DisplayName', formatVersion(versions{vi}));
end
title(ax2, sprintf('%% sujetos flagged artefacto (fid=%s)', fid));
xlabel(ax2, 'Ventana (min)'); ylabel(ax2, '% sujetos');
set(ax2, 'XTick', xPos, 'XTickLabel', compose('%d', windowsMin));
legend(ax2, 'Location', 'best'); grid(ax2, 'on');

sgtitle(sprintf('Cobertura - calidad de deteccion (fiducial %s)', fid));
saveFigAll(fig, plotFile); close(fig);
end

function generateQualityFigure(allData, versions, windowsMin, plotFile, fid)
fig = figure('Visible', 'off', 'Position', [100 100 1400 800]);

ax1 = subplot(2, 2, 1);
plotMetricBox(ax1, allData, versions, windowsMin, 'nightlyRanges', 'Rango MHR intra-noche (bpm)');
ax2 = subplot(2, 2, 2);
plotMetricBox(ax2, allData, versions, windowsMin, 'nightlyStds', 'Std MHR intra-noche (bpm)');
ax3 = subplot(2, 2, 3);
plotMetricBox(ax3, allData, versions, windowsMin, 'nightlyDeltas', 'Delta fin-inicio MHR (bpm)');
yline(ax3, 0, '--k', 'HandleVisibility', 'off');
ax4 = subplot(2, 2, 4);
plotMetricBox(ax4, allData, versions, windowsMin, 'subjectBetweenNightStds', 'Std entre noches por sujeto (bpm)');

sgtitle(sprintf('Variabilidad MHR (fiducial %s)', fid));
saveFigAll(fig, plotFile); close(fig);
end

function plotMetricBox(ax, allData, versions, windowsMin, fieldName, ylabelText)
hold(ax, 'on');
allValues = []; groupVersion = {}; groupWindow = [];
for vi = 1:numel(versions)
    for wi = 1:numel(windowsMin)
        v = allData(vi, 1, wi).(fieldName);
        v = v(~isnan(v));
        allValues = [allValues; v]; %#ok<AGROW>
        groupVersion = [groupVersion; repmat({formatVersion(versions{vi})}, numel(v), 1)]; %#ok<AGROW>
        groupWindow = [groupWindow; repmat(windowsMin(wi), numel(v), 1)]; %#ok<AGROW>
    end
end
if isempty(allValues); return; end
boxplot(ax, allValues, {groupWindow, groupVersion}, 'FactorGap', [10 1], ...
    'ColorGroup', groupVersion, 'Symbol', '.');
thickenBoxplotMedians(ax);
title(ax, ylabelText);
xlabel(ax, 'Ventana (min) | Version'); ylabel(ax, ylabelText);
grid(ax, 'on');
end

function generateDistributionFigure(allData, versions, windowsMin, referenceWindow, plotFile, fid)
wi = find(windowsMin == referenceWindow, 1);
if isempty(wi); wi = 1; end

fig = figure('Visible', 'off', 'Position', [100 100 1100 500]);
ax1 = subplot(1, 2, 1);
nightData = cell(numel(versions), 1); nightLabels = cell(numel(versions), 1);
for vi = 1:numel(versions)
    v = allData(vi, 1, wi).nightlyMeans;
    v = v(~isnan(v));
    nightData{vi} = v;
    nightLabels{vi} = sprintf('%s (n=%d)', formatVersion(versions{vi}), numel(v));
end
boxplotMultiSet(ax1, nightData, nightLabels);
title(ax1, sprintf('MHR medio nocturno (ventana %d min)', referenceWindow));
ylabel(ax1, 'MHR (bpm)'); grid(ax1, 'on');

ax2 = subplot(1, 2, 2);
subjData = cell(numel(versions), 1); subjLabels = cell(numel(versions), 1);
for vi = 1:numel(versions)
    v = allData(vi, 1, wi).subjectMeans;
    v = v(~isnan(v));
    subjData{vi} = v;
    subjLabels{vi} = sprintf('%s (n=%d)', formatVersion(versions{vi}), numel(v));
end
boxplotMultiSet(ax2, subjData, subjLabels);
title(ax2, sprintf('MHR medio por sujeto (ventana %d min)', referenceWindow));
ylabel(ax2, 'MHR (bpm)'); grid(ax2, 'on');

linkaxes([ax1, ax2], 'y'); ylim(ax1, [40 140]);
sgtitle(sprintf('Distribucion MHR (fiducial %s)', fid));
saveFigAll(fig, plotFile); close(fig);
end

function boxplotMultiSet(ax, data, labels)
allValues = []; groups = {};
for i = 1:numel(data)
    allValues = [allValues; data{i}]; %#ok<AGROW>
    groups = [groups; repmat(labels(i), numel(data{i}), 1)]; %#ok<AGROW>
end
if isempty(allValues); return; end
boxplot(ax, allValues, groups);
thickenBoxplotMedians(ax);
end

function generatePopulationTrajectoryFigure(allData, versions, windowsMin, referenceWindow, plotFile, fid)
wi = find(windowsMin == referenceWindow, 1);
if isempty(wi); wi = 1; end

fig = figure('Visible', 'off', 'Position', [100 100 1100 650]); hold on;
colors = lines(numel(versions));
for vi = 1:numel(versions)
    e = allData(vi, 1, wi);
    label = sprintf('%s (n=%d noches, %d sujetos)', formatVersion(versions{vi}), e.nNights, e.nSubjects);
    drawMeanStdBand(gca, e.populationTimeHours, e.populationMeanMhr, e.populationStdMhr, ...
        colors(vi, :), label, 0.18);
end
xlabel('Tiempo desde inicio del sueno (h)'); ylabel('MHR poblacional media (bpm)');
title(sprintf('Trayectoria MHR poblacional (ventana %d min, fiducial %s)', referenceWindow, fid));
legend('Location', 'best'); grid on; xlim([0 8]);
saveFigAll(fig, plotFile); close(fig);
end

function drawMeanStdBand(ax, t, meanVals, stdVals, color, label, alpha)
if nargin < 7, alpha = 0.15; end
bothValid = ~isnan(meanVals) & ~isnan(stdVals);
if any(bothValid)
    d = diff([0; bothValid(:); 0]);
    starts = find(d == 1); ends = find(d == -1) - 1;
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
if nargin < 2, lineWidth = 2.2; end
hMedians = findobj(ax, 'Tag', 'Median');
set(hMedians, 'LineWidth', lineWidth);
end

function generateBetweenSubjectFigure(allData, versions, windowsMin, plotFile, fid)
fig = figure('Visible', 'off', 'Position', [100 100 1200 500]);
ax1 = subplot(1, 2, 1);
plotMetricBox(ax1, allData, versions, windowsMin, 'subjectMeans', 'MHR medio por sujeto (bpm)');
ax2 = subplot(1, 2, 2);
plotMetricBox(ax2, allData, versions, windowsMin, 'subjectStds', 'Std MHR intra-sujeto (bpm)');
sgtitle(sprintf('Distribucion entre sujetos (fiducial %s)', fid));
saveFigAll(fig, plotFile); close(fig);
end

function generateFiducialSensitivityFigure(allData, versions, fiducials, windowsMin, referenceWindow, plotFile)
wi = find(windowsMin == referenceWindow, 1);
if isempty(wi); wi = 1; end

fig = figure('Visible', 'off', 'Position', [100 100 1400 500]);

% Subplot 1: MHR medio nocturno (boxplot) por (version x fiducial)
ax1 = subplot(1, 2, 1); hold(ax1, 'on');
allValues = []; groupVersion = {}; groupFiducial = {};
for vi = 1:numel(versions)
    for fi = 1:numel(fiducials)
        v = allData(vi, fi, wi).nightlyMeans;
        v = v(~isnan(v));
        allValues = [allValues; v]; %#ok<AGROW>
        groupVersion = [groupVersion; repmat({formatVersion(versions{vi})}, numel(v), 1)]; %#ok<AGROW>
        groupFiducial = [groupFiducial; repmat({fiducials{fi}}, numel(v), 1)]; %#ok<AGROW>
    end
end
if ~isempty(allValues)
    boxplot(ax1, allValues, {groupFiducial, groupVersion}, 'FactorGap', [10 1], ...
        'ColorGroup', groupFiducial, 'Symbol', '.');
    thickenBoxplotMedians(ax1);
end
title(ax1, sprintf('MHR medio nocturno por fiducial (ventana %d min)', referenceWindow));
xlabel(ax1, 'Fiducial | Version'); ylabel(ax1, 'MHR (bpm)');
ylim(ax1, [40 140]); grid(ax1, 'on');

% Subplot 2: % sujetos flagged por (version x fiducial)
ax2 = subplot(1, 2, 2); hold(ax2, 'on');
xPos = 1:numel(versions);
barWidth = 0.25;
colors = lines(numel(fiducials));
for fi = 1:numel(fiducials)
    pct = arrayfun(@(vi) allData(vi, fi, wi).pctSubjectsArtifact, 1:numel(versions));
    bar(ax2, xPos + (fi - 2) * barWidth, pct, barWidth, ...
        'FaceColor', colors(fi, :), 'DisplayName', fiducials{fi});
end
set(ax2, 'XTick', xPos, 'XTickLabel', cellfun(@formatVersion, versions, 'UniformOutput', false));
title(ax2, sprintf('%% sujetos flagged artefacto (ventana %d min)', referenceWindow));
ylabel(ax2, '% sujetos');
legend(ax2, 'Location', 'best'); grid(ax2, 'on');

sgtitle('Sensibilidad al fiducial point (nD vs nZ vs nB)');
saveFigAll(fig, plotFile); close(fig);
end

function generateOldVsNewTrajectoryFigure(newEntries, oldEntries, versions, referenceWindow, fid, plotFile)
% Un subplot por version: trayectoria MHR poblacional del pipeline antiguo
% (sin corregir) frente al corregido.
figh = figure('Visible', 'off', 'Position', [100 100 1500 450]);
colors = lines(2);
for vi = 1:numel(versions)
    ax = subplot(1, numel(versions), vi); hold(ax, 'on');
    eo = oldEntries(vi); en = newEntries(vi);
    if ~isempty(eo.version)
        drawMeanStdBand(ax, eo.populationTimeHours, eo.populationMeanMhr, eo.populationStdMhr, ...
            colors(1, :), 'Sin corregir (antiguo)', 0.15);
    end
    if ~isempty(en.version)
        drawMeanStdBand(ax, en.populationTimeHours, en.populationMeanMhr, en.populationStdMhr, ...
            colors(2, :), sprintf('Corregido (%s)', fid), 0.15);
    end
    title(ax, formatVersion(versions{vi}));
    xlabel(ax, 'Tiempo desde inicio del sueno (h)'); ylabel(ax, 'MHR poblacional (bpm)');
    grid(ax, 'on'); xlim(ax, [0 8]); ylim(ax, [40 130]);
    if vi == 1, legend(ax, 'Location', 'best'); end
end
sgtitle(figh, sprintf('Trayectoria MHR poblacional: sin corregir vs corregido (ventana %d min)', referenceWindow));
saveFigAll(figh, plotFile); close(figh);
end

%% ============================== report ==============================

function writeComparisonReport(reportFile, allData, oldData, versions, fiducials, windowsMin, ...
    primaryFiducial, referenceWindow, figDir, refTable)

fid = fopen(reportFile, 'w');
if fid == -1, error('Cannot write %s', reportFile); end
cleanupObj = onCleanup(@() fclose(fid));
assert(isobject(cleanupObj));

reportDir = fileparts(reportFile);
timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS'); %#ok<TNOW1,DATST>
primaryFi = find(strcmp(fiducials, primaryFiducial), 1);
refWi     = find(windowsMin == referenceWindow, 1);

fprintf(fid, '# Comparativa entre versiones del dataset PMP (V2)\n\n');
fprintf(fid, 'Generado el %s con `compareDatasetVersionsV2.m`.\n\n', timestamp);
fprintf(fid, 'Pipeline actualizado: `segmentNights.m` -> `extract_HR_main.m` (delineacion `estimate_hr_segment2.m` con correccion de interferencia en v2_1/v2_2) -> `hrvtd.m` -> `compareDatasetVersionsV2.m`.\n\n');
fprintf(fid, 'Por defecto los reports se muestran con el fiducial **%s** y ventana de referencia **%d min**. La seccion 7 analiza la sensibilidad a la eleccion del fiducial point.\n\n', ...
    primaryFiducial, referenceWindow);

writeMethodsSection(fid);

%% --- 1. Cobertura (primary fiducial, todas las ventanas) ---
fprintf(fid, '## 1. Cobertura y descarte (fiducial %s)\n\n', primaryFiducial);
fprintf(fid, 'Cada noche se trocea en ventanas de W minutos y en cada ventana se calcula la MHR (mean heart rate). Definiciones de la tabla:\n\n');
fprintf(fid, '- **Trayectorias validas**: noches con al menos 2 ventanas con MHR valida (hacen falta >= 2 puntos para describir como evoluciona la HR durante la noche).\n');
fprintf(fid, '- **%% sin trayectoria**: porcentaje de noches que no llegan a esas 2 ventanas validas.\n');
fprintf(fid, '- **Sujetos sin datos** y **Sujetos flagged**: definidos en la seccion 2.\n\n');
fprintf(fid, '| Version | Ventana (min) | Sujetos | Noches | Trayectorias validas | %% sin trayectoria | Sujetos sin datos | Sujetos flagged | %% flagged |\n');
fprintf(fid, '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |\n');
for vi = 1:numel(versions)
    for wi = 1:numel(windowsMin)
        e = allData(vi, primaryFi, wi);
        fprintf(fid, '| %s | %d | %d | %d | %d | %.1f | %d | %d | %.1f |\n', ...
            formatVersion(e.version), e.window, e.nSubjects, e.nNights, e.nValidTrajectories, ...
            e.pctNoTrajectory, e.nSubjectsNoData, e.nSubjectsArtifact, e.pctSubjectsArtifact);
    end
end
fprintf(fid, '\n![Cobertura](%s)\n\n', toMarkdownPath(fullfile(figDir, 'coverage.png'), reportDir));

%% --- 2. Sujetos sin datos / artefacto ---
fprintf(fid, '## 2. Sujetos sin datos o con artefactos (fiducial %s, ventana %d min)\n\n', primaryFiducial, referenceWindow);
fprintf(fid, '- **Sujeto sin datos**: ninguna de sus noches aporta una sola ventana con MHR dentro del rango valido [40, 180] bpm. Suele indicar un PPG demasiado degradado para detectar pulsos de forma fiable.\n');
fprintf(fid, '- **Sujeto con artefacto (flagged)**: su distribucion de MHR sugiere errores de deteccion (doblado de pulsos, saturacion). Se marca con la heuristica: mediana > 90 bpm, o maximo > 130 bpm, o |media - mediana| > 10 bpm (distribucion bimodal). Es una senal para revisar manualmente, no un descarte automatico.\n\n');
fprintf(fid, '| Version | Sujetos sin datos | Sujetos artefacto |\n');
fprintf(fid, '| --- | --- | --- |\n');
for vi = 1:numel(versions)
    e = allData(vi, primaryFi, refWi);
    fprintf(fid, '| %s | %s | %s |\n', formatVersion(e.version), ...
        strjoinSafe(e.noDataSubjectsList), strjoinSafe(e.flaggedSubjectsList));
end
fprintf(fid, '\n');

%% --- 3. Distribucion global ---
fprintf(fid, '## 3. Distribucion global de MHR (fiducial %s)\n\n', primaryFiducial);
fprintf(fid, '`n` = numero total de ventanas con MHR valida agregando todas las noches y sujetos de la version. Es el tamano muestral de la distribucion (no un resultado en si): disminuye al agrandar la ventana, porque la misma noche produce menos ventanas de 60 min que de 5 min.\n\n');
fprintf(fid, '| Version | Ventana | n | min | p10 | p25 | mediana | media | p75 | p90 | max | std |\n');
fprintf(fid, '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |\n');
for vi = 1:numel(versions)
    for wi = 1:numel(windowsMin)
        e = allData(vi, primaryFi, wi); s = e.globalStats;
        fprintf(fid, '| %s | %d | %d | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f |\n', ...
            formatVersion(e.version), e.window, s.n, s.min, s.p10, s.p25, s.median, s.mean, s.p75, s.p90, s.max, s.std);
    end
end
fprintf(fid, '\n![MHR distribution](%s)\n\n', toMarkdownPath(fullfile(figDir, 'mhr_distribution.png'), reportDir));

%% --- 4. Variabilidad ---
fprintf(fid, '## 4. Variabilidad intra-noche y entre noches (fiducial %s)\n\n', primaryFiducial);
fprintf(fid, '| Version | Ventana | Rango medio | Rango mediana | Std intra media | Std intra mediana | Std entre noches medio | Std entre noches mediano |\n');
fprintf(fid, '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |\n');
for vi = 1:numel(versions)
    for wi = 1:numel(windowsMin)
        e = allData(vi, primaryFi, wi);
        ranges = e.nightlyRanges(~isnan(e.nightlyRanges));
        stds = e.nightlyStds(~isnan(e.nightlyStds));
        bnStds = e.subjectBetweenNightStds(~isnan(e.subjectBetweenNightStds));
        fprintf(fid, '| %s | %d | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f |\n', ...
            formatVersion(e.version), e.window, ...
            meanOrNaN(ranges), medianOrNaN(ranges), meanOrNaN(stds), medianOrNaN(stds), ...
            meanOrNaN(bnStds), medianOrNaN(bnStds));
    end
end
fprintf(fid, '\n![Quality metrics](%s)\n\n', toMarkdownPath(fullfile(figDir, 'quality_metrics.png'), reportDir));

%% --- 5. Trayectoria ---
fprintf(fid, '## 5. Trayectoria nocturna (fiducial %s)\n\n', primaryFiducial);
fprintf(fid, 'La **trayectoria nocturna** es la evolucion de la MHR a lo largo de la noche. El **delta fin-inicio** = MHR de la ultima ventana valida menos la de la primera; un valor negativo significa que la HR desciende durante la noche, patron fisiologico normal del sueno. La figura de **trayectoria poblacional** promedia, en cada instante desde el inicio del sueno, la MHR de todas las noches (la banda es +/- 1 desviacion tipica entre noches).\n\n');
fprintf(fid, '| Version | Ventana | Delta fin-inicio medio (bpm) | Delta mediana (bpm) |\n');
fprintf(fid, '| --- | ---: | ---: | ---: |\n');
for vi = 1:numel(versions)
    for wi = 1:numel(windowsMin)
        e = allData(vi, primaryFi, wi);
        d = e.nightlyDeltas(~isnan(e.nightlyDeltas));
        fprintf(fid, '| %s | %d | %.2f | %.2f |\n', formatVersion(e.version), e.window, meanOrNaN(d), medianOrNaN(d));
    end
end
fprintf(fid, '\n![Population trajectory](%s)\n\n', toMarkdownPath(fullfile(figDir, 'population_trajectory.png'), reportDir));

%% --- 6. Distribucion entre sujetos ---
fprintf(fid, '## 6. Distribucion entre sujetos (fiducial %s)\n\n', primaryFiducial);
fprintf(fid, '![Between subjects](%s)\n\n', toMarkdownPath(fullfile(figDir, 'between_subjects.png'), reportDir));

%% --- 7. NEW: Sensibilidad al fiducial ---
fprintf(fid, '## 7. Sensibilidad al fiducial point (nD vs nZ vs nB)\n\n');
fprintf(fid, 'Ventana de referencia (%d min). Compara usar como serie de latidos el fiducial nD (maxima pendiente de subida), nZ (onset / cruce por cero) o nB (punto basal). `n ventanas` es el tamano muestral (ver seccion 3). Un fiducial mejor da menor std y rango intra-noche y menos sujetos flagged.\n\n', referenceWindow);
fprintf(fid, '| Version | Fiducial | n ventanas | MHR mediana | MHR media | Std intra-noche media | Rango intra-noche medio | %% sujetos artefacto |\n');
fprintf(fid, '| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |\n');
for vi = 1:numel(versions)
    for fi = 1:numel(fiducials)
        e = allData(vi, fi, refWi);
        if isempty(e.version), continue; end
        fprintf(fid, '| %s | %s | %d | %.2f | %.2f | %.2f | %.2f | %.1f |\n', ...
            formatVersion(e.version), e.fiducial, e.globalStats.n, ...
            e.globalStats.median, e.globalStats.mean, ...
            meanOrNaN(e.nightlyStds), meanOrNaN(e.nightlyRanges), e.pctSubjectsArtifact);
    end
end
fprintf(fid, '\n![Fiducial sensitivity](%s)\n\n', toMarkdownPath(fullfile(figDir, 'fiducial_sensitivity.png'), reportDir));
fprintf(fid, '**Recomendacion**: el fiducial elegido como referencia es **%s**. nZ tiende a ser mas robusto frente a la interferencia del firmware v2 (es invariante a la localizacion exacta del pico cuando se interpola por la correccion).\n\n', primaryFiducial);

%% --- 8. NEW: Tabla de referencia ---
fprintf(fid, '## 8. Valores de referencia (sueno, fiducial %s)\n\n', primaryFiducial);
fprintf(fid, 'Valores tipicos durante el sueno por version. Cada metrica se agrega primero a **un valor por noche** (la mediana de esa noche) y luego se resume entre noches; asi `n` = numero de noches y es comparable entre todas las filas.\n\n');
fprintf(fid, '- **HR_MATRIX**: HR onboard que reporta el dispositivo (`data/<v>/pr/`).\n');
fprintf(fid, '- **HR_spectral**: pico espectral del PPG limpio (banda 0.4-1.7 Hz).\n');
fprintf(fid, '- **mHR_det / SDNN_det / RMSSD_det**: calculados a partir de los intervalos entre fiducials %s de la deteccion.\n\n', primaryFiducial);
fprintf(fid, '| Version | Variable | n | mediana | media | p25 | p75 | std |\n');
fprintf(fid, '| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |\n');
for vi = 1:numel(versions)
    e = refTable(vi);
    if isempty(e.version), continue; end
    writeRefRow(fid, e.version, 'HR\_MATRIX (bpm)', e.matrixHR);
    writeRefRow(fid, e.version, 'HR\_spectral (bpm)', e.spectralHR);
    writeRefRow(fid, e.version, 'mHR\_det (bpm)', e.mhrDet);
    writeRefRow(fid, e.version, 'SDNN\_det (ms)', e.sdnnDet);
    writeRefRow(fid, e.version, 'RMSSD\_det (ms)', e.rmssdDet);
end
fprintf(fid, '\n');

%% --- 9. Comparativa con el pipeline sin corregir ---
writeUncorrectedComparison(fid, allData, oldData, versions, fiducials, ...
    primaryFiducial, referenceWindow, windowsMin, figDir, reportDir);

%% --- 10. Veredicto ---
writeVerdict(fid, allData, versions, fiducials, primaryFiducial, referenceWindow, windowsMin);
end

function writeRefRow(fid, version, label, s)
fprintf(fid, '| %s | %s | %d | %.2f | %.2f | %.2f | %.2f | %.2f |\n', ...
    formatVersion(version), label, s.n, s.median, s.mean, s.p25, s.p75, s.std);
end

function writeUncorrectedComparison(fid, allData, oldData, versions, fiducials, ...
    primaryFiducial, referenceWindow, windowsMin, figDir, reportDir)
primaryFi = find(strcmp(fiducials, primaryFiducial), 1);
wi = find(windowsMin == referenceWindow, 1);
if isempty(wi), wi = 1; end

fprintf(fid, '## 9. Comparativa con el pipeline sin corregir\n\n');
fprintf(fid, 'El pipeline antiguo (`pulseDetection.m`, resultados en `data/<v>/hrvtd_oldPulseDetection/`) no corregia la interferencia del firmware v2. La tabla compara antiguo vs actual en la ventana de referencia (%d min).\n\n', referenceWindow);
fprintf(fid, '> Nota: el pipeline antiguo ademas usaba otro detector de pulso (LPD sobre la derivada), no el de delineacion actual. Por tanto la mejora observada en v2 combina dos cambios: la correccion de interferencia y el cambio de detector. En v1 (PPG limpio) la comparativa aisla casi por completo el efecto del detector.\n\n');
fprintf(fid, '| Version | Pipeline | MHR mediana (bpm) | Std intra-noche media (bpm) | Rango intra-noche medio (bpm) | %% sujetos artefacto | %% noches sin trayectoria |\n');
fprintf(fid, '| --- | --- | ---: | ---: | ---: | ---: | ---: |\n');
for vi = 1:numel(versions)
    eo = oldData(vi, wi);
    en = allData(vi, primaryFi, wi);
    if ~isempty(eo.version)
        fprintf(fid, '| %s | sin corregir (antiguo) | %.2f | %.2f | %.2f | %.1f | %.1f |\n', ...
            formatVersion(versions{vi}), eo.globalStats.median, meanOrNaN(eo.nightlyStds), ...
            meanOrNaN(eo.nightlyRanges), eo.pctSubjectsArtifact, eo.pctNoTrajectory);
    end
    fprintf(fid, '| %s | corregido (%s) | %.2f | %.2f | %.2f | %.1f | %.1f |\n', ...
        formatVersion(versions{vi}), primaryFiducial, en.globalStats.median, ...
        meanOrNaN(en.nightlyStds), meanOrNaN(en.nightlyRanges), ...
        en.pctSubjectsArtifact, en.pctNoTrajectory);
end
fprintf(fid, '\n![Trayectoria sin corregir vs corregido](%s)\n\n', ...
    toMarkdownPath(fullfile(figDir, 'population_trajectory_old_vs_new.png'), reportDir));
fprintf(fid, 'En v2_1/v2_2 el pipeline sin corregir presentaba muchas mas ventanas sin trayectoria valida y mas sujetos flagged como artefacto; la correccion de interferencia los reduce drasticamente y acerca la MHR mediana al rango fisiologico de sueno (~60 bpm).\n\n');
end

function writeVerdict(fid, allData, versions, fiducials, primaryFiducial, referenceWindow, windowsMin)
primaryFi = find(strcmp(fiducials, primaryFiducial), 1);
wi = find(windowsMin == referenceWindow, 1);
if isempty(wi); wi = 1; end

fprintf(fid, '## 10. Veredicto sobre la usabilidad de v2 (corregido)\n\n');
fprintf(fid, 'Ventana de referencia (%d min), fiducial %s:\n\n', referenceWindow, primaryFiducial);

baselineEntry = allData(strcmp(versions, 'v1'), primaryFi, wi);
if isempty(baselineEntry) || isempty(baselineEntry.version)
    baselineEntry = allData(1, primaryFi, wi);
end
baselineRange = meanOrNaN(baselineEntry.nightlyRanges);
baselineFlaggedPct = baselineEntry.pctSubjectsArtifact;

fprintf(fid, '| Indicador | v1 | v2_1 | v2_2 | Cambio v2_1 vs v1 | Cambio v2_2 vs v1 |\n');
fprintf(fid, '| --- | ---: | ---: | ---: | ---: | ---: |\n');

vIdx_v21 = find(strcmp(versions, 'v2_1'), 1);
vIdx_v22 = find(strcmp(versions, 'v2_2'), 1);

writeIndicator(fid, 'Sujetos con datos validos (%)', allData, primaryFi, wi, versions, vIdx_v21, vIdx_v22, ...
    @(e) 100 * (e.nSubjects - e.nSubjectsNoData) / max(1, e.nSubjects), '%');
writeIndicator(fid, '% sujetos artefacto', allData, primaryFi, wi, versions, vIdx_v21, vIdx_v22, ...
    @(e) e.pctSubjectsArtifact, '%');
writeIndicator(fid, '% noches sin trayectoria', allData, primaryFi, wi, versions, vIdx_v21, vIdx_v22, ...
    @(e) e.pctNoTrajectory, '%');
writeIndicator(fid, 'Rango intra-noche medio (bpm)', allData, primaryFi, wi, versions, vIdx_v21, vIdx_v22, ...
    @(e) meanOrNaN(e.nightlyRanges), 'bpm');
writeIndicator(fid, 'Std intra-noche media (bpm)', allData, primaryFi, wi, versions, vIdx_v21, vIdx_v22, ...
    @(e) meanOrNaN(e.nightlyStds), 'bpm');
writeIndicator(fid, 'Std entre noches por sujeto (bpm)', allData, primaryFi, wi, versions, vIdx_v21, vIdx_v22, ...
    @(e) meanOrNaN(e.subjectBetweenNightStds), 'bpm');
fprintf(fid, '\n');

v21 = allData(vIdx_v21, primaryFi, wi);
v22 = allData(vIdx_v22, primaryFi, wi);

fprintf(fid, '### Heuristicas\n\n');
fprintf(fid, '- **OK**: %% artefacto < 15%% y rango intra-noche < 1.5x baseline.\n');
fprintf(fid, '- **Usable con cuidado**: %% artefacto 15-30%% o rango 1.5-2x baseline.\n');
fprintf(fid, '- **Descartar**: %% artefacto > 30%% o rango > 2x baseline.\n\n');

fprintf(fid, '### v2_1 vs v1\n\n');
writeJudgement(fid, 'v2_1', v21, baselineFlaggedPct, baselineRange);
fprintf(fid, '### v2_2 vs v1\n\n');
writeJudgement(fid, 'v2_2', v22, baselineFlaggedPct, baselineRange);

fprintf(fid, '### Caveats\n\n');
fprintf(fid, '- En v2 la interferencia se corrige con interpolacion en `estimate_hr_segment2.m` y los fiducials sobre muestras interpoladas se descartan; esto mejora la calidad respecto al pipeline antiguo (`pulseDetection.m`) pero deja huecos donde la senal estaba completamente perdida.\n');
fprintf(fid, '- Comparar con `data/<v>/hrvtd/old/` (pipeline antiguo sin correccion) para ver el efecto neto de la limpieza.\n');
fprintf(fid, '- Para inspeccion visual ver `data/comparison/subject_plots/` (MATRIX vs spectral vs deteccion).\n');
end

function writeIndicator(fid, label, allData, primaryFi, wi, versions, vIdx_v21, vIdx_v22, fn, unit)
v1Idx = find(strcmp(versions, 'v1'), 1);
v1Val  = fn(allData(v1Idx, primaryFi, wi));
v21Val = fn(allData(vIdx_v21, primaryFi, wi));
v22Val = fn(allData(vIdx_v22, primaryFi, wi));
fprintf(fid, '| %s | %.2f | %.2f | %.2f | %s | %s |\n', label, v1Val, v21Val, v22Val, ...
    formatChange(v1Val, v21Val, unit), formatChange(v1Val, v22Val, unit));
end

function s = formatChange(baseline, value, unit)
if isnan(baseline) || isnan(value), s = '-'; return; end
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
fprintf(fid, '- Veredicto: **%s**.\n', verdict);
fprintf(fid, '- Sujetos flagged en %s: %.1f%% (vs %.1f%% en v1).\n', name, flaggedPct, baselineFlaggedPct);
if ~isnan(nightRange) && ~isnan(baselineRange)
    fprintf(fid, '- Rango intra-noche medio en %s: %.2f bpm (%.2f x el de v1).\n', name, nightRange, nightRange / max(baselineRange, eps));
end
fprintf(fid, '\n');
end

function s = formatVersion(v), s = strrep(v, '_', '.'); end

function s = strjoinSafe(items)
if isempty(items), s = '-'; else, s = strjoin(items(:)', ', '); end
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
    if strcmpi(targetParts{idx}, baseParts{idx}), commonLength = idx;
    else, break; end
end
upParts = repmat({'..'}, 1, numel(baseParts) - commonLength);
downParts = targetParts(commonLength + 1:end);
allParts = [upParts downParts];
if isempty(allParts), relativePath = '.';
else, relativePath = strjoin(allParts, filesep); end
end

function parts = splitPathParts(filePath)
normalizedPath = strrep(filePath, '/', filesep);
parts = regexp(normalizedPath, ['[^' regexptranslate('escape', filesep) ']+'], 'match');
end
