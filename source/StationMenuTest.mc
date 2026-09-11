using Toybox.Test;

(:test)
function stationLineRules(logger) {
    var routes = StationMenu.routes({"routes" => ["L", "G", "L", null, "", 3, "7X"]});
    Test.assert(routes.size() == 3 && routes[0].equals("L") && routes[2].equals("7X"));
    Test.assert(StationMenu.routes({}).size() == 0);
    var station = {"routes" => ["1", "2", "3", "4", "5", "6", "7", "A", "C", "E", "N", "Q"]};
    Test.assert(StationMenu.routes(station).size() == 12);
    var item = StationMenu.item("Test", "Distance", :station, station);
    Test.assert(item.getId() == :station);
    var menu = StationMenu.create("Nearby", [{"station" => station}]);
    menu.addItem(item);
    Test.assert(menu.getItem(0).getId() == :station);
    return true;
}
