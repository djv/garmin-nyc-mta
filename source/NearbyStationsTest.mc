using Toybox.Application;
using Toybox.System;
using Toybox.Test;
using Toybox.Time;

(:test)
class NearbyBoardProbe extends BoardView {
    var known = [40.7033, -74.0170];
    var target = null;
    var gpsChecks = 0;
    function initialize() { BoardView.initialize(); }
    function lastKnown() { return known; }
    function refreshPack() {}
    function fetch(lat, lon, stale, gen) { target = _requestSelection; }
    function refresh() { gpsChecks += 1; _nextLocation = System.getTimer() + LOCATION_MS; }

    function run() {
        // A new launch opens the nearest station, even with another station cached.
        var wrong = {"id" => "L10", "name" => "Lorimer", "lat" => 40.714, "lon" => -73.95};
        BoardStore.save({"station" => wrong, "arrivals" => []});
        onShow();
        Test.assert(selection == null && _static && _boardName.equals("Bowling Green"));
        Test.assert(nearby.size() == 5 && gpsChecks == 1);
        var first = nearby[0]["station"];
        var second = nearby[1]["station"];
        var last = nearby[4]["station"];
        Test.assert(nearbySelection()["station"]["id"].equals(first["id"]));

        // DOWN/UP cycle five stations offline, with no recents or inherited filters.
        cycleNearby(1);
        Test.assert(_boardStation["id"].equals(second["id"]) && target["station"]["id"].equals(second["id"]));
        Test.assert(selection == null && target["route"] == null && target["dir"] == null);
        cycleNearby(-1);
        Test.assert(_boardStation["id"].equals(first["id"]));
        cycleNearby(-1);
        Test.assert(_boardStation["id"].equals(last["id"]));
        cycleNearby(1);
        Test.assert(_boardStation["id"].equals(first["id"]));
        Test.assert(RecentCommutes.load().size() == 0);

        selection = {"station" => first, "route" => "4", "dir" => "S"};
        cycleNearby(1);
        Test.assert(selection == null && target["route"] == null && target["dir"] == null);
        var gen = _requestGen;
        cycleNearby(1);
        var chosen = _boardStation;
        onBoard(gen, 200, {"stations" => [{"station" => wrong, "arrivals" => []}]});
        Test.assert(_boardStation["id"].equals(chosen["id"]));

        // A pack for somewhere else must not replace the browsed station.
        var now = Time.now().value();
        PackStore.save(PolishFixture.pack(now));
        Test.assert(!restorePack());
        Test.assert(restoreOffline() && _static && _boardStation["id"].equals(chosen["id"]));
        var wrongPack = PolishFixture.pack(now);
        wrongPack["stations"][0]["name"] = chosen["name"];
        PackStore.save(wrongPack);
        Test.assert(!restorePack());  // same name, different station ID
        Application.Storage.deleteValue("pack");

        // Live direction labels survive recomputing the nearby list on key presses.
        var route = chosen["routes"][0];
        var options = [{"route" => route, "dir" => "N", "dest" => "Woodlawn"}];
        onBoard(_requestGen, 200, {"stations" => [{"station" => chosen, "arrivals" => [], "options" => options}]});
        updateNearby();
        Test.assert(nearby[nearbyIndex(chosen)]["options"].size() == 1);
        Test.assert(DirectionLabels.destinations(nearby[nearbyIndex(chosen)]["options"], route, "N").equals("Woodlawn"));

        // Proxy merging must not add another avenue's line or entrances to a choice.
        var broad = {"id" => chosen["id"], "name" => chosen["name"], "lat" => chosen["lat"], "lon" => chosen["lon"],
            "routes" => [route, "FAKE"], "entrances" => [{"lat" => 40.783, "lon" => -73.96}]};
        var arrivals = [{"route" => route, "arrival_at" => now + 300}, {"route" => "FAKE", "arrival_at" => now + 120}];
        var parsed = parseBoard(200, {"stations" => [{"station" => broad, "arrivals" => arrivals, "options" => options}]});
        keepNearbyComplex(parsed);
        Test.assert(parsed[:arrivals].size() == 1 && parsed[:arrivals][0]["route"].equals(route));
        Test.assert(parsed[:raw]["station"]["entrances"][0]["lat"] == chosen["entrances"][0]["lat"]);

        // Moving beyond the old five stations resets browsing to the new nearest;
        // a nearby choice still reacquires GPS on the normal two-minute cadence.
        _fetching = true;
        onFix(40.7830, -73.9600, null);
        Test.assert(nearby.size() == 5 && target["station"]["id"].equals(nearby[0]["station"]["id"]));
        Test.assert(selection == null && !target["station"]["id"].equals(chosen["id"]));
        _fetching = false;
        _nextLocation = 0;
        var checks = gpsChecks;
        onRefreshTick();
        Test.assert(gpsChecks == checks + 1);

        // No personal position means no stale nearest list and no invented home fix.
        known = null;
        clearLocation();
        updateNearby();
        Test.assert(nearby.size() == 0 && locationLat == null && _nearbyStation == null);
        onHide();
        return true;
    }
}

(:test)
function nearbyStationBrowsing(logger) {
    var keys = ["board", "boards", "pack", "recentCommutesV1"];
    var saved = {};
    for (var i = 0; i < keys.size(); i += 1) {
        saved[keys[i]] = Application.Storage.getValue(keys[i]);
        Application.Storage.deleteValue(keys[i]);
    }
    var view = new NearbyBoardProbe();
    try { view.run(); }
    finally {
        view.onHide();
        for (var i = 0; i < keys.size(); i += 1) {
            if (saved[keys[i]] == null) { Application.Storage.deleteValue(keys[i]); }
            else { Application.Storage.setValue(keys[i], saved[keys[i]]); }
        }
    }
    return true;
}
