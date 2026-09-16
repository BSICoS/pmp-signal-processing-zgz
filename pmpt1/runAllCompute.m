% runAllCompute.m - Orquestador. Ejecuta secuencialmente:
%   A) compute_HR_spectral.m  para v1, v2_1, v2_2  (corrected)
%   B) extract_HR_uncorrected_examples.m  (5 sujetos, correctInterference=false)
%   C) segmentHrNights.m  (MATRIX device HR -> data/<v>/hr_nights)
%   D) run_hrvtd_sweep.m  (3 versions x 3 fiducials x 4 windows = 36 runs)
% Cada paso aisla su workspace antes de delegar al script correspondiente.

tStart = tic;

%% A) HR espectral (corrected)
for vers = ["v1", "v2_1", "v2_2"]
    fprintf('\n========== A. compute_HR_spectral %s ==========\n', vers);
    try
        clearvars -except vers tStart
        datasetVersion      = char(vers); %#ok<NASGU>
        correctInterference = ~strcmp(char(vers), 'v1'); %#ok<NASGU>
        saveSuffix          = ''; %#ok<NASGU>
        run('compute_HR_spectral.m');
    catch ME
        warning('compute_HR_spectral %s failed: %s', vers, ME.message);
    end
end

%% B) Ejemplos uncorrected
fprintf('\n========== B. extract_HR_uncorrected_examples ==========\n');
try
    clearvars -except tStart
    run('extract_HR_uncorrected_examples.m');
catch ME
    warning('extract_HR_uncorrected_examples failed: %s', ME.message);
end

%% C) MATRIX HR
fprintf('\n========== C. segmentHrNights ==========\n');
try
    clearvars -except tStart
    run('segmentHrNights.m');
catch ME
    warning('segmentHrNights failed: %s', ME.message);
end

%% D) Sweep de hrvtd
fprintf('\n========== D. run_hrvtd_sweep ==========\n');
try
    clearvars -except tStart
    run('run_hrvtd_sweep.m');
catch ME
    warning('run_hrvtd_sweep failed: %s', ME.message);
end

fprintf('\n[runAllCompute DONE in %.1f min]\n', toc(tStart)/60);
