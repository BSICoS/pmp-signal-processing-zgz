addpath(genpath('D:\OneDrive - unizar.es\UNIVERSIDAD\POSTDOCTORADO\biosigmat'));
addpath(genpath('C:\Users\user\OneDrive - unizar.es\UNIVERSIDAD\POSTDOCTORADO\biosigmat'));
addpath('lib');

config = sharedConfig();
fs = config.fs;

plotResults = true;

if ~exist('datasetVersion', 'var') || isempty(datasetVersion)
    datasetVersion = 'v1';
end

nightsDir = fullfile('data', datasetVersion, 'nights');
inputFiles = dir(fullfile(nightsDir, '*.mat'));

fprintf('Found %d pulse files in %s\n', numel(inputFiles), nightsDir);

for fileIdx = 1:numel(inputFiles)
    inputPath = fullfile(inputFiles(fileIdx).folder, inputFiles(fileIdx).name);
    fprintf('\nProcessing pulse file %d/%d: %s\n', fileIdx, numel(inputFiles), inputFiles(fileIdx).name);

    loadedData = load(inputPath);
    if ~isfield(loadedData, 'ppg')
        fprintf('  Missing ppg variable. Skipping file.\n');
        continue;
    end

    ppgRaw = loadedData.ppg(:);
    if isfield(loadedData, 't')
        t = loadedData.t(:);
    else
        t = (0:length(ppgRaw)-1)' / fs;
    end

    ppg = highpassPpg(ppgRaw, fs);
    % ppg = lowpassPpg(ppg, fs);
    [ppgClean, artifacts, artifactMatrix1, artifactMatrix2] = removeArtifacts(ppg, fs);
    [ppgDerivative, tk, threshold] = detectPulses(ppgClean, fs);

    if plotResults && sum(~isnan(tk))>=300
        tk = correctPulseResults(t, ppg, ppgClean, ppgDerivative, tk, threshold, fs, inputFiles(fileIdx).name); %#ok<*UNRCH>
    end

    % save(inputPath, 't', 'ppgRaw', 'ppg', 'ppgClean', 'ppgDerivative', 'tk', 'threshold', ...
    %     'artifacts', 'artifactMatrix1', 'artifactMatrix2');
    fprintf('  Saved processed pulse data to %s\n', inputPath);
end

function ppg = highpassPpg(ppgRaw, fs)
cutoffFreq = 0.5;
[b, a] = butter(4, cutoffFreq / (fs / 2), 'high');
ppg = filtfilt(b, a, ppgRaw);
end

% function ppg = lowpassPpg(ppgRaw, fs)
% cutoffFreq = 40;
% [b, a] = butter(4, cutoffFreq / (fs / 2), 'low');
% ppg = filtfilt(b, a, ppgRaw);
% end

function [ppgClean, artifacts, artifactMatrix1, artifactMatrix2] = removeArtifacts(ppg, fs)
plotflag = false;
seg = 4;
step = 3;
minSegmentSeparation = 15;

marginH0 = [1 1]*0.15;
marginH1 = [1 1]*0.3;
marginH2 = [1 1]*0.8;
margins = [marginH0; marginH1; marginH2];

[artifacts1, artifactMatrix1] = hjorthArtifacts(ppg ./ movstd(ppg, round(2 * fs)), ...
    fs, seg, step, margins, 'plotflag', plotflag, 'minSegmentSeparation', minSegmentSeparation);

marginH0 = [1 1]*0.15;
marginH1 = [1 1]*0.3;
marginH2 = [1 1];
margins = [marginH0; marginH1; marginH2];

[artifacts2, artifactMatrix2] = hjorthArtifacts(piecewiseNormalize(ppg, round(2 * fs)), ...
    fs, seg, step, margins, 'plotflag', plotflag, 'minSegmentSeparation', minSegmentSeparation);

artifacts = artifacts1 | artifacts2;
ppgClean = ppg;
ppgClean(logical(artifacts)) = nan;
end

function [ppgDerivative, tk, threshold] = detectPulses(ppgClean, fs)
fpLPD = 7.8;
fcLPD = 8;
orderLPD = 100;

% Upsample to fsResample just for pulse detection
fsResample = 100;
ppgCleanResampled = interp1((0:length(ppgClean)-1)' / fs, ppgClean, (0:round(length(ppgClean)*fsResample/fs)-1)' / fsResample, 'pchip');

[b, delay] = lpdfilter(fsResample, fcLPD, 'PassFreq', fpLPD, 'Order', orderLPD);
ppgDerivative = filter(b, 1, ppgCleanResampled);
ppgDerivative = [ppgDerivative(delay+1:end); zeros(delay, 1)];

refractoryPeriod = 0.3;
alphaAmp = 0.4;
tauRR = 0.8;

[tk, threshold] = pulsedetection(ppgDerivative, fsResample, ...
    'AdaptiveRefractPeriod', refractoryPeriod, 'AdaptiveAlphaAmp', alphaAmp, 'AdaptiveTauRR', tauRR);

% Downsample threshold and ppgDerivative to original fs
threshold = interp1((0:length(threshold)-1)' / fsResample, threshold, (0:length(ppgClean)-1)' / fs, 'pchip');
ppgDerivative = interp1((0:length(ppgDerivative)-1)' / fsResample, ppgDerivative, (0:length(ppgClean)-1)' / fs, 'pchip');

end