using Toybox.Application;
using Toybox.Communications;
using Toybox.Lang;

(:glance)
class MtaClient {
    static const FALLBACK_BASE_URL = "https://ubuntu-8gb-nbg1-1.tailca4726.ts.net";

    static const LEGACY_BASE_URL = "https://mandatory-paintings-buf-invention.trycloudflare.com";

    // App setting is the single source of truth; const is the fallback.
    static function baseUrl() {
        try {
            var v = Application.Properties.getValue("proxyUrl");
            if (v != null && (v as Lang.String).length() > 0) {
                if ((v as Lang.String).equals(LEGACY_BASE_URL)) {
                    Application.Properties.setValue("proxyUrl", FALLBACK_BASE_URL);
                    return FALLBACK_BASE_URL;
                }
                return v as Lang.String;
            }
        } catch (ex) {}
        return FALLBACK_BASE_URL;
    }

    static function fetchBoard(lat, lon, callback) {
        fetchSelection(lat, lon, null, callback);
    }

    static function fetchSelection(lat, lon, selection, callback) {
        var url = baseUrl() + "/mta/board?lat=" + lat.format("%.5f") +
            "&lon=" + lon.format("%.5f") + "&limitStations=5&limitArrivals=8";
        if (selection != null) {
            url += "&station=" + Communications.encodeURL(selection["station"]["id"]);
            if (selection["route"] != null) { url += "&route=" + Communications.encodeURL(selection["route"]); }
            if (selection["dir"] != null) { url += "&dir=" + Communications.encodeURL(selection["dir"]); }
        }
        try {
            Communications.makeWebRequest(url, null, {
                :timeout => 10,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            }, callback);
        } catch (ex) {
            callback.invoke(-1, null);
        }
    }
}
