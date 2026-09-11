using Toybox.WatchUi;
using Toybox.Lang;

module CommuteMenus {
    function open(view) {
        var menu = new WatchUi.Menu2({:title => "Stations"});
        menu.addItem(new WatchUi.MenuItem("Nearby stations", null, :nearby, null));
        menu.addItem(new WatchUi.MenuItem("Recent commutes", "10 most recently used", :recent, null));
        menu.addItem(new WatchUi.MenuItem("Automatic nearest", "Clear station filter", :auto, null));
        WatchUi.pushView(menu, new CommuteMenuDelegate(view, :root, null, null), WatchUi.SLIDE_LEFT);
    }

    function show(view, mode, entry, route) {
        var title = "Direction";
        if (mode == :nearby) { title = "Nearby stations"; }
        else if (mode == :line) { title = "Choose line"; }
        else if (mode == :recent) { title = view.locationLat == null ? "Recent commutes" : "Recents / nearest"; }
        var menu = new WatchUi.Menu2({:title => title});
        if (mode == :nearby) {
            for (var i = 0; i < view.nearby.size(); i += 1) {
                var e = view.nearby[i];
                var distance = view.locationLat == null ? "GPS unavailable" :
                    "~" + RecentCommutes.distance(e, view.locationLat, view.locationLon).format("%.0f") + " m direct";
                menu.addItem(new WatchUi.MenuItem(e["station"]["name"], distance, e, null));
            }
            if (view.nearby.size() == 0) { menu.addItem(new WatchUi.MenuItem("Get location first", "Back, then tap to refresh", :empty, null)); }
        } else if (mode == :recent) {
            var items = RecentCommutes.sorted(view.locationLat, view.locationLon);
            for (var i = 0; i < items.size(); i += 1) {
                var value = items[i];
                var label = value["route"] == null ? "All lines" : value["route"];
                if (value["dir"] != null) { label += " / " + value["dir"] + " bound"; }
                if (view.locationLat != null) { label += " / ~" + RecentCommutes.distance(value, view.locationLat, view.locationLon).format("%.0f") + " m direct"; }
                menu.addItem(new WatchUi.MenuItem(value["station"]["name"], label, value, null));
            }
            if (items.size() == 0) { menu.addItem(new WatchUi.MenuItem("No recent commutes", "Choose a nearby station", :empty, null)); }
        } else if (mode == :line) {
            menu.addItem(new WatchUi.MenuItem("All lines", null, :all, null));
            var routes = entry["station"]["routes"];
            for (var i = 0; i < routes.size(); i += 1) { menu.addItem(new WatchUi.MenuItem(routes[i], null, routes[i], null)); }
        } else {
            var options = entry["options"];
            var directions = ["N", "S"];
            for (var d = 0; d < directions.size(); d += 1) {
                var names = "";
                if (options instanceof Lang.Array) {
                    for (var i = 0; i < options.size(); i += 1) {
                        var o = options[i];
                        if (o["route"].equals(route) && o["dir"] != null && o["dir"].equals(directions[d]) && o["dest"].length() > 0) {
                            names += (names.length() > 0 ? " / " : "") + o["dest"];
                        }
                    }
                }
                menu.addItem(new WatchUi.MenuItem(names.length() > 0 ? names : "Direction " + directions[d],
                    route + " / direction " + directions[d] + (names.length() > 0 ? "" : " / No trains"), directions[d], null));
            }
        }
        WatchUi.switchToView(menu, new CommuteMenuDelegate(view, mode, entry, route), WatchUi.SLIDE_LEFT);
    }
}

class CommuteMenuDelegate extends WatchUi.Menu2InputDelegate {
    var view;
    var mode;
    var entry;
    var route;
    function initialize(v, m, e, r) {
        Menu2InputDelegate.initialize();
        view = v; mode = m; entry = e; route = r;
    }
    function onSelect(item) {
        var id = item.getId();
        if (id == :empty) { return; }
        if (mode == :root) {
            if (id == :auto) { view.choose(null); }
            else { CommuteMenus.show(view, id, null, null); }
        } else if (mode == :nearby) { CommuteMenus.show(view, :line, id, null); }
        else if (mode == :recent) { view.choose(id); }
        else if (mode == :line && id != :all) { CommuteMenus.show(view, :direction, entry, id); }
        else {
            view.choose({"station" => entry["station"], "route" => mode == :line ? null : route,
                "dir" => id == :all ? null : id});
        }
    }
}
