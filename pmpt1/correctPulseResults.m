function tk = correctPulseResults(t, ppg, ppgClean, ppgDerivative, tk, threshold, fs, fileName)
originalTk = tk(:);
pulseTimes = originalTk(~isnan(originalTk));
pulseTimes = pulseTimes(pulseTimes >= t(1) & pulseTimes <= t(end));
finalTk = rebuildTk();
movingPulseIdx = [];

fig = figure('Name', sprintf('Pulse correction - %s', fileName), ...
    'NumberTitle', 'off', ...
    'Units', 'normalized', ...
    'Position', [0.05 0.06 0.9 0.84], ...
    'WindowButtonDownFcn', @onMouseDown, ...
    'WindowButtonMotionFcn', @onMouseMove, ...
    'WindowButtonUpFcn', @onMouseUp, ...
    'CloseRequestFcn', @onCloseRequest);

instructionLabel = uicontrol(fig, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.03 0.95 0.72 0.04], ...
    'HorizontalAlignment', 'left', ...
    'String', 'Izquierdo sobre deteccion: mover. Ctrl+izquierdo: anadir. Derecho sobre deteccion: eliminar.');
statusLabel = uicontrol(fig, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.03 0.01 0.72 0.04], ...
    'HorizontalAlignment', 'left', ...
    'String', 'Editor listo.');
uicontrol(fig, 'Style', 'pushbutton', ...
    'Units', 'normalized', ...
    'Position', [0.78 0.945 0.09 0.045], ...
    'String', 'Restaurar', ...
    'Callback', @onReset);
uicontrol(fig, 'Style', 'pushbutton', ...
    'Units', 'normalized', ...
    'Position', [0.88 0.945 0.09 0.045], ...
    'String', 'Continuar', ...
    'Callback', @onAccept);

ax(1) = axes(fig, 'Position', [0.07 0.68 0.9 0.21]); hold(ax(1), 'on'); box(ax(1), 'on');
plot(ax(1), t, ppg, 'r', 'LineWidth', 1, 'DisplayName', 'Original PPG');
plot(ax(1), t, ppgClean, 'k', 'LineWidth', 1, 'DisplayName', 'Cleaned PPG');
pulsePlot1 = plot(ax(1), nan, nan, 'o', 'LineWidth', 1, 'Color', [0.47, 0.67, 0.19], ...
    'MarkerFaceColor', [0.47, 0.67, 0.19], 'DisplayName', 'n_D');
title(ax(1), 'PPG Detection');
xlabel(ax(1), 'Time (s)');
ylabel(ax(1), 'Amplitude');
grid(ax(1), 'on');
legend(ax(1), 'show');

ax(2) = axes(fig, 'Position', [0.07 0.40 0.9 0.21]); hold(ax(2), 'on'); box(ax(2), 'on');
plot(ax(2), t, ppgDerivative, 'k', 'LineWidth', 1, 'DisplayName', 'LPD-Filtered PPG');
plot(ax(2), t, threshold, 'LineWidth', 1, 'DisplayName', 'Adaptive Threshold');
pulsePlot2 = plot(ax(2), nan, nan, 'o', 'LineWidth', 1, 'Color', [0.47, 0.67, 0.19], ...
    'MarkerFaceColor', [0.47, 0.67, 0.19], 'DisplayName', 'n_D');
xlabel(ax(2), 'Time (s)');
ylabel(ax(2), 'Amplitude');
grid(ax(2), 'on');
legend(ax(2), 'show');

ax(3) = axes(fig, 'Position', [0.07 0.12 0.9 0.21]); hold(ax(3), 'on'); box(ax(3), 'on');
intervalPlot = plot(ax(3), nan, nan, '-o', 'LineWidth', 1, 'Color', [0.00, 0.45, 0.74], ...
    'MarkerFaceColor', [0.00, 0.45, 0.74], 'DisplayName', 'diff(tk)');
title(ax(3), 'Pulse intervals');
xlabel(ax(3), 'Time (s)');
ylabel(ax(3), 'diff(tk) (s)');
grid(ax(3), 'on');
legend(ax(3), 'show');

linkaxes(ax, 'x');
setappdata(fig, 'xLimListeners', registerXLimListeners());
redrawDetections();
uiwait(fig);

if ishandle(fig)
    delete(fig);
end

tk = finalTk;

    function onMouseDown(~, ~)
        clickedObject = hittest(fig);
        clickedAxes = ancestor(clickedObject, 'axes');
        if isempty(clickedAxes) || ~any(clickedAxes == ax)
            return;
        end

        clickPoint = get(clickedAxes, 'CurrentPoint');
        clickTime = clampTime(clickPoint(1, 1));
        selectionType = get(fig, 'SelectionType');
        modifiers = get(fig, 'CurrentModifier');
        nearestIdx = findNearestPulse(clickTime, clickedAxes);

        if strcmp(selectionType, 'alt')
            if isempty(nearestIdx)
                setStatus('No hay ninguna deteccion cercana para eliminar.');
                return;
            end
            pulseTimes(nearestIdx) = [];
            redrawDetections();
            setStatus('Deteccion eliminada.');
            return;
        end

        if isAddSelection(selectionType, modifiers)
            addPulse(clickTime);
            return;
        end

        if strcmp(selectionType, 'normal') && ~isempty(nearestIdx)
            movingPulseIdx = nearestIdx;
            pulseTimes(movingPulseIdx) = clickTime;
            redrawDetections();
            setStatus('Moviendo deteccion.');
        end
    end

    function onMouseMove(~, ~)
        if isempty(movingPulseIdx) || movingPulseIdx < 1 || movingPulseIdx > numel(pulseTimes)
            return;
        end

        currentAxes = gca;
        if isempty(currentAxes) || ~any(currentAxes == ax)
            return;
        end

        clickPoint = get(currentAxes, 'CurrentPoint');
        pulseTimes(movingPulseIdx) = clampTime(clickPoint(1, 1));
        redrawDetections();
    end

    function onMouseUp(~, ~)
        if isempty(movingPulseIdx)
            return;
        end

        releaseAxes = getPointerAxes();
        if isequal(releaseAxes, ax(2))
            pulseTimes(movingPulseIdx) = snapToNearestDerivativePeak(pulseTimes(movingPulseIdx));
        end

        pulseTimes = sort(pulseTimes(:));
        movingPulseIdx = [];
        redrawDetections();
        setStatus('Deteccion recolocada.');
    end

    function onReset(~, ~)
        pulseTimes = originalTk(~isnan(originalTk));
        pulseTimes = pulseTimes(pulseTimes >= t(1) & pulseTimes <= t(end));
        movingPulseIdx = [];
        redrawDetections();
        setStatus('Detecciones restauradas al estado original.');
    end

    function onAccept(~, ~)
        finalTk = rebuildTk();
        uiresume(fig);
    end

    function onCloseRequest(~, ~)
        finalTk = rebuildTk();
        uiresume(fig);
    end

    function addPulse(clickTime)
        if ~isempty(findNearestPulse(clickTime, ax(1)))
            setStatus('Ya existe una deteccion cercana.');
            return;
        end

        pulseTimes(end+1, 1) = clickTime;
        pulseTimes = sort(pulseTimes(:));
        redrawDetections();
        setStatus('Deteccion anadida.');
    end

    function redrawDetections()
        displayTk = pulseTimes(:);
        if isempty(displayTk)
            set(pulsePlot1, 'XData', nan, 'YData', nan);
            set(pulsePlot2, 'XData', nan, 'YData', nan);
            set(intervalPlot, 'XData', nan, 'YData', nan);
        else
            displayTk = sort(displayTk);
            displayIdx = timeToIndex(displayTk);
            set(pulsePlot1, 'XData', displayTk, 'YData', ppg(displayIdx));
            set(pulsePlot2, 'XData', displayTk, 'YData', ppgDerivative(displayIdx));
            if numel(displayTk) >= 2
                set(intervalPlot, 'XData', displayTk(2:end), 'YData', diff(displayTk));
            else
                set(intervalPlot, 'XData', nan, 'YData', nan);
            end
        end

        title(ax(1), sprintf('PPG Detection (%d detecciones)', numel(displayTk)));
        title(ax(3), sprintf('Pulse intervals (%d diferencias)', max(0, numel(displayTk) - 1)));
        updateYLimits();
        drawnow limitrate;
    end

    function listeners = registerXLimListeners()
        listeners = cell(numel(ax), 1);
        for axisIdx = 1:numel(ax)
            listeners{axisIdx} = addlistener(ax(axisIdx), 'XLim', 'PostSet', @onViewChanged);
        end
    end

    function onViewChanged(~, ~)
        if ~ishandle(fig)
            return;
        end
        updateYLimits();
        drawnow limitrate;
    end

    function updateYLimits()
        visibleXLim = xlim(ax(1));
        displayTk = sort(pulseTimes(:));

        if isempty(displayTk)
            displayIdx = zeros(0, 1);
        else
            displayIdx = timeToIndex(displayTk);
        end

        signalMask = t >= visibleXLim(1) & t <= visibleXLim(2);
        detectionMask = displayTk >= visibleXLim(1) & displayTk <= visibleXLim(2);

        updateAxisYLimit(ax(1), [ppg(signalMask); ppgClean(signalMask); ppg(displayIdx(detectionMask))]);
        updateAxisYLimit(ax(2), [ppgDerivative(signalMask); threshold(signalMask); ppgDerivative(displayIdx(detectionMask))]);

        if numel(displayTk) >= 2
            intervalTimes = displayTk(2:end);
            intervalValues = diff(displayTk);
            intervalMask = intervalTimes >= visibleXLim(1) & intervalTimes <= visibleXLim(2);
            updateAxisYLimit(ax(3), intervalValues(intervalMask));
        else
            updateAxisYLimit(ax(3), nan);
        end
    end

    function updateAxisYLimit(axisHandle, values)
        values = values(isfinite(values));
        if isempty(values)
            return;
        end

        minValue = min(values);
        maxValue = max(values);
        if minValue == maxValue
            padding = max(abs(minValue) * 0.05, 1e-3);
        else
            padding = 0.05 * (maxValue - minValue);
        end

        ylim(axisHandle, [minValue - padding, maxValue + padding]);
    end

    function targetAxes = getPointerAxes()
        targetAxes = [];
        hoveredObject = hittest(fig);
        if isempty(hoveredObject) || ~ishandle(hoveredObject)
            return;
        end

        targetAxes = ancestor(hoveredObject, 'axes');
        if isempty(targetAxes) || ~any(targetAxes == ax)
            targetAxes = [];
        end
    end

    function snappedTime = snapToNearestDerivativePeak(clickTime)
        searchRadius = max(1, round(0.25 * fs));
        centerIdx = timeToIndex(clickTime);
        searchStart = max(2, centerIdx - searchRadius);
        searchEnd = min(numel(ppgDerivative) - 1, centerIdx + searchRadius);

        if searchStart > searchEnd
            snappedTime = t(centerIdx);
            return;
        end

        windowIdx = (searchStart:searchEnd)';
        windowSignal = ppgDerivative(windowIdx);
        validMask = isfinite(windowSignal);
        if ~any(validMask)
            snappedTime = t(centerIdx);
            return;
        end

        peakMask = false(size(windowIdx));
        for idx = 2:numel(windowIdx)-1
            leftValue = windowSignal(idx - 1);
            centerValue = windowSignal(idx);
            rightValue = windowSignal(idx + 1);
            if isfinite(leftValue) && isfinite(centerValue) && isfinite(rightValue) ...
                    && centerValue >= leftValue && centerValue >= rightValue
                peakMask(idx) = true;
            end
        end

        candidateIdx = windowIdx(peakMask);
        if isempty(candidateIdx)
            validIdx = windowIdx(validMask);
            [~, fallbackPos] = max(ppgDerivative(validIdx));
            snappedIdx = validIdx(fallbackPos);
        else
            [~, nearestPos] = min(abs(candidateIdx - centerIdx));
            snappedIdx = candidateIdx(nearestPos);
        end

        snappedTime = t(snappedIdx);
    end

    function idx = findNearestPulse(clickTime, clickedAxes)
        idx = [];
        if isempty(pulseTimes)
            return;
        end

        currentXLim = xlim(clickedAxes);
        tolerance = max(3 / fs, min(0.15, diff(currentXLim) / 40));
        [distance, candidateIdx] = min(abs(pulseTimes - clickTime));
        if distance <= tolerance
            idx = candidateIdx;
        end
    end

    function sampleIdx = timeToIndex(times)
        sampleIdx = round(interp1(t, 1:numel(t), times, 'nearest', 'extrap'));
        sampleIdx = max(1, min(numel(t), sampleIdx));
    end

    function tkOut = rebuildTk()
        tkOut = sort(pulseTimes(:));
        if isempty(tkOut)
            if isempty(originalTk)
                tkOut = zeros(0, 1);
            else
                tkOut = nan(size(originalTk));
            end
            return;
        end

        tkOut = round(tkOut * fs) / fs;
        tkOut = tkOut([true; diff(tkOut) > (0.5 / fs)]);
        if numel(originalTk) > numel(tkOut)
            tkOut = [tkOut; nan(numel(originalTk) - numel(tkOut), 1)];
        end
    end

    function clampedTime = clampTime(clickTime)
        clampedTime = min(max(clickTime, t(1)), t(end));
    end

    function tf = isAddSelection(selectionType, modifiers)
        tf = strcmp(selectionType, 'extend') || hasModifier(modifiers, 'control');
    end

    function tf = hasModifier(modifiers, modifierName)
        if ischar(modifiers) || isstring(modifiers)
            tf = any(strcmpi(cellstr(modifiers), modifierName));
            return;
        end

        tf = iscell(modifiers) && any(strcmpi(modifiers, modifierName));
    end

    function setStatus(message)
        set(statusLabel, 'String', message);
        set(instructionLabel, 'String', 'Izquierdo sobre deteccion: mover. Ctrl+izquierdo: anadir. Derecho sobre deteccion: eliminar.');
    end
end