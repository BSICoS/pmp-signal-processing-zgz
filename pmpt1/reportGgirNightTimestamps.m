versions = {'v1', 'v2_1', 'v2_2'};

rows = {};

for vi = 1:numel(versions)
    v = versions{vi};
    ggirDir = fullfile('data', v, 'ggir');
    files = dir(fullfile(ggirDir, 'PMP*.mat'));

    for fi = 1:numel(files)
        ggirFile = fullfile(files(fi).folder, files(fi).name);
        tok = regexp(files(fi).name, '(\d+)', 'tokens', 'once');
        if isempty(tok); continue; end
        subjectId = tok{1};

        s = load(ggirFile, 'GGIR');
        if ~isfield(s, 'GGIR') || ~istable(s.GGIR); continue; end
        T = s.GGIR;

        if ~ismember('SleepPeriodTime', T.Properties.VariableNames); continue; end

        timeCol = '';
        for c = {'timeStamp', 'timestamp'}
            if ismember(c{1}, T.Properties.VariableNames); timeCol = c{1}; break; end
        end
        if isempty(timeCol); continue; end

        ts = T.(timeCol);
        if ~isdatetime(ts); ts = datetime(ts, 'ConvertFrom', 'datenum'); end
        sp = double(T.SleepPeriodTime);

        ok = ~isnat(ts) & ~isnan(sp);
        ts = ts(ok); sp = sp(ok);

        m = sp == 1;
        startIdx = find(diff([false; m]) == 1);
        endIdx   = find(diff([m; false]) == -1);
        if isempty(startIdx); continue; end

        if numel(ts) > 1; step = median(diff(ts)); else; step = seconds(0); end

        for n = 1:numel(startIdx)
            tStart = ts(startIdx(n));
            if endIdx(n) < numel(ts)
                tEnd = ts(endIdx(n) + 1);
            else
                tEnd = ts(endIdx(n)) + step;
            end
            dur  = hours(tEnd - tStart);
            startH = hour(tStart) + minute(tStart)/60;
            endH   = hour(tEnd)   + minute(tEnd)/60;
            rows{end+1} = {v, subjectId, n, tStart, tEnd, dur, startH, endH}; %#ok<SAGROW>
        end
    end
end

rows = vertcat(rows{:});
nightTimestamps = cell2table(rows, ...
    'VariableNames', {'version', 'subject', 'night', 'tStart', 'tEnd', 'durH', 'startH', 'endH'});

nightTimestamps.version = string(nightTimestamps.version);
nightTimestamps.subject = string(nightTimestamps.subject);
