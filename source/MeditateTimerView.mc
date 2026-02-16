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

    var _phaseOrder as Array<String> = ["Prepare", "Meditate", "Return"];
    var _phaseDurations as Array<Number> = [PREP_DURATION_SEC, MEDITATE_DURATION_SEC, RETURN_DURATION_SEC];

    var _phaseIndex as Number = 0;
    var _remainingSeconds as Number = PREP_DURATION_SEC;

    var _tickTimer as Timer.Timer?;
    var _vibeTimer as Timer.Timer?;
    var _vibePulsesRemaining as Number = 0;
    var _completed as Boolean = false;

    var _recordingSession as ActivityRecording.Session?;
    var _recordingActive as Boolean = false;

    var _heartRateText as String = "--";
    var _stressText as String = "--";
    var _bodyBatteryText as String = "--";

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        _phaseIndex = 0;
        _remainingSeconds = _phaseDurations[_phaseIndex];
        _completed = false;

        startRecording();
        refreshWellnessMetrics();

        _tickTimer = new Timer.Timer();
        _tickTimer.start(method(:onSecondTick), 1000, true);
    }

    function onHide() as Void {
        if (_tickTimer != null) {
            _tickTimer.stop();
        }

        if (_vibeTimer != null) {
            _vibeTimer.stop();
        }

        stopRecording();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.clear();

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

    function onSecondTick() as Void {
        if (_completed) {
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

    function startRecording() as Void {
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

    function stopRecording() as Void {
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

    function refreshWellnessMetrics() as Void {
        try {
            var info = ActivityMonitor.getInfo();
            _heartRateText = formatMetricValue(info.currentHeartRate);
            _stressText = formatMetricValue(info.stressScore);
            _bodyBatteryText = formatMetricValue(info.bodyBattery);
        } catch (e) {
            _heartRateText = "--";
            _stressText = "--";
            _bodyBatteryText = "--";
        }
    }

    function formatMetricValue(metric as Number?) as String {
        if (metric == null) {
            return "--";
        }

        return metric.format("%d");
    }

    function startSilentVibrationCue() as Void {
        _vibePulsesRemaining = 12;

        if (_vibeTimer != null) {
            _vibeTimer.stop();
        }

        _vibeTimer = new Timer.Timer();
        _vibeTimer.start(method(:sendVibePulse), 250, true);
    }

    function sendVibePulse() as Void {
        if (_vibePulsesRemaining <= 0) {
            if (_vibeTimer != null) {
                _vibeTimer.stop();
            }
            return;
        }

        Attention.vibrate(new Attention.VibeProfile(80, 60));
        _vibePulsesRemaining -= 1;
    }

    function formatTime(totalSeconds as Number) as String {
        var minutes = (totalSeconds / 60).toNumber();
        var seconds = (totalSeconds % 60).toNumber();
        return minutes.format("%02d") + ":" + seconds.format("%02d");
    }
}
