using Toybox.Application;
using Toybox.Lang;
using Toybox.System;
using Toybox.Test;
using Toybox.Time;

// Bundled dataset: every chunk well formed, home stations first, lookups and hints.
(:test)
function offlineDataset(logger) {
    var idx = StationData.index() as Lang.Array;
    Test.assert(StationData.COUNT >= 200 && idx.size() == StationData.COUNT * 2);
    var homes = 0;
    for (var i = 0; i < StationData.COUNT; i += 1) {
        var st = OfflineStations.station(i);
        Test.assert(Config.station(st));
        Test.assert((st["routes"] as Lang.Array).size() > 0);
        Test.assert((st["groups"] as Lang.Array).size() % 5 == 0);
        // The index and the chunk agree on the point; entrances are within 400 m of it.
        Test.assert(PackStore.meters(st["lat"], st["lon"], idx[2 * i] / 100000.0d, idx[2 * i + 1] / 100000.0d) < 1);
        var ents = st["entrances"] as Lang.Array;
        for (var e = 0; e < ents.size(); e += 1) {
            Test.assert(PackStore.meters(st["lat"], st["lon"], ents[e]["lat"], ents[e]["lon"]) < 400);
        }
        if (st["home"] == true) { homes += 1; }
    }
    logger.debug("bundled stations: " + StationData.COUNT + ", home: " + homes + ", " + StationData.SOURCE);
    Test.assert(homes == 7);
    Test.assert(OfflineStations.station(StationData.COUNT) == null && OfflineStations.station(-1) == null);

    // Nearest first, bounded, and nothing for an invalid fix.
    var home = OfflineStations.nearest(40.73339, -73.99367, 5);
    Test.assert(home.size() == 5);
    for (var i = 1; i < home.size(); i += 1) { Test.assert(home[i - 1][1] <= home[i][1]); }
    var union = OfflineStations.station(home[0][0]);
    Test.assert(union["name"].equals("14 St-Union Sq") && union["home"] == true);
    Test.assert(OfflineStations.hint(union, null).equals("Home station"));
    Test.assert(OfflineStations.nearest(0, 0, 5).size() == 0);

    // Battery Park: Bowling Green, 4 5 uptown ride home.
    var battery = OfflineStations.station(OfflineStations.nearest(40.7033, -74.0170, 1)[0][0]);
    Test.assert(battery["name"].equals("Bowling Green"));
    Test.assert(OfflineStations.hint(battery, null).equals("Home: 4 5 Uptown"));
    Test.assert(OfflineStations.homeRoute(battery).equals("4"));
    // Canal St (J Z, N Q, R W, 6): several home rides, first one only when limited.
    var canal = OfflineStations.station(OfflineStations.nearest(40.71870, -74.00058, 1)[0][0]);
    Test.assert(canal["name"].equals("Canal St") && canal["routes"].size() == 7);
    Test.assert(OfflineStations.hint(canal, 1).equals("Home: N Q Uptown"));
    Test.assert(OfflineStations.hint(canal, null).equals("Home: N Q Uptown, R W Uptown, 6 Uptown"));
    // Walking distance uses the nearest entrance, not the station point.
    var m = OfflineStations.meters(battery, 40.7033, -74.0170);
    Test.assert(m <= PackStore.meters(40.7033, -74.0170, battery["lat"], battery["lon"]));

    // Board rows: rides home first (green), then other lines per direction.
    var rows = MtaBoardRenderer.staticRows(canal);
    Test.assert(rows[0][0].equals("N Q") && rows[0][1].equals("Uptown") && rows[0][2] == true);
    Test.assert(rows[3][0].equals("J Z") && rows[3][2] == false);
    // Home stations list every direction plainly.
    var urows = MtaBoardRenderer.staticRows(union);
    Test.assert(urows.size() == 6 && urows[0][2] == false);
    return true;
}

(:test)
class OfflineBoardProbe extends BoardView {
    var known = null;
    function initialize() { BoardView.initialize(); _visible = true; }
    function fetch(lat, lon, stale, gen) {}
    function lastKnown() { return known; }

    function run(logger) {
        var now = Time.now().value();
        Application.Storage.deleteValue("pack");
        // No phone, a fix at Hudson River Park / W 22 St: the nearest bundled station.
        locationLat = 40.7475;
        locationLon = -74.0080;
        locationTime = System.getTimer();
        _requestSelection = null;
        Test.assert(restoreOffline());
        logger.debug("offline board: " + _boardName + " / " + OfflineStations.hint(_boardStation, null));
        Test.assert(_static && _boardName.equals("23 St") && _boardArrivals == null);
        Test.assert(stationTarget()["meters"] != null);  // arrow + walk to the nearest entrance
        Test.assert(refreshDelay() == REFRESH_MS);
        // A live board with trains still to come, near the fix, stays (marked Offline).
        var near = {"id" => "A30", "name" => "23 St", "lat" => 40.745906, "lon" => -73.998041};
        render("23 St", null, [{"route" => "C", "dest" => "Euclid Av", "arrival_at" => now + 300}]);
        _boardStation = near;
        Test.assert(!restoreOffline() && !_static);
        // ...but not once we have moved away (Battery Park).
        locationLat = 40.7033;
        locationLon = -74.0170;
        Test.assert(restoreOffline() && _static && _boardName.equals("Bowling Green"));
        // A fresh run pack beats the bundled data.
        Test.assert(PackStore.save(PolishFixture.pack(now)));
        Test.assert(restoreOffline() && _scheduled && !_static);
        Application.Storage.deleteValue("pack");
        // An explicit selection shows that station, wherever the fix is.
        selection = {"station" => {"id" => "L08", "name" => "Bedford Av", "lat" => 40.717304, "lon" => -73.956872},
            "route" => null, "dir" => null};
        _requestSelection = selection;
        Test.assert(restoreOffline() && _boardName.equals("Bedford Av"));
        Test.assert(OfflineStations.hint(_boardStation, null).equals("Home: L Manhattan"));
        selection = null;
        // No fix of its own: the last known position (e.g. the run just finished).
        locationLat = null;
        locationLon = null;
        known = [40.7003, -73.9967];
        _requestSelection = null;
        showStatus("Waiting for GPS", "");
        _fetching = true;
        fetchLastStation();
        Test.assert(_static && _boardName.equals("Clark St"));
        // Nothing to go on: the old status.
        known = null;
        showStatus("Waiting for GPS", "");
        _fetching = true;
        fetchLastStation();
        Test.assert(!_static && _boardName == null && _statusTitle.equals("No GPS fix"));
        return true;
    }
}

(:test)
class OfflineGlanceProbe extends MtaGlanceView {
    var known = null;
    function initialize() { MtaGlanceView.initialize(); }
    function lastKnown() { return known; }
    function run(logger) {
        var now = Time.now().value();
        var s = {"id" => "L03", "name" => "14 St-Union Sq", "lat" => 40.7347, "lon" => -73.9907};
        // Cached home board whose trains have all left; offline, no pack, last known at Battery Park.
        _entry = BoardStore.savePrimary({"station" => s,
            "arrivals" => [{"route" => "L", "dest" => "Canarsie-Rockaway Pkwy", "arrival_at" => now - 600}]});
        _pack = null;
        _packStation = null;
        known = [40.7033, -74.0170];
        _offline = true;
        paintFromCache();
        logger.debug("offline glance: " + _route + " " + _primary + " / " + secondaryText());
        Test.assert(_staticGlance && _route.equals("4") && _primary.equals("Bowling Green"));
        Test.assert(secondaryText().equals("Home: 4 5 Uptown"));
        // Online again: the cached board, not the bundled station.
        _offline = false;
        paintFromCache();
        Test.assert(!_staticGlance && _primary.equals("No trains"));
        // Offline without any last known position: the plain Offline line.
        onHide();
        _entry = BoardStore.load();
        known = null;
        _offline = true;
        paintFromCache();
        Test.assert(!_staticGlance && _primary.equals("Offline"));
        return true;
    }
}

(:test)
function offlineFallback(logger) {
    var keys = ["board", "boards", "pack"];
    var saved = {};
    for (var i = 0; i < keys.size(); i += 1) { saved[keys[i]] = Application.Storage.getValue(keys[i]); }
    try {
        Application.Storage.deleteValue("board");
        Application.Storage.deleteValue("boards");
        new OfflineBoardProbe().run(logger);
        new OfflineGlanceProbe().run(logger);
    } finally {
        for (var i = 0; i < keys.size(); i += 1) {
            if (saved[keys[i]] == null) { Application.Storage.deleteValue(keys[i]); }
            else { Application.Storage.setValue(keys[i], saved[keys[i]]); }
        }
    }
    return true;
}
