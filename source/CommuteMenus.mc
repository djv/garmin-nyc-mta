using Toybox.WatchUi;
using Toybox.Lang;

module CommuteMenus {
    function open(view) {
        var menu = new WatchUi.Menu2({:title => "Stations"});
        menu.addItem(new WatchUi.MenuItem("Nearby stations", null, :nearby, null));
        menu.addItem(new WatchUi.MenuItem("Recent commutes", "10 most recently used", :recent, null));
        menu.addItem(new WatchUi.MenuItem("Automatic nearest", "Clear station filter", :auto, null));
        var alerts = view.alerts();
        if (alerts.size() > 0) {
            menu.addItem(new WatchUi.MenuItem("Service alerts", alerts.size().toString() + " active", :alerts, null));
        }
        WatchUi.pushView(menu, new CommuteMenuDelegate(view, :root, null, null), WatchUi.SLIDE_LEFT);
    }

    function showAlerts(view) {
        var alerts = view.alerts();
        var menu = new WatchUi.Menu2({:title => "Service alerts"});
        for (var i = 0; i < alerts.size(); i += 1) {
            menu.addItem(new WatchUi.MenuItem(MtaFormat.safeText(alerts[i]["title"], "Alert"), null, i, null));
        }
        WatchUi.switchToView(menu, new AlertMenuDelegate(alerts), WatchUi.SLIDE_LEFT);
    }

    function show(view, mode, entry, route) {
        var title = "Direction";
        if (mode == :nearby) { title = "Nearby stations"; }
        else if (mode == :line) { title = "Choose line"; }
        else if (mode == :recent) { title = view.locationLat == null ? "Recent commutes" : "Recents / nearest"; }
        var menu = new WatchUi.Menu2({:title => title});
        if (mode == :nearby) {
            menu = StationMenu.create(title, view.nearby);
            for (var i = 0; i < view.nearby.size(); i += 1) {
                var e = view.nearby[i];
                var unit = Config.distanceUnit();
                var distance = view.locationLat == null ? "GPS unavailable" :
                    MtaFormat.distanceLabel(RecentCommutes.distance(e, view.locationLat, view.locationLon), unit) +
                    (unit.equals("walk") ? "" : " direct");
                menu.addItem(StationMenu.item(e["station"]["name"], distance, e, e["station"]));
            }
            if (view.nearby.size() == 0) { menu.addItem(StationMenu.item("Get location first", "Back, then tap to refresh", :empty, {})); }
        } else if (mode == :recent) {
            var items = RecentCommutes.sorted(view.locationLat, view.locationLon);
            menu = StationMenu.create(title, items);
            for (var i = 0; i < items.size(); i += 1) {
                var value = items[i];
                var label = DirectionLabels.selection(value);
                if (view.locationLat != null) {
                    var unit = Config.distanceUnit();
                    label += " / " + MtaFormat.distanceLabel(RecentCommutes.distance(value, view.locationLat, view.locationLon), unit) +
                        (unit.equals("walk") ? "" : " direct");
                }
                menu.addItem(StationMenu.item(value["station"]["name"], label, value, value["station"]));
            }
            if (items.size() == 0) { menu.addItem(StationMenu.item("No recent commutes", "Choose a nearby station", :empty, {})); }
        } else if (mode == :line) {
            menu.addItem(new WatchUi.MenuItem("All lines", null, :all, null));
            var routes = entry["station"]["routes"];
            for (var i = 0; i < routes.size(); i += 1) { menu.addItem(new WatchUi.MenuItem(routes[i], null, routes[i], null)); }
        } else {
            var options = entry["options"];
            var directions = ["N", "S"];
            for (var d = 0; d < directions.size(); d += 1) {
                var names = DirectionLabels.destinations(options, route, directions[d]);
                menu.addItem(new WatchUi.MenuItem(names != null ? names : "Direction " + directions[d],
                    route + (names != null ? " / Toward" : " / Destination unavailable"), directions[d], null));
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
            else if (id == :alerts) { CommuteMenus.showAlerts(view); }
            else { CommuteMenus.show(view, id, null, null); }
        } else if (mode == :nearby) { CommuteMenus.show(view, :line, id, null); }
        else if (mode == :recent) { view.choose(id); }
        else if (mode == :line && id != :all) { CommuteMenus.show(view, :direction, entry, id); }
        else {
            var value = {"station" => entry["station"], "route" => mode == :line ? null : route,
                "dir" => id == :all ? null : id};
            DirectionLabels.update(value, entry["options"]);
            view.choose(value);
        }
    }
}
