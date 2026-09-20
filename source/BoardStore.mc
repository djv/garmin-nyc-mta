using Toybox.Application;
using Toybox.Lang;
using Toybox.Time;

(:glance)
module BoardStore {
    const KEY = "board";
    const KEY_ALL = "boards";
    const MAX_STATIONS = 8;

    function save(board) {
        try {
            var entry = {
                "time" => Time.now().value(),
                "board" => board
            };
            Application.Storage.setValue(KEY, entry);
            saveStation(entry);
        } catch (ex) {}
    }

    // Keep a small per-station cache so other stations can be shown offline.
    function saveStation(entry) {
        if (!(entry instanceof Lang.Dictionary) || !(entry["board"] instanceof Lang.Dictionary)) { return; }
        var board = entry["board"] as Lang.Dictionary;
        var station = board["station"];
        if (!Config.station(station)) { return; }
        var id = (station as Lang.Dictionary)["id"];
        var result = [entry] as Lang.Array;
        var all = loadAll();
        for (var i = 0; i < all.size(); i += 1) {
            var old = boardOf(all[i]);
            if (old == null) { continue; }
            if ((old["station"] as Lang.Dictionary)["id"].equals(id)) { continue; }
            if (result.size() < MAX_STATIONS) { result.add(all[i]); }
        }
        try {
            Application.Storage.setValue(KEY_ALL, result);
        } catch (ex) {}
    }

    // Returns the "board" dictionary of an entry, or null when malformed.
    function boardOf(entry) {
        if (!(entry instanceof Lang.Dictionary) || !(entry["board"] instanceof Lang.Dictionary)) { return null; }
        return entry["board"] as Lang.Dictionary;
    }

    function loadAll() {
        try {
            var stored = Application.Storage.getValue(KEY_ALL);
            if (stored instanceof Lang.Array) {
                var valid = [] as Lang.Array;
                var list = stored as Lang.Array;
                for (var i = 0; i < list.size(); i += 1) {
                    var board = boardOf(list[i]);
                    if (board != null && Config.station(board["station"]) &&
                        board["arrivals"] instanceof Lang.Array) {
                        valid.add(list[i]);
                    }
                }
                if (valid.size() > 0) { return valid; }
            }
        } catch (ex) {}
        // Fall back to the v1 primary entry (lazy migration).
        var primary = load();
        return primary == null ? [] : [primary];
    }

    function forStation(stationId) {
        var all = loadAll();
        for (var i = 0; i < all.size(); i += 1) {
            var board = boardOf(all[i]);
            if (board == null || !(board["station"] instanceof Lang.Dictionary)) { continue; }
            if ((board["station"] as Lang.Dictionary)["id"].equals(stationId)) { return all[i]; }
        }
        return null;
    }

    function load() {
        try {
            var stored = Application.Storage.getValue(KEY);
            if (!(stored instanceof Lang.Dictionary)) { return null; }
            var entry = stored as Lang.Dictionary;
            var board = boardOf(entry);
            if (board != null && Config.station(board["station"]) &&
                board["arrivals"] instanceof Lang.Array) { return entry; }
            return null;
        } catch (ex) {
            return null;
        }
    }

    function ageSeconds(entry) {
        if (!(entry instanceof Lang.Dictionary) || !Config.numeric(entry["time"])) {
            return null;
        }
        return Time.now().value() - (entry["time"] as Lang.Number);
    }
}
