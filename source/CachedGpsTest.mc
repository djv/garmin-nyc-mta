using Toybox.Test;
using Toybox.Position;

(:test)
class CachedGpsProbe extends GpsTracker {
    var info;
    var enabled = 0;
    var calls = 0;
    var savedAge;
    function initialize() { GpsTracker.initialize(method(:received)); }
    function received(lat, lon, age) { calls += 1; savedAge = age; }
    hidden function readInfo() { return info; }
    hidden function enableLocation() { enabled += 1; }
    hidden function disableLocation() {}
    function run() {
        info = new TestFix([40.7, -73.9], Position.QUALITY_LAST_KNOWN, 60);
        start();
        Test.assert(calls == 1 && enabled == 0 && usedCache && savedAge >= 60);
        startFresh();
        Test.assert(calls == 1 && enabled == 1 && !usedCache);
        stop();
        info = new TestFix([40.7, -73.9], Position.QUALITY_LAST_KNOWN, 301);
        start();
        Test.assert(calls == 1 && enabled == 2 && !usedCache);
        stop();
        info = new TestFix([40.7, -73.9], Position.QUALITY_LAST_KNOWN, -60);
        start();
        Test.assert(calls == 1 && enabled == 3 && !usedCache);
        stop();
        info = null;
        start();
        Test.assert(calls == 1 && enabled == 4 && !usedCache);
        stop();
    }
}

(:test)
function immediateCachedGps(logger) {
    new CachedGpsProbe().run();
    new CachedBoardProbe().run();
    return true;
}

(:test)
class FreshGpsCounter {
    var calls = 0;
    function startFresh() { calls += 1; }
    function stop() {}
}

(:test)
class CachedBoardProbe extends BoardView {
    function initialize() { BoardView.initialize(); }
    function run() {
        var counter = new FreshGpsCounter();
        _tracker = counter;
        _visible = true;
        _freshGpsPending = true;
        refreshGpsAfterCache();
        Test.assert(counter.calls == 1 && _fetching && !_freshGpsPending);
        refreshGpsAfterCache();
        Test.assert(counter.calls == 1);
        _freshGpsPending = true;
        onHide();
        refreshGpsAfterCache();
        Test.assert(counter.calls == 1 && !_freshGpsPending);
        _visible = true;
        selection = {"route" => "L"};
        _freshGpsPending = true;
        refreshGpsAfterCache();
        Test.assert(counter.calls == 1);
    }
}
