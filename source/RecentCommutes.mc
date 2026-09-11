using Toybox.Application;
using Toybox.Lang;
using Toybox.Math;

module RecentCommutes {
    function load() {
        try {
            var items = Application.Storage.getValue("recentCommutesV1");
            if (items instanceof Lang.Array) {
                var valid = [];
                for (var i = 0; i < items.size(); i += 1) {
                    var item = items[i];
                    if (item instanceof Lang.Dictionary && Config.station((item as Lang.Dictionary)["station"])) { valid.add(item); }
                }
                return valid;
            }
        } catch (ex) {}
        return [];
    }

    function same(a, b) {
        return a["station"]["id"].equals(b["station"]["id"]) &&
            equalText(a["route"], b["route"]) && equalText(a["dir"], b["dir"]);
    }

    function equalText(a, b) { return a == null ? b == null : b != null && a.equals(b); }

    function use(value) {
        Application.Storage.setValue("recentCommutesV1", remember(load(), value));
    }

    // Refresh labels in place: network activity must never change recency.
    function refreshLabels(board) {
        var items = load();
        var changed = false;
        for (var i = 0; i < items.size(); i += 1) {
            if (items[i]["station"]["id"].equals(board["station"]["id"])) {
                if (DirectionLabels.update(items[i], board["options"])) { changed = true; }
            }
        }
        if (changed) { Application.Storage.setValue("recentCommutesV1", items); }
    }

    function remember(previous, value) {
        var result = [] as Lang.Array;
        result.add(value);
        for (var i = 0; i < previous.size(); i += 1) {
            var old = previous[i];
            if (!same(old, value) && result.size() < 10) { result.add(old); }
        }
        return result;
    }

    function distance(item, lat, lon) {
        var s = item["station"];
        var dy = (s["lat"] - lat) * Math.PI / 180.0;
        var dx = (s["lon"] - lon) * Math.PI / 180.0;
        var h = Math.pow(Math.sin(dy / 2), 2) + Math.cos(lat * Math.PI / 180.0) *
            Math.cos(s["lat"] * Math.PI / 180.0) * Math.pow(Math.sin(dx / 2), 2);
        return 12742000 * Math.asin(Math.sqrt(h));
    }

    function sorted(lat, lon) {
        return sortItems(load(), lat, lon);
    }

    function sortItems(items, lat, lon) {
        if (lat == null || lon == null) { return items; }
        // Stable insertion sort preserves recency for equal distances.
        for (var i = 1; i < items.size(); i += 1) {
            var value = items[i];
            var j = i;
            while (j > 0 && distance(items[j - 1], lat, lon) > distance(value, lat, lon)) {
                items[j] = items[j - 1];
                j -= 1;
            }
            items[j] = value;
        }
        return items;
    }
}
