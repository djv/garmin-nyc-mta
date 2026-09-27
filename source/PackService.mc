using Toybox.Application;
using Toybox.Background;
using Toybox.Communications;
using Toybox.Lang;
using Toybox.System;

// Background refresh of the run pack every 15 minutes while the phone is connected,
// so the schedule is current when you leave without the phone.
(:background)
class PackService extends System.ServiceDelegate {
    static const FALLBACK_BASE_URL = "https://ubuntu-8gb-nbg1-1.tailca4726.ts.net";

    function initialize() {
        ServiceDelegate.initialize();
    }

    // Lowercased run pack key from the app settings, or null when unset.
    static function key() {
        try {
            var v = Application.Properties.getValue("packKey");
            if (v instanceof Lang.String) {
                var k = (v as Lang.String).toLower();
                if (k.length() >= 10) { return k; }
            }
        } catch (ex) {}
        return null;
    }

    static function url() {
        var k = key();
        if (k == null) { return null; }
        var base = FALLBACK_BASE_URL;
        try {
            var v = Application.Properties.getValue("proxyUrl");
            if (v instanceof Lang.String && (v as Lang.String).find("https://") == 0 &&
                v.find("trycloudflare.com") == null) { base = v; }
        } catch (ex) {}
        return base + "/mta/pack?key=" + Communications.encodeURL(k);
    }

    function onTemporalEvent() as Void {
        var u = url();
        if (u == null) { Background.exit(null); return; }
        try {
            Communications.makeWebRequest(u, null, {
                :timeout => 20,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            }, method(:onPack));
        } catch (ex) {
            Background.exit(null);
        }
    }

    function onPack(code as Lang.Number, data as Lang.Dictionary or Lang.String or Null) as Void {
        if (code != 200 || !(data instanceof Lang.Dictionary)) { Background.exit(null); return; }
        try {
            Background.exit(data);
        } catch (ex) {
            // Over the background data limit: drop entrances and alerts, keep the schedule.
            var list = data["stations"];
            if (list instanceof Lang.Array) {
                for (var i = 0; i < list.size(); i += 1) {
                    if (list[i] instanceof Lang.Dictionary) {
                        list[i].remove("entrances");
                        list[i].remove("alerts");
                    }
                }
            }
            try { Background.exit(data); } catch (ex2) { Background.exit(null); }
        }
    }
}
