using Toybox.Activity;
using Toybox.ActivityMonitor;
using Toybox.ActivityRecording;
using Toybox.Attention;
using Toybox.Application;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.Timer;
using Toybox.WatchUi;

class MeditateTimerView extends WatchUi.View {

    const PREP_DURATION_SEC = 60;
    const MEDITATE_DURATION_SEC = 20 * 60;
    const RETURN_DURATION_SEC = 3 * 60;
    const MIN_DURATION_MINUTES = 0;
    const MAX_DURATION_MINUTES = 180;
    const SAVED_SETUP_DURATIONS_KEY = "setupDurationsMinutes";

    var _phaseOrder = [T(Rez.Strings.Preparation), T(Rez.Strings.Meditate), T(Rez.Strings.Return)];
    var _phaseDurations = [PREP_DURATION_SEC, MEDITATE_DURATION_SEC, RETURN_DURATION_SEC];

    var _defaultSetupDurationsMinutes = [1, 20, 3];
    var _setupDurationsMinutes = [1, 20, 3];
    var _setupSelection = 0;
    var _isSetupMode = true;
    var _isConfirmMode = false;
    var _isPaused = false;
    var _confirmSelection = 0;
    var _confirmHasContinue = false;

    var _phaseIndex = 0;
    var _remainingSeconds  = PREP_DURATION_SEC;

    var _tickTimer as Timer.Timer?;
    var _pauseConfirmTimer as Timer.Timer?;
    var _vibeTimer as Timer.Timer?;
    var _vibePulsesRemaining  = 0;
    var _completed = false;

    var _recordingSession as ActivityRecording.Session?;
    var _recordingActive = false;

    var _heartRateText = "--";
    var _activeLayoutId = "";

    function initialize() {
        View.initialize();
    }

    function onLayout(dc) {
        applySetupLayout(dc);
    }

    function onShow() {
        resetSetupDefaults();
    }

    function onHide() {
        stopTimers();
        finishRecording();
    }

    function T(identifier) {
        return WatchUi.loadResource(identifier);
    }

    function onUpdate(dc) {
        if (_isSetupMode) {
            applySetupLayout(dc);
            updateSetupLayoutText();
        } else if (_isConfirmMode) {
            applyConfirmLayout(dc);
            updateConfirmLayoutText();
        } else {
            applySessionLayout(dc);
            updateSessionLayoutText();
        }

        View.onUpdate(dc);

        if (!_isSetupMode && !_isConfirmMode) {
            drawPhaseProgressBar(dc, dc.getWidth(), (dc.getHeight() / 2) + 20);
        }
    }

    function resetSetupDefaults() {
        stopTimers();
        _activeLayoutId = "";

        _setupDurationsMinutes = loadSavedSetupDurations();
        _setupSelection = 0;
        _isSetupMode = true;
        _isConfirmMode = false;
        _isPaused = false;
        _confirmSelection = 0;
        _confirmHasContinue = false;

        _phaseIndex = 0;
        _phaseDurations = [
            _setupDurationsMinutes[0] * 60,
            _setupDurationsMinutes[1] * 60,
            _setupDurationsMinutes[2] * 60
        ];
        _remainingSeconds = _phaseDurations[0];
        _completed = false;
        _heartRateText = "--";

        WatchUi.requestUpdate();
    }

    function stopTimers() {
        if (_tickTimer != null) {
            _tickTimer.stop();
            _tickTimer = null;
        }

        if (_pauseConfirmTimer != null) {
            _pauseConfirmTimer.stop();
            _pauseConfirmTimer = null;
        }

        if (_vibeTimer != null) {
            _vibeTimer.stop();
            _vibeTimer = null;
        }
    }

    function applySetupLayout(dc) {
        if (_activeLayoutId == "setup") {
            return;
        }

        setLayout(Rez.Layouts.SetupLayout(dc));
        _activeLayoutId = "setup";
    }

    function applySessionLayout(dc) {
        if (_activeLayoutId == "session") {
            return;
        }

        setLayout(Rez.Layouts.SessionLayout(dc));
        _activeLayoutId = "session";
    }

    function applyConfirmLayout(dc) {
        if (_activeLayoutId == "confirm") {
            return;
        }

        setLayout(Rez.Layouts.ConfirmLayout(dc));
        _activeLayoutId = "confirm";
    }

    function updateSetupLayoutText() {
        setLayoutLabel("prepRow", formatSetupRowText(T(Rez.Strings.Preparation), _setupDurationsMinutes[0], _setupSelection == 0));
        setLayoutLabel("meditateRow", formatSetupRowText(T(Rez.Strings.Meditation), _setupDurationsMinutes[1], _setupSelection == 1));
        setLayoutLabel("returnRow", formatSetupRowText(T(Rez.Strings.Return), _setupDurationsMinutes[2], _setupSelection == 2));
        setLayoutLabel("startRow", _setupSelection == 3 ? "> " + T(Rez.Strings.Start) : "  " + T(Rez.Strings.Start));
    }

    function formatSetupRowText(label, minutes, selected) {
        var prefix = selected ? "> " : "  ";
        return prefix + label + ": " + minutes.format("%d") + " min";
    }

    function updateSessionLayoutText() {
        var phaseLabel = _completed ? T(Rez.Strings.Complete) : _phaseOrder[_phaseIndex];
        var minuteText = formatTime(_remainingSeconds);
        var progress = _isPaused ? T(Rez.Strings.Paused) : T(Rez.Strings.Step) + " " + (_phaseIndex + 1).format("%d") + " / 3";
        var wellnessLineA = "HR " + _heartRateText;

        setLayoutLabel("phaseLabel", phaseLabel);
        setLayoutLabel("timerLabel", minuteText);
        setLayoutLabel("progressLabel", progress);
        setLayoutLabel("wellnessLineA", wellnessLineA);
    }

    function updateConfirmLayoutText() {
        setLayoutLabel("confirmTitle", T(Rez.Strings.EndSession));
        setLayoutLabel("continueRow", _confirmHasContinue ? formatConfirmOption(T(Rez.Strings.ContinueSession), _confirmSelection == 0) : "");
        setLayoutLabel("finishRow", formatConfirmOption(T(Rez.Strings.FinishSave), _confirmSelection == getConfirmFinishIndex()));
        setLayoutLabel("cancelRow", formatConfirmOption(T(Rez.Strings.CancelActivity), _confirmSelection == getConfirmCancelIndex()));
        setLayoutLabel("confirmHelp1", T(Rez.Strings.UpDown));
        setLayoutLabel("confirmHelp2", T(Rez.Strings.ConfirmHelp));
    }

    function formatConfirmOption(label, selected) {
        var prefix = selected ? "> " : "  ";
        return prefix + label;
    }

    function setLayoutLabel(id, text) {
        var drawable = findDrawableById(id);
        if (drawable != null && drawable instanceof WatchUi.Text) {
            (drawable as WatchUi.Text).setText(text);
        }
    }

    function drawPhaseProgressBar(dc, width, y) {
        var barWidth = width - 64;
        var barHeight = 8;
        var x = 32;
        var maxFillWidth = barWidth - 2;

        var progressRatio = 0.0;
        if (_completed) {
            progressRatio = 1.0;
        } else {
            var phaseDuration = _phaseDurations[_phaseIndex];
            if (phaseDuration > 0) {
                progressRatio = (phaseDuration - _remainingSeconds).toFloat() / phaseDuration.toFloat();
            }
        }

        if (progressRatio < 0.0) {
            progressRatio = 0.0;
        }
        if (progressRatio > 1.0) {
            progressRatio = 1.0;
        }

        var fillWidth = (maxFillWidth * progressRatio).toNumber();

        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_BLUE);
        dc.drawRoundedRectangle(x, y, barWidth, barHeight, 5);
        if (fillWidth > 0) {
            dc.fillRoundedRectangle(x + 1, y + 1, fillWidth, barHeight - 2, 5);
        }
    }

    function isSetupMode() {
        return _isSetupMode;
    }

    function selectPreviousSetupOption() {
        if (_isConfirmMode) {
            _confirmSelection -= 1;
            if (_confirmSelection < 0) {
                _confirmSelection = getConfirmOptionCount() - 1;
            }
            WatchUi.requestUpdate();
            return true;
        }

        if (!_isSetupMode) {
            return false;
        }

        _setupSelection -= 1;
        if (_setupSelection < 0) {
            _setupSelection = 3;
        }
        WatchUi.requestUpdate();
        return true;
    }

    function selectNextSetupOption() {
        if (_isConfirmMode) {
            _confirmSelection += 1;
            if (_confirmSelection >= getConfirmOptionCount()) {
                _confirmSelection = 0;
            }
            WatchUi.requestUpdate();
            return true;
        }

        if (!_isSetupMode) {
            return false;
        }

        _setupSelection += 1;
        if (_setupSelection > 3) {
            _setupSelection = 0;
        }
        WatchUi.requestUpdate();
        return true;
    }

    function activateSetupSelection() {
        if (_isConfirmMode) {
            if (_confirmHasContinue && _confirmSelection == 0) {
                resumeSession();
            } else if (_confirmSelection == getConfirmFinishIndex()) {
                finishAndSaveSession();
            } else {
                cancelSession();
            }
            return true;
        }

        if (_isPaused) {
            resumeSession();
            return true;
        }

        if (!_isSetupMode) {
            pauseSession();
            return true;
        }

        if (_setupSelection == 3) {
            startMeditationSession();
            return true;
        }

        adjustSelectedSetupDuration(1);
        return true;
    }

    function decrementSetupSelection() {
        if (_isConfirmMode) {
            exitConfirmMode();
            return true;
        }

        if (!_isSetupMode || _setupSelection >= 3) {
            return false;
        }

        adjustSelectedSetupDuration(-1);
        return true;
    }

    function adjustSelectedSetupDuration(delta) {
        if (_setupSelection >= 3) {
            return;
        }

        var updatedValue = _setupDurationsMinutes[_setupSelection] + delta;
        if (updatedValue < MIN_DURATION_MINUTES) {
            updatedValue = MIN_DURATION_MINUTES;
        }
        if (updatedValue > MAX_DURATION_MINUTES) {
            updatedValue = MAX_DURATION_MINUTES;
        }

        _setupDurationsMinutes[_setupSelection] = updatedValue;
        WatchUi.requestUpdate();
    }

    function startMeditationSession() {
        saveSetupDurations();

        _phaseDurations = [
            _setupDurationsMinutes[0] * 60,
            _setupDurationsMinutes[1] * 60,
            _setupDurationsMinutes[2] * 60
        ];

        _isSetupMode = false;
        _isConfirmMode = false;
        _isPaused = false;
        _confirmHasContinue = false;
        _activeLayoutId = "";
        _phaseIndex = 0;
        _remainingSeconds = _phaseDurations[0];
        _completed = false;

        startRecording();
        refreshWellnessMetrics();
        advancePastCompletedPhases(false);

        if (!_completed) {
            startTickTimer();
        }
        WatchUi.requestUpdate();
    }

    function loadSavedSetupDurations() {
        var savedDurations = Application.Storage.getValue(SAVED_SETUP_DURATIONS_KEY);
        if (savedDurations == null || !(savedDurations instanceof Array) || savedDurations.size() != 3) {
            return copySetupDurations(_defaultSetupDurationsMinutes);
        }

        var sanitizedDurations = [];
        for (var i = 0; i < savedDurations.size(); i += 1) {
            var duration = savedDurations[i];
            if (!(duration instanceof Number)) {
                return copySetupDurations(_defaultSetupDurationsMinutes);
            }

            var clampedDuration = duration;
            if (clampedDuration < MIN_DURATION_MINUTES) {
                clampedDuration = MIN_DURATION_MINUTES;
            }
            if (clampedDuration > MAX_DURATION_MINUTES) {
                clampedDuration = MAX_DURATION_MINUTES;
            }

            sanitizedDurations.add(clampedDuration);
        }

        return sanitizedDurations;
    }

    function copySetupDurations(durations) {
        return [durations[0], durations[1], durations[2]];
    }

    function saveSetupDurations() {
        Application.Storage.setValue(SAVED_SETUP_DURATIONS_KEY, copySetupDurations(_setupDurationsMinutes));
    }

    function onSecondTick() {
        if (_isSetupMode || _isConfirmMode || _completed) {
            return;
        }

        refreshWellnessMetrics();

        if (_remainingSeconds > 0) {
            _remainingSeconds -= 1;
            WatchUi.requestUpdate();
            return;
        }

        advancePastCompletedPhases(true);
        WatchUi.requestUpdate();
    }

    function advancePastCompletedPhases(shouldVibrate) {
        while (!_completed && _remainingSeconds <= 0) {
            if (shouldVibrate) {
                startSilentVibrationCue();
            }

            if (_phaseIndex < (_phaseOrder.size() - 1)) {
                _phaseIndex += 1;
                _remainingSeconds = _phaseDurations[_phaseIndex];
            } else {
                _remainingSeconds = 0;
                _completed = true;
                if (_tickTimer != null) {
                    _tickTimer.stop();
                }
                finishRecording();
            }
        }
    }

    function handleSessionBack() {
        if (_isSetupMode) {
            return decrementSetupSelection();
        }

        if (_isConfirmMode) {
            exitConfirmMode();
            return true;
        }

        if (_isPaused) {
            return true;
        }

        if (_completed) {
            return false;
        }

        if (_phaseIndex < (_phaseOrder.size() - 1)) {
            startSilentVibrationCue();
            _phaseIndex += 1;
            _remainingSeconds = _phaseDurations[_phaseIndex];
            advancePastCompletedPhases(false);
            WatchUi.requestUpdate();
            return true;
        }

        enterConfirmMode(false);
        return true;
    }

    function enterConfirmMode(hasContinueOption) {
        if (_tickTimer != null) {
            _tickTimer.stop();
            _tickTimer = null;
        }

        if (_pauseConfirmTimer != null) {
            _pauseConfirmTimer.stop();
            _pauseConfirmTimer = null;
        }

        _isConfirmMode = true;
        _confirmHasContinue = hasContinueOption;
        _confirmSelection = 0;
        _activeLayoutId = "";
        WatchUi.requestUpdate();
    }

    function exitConfirmMode() {
        _isConfirmMode = false;
        _activeLayoutId = "";

        if (_isPaused) {
            schedulePauseConfirm();
        } else if (!_completed) {
            startTickTimer();
        }

        WatchUi.requestUpdate();
    }

    function pauseSession() {
        if (_isSetupMode || _isConfirmMode || _isPaused || _completed) {
            return;
        }

        if (_tickTimer != null) {
            _tickTimer.stop();
            _tickTimer = null;
        }

        _isPaused = true;
        schedulePauseConfirm();
        WatchUi.requestUpdate();
    }

    function resumeSession() {
        if (_isSetupMode || _completed) {
            return;
        }

        if (_pauseConfirmTimer != null) {
            _pauseConfirmTimer.stop();
            _pauseConfirmTimer = null;
        }

        _isPaused = false;
        _isConfirmMode = false;
        _confirmHasContinue = false;
        _activeLayoutId = "";

        startTickTimer();
        WatchUi.requestUpdate();
    }

    function schedulePauseConfirm() {
        if (_pauseConfirmTimer != null) {
            _pauseConfirmTimer.stop();
        }

        _pauseConfirmTimer = new Timer.Timer();
        _pauseConfirmTimer.start(method(:onPauseConfirmTimeout) as Method() as Void, 3000, false);
    }

    function onPauseConfirmTimeout() {
        _pauseConfirmTimer = null;

        if (_isPaused && !_isConfirmMode && !_completed) {
            enterConfirmMode(true);
        }
    }

    function startTickTimer() {
        if (_completed || _isPaused || _isConfirmMode) {
            return;
        }

        if (_tickTimer != null) {
            _tickTimer.stop();
        }

        _tickTimer = new Timer.Timer();
        _tickTimer.start(method(:onSecondTick) as Method() as Void, 1000, true);
    }

    function getConfirmOptionCount() {
        return _confirmHasContinue ? 3 : 2;
    }

    function getConfirmFinishIndex() {
        return _confirmHasContinue ? 1 : 0;
    }

    function getConfirmCancelIndex() {
        return _confirmHasContinue ? 2 : 1;
    }

    function finishAndSaveSession() {
        finishRecording();
        System.exit();
    }

    function cancelSession() {
        discardRecording();
        System.exit();
    }

    function startRecording() {
        _recordingActive = false;
        _recordingSession = null;

        try {
            _recordingSession = ActivityRecording.createSession({
                :name => "Meditation",
                :sport => Activity.SPORT_MEDITATION,

            });

            if (_recordingSession != null) {
                _recordingSession.start();
                _recordingActive = true;
            }
        } catch (e) {
            _recordingSession = null;
            _recordingActive = false;
        }
    }

    function finishRecording() {
        if (_recordingSession == null) {
            _recordingActive = false;
            return;
        }

        try {
            _recordingSession.stop();
            _recordingSession.save();
        } catch (e) {
        }

        _recordingSession = null;
        _recordingActive = false;
    }

    function discardRecording() {
        if (_recordingSession == null) {
            _recordingActive = false;
            return;
        }

        try {
            _recordingSession.stop();
            _recordingSession.discard();
        } catch (e) {
        }

        _recordingSession = null;
        _recordingActive = false;
    }

    function refreshWellnessMetrics() {
        try {
            var info = Activity.getActivityInfo();
            _heartRateText = formatMetricValue(info.currentHeartRate);
        } catch (e) {
            _heartRateText = "--";
        }
    }

    function formatMetricValue(metric) {
        if (metric == null) {
            return "--";
        }

        return metric.format("%d");
    }

    function startSilentVibrationCue() {
        Attention.vibrate([
            new Attention.VibeProfile(15, 1500),
            new Attention.VibeProfile(30, 1000),
            new Attention.VibeProfile(50, 500),
            new Attention.VibeProfile(30, 1000),
            new Attention.VibeProfile(15, 1500)
        ]);
    }

    function formatTime(totalSeconds) {
        var minutes = (totalSeconds / 60).toNumber();
        var seconds = (totalSeconds % 60).toNumber();
        return minutes.format("%02d") + ":" + seconds.format("%02d");
    }
}

class MeditateTimerDelegate extends WatchUi.BehaviorDelegate {

    var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onPreviousPage() {
        return _view.selectPreviousSetupOption();
    }

    function onNextPage() {
        return _view.selectNextSetupOption();
    }

    function onSelect() {
        return _view.activateSetupSelection();
    }

    function onBack() {
        return _view.handleSessionBack();
    }
}
