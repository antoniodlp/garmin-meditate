using Toybox.Application;
using Toybox.WatchUi;

class MeditateTimerApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(a) as Void {
    }

    function onStop(a) as Void {
    }

    function getInitialView() {
        return [ new MeditateTimerView() ];
    }
}
