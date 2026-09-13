using Toybox.Application;
using Toybox.Lang;

(:glance)
module GlanceSelection {
    function forStation(station) {
        try {
            return newest(station, Application.Storage.getValue("recentCommutesV1"));
        } catch (ex) { return null; }
    }

    // Storage order is most-recent-use first, independent of menu distance order.
    function newest(station, items) {
        if (!(station instanceof Lang.Dictionary) || !(items instanceof Lang.Array)) { return null; }
        for (var i = 0; i < items.size(); i += 1) {
            var item = items[i];
            if (item instanceof Lang.Dictionary && item["station"] instanceof Lang.Dictionary &&
                item["station"]["id"] != null && item["station"]["id"].equals(station["id"])) {
                return item;
            }
        }
        return null;
    }

    function matches(arrival, selection) {
        if (!(arrival instanceof Lang.Dictionary)) { return false; }
        if (selection == null) { return true; }
        return (selection["route"] == null || (arrival["route"] != null && arrival["route"].equals(selection["route"]))) &&
            (selection["dir"] == null || (arrival["dir"] != null && arrival["dir"].equals(selection["dir"])));
    }
}
