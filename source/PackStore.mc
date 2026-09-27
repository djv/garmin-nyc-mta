using Toybox.Application;
using Toybox.Lang;
using Toybox.Math;
using Toybox.Time;
using Toybox.Time.Gregorian;

// Run pack: scheduled trains home from the stations of a planned run, fetched from
// GET /mta/pack while the phone is connected, shown offline mid-run.
// Each pack station has d = [departure epoch, route index, minutes to the door, ...] and
// h = [index into heads (the train's terminal), ...], one per departure (older packs lack h).
(:glance)
module PackStore {
    const KEY = "pack";
    const MAX_ROWS = 8;

    function valid(data) {
        return data instanceof Lang.Dictionary && data["stations"] instanceof Lang.Array &&
            Config.numeric(data["expires"]);
    }

    function save(data) {
        if (!valid(data)) { return false; }
        try {
            Application.Storage.setValue(KEY, {"time" => Time.now().value(), "pack" => data});
            return true;
        } catch (ex) {
            return false;
        }
    }

    // The stored pack while it is unexpired, else null.
    function load() {
        try {
            var stored = Application.Storage.getValue(KEY);
            if (stored instanceof Lang.Dictionary && valid(stored["pack"])) {
                var pack = stored["pack"] as Lang.Dictionary;
                if ((pack["expires"] as Lang.Number) > Time.now().value()) { return pack; }
            }
        } catch (ex) {}
        return null;
    }

    function ageSeconds() {
        try {
            var stored = Application.Storage.getValue(KEY);
            if (stored instanceof Lang.Dictionary && Config.numeric(stored["time"])) {
                return Time.now().value() - (stored["time"] as Lang.Number);
            }
        } catch (ex) {}
        return null;
    }

    function stations(pack) {
        var out = [] as Lang.Array;
        if (!valid(pack)) { return out; }
        var list = pack["stations"] as Lang.Array;
        for (var i = 0; i < list.size(); i += 1) {
            if (Config.station(list[i]) && list[i]["d"] instanceof Lang.Array) { out.add(list[i]); }
        }
        return out;
    }

    // Pack station with this id, or the same name (station complexes have several ids).
    function find(pack, station) {
        if (!(station instanceof Lang.Dictionary)) { return null; }
        var list = stations(pack);
        for (var i = 0; i < list.size(); i += 1) {
            if (list[i]["id"].equals(station["id"])) { return list[i]; }
        }
        for (var i = 0; i < list.size(); i += 1) {
            if (station["name"] instanceof Lang.String && list[i]["name"].equals(station["name"])) { return list[i]; }
        }
        return null;
    }

    // Nearest pack station to the fix (within maxMeters unless null), or null.
    function nearest(pack, lat, lon, maxMeters) {
        if (!Config.coordinates(lat, lon)) { return null; }
        var best = null;
        var bestM = maxMeters;
        var list = stations(pack);
        for (var i = 0; i < list.size(); i += 1) {
            var m = meters(lat, lon, list[i]["lat"], list[i]["lon"]);
            if (bestM == null || m <= bestM) { best = list[i]; bestM = m; }
        }
        return best;
    }

    // The run's destination: the first pack station.
    function destination(pack) {
        var list = stations(pack);
        return list.size() > 0 ? list[0] : null;
    }

    function meters(lat1, lon1, lat2, lon2) {
        var k = Math.cos(lat1 * Math.PI / 180);
        var dy = (lat2 - lat1) * 111320.0;
        var dx = (lon2 - lon1) * 111320.0 * k;
        return Math.sqrt(dx * dx + dy * dy);
    }

    // A board shaped like the proxy's /mta/board station entry, with upcoming scheduled rows.
    function board(station, now) {
        var routes = station["routes"] instanceof Lang.Array ? station["routes"] : [];
        var d = station["d"] as Lang.Array;
        var heads = station["heads"] instanceof Lang.Array ? station["heads"] : [];
        var h = station["h"] instanceof Lang.Array ? station["h"] : [];
        var rows = [] as Lang.Array;
        for (var i = 0; i + 2 < d.size() && rows.size() < MAX_ROWS; i += 3) {
            var dep = d[i];
            var idx = d[i + 1];
            var mins = d[i + 2];
            if (!(dep instanceof Lang.Number) || !(idx instanceof Lang.Number) || !Config.numeric(mins)) { continue; }
            if (dep < now) { continue; }
            var route = idx >= 0 && idx < routes.size() ? routes[idx] : "?";
            var home = dep + ((mins as Lang.Number) * 60).toNumber();
            var k = i / 3;
            var head = k < h.size() && h[k] instanceof Lang.Number && h[k] >= 0 && h[k] < heads.size() ? heads[h[k]] : null;
            rows.add({"route" => route, "dest" => head instanceof Lang.String ? head : "by " + clock(home),
                      "arrival_at" => dep, "scheduled" => true});
        }
        var info = {"id" => station["id"], "name" => station["name"], "lat" => station["lat"],
                    "lon" => station["lon"], "routes" => routes};
        if (station["entrances"] instanceof Lang.Array) { info["entrances"] = station["entrances"]; }
        if (station["alerts"] instanceof Lang.Array) { info["alerts"] = station["alerts"]; }
        return {"station" => info, "arrivals" => rows, "partial" => false, "scheduled" => true};
    }

    function clock(epoch) {
        var t = Gregorian.info(new Time.Moment(epoch), Time.FORMAT_SHORT);
        return t.hour.format("%d") + ":" + t.min.format("%02d");
    }
}
