using Toybox.Application;
using Toybox.WatchUi;

class MeditateTimerApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(a) {
    }

    function onStop(a) {
    }

    function getInitialView() {
        var view = new MeditateTimerView();
        var delegate = new MeditateTimerDelegate(view);
        return [ view, delegate ];
    }
}
