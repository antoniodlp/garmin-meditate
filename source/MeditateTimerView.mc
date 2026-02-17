using Toybox.Activity;
using Toybox.ActivityMonitor;
using Toybox.ActivityRecording;
using Toybox.Attention;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Timer;
using Toybox.WatchUi;

class MeditateTimerView extends WatchUi.View {

    const PREP_DURATION_SEC = 60;
    const MEDITATE_DURATION_SEC = 20 * 60;
    const RETURN_DURATION_SEC = 3 * 60;
    const MIN_DURATION_MINUTES = 1;
    const MAX_DURATION_MINUTES = 180;

    var _phaseOrder = ["Prepare", "Meditate", "Return"];
    var _phaseDurations = [PREP_DURATION_SEC, MEDITATE_DURATION_SEC, RETURN_DURATION_SEC];

    var _setupDurationsMinutes = [1, 20, 3];
    var _setupSelection = 0;
    var _isSetupMode = true;

    var _phaseIndex = 0;
    var _remainingSeconds  = PREP_DURATION_SEC;

    var _tickTimer as Timer.Timer?;
    var _vibeTimer as Timer.Timer?;
    var _vibePulsesRemaining  = 0;
    var _completed = false;

    var _recordingSession as ActivityRecording.Session?;
    var _recordingActive = false;

    var _heartRateText = "--";
    var _stressText = "--";
    var _bodyBatteryText = "--";

    function initialize() {
        View.initialize();
    }

    function onShow() {
        resetSetupDefaults();
    }

    function onHide() {
        stopTimers();
        stopRecording();
    }

    function onUpdate(dc) {
        dc.clear();

        if (_isSetupMode) {
            drawSetupScreen(dc);
            return;
        }

        drawSessionScreen(dc);
    }

    function resetSetupDefaults() {
        stopTimers();

        _setupDurationsMinutes = [1, 20, 3];
        _setupSelection = 0;
        _isSetupMode = true;

        _phaseIndex = 0;
        _phaseDurations = [
            _setupDurationsMinutes[0] * 60,
            _setupDurationsMinutes[1] * 60,
            _setupDurationsMinutes[2] * 60
        ];
        _remainingSeconds = _phaseDurations[0];
        _completed = false;
        _heartRateText = "--";
        _stressText = "--";
        _bodyBatteryText = "--";

        WatchUi.requestUpdate();
    }

    function stopTimers() {
        if (_tickTimer != null) {
            _tickTimer.stop();
            _tickTimer = null;
        }

        if (_vibeTimer != null) {
            _vibeTimer.stop();
            _vibeTimer = null;
        }
    }

    function drawSetupScreen(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var rowStart = 54;
        var rowSpacing = 26;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(width / 2, 20, Graphics.FONT_MEDIUM, "Set Durations", Graphics.TEXT_JUSTIFY_CENTER);

        drawSetupRow(dc, width, rowStart + (rowSpacing * 0), "Prep", _setupDurationsMinutes[0], _setupSelection == 0);
        drawSetupRow(dc, width, rowStart + (rowSpacing * 1), "Meditate", _setupDurationsMinutes[1], _setupSelection == 1);
        drawSetupRow(dc, width, rowStart + (rowSpacing * 2), "Return", _setupDurationsMinutes[2], _setupSelection == 2);
        drawStartRow(dc, width, rowStart + (rowSpacing * 3), _setupSelection == 3);

        dc.drawText(width / 2, height - 28, Graphics.FONT_XTINY, "Up/Down select  Select +1", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(width / 2, height - 12, Graphics.FONT_XTINY, "Back -1  Select on Start", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawSetupRow(dc, width, y, label, minutes, selected) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        var prefix = selected ? "> " : "  ";
        var text = prefix + label + ": " + minutes.format("%d") + " min";
        dc.drawText(width / 2, y, Graphics.FONT_SMALL, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawStartRow(dc, width, y, selected) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        var text = selected ? "> [ Start ]" : "  [ Start ]";
        dc.drawText(width / 2, y, Graphics.FONT_SMALL, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawSessionScreen(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);

        var phaseLabel = _completed ? "Complete" : (_phaseOrder[_phaseIndex] + " phase");
        dc.drawText(width / 2, 34, Graphics.FONT_MEDIUM, phaseLabel, Graphics.TEXT_JUSTIFY_CENTER);

        var minuteText = formatTime(_remainingSeconds);
        dc.drawText(width / 2, 74, Graphics.FONT_LARGE, minuteText, Graphics.TEXT_JUSTIFY_CENTER);

        var progress = "Step " + (_phaseIndex + 1).format("%d") + " / 3";
        dc.drawText(width / 2, 114, Graphics.FONT_XTINY, progress, Graphics.TEXT_JUSTIFY_CENTER);

        var recordingStatus = _recordingActive ? "Recording: on" : "Recording: off";
        dc.drawText(width / 2, height - 56, Graphics.FONT_XTINY, recordingStatus, Graphics.TEXT_JUSTIFY_CENTER);

        var wellnessLine = "HR " + _heartRateText + "  Stress " + _stressText + "  BB " + _bodyBatteryText;
        dc.drawText(width / 2, height - 26, Graphics.FONT_XTINY, wellnessLine, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function isSetupMode() {
        return _isSetupMode;
    }

    function selectPreviousSetupOption() {
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
        if (!_isSetupMode) {
            return false;
        }

        if (_setupSelection == 3) {
            startMeditationSession();
            return true;
        }

        adjustSelectedSetupDuration(1);
        return true;
    }

    function decrementSetupSelection() {
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
        _phaseDurations = [
            _setupDurationsMinutes[0] * 60,
            _setupDurationsMinutes[1] * 60,
            _setupDurationsMinutes[2] * 60
        ];

        _isSetupMode = false;
        _phaseIndex = 0;
        _remainingSeconds = _phaseDurations[0];
        _completed = false;

        startRecording();
        refreshWellnessMetrics();

        _tickTimer = new Timer.Timer();
        _tickTimer.start(method(:onSecondTick) as Method() as Void, 1000, true);
        WatchUi.requestUpdate();
    }

    function onSecondTick() {
        if (_isSetupMode || _completed) {
            return;
        }

        refreshWellnessMetrics();

        if (_remainingSeconds > 0) {
            _remainingSeconds -= 1;
            WatchUi.requestUpdate();
            return;
        }

        startSilentVibrationCue();

        if (_phaseIndex < (_phaseOrder.size() - 1)) {
            _phaseIndex += 1;
            _remainingSeconds = _phaseDurations[_phaseIndex];
            WatchUi.requestUpdate();
            return;
        }

        _remainingSeconds = 0;
        _completed = true;
        if (_tickTimer != null) {
            _tickTimer.stop();
        }

        stopRecording();
        WatchUi.requestUpdate();
    }

    function startRecording() {
        _recordingActive = false;
        _recordingSession = null;

        try {
            _recordingSession = ActivityRecording.createSession({
                :name => "Meditation",
                :sport => Activity.SPORT_GENERIC
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

    function stopRecording() {
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

    function refreshWellnessMetrics() {
        try {
            var info = Activity.getActivityInfo();
            _heartRateText = formatMetricValue(info.currentHeartRate);
            //_stressText = formatMetricValue(info.stressScore);
            //_bodyBatteryText = formatMetricValue(info.bodyBattery);
        } catch (e) {
            _heartRateText = "--";
            _stressText = "--";
            _bodyBatteryText = "--";
        }
    }

    function formatMetricValue(metric) {
        if (metric == null) {
            return "--";
        }

        return metric.format("%d");
    }

    function startSilentVibrationCue() {
        _vibePulsesRemaining = 12;

        if (_vibeTimer != null) {
            _vibeTimer.stop();
        }

        _vibeTimer = new Timer.Timer();
        _vibeTimer.start(method(:sendVibePulse) as Method() as Void, 250, true);
    }

    function sendVibePulse() {
        if (_vibePulsesRemaining <= 0) {
            if (_vibeTimer != null) {
                _vibeTimer.stop();
            }
            return;
        }

        Attention.vibrate([new Attention.VibeProfile(80, 60)]);
        _vibePulsesRemaining -= 1;
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
        return _view.decrementSetupSelection();
    }
}
