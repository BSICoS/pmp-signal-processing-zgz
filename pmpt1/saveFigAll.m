function saveFigAll(fig, baseFile)
% saveFigAll - Guarda una figura en tres formatos a la vez:
%   .png  (raster, 200 dpi, para inspeccion rapida)
%   .eps  (vectorial, el que usa el paper LaTeX)
%   .fig  (figura nativa de MATLAB, editable)
%
% baseFile es la ruta base; su extension (si la tiene) se ignora y se
% sustituye por cada formato. Ej.: saveFigAll(fig, 'figures/coverage.png')
% genera coverage.png, coverage.eps y coverage.fig en figures/.

[d, n] = fileparts(baseFile);
if isempty(d), d = pwd; end
base = fullfile(d, n);

exportgraphics(fig, [base '.png'], 'Resolution', 200);
exportgraphics(fig, [base '.eps'], 'ContentType', 'vector');
savefig(fig, [base '.fig']);
end
