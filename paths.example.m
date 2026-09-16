function p = paths()
% PATHS  Machine-specific paths for pmp-signal-processing-zgz.
%
%   SETUP: copy this file as "paths.m" (same folder; gitignored) and edit the
%   values for your machine. Scripts use it like this:
%
%       repoRoot = fileparts(fileparts(mfilename('fullpath'))); addpath(repoRoot);
%       p = paths();
%       addpath(genpath(p.biomedSigProc));
%
%   Leave a field empty ("") on machines where it does not apply.

% --- MATLAB toolboxes (roots; added with addpath(genpath(...))) ---
p.biomedSigProc = "D:\OneDrive - unizar.es\DOCTORADO\biomedical-signal-processing"; % EDIT
p.biosigmat     = "D:\OneDrive - unizar.es\UNIVERSIDAD\POSTDOCTORADO\biosigmat";    % EDIT

% --- Data roots (NOT in this repo) ---
p.dataRootT0 = "REGISTROS 3 DIAS";      % T0 cohort: 3-day Holter + MATA records
p.dataRootT1 = "D:\werpermed\PMP_T1";   % T1 cohort: PMP_T1 biosignals

% --- NAS share (used by some pmpt1 scripts) ---
p.nasRoot = "\\smb2.i3a.es\nas2\bsicos01\__comun\ecg\PMP_T1\PMP_T1_biosignals";
end
