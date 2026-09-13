using Toybox.Application;

class NycMtaApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    (:glance)
    function getGlanceView() {
        return [ new MtaGlanceView() ];
    }

    function getInitialView() {
        var view = new BoardView();
        return [ view, new BoardDelegate(view) ];
    }
}
