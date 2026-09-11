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
