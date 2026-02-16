using Toybox.Application;
using Toybox.WatchUi;

class MeditateTimerApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new MeditateTimerView() ];
    }
}
