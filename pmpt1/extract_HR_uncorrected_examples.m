% extract_HR_uncorrected_examples.m - Re-procesa unos pocos sujetos con
% correctInterference=false. Guarda las salidas con sufijo '_uncorr' en los
% night files para poder comparar corrected vs uncorrected en los plots.
%
% Variables de workspace de entrada (opcionales):
%   examples - cell array de struct con fields:
%                 .version  ('v1' | 'v2_1' | 'v2_2')
%                 .subject  ('PMPxxxx')
%                 .nights   (vector con numeros de noche, [] = todas)
%
% NB: no hace clearvars (preserva el workspace del caller).

addpath(genpath('D:\OneDrive - unizar.es\UNIVERSIDAD\POSTDOCTORADO\biosigmat'));
addpath(genpath('C:\Users\user\OneDrive - unizar.es\UNIVERSIDAD\POSTDOCTORADO\biosigmat'));
addpath(genpath('C:\Users\user\OneDrive - unizar.es\UNIVERSIDAD\DOCTORADO\biomedical-signal-processing'));
addpath('lib');

if ~exist('examples','var') || isempty(examples)
    examples = {
        struct('version','v1',   'subject','PMP1011', 'nights', []); ...
        struct('version','v2_1', 'subject','PMP1019', 'nights', []); ...
        struct('version','v2_1', 'subject','PMP1006', 'nights', []); ...
        struct('version','v2_2', 'subject','PMP1085', 'nights', []); ...
        struct('version','v2_2', 'subject','PMP1088', 'nights', []); ...
    };
end

fs = 25.6;
segment_duration = 4 * 60 * 60;
min_duration     = 10 * 60;
Nseg = round(segment_duration * fs);
Nmin = round(min_duration * fs);

for i = 1:numel(examples)
    e = examples{i};
    versionDir = fullfile('data', e.version, 'nights');

    if isempty(e.nights)
        files = dir(fullfile(versionDir, [e.subject '_night*.mat']));
    else
        files = [];
        for n = e.nights(:)'
            cand = dir(fullfile(versionDir, sprintf('%s_night%d.mat', e.subject, n)));
            files = [files; cand]; %#ok<AGROW>
        end
    end

    fprintf('\n%s/%s: %d nights\n', e.version, e.subject, numel(files));

    for f = 1:numel(files)
        nightPath = fullfile(versionDir, files(f).name);
        data = load(nightPath, 'ppg', 't');
        ppg = data.ppg(:);
        t   = data.t(:);
        N   = numel(ppg);

        HR_all_uncorr          = [];
        tHR_all_uncorr         = [];
        qualityFlag_all_uncorr = [];
        specQuality_all_uncorr = [];
        nD_all_uncorr          = [];
        nZ_all_uncorr          = [];
        nB_all_uncorr          = [];

        num_segments = floor(N/Nseg);
        segStarts = ((1:num_segments)-1)*Nseg + 1;
        remaining = N - num_segments*Nseg;
        if remaining >= Nmin; segStarts(end+1) = N - remaining + 1; end %#ok<AGROW>

        for s = 1:numel(segStarts)
            idx_a = segStarts(s);
            idx_b = min(idx_a + Nseg - 1, N);
            segment = ppg(idx_a:idx_b);

            [HR, tHR, qF, sQ, nD, nZ, nB] = ...
                estimate_hr_segment2(segment, fs, false, false);

            offset = t(idx_a);
            HR_all_uncorr          = [HR_all_uncorr;          HR(:)];           %#ok<AGROW>
            tHR_all_uncorr         = [tHR_all_uncorr;         tHR(:) + offset]; %#ok<AGROW>
            qualityFlag_all_uncorr = [qualityFlag_all_uncorr; qF(:)];           %#ok<AGROW>
            specQuality_all_uncorr = [specQuality_all_uncorr; sQ(:)];           %#ok<AGROW>
            nD_all_uncorr = [nD_all_uncorr; nD(:) + offset]; %#ok<AGROW>
            nZ_all_uncorr = [nZ_all_uncorr; nZ(:) + offset]; %#ok<AGROW>
            nB_all_uncorr = [nB_all_uncorr; nB(:) + offset]; %#ok<AGROW>
        end

        nD_all_uncorr = sort(nD_all_uncorr(~isnan(nD_all_uncorr)));
        nZ_all_uncorr = sort(nZ_all_uncorr(~isnan(nZ_all_uncorr)));
        nB_all_uncorr = sort(nB_all_uncorr(~isnan(nB_all_uncorr)));

        save(nightPath, ...
            'HR_all_uncorr', 'tHR_all_uncorr', ...
            'qualityFlag_all_uncorr', 'specQuality_all_uncorr', ...
            'nD_all_uncorr', 'nZ_all_uncorr', 'nB_all_uncorr', '-append');

        fprintf('  %s: %d det nZ_uncorr | HR_uncorr med=%.1f\n', files(f).name, ...
            numel(nZ_all_uncorr), median(HR_all_uncorr, 'omitnan'));
    end
end

fprintf('Done.\n');
