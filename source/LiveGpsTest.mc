using Toybox.System;
using Toybox.Test;
using Toybox.Time;

(:test)
class LiveGpsStub {
    var starts = 0;
    var stops = 0;
    function start() { starts += 1; }
    function stop() { stops += 1; }
}

(:test)
class LiveGpsBoardProbe extends BoardView {
    var calls = 0;
    var target;
    function initialize() { BoardView.initialize(); _tracker = new LiveGpsStub(); }
    function lastKnown() { return null; }
    function refreshPack() {}
    function fetch(lat, lon, stale, gen) {
        calls += 1;
        target = _requestSelection;
        _boardStation = target["station"];
        _fetching = false;
        render(_boardStation["name"], stale, []);
    }

    function checkMovement() {
        onFix(40.7033, -74.0170, null);
        var first = stationTarget();
        Test.assert(first != null && first["meters"] > 0);
        var lat = (locationLat + first["point"]["lat"]) / 2;
        var lon = (locationLon + first["point"]["lon"]) / 2;
        var count = calls;
        locationTime = System.getTimer() - 1000;
        onFix(lat, lon, null);
        Test.assert(locationLat == lat && locationLon == lon);
        Test.assert(System.getTimer() - locationTime < 1000);
        Test.assert(stationTarget()["meters"] < first["meters"]);
        _heading = 0.0;
        _headingTime = System.getTimer();
        Test.assert(stationDirection(stationTarget()) != null);
        onFix(40.7, -74.0, 60);
        onFix(null, null, null);
        Test.assert(locationLat == lat && locationLon == lon && calls == count);
        _fetching = true;
        onFix(lat + 0.00001, lon + 0.00001, null);
        Test.assert(locationLat == lat + 0.00001 && locationLon == lon + 0.00001 && calls == count);
        _fetching = false;
    }

    function checkHidden() {
        var lat = locationLat;
        var lon = locationLon;
        var time = locationTime;
        var list = nearby;
        var count = calls;
        onHide();
        onFix(41.0, -73.0, null);
        onRedrawTick();
        Test.assert(locationLat == lat && locationLon == lon && locationTime == time);
        Test.assert(nearby == list && calls == count && _tracker.stops == 1);
    }

    function runNearby() {
        onShow();
        Test.assert(_tracker.starts == 1 && calls == 0);
        checkMovement();
        Test.assert(calls == 1 && selection == null);
        var first = target["station"]["id"];
        for (var i = 0; i < 5; i += 1) {
            onFix(40.7830 + i * 0.00001, -73.9600, null);
            onRedrawTick();
        }
        Test.assert(calls == 1 && !nearby[0]["station"]["id"].equals(first));
        _nextRefresh = 0;
        onRedrawTick();
        Test.assert(calls == 2 && target["station"]["id"].equals(nearby[0]["station"]["id"]));
        cycleNearby(1);
        var browsed = target["station"]["id"];
        var count = calls;
        onFix(40.7033, -74.0170, null);
        Test.assert(nearbyIndex(_nearbyStation) < 0 && _nearbyStation["id"].equals(browsed));
        Test.assert(calls == count && _tracker.stops == 0);
        _boardArrivals = [{"route" => "4", "arrival_at" => Time.now().value() + 120}];
        _nextRefresh = 0;
        onRedrawTick();
        Test.assert(calls == count + 1 && target["station"]["id"].equals(browsed));
        Test.assert(_nextRefresh - System.getTimer() <= FAST_REFRESH_MS);
        Test.assert(_nextRefresh - System.getTimer() > FAST_REFRESH_MS - 1000);
        onRedrawTick();
        Test.assert(calls == count + 1 && _tracker.starts == 1);
        checkHidden();
    }

    function runSelected() {
        var station = {"id" => "test", "name" => "Test", "lat" => 40.705, "lon" => -74.015,
            "entrances" => [{"lat" => 40.704, "lon" => -74.016}]};
        selection = {"station" => station, "route" => "4", "dir" => "N"};
        onShow();
        Test.assert(_tracker.starts == 1 && calls == 1);
        checkMovement();
        Test.assert(calls == 1 && target == selection);
        _fetching = true;
        onRequestTimeout();
        onFix(40.704, -74.016, null);
        Test.assert(_tracker.stops == 0 && locationLat == 40.704 && locationLon == -74.016);
        locationTime = System.getTimer() - 301000;
        onRedrawTick();
        Test.assert(locationLat == null && locationLon == null && stationTarget() == null);
        _nextRefresh = 0;
        onRedrawTick();
        Test.assert(calls == 2 && target == selection && _tracker.starts == 1);
        checkHidden();
    }
}

(:test)
function liveGpsNearby(logger) {
    var view = new LiveGpsBoardProbe();
    try { view.runNearby(); }
    finally { view.onHide(); }
    return true;
}

(:test)
function liveGpsSelection(logger) {
    var view = new LiveGpsBoardProbe();
    try { view.runSelected(); }
    finally { view.onHide(); }
    return true;
}
