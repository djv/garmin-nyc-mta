using Toybox.Application;
using Toybox.Communications;
using Toybox.Lang;

(:glance)
class MtaClient {
    static function baseUrl() {
        return ProxyConfig.baseUrl();
    }

    static function fetchPack(callback) {
        var url = PackService.url();
        if (url == null) { return false; }
        try {
            Communications.makeWebRequest(url, null, {
                :timeout => 15,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            }, callback);
            return true;
        } catch (ex) {
            return false;
        }
    }

    static function fetchBoard(lat, lon, callback) {
        fetchSelection(lat, lon, null, callback);
    }

    static function fetchSelection(lat, lon, selection, callback) {
        var base = baseUrl();
        if (base.length() == 0) { callback.invoke(-1, null); return; }
        var url = base + "/mta/board?lat=" + lat.format("%.5f") +
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
