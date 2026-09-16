% Ruta completa al archivo .mat (EDIT: export local de Consensys)
fileName = 'path/to/2025-03-04_18.45.54_DefaultTrial_SD_Session1/DefaultTrial_Session1_Shimmer_68B7_Calibrated_SD.mat';
dataSHIMMER = struct2table(load(fileName));

dateStr = regexp(fileName, '(\d{4}-\d{2}-\d{2}_\d{2}\.\d{2}\.\d{2})', 'match', 'once');
endTime = datetime(dateStr,'InputFormat','yyyy-MM-dd_HH.mm.ss');

timestampData = dataSHIMMER.Shimmer_68B7_Timestamp_Shimmer_CAL;
ecgData       = dataSHIMMER.Shimmer_68B7_ECG_LL_RA_24BIT_CAL;


time_offset_s = (timestampData - timestampData(1)) / 1000;


dataSHIMMER.TimeStamp = endTime - seconds(flipud(time_offset_s));

figure;
plot(Time, ecgData);
xlabel('Time');
ylabel('ECG (LL-RA)');
title('ECG vs Timestamp');

figure;
plot(1000 ./ diff(timestampData));
xlabel('Muestras');
ylabel('Frecuencia (Hz estimada)');
title('Frecuencia de muestreo aproximada');


save('shimmer_andando.mat','dataSHIMMER');