% run_hrvtd_sweep.m - Corre hrvtd.m para todas las combinaciones
% de version x fiducial x ventana. Idempotente: cada salida se guarda en
% data/<v>/hrvtd/hrvtd_results_<v>_<fid>_<W>min.mat.

versions  = {'v1', 'v2_1', 'v2_2'};
fiducials = {'nD', 'nZ', 'nB'};
windows   = [5*60, 10*60, 30*60, 60*60];  % segundos

t0 = tic;
for vi = 1:numel(versions)
    for fi = 1:numel(fiducials)
        for wi = 1:numel(windows)
            datasetVersion = versions{vi};   %#ok<NASGU>
            fiducial       = fiducials{fi};  %#ok<NASGU>
            segmentSeconds = windows(wi);    %#ok<NASGU>
            fprintf('\n=== %s x %s x %d min ===\n', versions{vi}, fiducials{fi}, windows(wi)/60);
            run('hrvtd.m');
        end
    end
end
fprintf('\nSweep done in %.1f min.\n', toc(t0)/60);
