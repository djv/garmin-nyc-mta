using Toybox.Application;
using Toybox.Lang;

(:glance)
module Config {
    const DISTANCE_UNITS = ["walk", "meters", "feet", "miles"];

    function coordinates(lat, lon) {
        return numeric(lat) && numeric(lon) && lat >= -90 && lat <= 90 &&
            lon >= -180 && lon <= 180 && (lat != 0 || lon != 0);
    }
    function numeric(v) {
        return v instanceof Lang.Number || v instanceof Lang.Long ||
            v instanceof Lang.Float || v instanceof Lang.Double;
    }
    function station(s) {
        return s instanceof Lang.Dictionary && s["id"] instanceof Lang.String &&
            s["id"].length() > 0 && s["name"] instanceof Lang.String &&
            s["name"].length() > 0 && coordinates(s["lat"], s["lon"]);
    }
    function fixAge(age) { return numeric(age) && age >= 0 && age <= 300; }
    function distanceUnit() {
        var v = 0;
        try { v = Application.Properties.getValue("distanceUnit"); } catch (ex) { v = 0; }
        var i = numeric(v) ? (v as Lang.Number).toNumber() : 0;
        if (i < 0 || i >= DISTANCE_UNITS.size()) { i = 0; }
        return DISTANCE_UNITS[i];
    }
}
