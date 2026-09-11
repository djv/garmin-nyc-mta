using Toybox.Lang;
using Toybox.Position;
using Toybox.Time;
using Toybox.Timer;

// One-shot location fix with Lorimer-style fallback handling by the caller.
//
// notify is invoked exactly once as notify.invoke(lat, lon, staleAgeOrNull)
// on a usable fix, or notify.invoke(null, null, null) when unresolvable
// (caller falls back to a default location).
class GpsTracker {
    static const LAST_KNOWN_MAX_AGE_S = 300;
    static const TIMEOUT_S = 15;
    static const NO_SIGNAL_POLLS = 3;
    static const POLL_MS = 3000;

    hidden var _timer;
    hidden var _notify;
    hidden var _requestTime;
    hidden var _noSignalPolls;
    hidden var _done;

    function initialize(notify as Lang.Method) {
        _timer = new Timer.Timer();
        _notify = notify;
        _requestTime = null;
        _noSignalPolls = 0;
        _done = true;
    }

    function start() {
        stop();
        _done = false;
        _noSignalPolls = 0;
        _requestTime = Time.now();
        enableLocation();
        _timer.start(method(:onPoll), POLL_MS, true);
    }

    function stop() {
        _timer.stop();
        disableLocation();
        _done = true;
    }

    function onPosition(info as Position.Info) as Void {
        if (_done) {
            return;
        }
        if (isFresh(info)) {
            var degrees = info.position.toDegrees();
            finish(degrees[0].toDouble(), degrees[1].toDouble(), null);
        }
    }

    function onPoll() {
        if (_done) {
            _timer.stop();
            return;
        }
        var info = null;
        try {
            info = Position.getInfo();
        } catch (ex) {
            info = null;
        }
        if (info != null && isFresh(info)) {
            var degrees = info.position.toDegrees();
            finish(degrees[0].toDouble(), degrees[1].toDouble(), null);
            return;
        }
        if (elapsed() >= TIMEOUT_S) {
            if (info != null && isRecentLastKnown(info)) {
                var degrees = info.position.toDegrees();
                finish(degrees[0].toDouble(), degrees[1].toDouble(), ageOf(info));
            } else {
                finish(null, null, null);
            }
            return;
        }
        if (hasNoSignal(info)) {
            _noSignalPolls += 1;
            if (_noSignalPolls >= NO_SIGNAL_POLLS) {
                finish(null, null, null);
                return;
            }
        } else {
            _noSignalPolls = 0;
        }
        // Caller may poll progress() for status text.
    }

    // Seconds since start, for "Locating Ns..." status lines.
    function progress() {
        if (_requestTime == null) {
            return 0;
        }
        return Time.now().value() - _requestTime.value();
    }

    hidden function finish(lat, lon, staleAge) {
        stop();
        _notify.invoke(lat, lon, staleAge);
    }

    hidden function elapsed() {
        if (_requestTime == null) {
            return 0;
        }
        return Time.now().compare(_requestTime);
    }

    hidden function enableLocation() {
        try {
            Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
            Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        } catch (ex) {
            finish(null, null, null);
        }
    }

    hidden function disableLocation() {
        try {
            Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
        } catch (ex) {}
    }

    hidden function isFresh(info) {
        if (info == null || info.position == null || info.accuracy == null
                || info.when == null || _requestTime == null) {
            return false;
        }
        if (info.accuracy == Position.QUALITY_NOT_AVAILABLE
                || info.accuracy == Position.QUALITY_LAST_KNOWN
                || _requestTime.compare(info.when) > 0) {
            return false;
        }
        return hasValidCoords(info.position.toDegrees());
    }

    hidden function hasValidCoords(degrees) {
        if (!(degrees instanceof Array) || degrees.size() < 2) {
            return false;
        }
        var lat = degrees[0].toDouble();
        var lon = degrees[1].toDouble();
        return lat >= -90.0 && lat <= 90.0 && lon >= -180.0 && lon <= 180.0
            && (lat != 0.0 || lon != 0.0);
    }

    hidden function isRecentLastKnown(info) {
        if (info == null || info.position == null || info.when == null) {
            return false;
        }
        return info.accuracy == Position.QUALITY_LAST_KNOWN
            && ageOf(info) <= LAST_KNOWN_MAX_AGE_S;
    }

    hidden function hasNoSignal(info) {
        return info == null || info.position == null
            || info.accuracy == Position.QUALITY_NOT_AVAILABLE;
    }

    hidden function ageOf(info) {
        return Time.now().value() - info.when.value();
    }
}
