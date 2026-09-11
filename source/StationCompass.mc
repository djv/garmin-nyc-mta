using Toybox.Math;
using Toybox.Lang;

module StationCompass {
    function abs(v) { return v < 0 ? -v : v; }
    // Radians clockwise from the top of the display; null has no direction.
    function direction(lat, lon, station, heading) {
        if (!Config.coordinates(lat, lon) || !(station instanceof Lang.Dictionary) ||
            !Config.coordinates(station["lat"], station["lon"]) ||
            !Config.numeric(heading) || !(heading >= -2*Math.PI && heading <= 2*Math.PI)) { return null; }
        var p1 = lat * Math.PI / 180;
        var p2 = station["lat"] * Math.PI / 180;
        var dl = (station["lon"] - lon) * Math.PI / 180;
        var y = Math.sin(dl) * Math.cos(p2);
        var x = Math.cos(p1)*Math.sin(p2) - Math.sin(p1)*Math.cos(p2)*Math.cos(dl);
        if (abs(x) + abs(y) < 0.0000001) { return null; }
        var angle = Math.atan2(y, x) - heading;
        while (angle < 0) { angle += 2*Math.PI; }
        while (angle >= 2*Math.PI) { angle -= 2*Math.PI; }
        return angle;
    }
}
