using Toybox.Lang;
using Toybox.Position;
using Toybox.Time;

// The watch's last known position when recent, e.g. from the run just finished. The glance
// has no GPS of its own; the board uses this when no fix of its own arrives.
(:glance)
module LastFix {
    const MAX_AGE_S = 900;

    // [lat, lon] in degrees, or null.
    function recent() {
        try {
            var info = Position.getInfo();
            if (info == null || info.position == null || info.when == null ||
                info.accuracy == Position.QUALITY_NOT_AVAILABLE) { return null; }
            var age = Time.now().value() - info.when.value();
            if (age < 0 || age > MAX_AGE_S) { return null; }
            var d = info.position.toDegrees();
            if (Config.coordinates(d[0], d[1])) { return [d[0].toDouble(), d[1].toDouble()]; }
        } catch (ex) {}
        return null;
    }
}
