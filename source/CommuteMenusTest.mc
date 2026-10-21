using Toybox.Test;
using Toybox.WatchUi;

(:test)
class MenuBoardProbe extends BoardView {
    function initialize() { BoardView.initialize(); }
    function lastKnown() { return [40.7033, -74.0170]; }
    function choose(value) { selection = value; }

    function run() {
        updateNearby();
        var root = CommuteMenus.rootMenu(self);
        Test.assert(root.getItem(0).getId() == :nearby && root.getItem(1).getId() == :recent);
        Test.assert(root.getItem(2) == null);

        // Offline choices keep their canonical station and useful platform labels.
        var menu = CommuteMenus.nearbyMenu("Nearby stations", nearby, offlinePosition());
        var entry = menu.getItem(0).getId();
        Test.assert(entry["station"]["id"].equals(nearby[0]["station"]["id"]));
        Test.assert(CommuteMenus.directionName(entry, "4", "N").equals("Uptown"));
        var north = new WatchUi.MenuItem("Uptown", null, "N", null);
        new CommuteMenuDelegate(self, :direction, entry, "4").onSelect(north);
        Test.assert(selection["station"]["id"].equals(entry["station"]["id"]));
        Test.assert(selection["route"].equals("4") && selection["dir"].equals("N"));
        Test.assert(selection["directionLabel"].equals("Uptown"));

        // Merging the menus must preserve current live destinations and their filters.
        entry["options"] = [{"route" => "4", "dir" => "N", "dest" => "Woodlawn"}];
        menu = CommuteMenus.nearbyMenu("Nearby stations", nearby, offlinePosition());
        entry = menu.getItem(0).getId();
        Test.assert(CommuteMenus.directionName(entry, "4", "N").equals("Woodlawn"));
        new CommuteMenuDelegate(self, :direction, entry, "4").onSelect(north);
        Test.assert(selection["directionLabel"].equals("Woodlawn"));

        // All trains clears filters, while Follow location clears the fixed station too.
        new CommuteMenuDelegate(self, :line, entry, null).onSelect(
            new WatchUi.MenuItem("All trains", null, :all, null));
        Test.assert(selection["route"] == null && selection["dir"] == null);
        _boardStation = entry["station"];
        _boardStation["alerts"] = [{"title" => "Track work", "desc" => "No service"}];
        root = CommuteMenus.rootMenu(self);
        Test.assert(root.getItem(2).getId() == :alerts && root.getItem(3).getId() == :auto);
        new CommuteMenuDelegate(self, :root, null, null).onSelect(root.getItem(3));
        Test.assert(selection == null && CommuteMenus.rootMenu(self).getItem(3) == null);

        // No usable position must not invent a nearest station or home location.
        menu = CommuteMenus.nearbyMenu("Nearby stations", [], null);
        Test.assert(menu.getItem(0).getId() == :empty);
        return true;
    }
}

(:test)
function combinedNearbyMenu(logger) {
    var view = new MenuBoardProbe();
    try { return view.run(); }
    finally { view.onHide(); }
}
