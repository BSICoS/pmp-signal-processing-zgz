% runAllReports.m - Genera todos los outputs de reporte:
%   1) data/comparison/comparison_report.md (+ figuras)
%   2) data/<v>/hrvtd/mhr_report/mhr_report_<v>_v2.md (+ figuras), per version
%   3) data/comparison/subject_plots/*.png (per subject)
% Requiere que la cascada de compute (runAllCompute.m) haya completado.
%
% Los scripts de ploteo (buildSubjectComparisonPlots.m, makePaperFigures.m)
% viven en plotting/; se anade al path para que run() los encuentre sin
% cambiar el directorio de trabajo (las rutas data/ son relativas a la raiz).

addpath('plotting');

tStart = tic;

fprintf('========== 1. compareDatasetVersionsV2 ==========\n');
try
    clearvars -except tStart
    run('compareDatasetVersionsV2.m');
catch ME
    warning('compareDatasetVersionsV2 failed: %s\n%s', ME.message, getReport(ME));
end

fprintf('\n========== 2. reportMhrEvolutionV2 ==========\n');
try
    clearvars -except tStart
    run('reportMhrEvolutionV2.m');
catch ME
    warning('reportMhrEvolutionV2 failed: %s\n%s', ME.message, getReport(ME));
end

fprintf('\n========== 3. buildSubjectComparisonPlots ==========\n');
try
    clearvars -except tStart
    run('buildSubjectComparisonPlots.m');
catch ME
    warning('buildSubjectComparisonPlots failed: %s\n%s', ME.message, getReport(ME));
end

fprintf('\n[runAllReports DONE in %.1f min]\n', toc(tStart)/60);
