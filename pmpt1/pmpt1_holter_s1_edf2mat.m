clear
close all force
clc

%%

% Define the root directory to search for patient folders
repoRoot = fileparts(fileparts(mfilename('fullpath'))); addpath(repoRoot);
p = paths();
rootDir = p.dataRootT1;

% Get a list of all subdirectories (patients) in the root directory
patientDirs = dir(rootDir);
patientDirs = patientDirs([patientDirs.isdir]); % Keep only directories
patientDirs = patientDirs(~ismember({patientDirs.name}, {'.', '..'})); % Remove . and .. directories

% Loop sobre cada paciente
for p = 3:numel(patientDirs)

    clearvars -except p patientDirs rootDir

    patientID  = patientDirs(p).name;
    patientPath = fullfile(rootDir, patientID);
    fileList = dir(fullfile(patientPath, '**', '*.EDF'));

    if isempty(fileList), disp('NO EDF'); continue; end


    ECG          = cell(numel(fileList),1);
    ACC          = cell(numel(fileList),1);
    timeStamp    = cell(numel(fileList),1);     % ECG
    timeStampACC = cell(numel(fileList),1);     % ACC

    for i = 1:numel(fileList)
        filePath = fullfile(fileList(i).folder, fileList(i).name);
        disp(['Processing file: ' filePath]);

        info = edfinfo(filePath);

        %--------- Zona horaria (leer TZ del campo Recording si existe)
        recStr = string(info.Recording);
        tok = regexp(recStr, 'TZ=([+\-]\d{2})0{2}', 'tokens', 'once');  % p.ej. +02
        if ~isempty(tok)
            tz_iso = tok{1} + ":00";         % "+02:00"
        else
            % Fallback sensato si no viene TZ: usa la zona del dispositivo/país
            tz_iso = "Europe/Madrid";
        end

        %--------- Instante inicial absoluto
        t0_local = datetime(info.StartDate + " " + info.StartTime, ...
            'InputFormat','dd.MM.yy HH.mm.ss', ...
            'TimeZone', tz_iso);
        t0_utc   = datetime(t0_local, 'TimeZone','UTC');

        %--------- Frecuencias de muestreo por canal (genérico EDF)
        dr = seconds(info.DataRecordDuration);             % duración data record [s]
        Fs_ch = info.NumSamples ./ dr;                     % vector de Fs por canal

        %--------- Localiza canales por nombre (robusto a reordenaciones)
        labels = string(info.SignalLabels);
        idxECG = find(contains(labels, "ECG", 'IgnoreCase', true), 1, 'first');
        idxAX  = find(contains(labels, "Accelerometer_X", 'IgnoreCase', true), 1, 'first');
        idxAY  = find(contains(labels, "Accelerometer_Y", 'IgnoreCase', true), 1, 'first');
        idxAZ  = find(contains(labels, "Accelerometer_Z", 'IgnoreCase', true), 1, 'first');

        if isempty(idxECG) || isempty(idxAX) || isempty(idxAY) || isempty(idxAZ)
            error('No se localizaron todos los canales esperados (ECG y ACC XYZ).');
        end

        %--------- Carga de datos (edfread devuelve timetable con celdas por record)
        tt = edfread(filePath);             % ya devuelve unidades físicas

        % Extrae y concatena por canal
        ECG_aux  = vertcat(tt{:, idxECG}{:});          % vector columna
        ACCX_aux = vertcat(tt{:, idxAX }{:});
        ACCY_aux = vertcat(tt{:, idxAY }{:});
        ACCZ_aux = vertcat(tt{:, idxAZ }{:});

        %--------- Ejes temporales absolutos
        fsECG = Fs_ch(idxECG);
        t_ecg = t0_local + seconds( (0:numel(ECG_aux)-1)' / fsECG );

        % En Faros los tres ejes suelen compartir Fs; aun así, calcula por eje
        fsAX  = Fs_ch(idxAX);
        fsAY  = Fs_ch(idxAY);
        fsAZ  = Fs_ch(idxAZ);
        % Si difieren, se usa la de cada eje (aquí asumo iguales y tomo X)
        t_acc = t0_local + seconds( (0:numel(ACCX_aux)-1)' / fsAX );

        %--------- Acumula
        ECG{i}          = ECG_aux(:);
        ACC{i}          = [ACCX_aux(:), ACCY_aux(:), ACCZ_aux(:)];
        timeStamp{i}    = t_ecg;
        timeStampACC{i} = t_acc;

        % (Opcional) guarda metadatos útiles del archivo i por si luego quieres auditarlos
        meta(i).file     = filePath;
        meta(i).t0_local = t0_local;
        meta(i).t0_utc   = t0_utc;
        meta(i).Fs       = struct('ECG', fsECG, 'ACCX', fsAX, 'ACCY', fsAY, 'ACCZ', fsAZ);
        
    end

    %--------- Concatenación final
    ECG          = vertcat(ECG{:});
    ACC          = vertcat(ACC{:});
    timeStamp    = vertcat(timeStamp{:});      % ECG times (zona local tz_iso)
    timeStampACC = vertcat(timeStampACC{:});   % ACC times (zona local tz_iso)

    % También en UTC y en POSIX si vas a sincronizar con otros dispositivos
    timeStampUTC    = datetime(timeStamp,    'TimeZone','UTC');
    timeStampACCUTC = datetime(timeStampACC, 'TimeZone','UTC');
    t_posix_ecg     = posixtime(timeStampUTC);
    t_posix_acc     = posixtime(timeStampACCUTC);

    %--------- Guardado ---------
    filename = fullfile(patientPath, [patientID '_holter.mat']);
    if ~exist(filename,"file")
        save(filename, ...
        "ECG","ACC", ...
        "timeStamp","timeStampACC", ...
        "meta");
    else
        disp('archivo ya existe');    
        pause;
    end
    disp([filename ' processed']);
end

% figure
% plot(timeStamp,ECG)
% yyaxis right
% plot(timeStampACC,sqrt(sum(ACC,2).^2))