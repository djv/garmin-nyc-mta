using Toybox.Test;
using Toybox.Application;

(:test)
function directionLabelRules(logger) {
    var station = {"id" => "L10", "name" => "Lorimer", "lat" => 40.714, "lon" => -73.95};
    var value = {"station" => station, "route" => "L", "dir" => "S"};
    var options = [
        {"route" => "L", "dir" => "S", "dest" => "Canarsie-Rockaway Pkwy"},
        {"route" => "L", "dir" => "S", "dest" => "Canarsie"},
        {"route" => "L", "dir" => "S", "dest" => "Myrtle-Wyckoff Avs"},
        {"route" => "L", "dir" => "N", "dest" => "8 Av"},
        {"route" => "G", "dir" => "S", "dest" => "Church Av"}, null];
    Test.assert(DirectionLabels.selection(value).equals("L / Direction S"));
    Test.assert(DirectionLabels.update(value, options));
    Test.assert(DirectionLabels.selection(value).equals("L to Canarsie / Myrtle-Wyckoff Avs"));
    Test.assert(!DirectionLabels.update(value, []));
    Test.assert(DirectionLabels.destinations(options, "L", "N").equals("8 Av"));
    Test.assert(DirectionLabels.destinations(null, "L", "N") == null);
    Test.assert(DirectionLabels.selection({"route" => "L", "dir" => null}).equals("L / All directions"));
    Test.assert(DirectionLabels.selection({"route" => null}).equals("All lines"));
    Test.assert(GlanceSelection.matches({"route" => "L", "dir" => "S"}, value));
    Test.assert(!GlanceSelection.matches({"route" => "L", "dir" => "N"}, value));
    var old = Application.Storage.getValue("recentCommutesV1");
    try {
        var north = {"station" => station, "route" => "L", "dir" => "N"};
        var south = {"station" => station, "route" => "L", "dir" => "S"};
        Application.Storage.setValue("recentCommutesV1", [north, south]);
        RecentCommutes.refreshLabels({"station" => station, "options" => options});
        var items = RecentCommutes.load();
        Test.assert(items.size() == 2 && items[0]["dir"].equals("N"));
        Test.assert(items[1]["directionLabel"].equals("Canarsie / Myrtle-Wyckoff Avs"));
        Test.assert(items[0]["directionLabel"].equals("8 Av"));
    } finally {
        if (old == null) { Application.Storage.deleteValue("recentCommutesV1"); }
        else { Application.Storage.setValue("recentCommutesV1", old); }
    }
    return true;
}
