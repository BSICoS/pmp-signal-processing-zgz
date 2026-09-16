% load('path/to/<recording>.mat')   % EDIT: registro a analizar

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


