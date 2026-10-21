using Toybox.Test;
using Toybox.Position;

(:test)
class CachedGpsProbe extends GpsTracker {
    var info;
    var enabled = 0;
    var calls = 0;
    var savedAge;
    var latitude;
    var longitude;
    function initialize() { GpsTracker.initialize(method(:received)); }
    function received(lat, lon, age) {
        calls += 1; savedAge = age; latitude = lat; longitude = lon;
    }
    hidden function readInfo() { return info; }
    hidden function enableLocation() { enabled += 1; }
    hidden function disableLocation() {}
    function run() {
        info = new TestFix([40.7, -73.9], Position.QUALITY_LAST_KNOWN, 60);
        start();
        Test.assert(calls == 1 && enabled == 1 && usedCache && savedAge >= 60);
        onPosition(_generation, new TestFix([40.71, -73.91], Position.QUALITY_GOOD, 0));
        Test.assert(calls == 2 && !usedCache && savedAge == null && !_done);
        onPosition(_generation, new TestFix([40.72, -73.92], Position.QUALITY_GOOD, 0));
        Test.assert(calls == 3 && latitude == 40.72 && longitude == -73.92 && !_done);
        onPosition(_generation, info);
        onPoll(_generation);
        Test.assert(calls == 3); // cached positions and queued acquisition polls cannot win
        var prior = _generation;
        stop();
        onPosition(prior, new TestFix([40.73, -73.93], Position.QUALITY_GOOD, 0));
        Test.assert(calls == 3);
        startFresh();
        Test.assert(calls == 3 && enabled == 2 && !usedCache);
        finish(null, null, null); // no initial signal must not prevent a later fix
        onPosition(_generation, new TestFix([40.74, -73.94], Position.QUALITY_GOOD, 0));
        Test.assert(calls == 5 && latitude == 40.74 && !_done);
        stop();
        info = new TestFix([40.7, -73.9], Position.QUALITY_LAST_KNOWN, 301);
        start();
        Test.assert(calls == 5 && enabled == 3 && !usedCache);
        stop();
        info = new TestFix([40.7, -73.9], Position.QUALITY_LAST_KNOWN, -60);
        start();
        Test.assert(calls == 5 && enabled == 4 && !usedCache);
        stop();
        info = null;
        start();
        Test.assert(calls == 5 && enabled == 5 && !usedCache);
        stop();
    }
}

(:test)
function immediateCachedGps(logger) {
    new CachedGpsProbe().run();
    return true;
}
