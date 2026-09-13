using Toybox.Test;
using Toybox.Application;
using Toybox.System;

(:test)
function locationValidation(logger) {
    Test.assert(Config.coordinates(40.7, -73.9));
    Test.assert(!Config.coordinates(0, 0));
    Test.assert(!Config.coordinates(91, -73));
    Test.assert(!Config.coordinates("40", -73));
    Test.assert(!Config.coordinates(null, null));
    Test.assert(Config.fixAge(0) && Config.fixAge(300));
    Test.assert(!Config.fixAge(-1) && !Config.fixAge(301));
    Test.assert(!Config.station({"id" => "", "name" => "Bad", "lat" => 40, "lon" => -73}));
    return true;
}

(:test)
class LocationBoardProbe extends BoardView {
    var calls = 0;
    var gpsChecks = 0;
    var target = null;
    var latitude = null;
    function initialize() { BoardView.initialize(); _visible = true; }
    function fetch(lat, lon, stale, gen) {
        calls += 1; target = _requestSelection; latitude = lat; _staleTag = stale;
    }
    function refresh() { gpsChecks += 1; _nextLocation = System.getTimer() + LOCATION_MS; }
    function run(station) {
        _fetching = true;
        onFix(null, null, null);
        Test.assert(calls == 0 && _statusTitle.equals("Waiting for GPS"));
        BoardStore.save({"station" => station, "arrivals" => []});
        onShow();
        Test.assert(_boardName.equals("Lorimer") && _boardArrivals != null);
        gpsChecks = 0;
        _fetching = true;
        onFix(null, null, null);
        Test.assert(calls == 1 && target["station"]["id"].equals("L10"));
        Test.assert(locationLat == null && _staleTag.equals("Last station"));
        onFix(40.7, -73.9, -1);
        Test.assert(locationLat == null && target != null);
        onFix(40.7, -73.9, 301);
        Test.assert(locationLat == null);
        onFix(40.7, -73.9, 60);
        Test.assert(target == null && locationLat == 40.7 && _staleTag.equals("Saved GPS"));
        onFix(40.8, -73.8, null);
        Test.assert(latitude == 40.8 && locationLon == -73.8);
        _fetching = false;
        _nextLocation = System.getTimer() + LOCATION_MS;
        onRefreshTick();
        Test.assert(target == null && gpsChecks == 0);
        _fetching = false;
        _nextLocation = 0;
        onRefreshTick();
        Test.assert(gpsChecks == 1);
        selection = {"station" => station, "route" => "L", "dir" => "N"};
        _nextLocation = 0;
        onRefreshTick();
        Test.assert(gpsChecks == 1 && target["route"].equals("L"));
        Test.assert(REFRESH_MS == 60000 && LOCATION_MS == 120000);
        locationTime = System.getTimer() - 301000;
        validateLocation();
        Test.assert(locationLat == null && locationLon == null);
        onRequestTimeout();
        Test.assert(_boardName.equals("Lorimer") && _boardArrivals != null);
        var count = calls;
        onHide();
        onFix(41, -74, null);
        onBoard(_requestGen - 1, 200, {"stations" => []});
        onRefreshTick();
        Test.assert(calls == count && !_fetching);
    }
}

(:test)
function locationLifecycle(logger) {
    var old = Application.Storage.getValue("board");
    Application.Storage.deleteValue("board");
    try {
        var view = new LocationBoardProbe();
        view.run({"id" => "L10", "name" => "Lorimer", "lat" => 40.714, "lon" => -73.95});
        Application.Storage.setValue("board", {"board" => {"station" => {"id" => "bad"}, "arrivals" => []}});
        Test.assert(BoardStore.load() == null);
        var glance = new MtaGlanceView();
        glance.onShow();
        Test.assert(glance.secondaryText().equals("Open app"));
        glance.onHide();
    } finally {
        if (old == null) { Application.Storage.deleteValue("board"); }
        else { Application.Storage.setValue("board", old); }
    }
    return true;
}

using Toybox.Time;
using Toybox.Position;

(:test)
class TestCoordinates {
    var coords;
    function initialize(c) { coords = c; }
    function toDegrees() { return coords; }
}
(:test)
class TestFix {
    var position;
    var accuracy;
    var when;
    function initialize(c, q, age) {
        position = new TestCoordinates(c);
        accuracy = q;
        when = new Time.Moment(Time.now().value() - age);
    }
}
(:test)
class GpsPolicyProbe extends GpsTracker {
    var notified = false;
    function initialize() { GpsTracker.initialize(method(:received)); }
    function received(lat, lon, age) { notified = true; }
    function run() {
        _requestTime = Time.now();
        Test.assert(isFresh(new TestFix([40.7, -73.9], Position.QUALITY_GOOD, 0)));
        Test.assert(!isFresh(new TestFix([40.7, -73.9], Position.QUALITY_GOOD, -60)));
        Test.assert(isRecentLastKnown(new TestFix([40.7, -73.9], Position.QUALITY_GOOD, 60)));
        Test.assert(isRecentLastKnown(new TestFix([40.7, -73.9], Position.QUALITY_LAST_KNOWN, 300)));
        Test.assert(!isRecentLastKnown(new TestFix([40.7, -73.9], Position.QUALITY_LAST_KNOWN, 301)));
        Test.assert(!isRecentLastKnown(new TestFix([40.7, -73.9], Position.QUALITY_LAST_KNOWN, -60)));
        Test.assert(!isRecentLastKnown(new TestFix([100, -73.9], Position.QUALITY_LAST_KNOWN, 60)));
        Test.assert(!isRecentLastKnown(new TestFix([40.7, -73.9], Position.QUALITY_NOT_AVAILABLE, 60)));
        _done = false;
        var prior = _generation;
        stop();
        _done = false;
        onPosition(prior, new TestFix([40.7, -73.9], Position.QUALITY_GOOD, 0));
        onPoll(prior);
        Test.assert(!notified);
        stop();
    }
}
(:test)
function gpsPolicy(logger) {
    new GpsPolicyProbe().run();
    return true;
}
