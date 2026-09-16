% reportMhrEvolutionV2.m
% Report per-version: sensibilidad fiducial x ventana + (para v1) sanity
% check vs el pipeline antiguo en data/v1/hrvtd/old/.
%
% Vars de workspace (opcionales):
%   datasetVersion - 'v1' | 'v2_1' | 'v2_2'  (default loop sobre las tres)

if exist('datasetVersion', 'var') && ~isempty(datasetVersion)
    versionsToRun = {datasetVersion};
else
    versionsToRun = {'v1', 'v2_1', 'v2_2'};
end

fiducials       = {'nD', 'nZ', 'nB'};
windowsMin      = [5 10 30 60];
referenceWindow = 30;
primaryFiducial = 'nZ';

for vi = 1:numel(versionsToRun)
    v = versionsToRun{vi};
    fprintf('\n=== reportMhrEvolutionV2 %s ===\n', v);
    buildVersionReport(v, fiducials, windowsMin, primaryFiducial, referenceWindow);
end

%% ============================== per-version ==============================

function buildVersionReport(v, fiducials, windowsMin, primaryFiducial, referenceWindow)

resultsDir = fullfile('data', v, 'hrvtd');
reportDir  = fullfile(resultsDir, 'mhr_report');
figDir     = fullfile(reportDir, 'figures');
reportFile = fullfile(reportDir, sprintf('mhr_report_%s_v2.md', v));

if ~exist(reportDir, 'dir'); mkdir(reportDir); end
if ~exist(figDir, 'dir'); mkdir(figDir); end

% Load all (fiducial, window) entries
entries = repmat(emptyEntry(), numel(fiducials), numel(windowsMin));
for fi = 1:numel(fiducials)
    for wi = 1:numel(windowsMin)
        f = fullfile(resultsDir, sprintf('hrvtd_results_%s_%s_%dmin.mat', v, fiducials{fi}, windowsMin(wi)));
        if ~exist(f, 'file'), warning('missing %s', f); continue; end
        nsName = sprintf('nightSummary_%dmin', windowsMin(wi));
        neName = sprintf('nightEvolution_%dmin', windowsMin(wi));
        loaded = load(f, nsName, neName);
        entries(fi, wi) = entryFromHrvtd(v, fiducials{fi}, windowsMin(wi), ...
            loaded.(nsName), loaded.(neName));
    end
end
primaryFi = find(strcmp(fiducials, primaryFiducial), 1);

% Old pipeline (only for v1)
oldEntries = [];
if strcmp(v, 'v1')
    oldEntries = repmat(emptyEntry(), 1, numel(windowsMin));
    for wi = 1:numel(windowsMin)
        f = fullfile('data', v, 'hrvtd_oldPulseDetection', sprintf('hrvtd_results_%s_%dmin.mat', v, windowsMin(wi)));
        if ~exist(f, 'file'), continue; end
        nsName = sprintf('nightSummary_%dmin', windowsMin(wi));
        neName = sprintf('nightEvolution_%dmin', windowsMin(wi));
        loaded = load(f, nsName, neName);
        oldEntries(wi) = entryFromHrvtd([v ' (OLD)'], 'old', windowsMin(wi), ...
            loaded.(nsName), loaded.(neName));
    end
end

% Figures
fiducialBoxFile = fullfile(figDir, 'fiducial_box.png');
generateFiducialBoxFigure(entries, fiducials, windowsMin, referenceWindow, fiducialBoxFile);

popTrajFile = fullfile(figDir, sprintf('population_trajectory_%s.png', primaryFiducial));
generatePopulationTrajectoryFigure(entries(primaryFi, :), windowsMin, popTrajFile, primaryFiducial);

if strcmp(v, 'v1') && ~isempty(oldEntries)
    oldVsNewFile = fullfile(figDir, 'v1_old_vs_new.png');
    generateOldVsNewFigure(entries(primaryFi, :), oldEntries, windowsMin, oldVsNewFile, primaryFiducial);
else
    oldVsNewFile = '';
end

% Markdown
fid = fopen(reportFile, 'w');
if fid == -1, error('cannot write %s', reportFile); end
cleanupObj = onCleanup(@() fclose(fid));
assert(isobject(cleanupObj));

timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS'); %#ok<TNOW1,DATST>
fprintf(fid, '# Informe MHR nocturna - %s (V2)\n\n', upper(v));
fprintf(fid, 'Generado %s con `reportMhrEvolutionV2.m`.\n\n', timestamp);
fprintf(fid, 'Pipeline: `extract_HR_main.m` (estimate_hr_segment2, %s) -> `hrvtd.m` (fiducial parametrizado).\n\n', ...
    iif(strcmp(v,'v1'), 'sin correccion (v1 limpia)', 'correccion de interferencia'));

writeMethodsSection(fid);

%% --- Cobertura por (fiducial, ventana) ---
fprintf(fid, '## 1. Cobertura por fiducial x ventana\n\n');
fprintf(fid, '| Fiducial | Ventana | n ventanas | Sujetos | Noches | %% noches sin trayectoria | %% sujetos flagged |\n');
fprintf(fid, '| --- | ---: | ---: | ---: | ---: | ---: | ---: |\n');
for fi = 1:numel(fiducials)
    for wi = 1:numel(windowsMin)
        e = entries(fi, wi);
        if isempty(e.version), continue; end
        fprintf(fid, '| %s | %d | %d | %d | %d | %.1f | %.1f |\n', ...
            e.fiducial, e.window, e.globalStats.n, e.nSubjects, e.nNights, ...
            e.pctNoTrajectory, e.pctSubjectsArtifact);
    end
end
fprintf(fid, '\n');

%% --- Distribucion global por (fiducial, ventana) ---
fprintf(fid, '## 2. Distribucion global de MHR\n\n');
fprintf(fid, '| Fiducial | Ventana | n | min | p25 | mediana | media | p75 | max | std |\n');
fprintf(fid, '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |\n');
for fi = 1:numel(fiducials)
    for wi = 1:numel(windowsMin)
        e = entries(fi, wi); s = e.globalStats;
        if isempty(e.version), continue; end
        fprintf(fid, '| %s | %d | %d | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f |\n', ...
            e.fiducial, e.window, s.n, s.min, s.p25, s.median, s.mean, s.p75, s.max, s.std);
    end
end
fprintf(fid, '\n![Fiducial box plot](%s)\n\n', toMd(fiducialBoxFile, reportFile));

%% --- Variabilidad ---
fprintf(fid, '## 3. Variabilidad intra-noche y entre noches\n\n');
fprintf(fid, '| Fiducial | Ventana | Rango medio (bpm) | Std intra-noche media | Std entre noches medio |\n');
fprintf(fid, '| --- | ---: | ---: | ---: | ---: |\n');
for fi = 1:numel(fiducials)
    for wi = 1:numel(windowsMin)
        e = entries(fi, wi);
        if isempty(e.version), continue; end
        fprintf(fid, '| %s | %d | %.2f | %.2f | %.2f |\n', ...
            e.fiducial, e.window, ...
            meanOrNaN(e.nightlyRanges), meanOrNaN(e.nightlyStds), meanOrNaN(e.subjectBetweenNightStds));
    end
end
fprintf(fid, '\n');

%% --- Trayectoria poblacional (fiducial primario) ---
fprintf(fid, '## 4. Trayectoria poblacional MHR (fiducial %s)\n\n', primaryFiducial);
fprintf(fid, '![Population trajectory](%s)\n\n', toMd(popTrajFile, reportFile));

%% --- Sanity check vs pipeline antiguo (solo v1) ---
if strcmp(v, 'v1') && ~isempty(oldEntries)
    fprintf(fid, '## 5. Sanity check: pipeline V2 vs antiguo (v1)\n\n');
    fprintf(fid, 'El pipeline antiguo usaba `pulseDetection.m` (un detector LPD-derivada) y guardaba un solo `tk`. El nuevo pipeline usa `estimate_hr_segment2.m` + `pulseDelineation` y permite elegir nD/nZ/nB. Para v1 (sin interferencia) los numeros deberian ser similares.\n\n');
    fprintf(fid, '| Pipeline | Ventana | n | MHR mediana | MHR media | Std intra-noche media | Rango medio | %% noches sin trayectoria |\n');
    fprintf(fid, '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |\n');
    for wi = 1:numel(windowsMin)
        eOld = oldEntries(wi); eNew = entries(primaryFi, wi);
        if ~isempty(eOld.version)
            s = eOld.globalStats;
            fprintf(fid, '| OLD | %d | %d | %.2f | %.2f | %.2f | %.2f | %.1f |\n', ...
                eOld.window, s.n, s.median, s.mean, meanOrNaN(eOld.nightlyStds), ...
                meanOrNaN(eOld.nightlyRanges), eOld.pctNoTrajectory);
        end
        s = eNew.globalStats;
        fprintf(fid, '| NEW %s | %d | %d | %.2f | %.2f | %.2f | %.2f | %.1f |\n', ...
            eNew.fiducial, eNew.window, s.n, s.median, s.mean, meanOrNaN(eNew.nightlyStds), ...
            meanOrNaN(eNew.nightlyRanges), eNew.pctNoTrajectory);
    end
    fprintf(fid, '\n![Old vs new](%s)\n\n', toMd(oldVsNewFile, reportFile));
end

fprintf('Saved %s\n', reportFile);
end

%% ============================== helpers ==============================

function entry = emptyEntry()
entry = struct( ...
    'version', '', 'fiducial', '', 'window', NaN, ...
    'nightSummary', table(), 'nightEvolution', struct([]), ...
    'nSubjects', 0, 'nNights', 0, ...
    'nValidTrajectories', 0, 'pctNoTrajectory', NaN, ...
    'pctSubjectsArtifact', NaN, ...
    'nightlyMeans', [], 'nightlyRanges', [], 'nightlyStds', [], 'nightlyDeltas', [], ...
    'subjectBetweenNightStds', [], 'globalStats', emptyStats(), ...
    'populationTimeHours', [], 'populationMeanMhr', [], 'populationStdMhr', []);
end

function entry = entryFromHrvtd(version, fiducial, windowMin, nightSummary, nightEvolution)
entry = emptyEntry();
entry.version = version;
entry.fiducial = fiducial;
entry.window = windowMin;
entry.nightSummary = nightSummary;
entry.nightEvolution = nightEvolution;

allMhr = []; nightlyMeans = []; nightlyRanges = []; nightlyStds = []; nightlyDeltas = [];
nightlyValid = false(numel(nightEvolution), 1);
for ni = 1:numel(nightEvolution)
    v = nightEvolution(ni).mhr(:);
    v = v(~isnan(v));
    allMhr = [allMhr; v]; %#ok<AGROW>
    if numel(v) >= 2
        nightlyMeans(end+1, 1)  = mean(v); %#ok<AGROW>
        nightlyRanges(end+1, 1) = max(v) - min(v); %#ok<AGROW>
        nightlyStds(end+1, 1)   = std(v); %#ok<AGROW>
        nightlyDeltas(end+1, 1) = v(end) - v(1); %#ok<AGROW>
        nightlyValid(ni) = true;
    end
end
entry.globalStats = computeStats(allMhr);
entry.nightlyMeans = nightlyMeans;
entry.nightlyRanges = nightlyRanges;
entry.nightlyStds = nightlyStds;
entry.nightlyDeltas = nightlyDeltas;
entry.nNights = numel(nightEvolution);
entry.nValidTrajectories = sum(nightlyValid);
entry.pctNoTrajectory = 100 * (entry.nNights - entry.nValidTrajectories) / max(1, entry.nNights);

subjectIds = unique(nightSummary.subjectId, 'stable');
entry.nSubjects = numel(subjectIds);
subjBNstds = nan(numel(subjectIds), 1);
flagged = false(numel(subjectIds), 1);
for si = 1:numel(subjectIds)
    sid = subjectIds{si};
    mask = strcmp({nightEvolution.subjectId}, sid);
    subjEvo = nightEvolution(mask);
    subjMhr = [];
    for ni = 1:numel(subjEvo)
        subjMhr = [subjMhr; subjEvo(ni).mhr(~isnan(subjEvo(ni).mhr))]; %#ok<AGROW>
    end
    subjStat = computeStats(subjMhr);
    if subjStat.n == 0, continue; end
    if ~isnan(subjStat.median) && subjStat.median > 90, flagged(si) = true; end
    if ~isnan(subjStat.max) && subjStat.max > 130, flagged(si) = true; end
    if ~isnan(subjStat.mean) && ~isnan(subjStat.median) && abs(subjStat.mean - subjStat.median) > 10
        flagged(si) = true;
    end
    nightlyMeansForSubject = nan(numel(subjEvo), 1);
    for ni = 1:numel(subjEvo)
        sv = subjEvo(ni).mhr(:); sv = sv(~isnan(sv));
        if numel(sv) >= 2, nightlyMeansForSubject(ni) = mean(sv); end
    end
    nightlyMeansForSubject = nightlyMeansForSubject(~isnan(nightlyMeansForSubject));
    if numel(nightlyMeansForSubject) >= 2
        subjBNstds(si) = std(nightlyMeansForSubject);
    end
end
entry.subjectBetweenNightStds = subjBNstds;
entry.pctSubjectsArtifact = 100 * sum(flagged) / max(1, numel(subjectIds));

[entry.populationTimeHours, entry.populationMeanMhr, entry.populationStdMhr] = ...
    buildPopulationTrajectory(nightEvolution);
end

function [timeHours, meanMhr, stdMhr] = buildPopulationTrajectory(nightEvolution)
allTimes = [];
for ni = 1:numel(nightEvolution)
    allTimes = [allTimes; nightEvolution(ni).twindow(:)]; %#ok<AGROW>
end
timeSeconds = unique(allTimes);
meanMhr = nan(numel(timeSeconds), 1); stdMhr = nan(numel(timeSeconds), 1);
for ti = 1:numel(timeSeconds)
    samples = nan(numel(nightEvolution), 1);
    for ni = 1:numel(nightEvolution)
        nt = nightEvolution(ni).twindow(:);
        nm = nightEvolution(ni).mhr(:);
        idx = find(nt == timeSeconds(ti), 1);
        if ~isempty(idx) && ~isnan(nm(idx)), samples(ni) = nm(idx); end
    end
    valid = ~isnan(samples);
    if any(valid), meanMhr(ti) = mean(samples(valid)); end
    if sum(valid) >= 2, stdMhr(ti) = std(samples(valid)); end
end
timeHours = timeSeconds ./ 3600;
end

function s = emptyStats()
s = struct('n', 0, 'min', NaN, 'p25', NaN, 'median', NaN, 'mean', NaN, 'p75', NaN, 'max', NaN, 'std', NaN);
end

function s = computeStats(values)
v = values(~isnan(values));
if isempty(v), s = emptyStats(); return; end
s = struct('n', numel(v), 'min', min(v), 'p25', prctile(v, 25), ...
    'median', median(v), 'mean', mean(v), 'p75', prctile(v, 75), ...
    'max', max(v), 'std', std(v));
end

function m = meanOrNaN(values)
v = values(~isnan(values));
if isempty(v), m = NaN; else, m = mean(v); end
end

function out = iif(cond, a, b)
if cond, out = a; else, out = b; end
end

function generateFiducialBoxFigure(entries, fiducials, windowsMin, refWin, plotFile)
wi = find(windowsMin == refWin, 1); if isempty(wi), wi = 1; end
fig = figure('Visible', 'off', 'Position', [100 100 1100 500]);

ax1 = subplot(1, 2, 1); hold(ax1, 'on');
data = cell(numel(fiducials), 1); labels = cell(numel(fiducials), 1);
for fi = 1:numel(fiducials)
    e = entries(fi, wi);
    if isempty(e.version), data{fi} = []; labels{fi} = fiducials{fi}; continue; end
    data{fi} = e.nightlyMeans;
    labels{fi} = sprintf('%s (n=%d)', fiducials{fi}, numel(e.nightlyMeans));
end
allV = []; grp = {};
for i = 1:numel(data)
    allV = [allV; data{i}]; %#ok<AGROW>
    grp = [grp; repmat(labels(i), numel(data{i}), 1)]; %#ok<AGROW>
end
if ~isempty(allV), boxplot(ax1, allV, grp); end
title(ax1, sprintf('MHR medio nocturno por fiducial (ventana %d min)', refWin));
ylabel(ax1, 'MHR (bpm)'); grid(ax1, 'on'); ylim(ax1, [40 140]);

ax2 = subplot(1, 2, 2); hold(ax2, 'on');
colors = lines(numel(fiducials));
xPos = 1:numel(windowsMin);
barWidth = 0.25;
for fi = 1:numel(fiducials)
    pct = arrayfun(@(w) entries(fi, w).pctSubjectsArtifact, 1:numel(windowsMin));
    bar(ax2, xPos + (fi - 2) * barWidth, pct, barWidth, ...
        'FaceColor', colors(fi, :), 'DisplayName', fiducials{fi});
end
set(ax2, 'XTick', xPos, 'XTickLabel', compose('%d', windowsMin));
title(ax2, '% sujetos flagged por ventana y fiducial');
xlabel(ax2, 'Ventana (min)'); ylabel(ax2, '%');
legend(ax2, 'Location', 'best'); grid(ax2, 'on');

sgtitle('Sensibilidad fiducial');
saveFigAll(fig, plotFile); close(fig);
end

function generatePopulationTrajectoryFigure(entries, windowsMin, plotFile, fid)
fig = figure('Visible', 'off', 'Position', [100 100 1000 550]); hold on;
colors = lines(numel(windowsMin));
for wi = 1:numel(windowsMin)
    e = entries(wi);
    if isempty(e.version), continue; end
    drawMeanStdBand(gca, e.populationTimeHours, e.populationMeanMhr, e.populationStdMhr, ...
        colors(wi, :), sprintf('%d min', windowsMin(wi)), 0.15);
end
xlabel('Tiempo desde inicio del sueno (h)'); ylabel('MHR poblacional media (bpm)');
title(sprintf('Trayectoria poblacional - fiducial %s', fid));
legend('Location', 'best'); grid on; xlim([0 8]);
saveFigAll(fig, plotFile); close(fig);
end

function generateOldVsNewFigure(newEntries, oldEntries, windowsMin, plotFile, fid)
fig = figure('Visible', 'off', 'Position', [100 100 1000 550]); hold on;
colors = lines(2);
% Pick referenceWindow (30 min) or first
wi = find(windowsMin == 30, 1); if isempty(wi), wi = 1; end
if ~isempty(oldEntries(wi).version)
    drawMeanStdBand(gca, oldEntries(wi).populationTimeHours, oldEntries(wi).populationMeanMhr, ...
        oldEntries(wi).populationStdMhr, colors(1, :), 'OLD (pulseDetection.m)', 0.18);
end
if ~isempty(newEntries(wi).version)
    drawMeanStdBand(gca, newEntries(wi).populationTimeHours, newEntries(wi).populationMeanMhr, ...
        newEntries(wi).populationStdMhr, colors(2, :), sprintf('NEW (%s)', fid), 0.18);
end
xlabel('Tiempo desde inicio del sueno (h)'); ylabel('MHR poblacional media (bpm)');
title(sprintf('v1: trayectoria poblacional OLD vs NEW (ventana %d min)', windowsMin(wi)));
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

function md = toMd(filePath, reportFile)
reportDir = fileparts(reportFile);
md = strrep(relpath(filePath, reportDir), '\', '/');
end

function r = relpath(target, base)
tp = splitParts(target); bp = splitParts(base);
n = 0; m = min(numel(tp), numel(bp));
for i = 1:m
    if strcmpi(tp{i}, bp{i}), n = i; else, break; end
end
parts = [repmat({'..'}, 1, numel(bp) - n), tp(n + 1:end)];
if isempty(parts), r = '.'; else, r = strjoin(parts, filesep); end
end

function parts = splitParts(p)
p = strrep(p, '/', filesep);
parts = regexp(p, ['[^' regexptranslate('escape', filesep) ']+'], 'match');
end
