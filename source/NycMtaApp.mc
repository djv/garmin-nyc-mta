using Toybox.Application;
using Toybox.Background;
using Toybox.System;
using Toybox.Time;

(:background)
class NycMtaApp extends Application.AppBase {
    static const PACK_EVERY_S = 900;

    function initialize() {
        AppBase.initialize();
    }

    (:glance)
    function getGlanceView() {
        schedulePack();
        return [ new MtaGlanceView() ];
    }

    function getInitialView() {
        schedulePack();
        var view = new BoardView();
        return [ view, new BoardDelegate(view) ];
    }

    function getServiceDelegate() {
        return [ new PackService() ];
    }

    function onBackgroundData(data) {
        if (data != null) { PackStore.save(data); }
    }

    function onSettingsChanged() {
        schedulePack();
    }

    // Refresh the run pack in the background only when a pack key is set.
    (:glance)
    function schedulePack() {
        try {
            if (PackService.key() != null) {
                if (Background.getTemporalEventRegisteredTime() == null) {
                    Background.registerForTemporalEvent(new Time.Duration(PACK_EVERY_S));
                }
            } else {
                Background.deleteTemporalEvent();
            }
        } catch (ex) {}
    }
}
