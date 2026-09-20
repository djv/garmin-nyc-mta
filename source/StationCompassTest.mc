using Toybox.Application;
using Toybox.Test;
using Toybox.Math;

(:test)
function stationCompassRules(logger) {
    var north = {"lat" => 41.0, "lon" => -74.0};
    var east = {"lat" => 0.0, "lon" => -73.0};
    var south = {"lat" => 39.0, "lon" => -74.0};
    var west = {"lat" => 0.0, "lon" => -75.0};
    Test.assert(StationCompass.abs(StationCompass.direction(40.0, -74.0, north, 0.0)) < 0.0001);
    Test.assert(StationCompass.abs(StationCompass.direction(0.0, -74.0, east, 0.0) - Math.PI/2) < 0.0001);
    Test.assert(StationCompass.abs(StationCompass.direction(40.0, -74.0, south, 0.0) - Math.PI) < 0.0001);
    Test.assert(StationCompass.abs(StationCompass.direction(0.0, -74.0, west, 0.0) - 3*Math.PI/2) < 0.0001);
    // Facing east puts a northern station to the left.
    Test.assert(StationCompass.abs(StationCompass.direction(40.0, -74.0, north, Math.PI/2) - 3*Math.PI/2) < 0.0001);
    Test.assert(StationCompass.abs(StationCompass.direction(40.0, -74.0, north, 2*Math.PI-0.01) - 0.01) < 0.0001);
    Test.assert(StationCompass.direction(null, -74.0, north, 0.0) == null);
    Test.assert(StationCompass.direction(40.0, -74.0, null, 0.0) == null);
    Test.assert(StationCompass.direction(40.0, -74.0, north, null) == null);
    Test.assert(StationCompass.direction(40.0, -74.0, north, 100.0) == null);
    Test.assert(StationCompass.direction(41.0, -74.0, north, 0.0) == null);
    return true;
}

(:test)
function entranceRules(logger) {
    var a = {"lat" => 40.001, "lon" => -74.0};
    var b = {"lat" => 40.002, "lon" => -74.0};
    var s = {"id" => "test", "name" => "Test", "lat" => 40.1, "lon" => -74.0, "entrances" => [null, {}, b, a]};
    var t = StationCompass.target(40.0, -74.0, s);
    Test.assert(t["point"] == a && t["meters"] > 110 && t["meters"] < 112);
    Test.assert(StationCompass.target(40.003, -74.0, s)["point"] == b);
    Test.assert(StationCompass.direction(40.0, -74.0, t["point"], null) == null);
    Test.assert(t["meters"] != null);
    Test.assert(StationCompass.target(null, -74.0, s) == null);
    s["entrances"] = [];
    Test.assert(StationCompass.target(40.0, -74.0, s)["meters"] == null);
    s.remove("entrances");
    var previous = Application.Storage.getValue("board");
    try {
        BoardStore.save({"station" => s, "arrivals" => []});
        var old = BoardStore.load();
        Test.assert(old != null);
        Test.assert(StationCompass.target(40.0, -74.0, old["board"]["station"])["meters"] == null);
        s["entrances"] = [a,b];
        BoardStore.save({"station" => s, "arrivals" => []});
        Test.assert(BoardStore.load()["board"]["station"]["entrances"].size() == 2);
    } finally {
        if (previous == null) { Application.Storage.deleteValue("board"); }
        else { Application.Storage.setValue("board", previous); }
    }
    return true;
}
