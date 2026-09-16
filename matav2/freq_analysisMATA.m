% load('D:\OneDrive - unizar.es\DOCTORADO\0_WerPerMed\prueba_MATA02\registros\MATA00-1002663-20241129-114905.mat')
% load('D:\OneDrive - unizar.es\DOCTORADO\0_WerPerMed\prueba_MATA02\registros\MATA00-2000822-20241202-144225.mat')
% load('D:\OneDrive - unizar.es\DOCTORADO\0_WerPerMed\prueba_MATA02\newFW_prueba2\MATA00-2000822-20250120-113844.mat')
% load('C:\Users\user\OneDrive - unizar.es\DOCTORADO\0_WerPerMed\prueba_MATA02\newFW_prueba2\MATA00-2000822-20250120-113844.mat')

fs = 25.6;

[bb,aa] = butter (4,0.25/fs , "high" );
x = filtfilt(bb,aa,fillmissing(PPG,'pchip'));

wdw = fs*15*60 ;
nfft = 2^16;
[X,f] = pwelch( x, wdw, wdw/2 , nfft , fs);

figure
plot(f,X)

figure
plot(timeStamp,PPG)


