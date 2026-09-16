function [bounds, nights] = cleanGgirNightBounds(GGIR)
% One plausible SPT window per night, excluding non-wear and bad durations.

minHours = 3;
maxHours = 12;
maxInvalidPct = 20;
maxGapMinutes = 30;
minBlockHours = 2;
dayBoundaryHour = 12;

t = GGIR.timeStamp(:);
if ~isdatetime(t)
    t = datetime(t, 'ConvertFrom', 'datenum');
end

spt = GGIR.SleepPeriodTime(:) > 0;
if ismember('non_wear', GGIR.Properties.VariableNames)
    validEpoch = GGIR.non_wear(:) == 0;
else
    validEpoch = true(height(GGIR), 1);
end

epochSec = median(seconds(diff(t)), 'omitnan');
maxGap = max(1, round(maxGapMinutes * 60 / epochSec));
minBlock = max(1, round(minBlockHours * 3600 / epochSec));
nightDate = dateshift(t - hours(dayBoundaryHour), 'start', 'day');
uNight = unique(nightDate(~isnat(nightDate)));

if strlength(string(t.TimeZone)) == 0
    nightOut = NaT(0, 1);
else
    nightOut = NaT(0, 1, 'TimeZone', t.TimeZone);
end
startOut = nightOut;
endOut = nightOut;
durationOut = [];
validOut = [];
invalidOut = [];
statusOut = strings(0, 1);

for k = 1:numel(uNight)
    idx = find(nightDate == uNight(k));
    raw = spt(idx);
    if ~any(raw)
        continue;
    end

    valid = validEpoch(idx);
    invalidPct = invalidSleepPct(GGIR, idx, raw, valid);
    candidate = removeShortRuns(fillSmallGaps(raw & valid, maxGap) & raw, minBlock);
    [s, e] = trueRuns(candidate);

    status = "ok";
    if isempty(s)
        status = "rejected_no_valid_spt";
        best = NaN;
        durHours = NaN;
        validHours = NaN;
    else
        durHours = (e - s + 1) * epochSec / 3600;
        validHours = arrayfun(@(a,b) sum(raw(a:b) & valid(a:b)) * epochSec / 3600, s, e);
        plausible = durHours >= minHours & durHours <= maxHours;

        if ~any(plausible)
            status = "rejected_duration";
            best = NaN;
        elseif isfinite(invalidPct) && invalidPct > maxInvalidPct
            status = "rejected_invalid";
            best = NaN;
        else
            candidates = find(plausible);
            [~, bestPos] = max(validHours(candidates));
            best = candidates(bestPos);
        end
    end

    nightOut(end + 1, 1) = uNight(k); %#ok<AGROW>
    invalidOut(end + 1, 1) = invalidPct; %#ok<AGROW>
    statusOut(end + 1, 1) = status; %#ok<AGROW>

    if isnan(best)
        startOut(end + 1, 1) = NaT; %#ok<AGROW>
        endOut(end + 1, 1) = NaT; %#ok<AGROW>
        durationOut(end + 1, 1) = max(durHours, [], 'omitnan'); %#ok<AGROW>
        validOut(end + 1, 1) = max(validHours, [], 'omitnan'); %#ok<AGROW>
    else
        startOut(end + 1, 1) = t(idx(s(best))); %#ok<AGROW>
        endOut(end + 1, 1) = t(idx(e(best))) + seconds(epochSec); %#ok<AGROW>
        durationOut(end + 1, 1) = durHours(best); %#ok<AGROW>
        validOut(end + 1, 1) = validHours(best); %#ok<AGROW>
    end
end

nights = table(nightOut, startOut, endOut, durationOut, validOut, invalidOut, statusOut, ...
    'VariableNames', {'nightDate', 'nightStart', 'nightEndExclusive', ...
    'durationHours', 'validHours', 'invalidPct', 'status'});
bounds = [nights.nightStart(nights.status == "ok"), nights.nightEndExclusive(nights.status == "ok")];
end

function pct = invalidSleepPct(GGIR, idx, raw, valid)
if ismember('invalid_sleepperiod', GGIR.Properties.VariableNames)
    values = double(GGIR.invalid_sleepperiod(idx));
    values = values(raw & isfinite(values));
    pct = median(values, 'omitnan');
    if isfinite(pct) && pct <= 1.5
        pct = 100 * pct;
    end
else
    pct = 100 * sum(raw & ~valid) / max(1, sum(raw));
end
end

function m = fillSmallGaps(m, maxGap)
m = logical(m(:));
[s, e] = trueRuns(~m);
for i = 1:numel(s)
    if s(i) > 1 && e(i) < numel(m) && m(s(i)-1) && m(e(i)+1) && (e(i)-s(i)+1) <= maxGap
        m(s(i):e(i)) = true;
    end
end
end

function m = removeShortRuns(m, minSamples)
m = logical(m(:));
[s, e] = trueRuns(m);
for i = 1:numel(s)
    if (e(i) - s(i) + 1) < minSamples
        m(s(i):e(i)) = false;
    end
end
end

function [s, e] = trueRuns(m)
d = diff([false; logical(m(:)); false]);
s = find(d == 1);
e = find(d == -1) - 1;
end
