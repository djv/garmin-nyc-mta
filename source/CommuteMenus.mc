using Toybox.WatchUi;
using Toybox.Lang;

module CommuteMenus {
    function open(view) {
        WatchUi.pushView(rootMenu(view), new CommuteMenuDelegate(view, :root, null, null), WatchUi.SLIDE_LEFT);
    }

    function rootMenu(view) {
        var menu = new WatchUi.Menu2({:title => "Stations"});
        menu.addItem(new WatchUi.MenuItem("Nearby stations", null, :nearby, null));
        menu.addItem(new WatchUi.MenuItem("Recent commutes", "10 most recently used", :recent, null));
        var alerts = view.alerts();
        if (alerts.size() > 0) {
            menu.addItem(new WatchUi.MenuItem("Service alerts", alerts.size().toString() + " active", :alerts, null));
        }
        if (view.selection != null) {
            menu.addItem(new WatchUi.MenuItem("Follow location", "Show nearest station", :auto, null));
        }
        return menu;
    }

    // One phone-independent station list, retaining any live direction options.
    function nearbyMenu(title, stations, pos) {
        var menu = StationMenu.createWithNotes(title, stations, true);
        var unit = Config.distanceUnit();
        for (var i = 0; i < stations.size(); i += 1) {
            var st = stations[i]["station"];
            var hint = OfflineStations.hint(st, null);
            var detail = pos == null ? "GPS unavailable" :
                MtaFormat.distanceLabel(OfflineStations.meters(st, pos[0], pos[1]), unit) +
                (unit.equals("walk") ? "" : " direct");
            menu.addItem(StationMenu.itemWithNote(st["name"], detail, hint,
                stations[i], st));
        }
        if (stations.size() == 0) {
            menu.addItem(StationMenu.item("Get location first", "Back, then tap to refresh", :empty, {}));
        }
        return menu;
    }

    // Current destinations first; the bundled platform label works without a phone.
    function directionName(entry, route, dir) {
        var name = DirectionLabels.destinations(entry["options"], route, dir);
        if (name != null) { return name; }
        var groups = entry["station"]["groups"];
        if (!(groups instanceof Lang.Array)) { return null; }
        for (var i = 0; i + 4 < groups.size(); i += 5) {
            var routes = MtaFormat.words(groups[i]);
            for (var r = 0; r < routes.size(); r += 1) {
                if (routes[r].equals(route)) {
                    var label = groups[i + (dir.equals("N") ? 1 : 2)];
                    if (label instanceof Lang.String && label.length() > 0) { return label; }
                }
            }
        }
        return null;
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
            view.updateNearby();
            menu = nearbyMenu(title, view.nearby, view.offlinePosition());
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
                var cached = BoardStore.forStation(value["station"]["id"]);
                if (cached != null) { label += " / cached " + MtaFormat.ageText(BoardStore.ageSeconds(cached)); }
                menu.addItem(StationMenu.item(value["station"]["name"], label, value, value["station"]));
            }
            if (items.size() == 0) { menu.addItem(StationMenu.item("No recent commutes", "Choose a nearby station", :empty, {})); }
        } else if (mode == :line) {
            menu.addItem(new WatchUi.MenuItem("All trains", null, :all, null));
            var routes = entry["station"]["routes"];
            for (var i = 0; i < routes.size(); i += 1) { menu.addItem(new WatchUi.MenuItem(routes[i], null, routes[i], null)); }
        } else {
            var directions = ["N", "S"];
            for (var d = 0; d < directions.size(); d += 1) {
                var names = directionName(entry, route, directions[d]);
                menu.addItem(new WatchUi.MenuItem(names != null ? names : "Direction " + directions[d],
                    route, directions[d], null));
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
            if (value["dir"] != null) {
                value["directionLabel"] = CommuteMenus.directionName(entry, route, value["dir"]);
            }
            view.choose(value);
        }
    }
}
