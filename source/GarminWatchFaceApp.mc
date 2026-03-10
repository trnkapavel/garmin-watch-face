import Toybox.Application;
import Toybox.WatchUi;

class GarminWatchFaceApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        return [ new GarminWatchFaceView() ];
    }
}

function getApp() {
    return Application.getApp();
}
