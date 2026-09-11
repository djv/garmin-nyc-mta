using Toybox.Graphics;
using Toybox.Lang;
using Toybox.PersistedContent;
using Toybox.Timer;
using Toybox.WatchUi;

(:glance)
class MtaGlanceView extends WatchUi.GlanceView {
    static const REFRESH_MIN_S = 120;
    static const REDRAW_MS = 30000;

    hidden var _primary;
    hidden var _stationName;
    hidden var _visible;
    hidden var _refreshing;
    hidden var _redrawTimer;
    hidden var _route;

    function initialize() {
        GlanceView.initialize();
        _visible = false;
        _refreshing = false;
        _primary = "MTA";
        _stationName = null;
        _route = null;
        _redrawTimer = new Timer.Timer();
    }

    function onShow() {
        _visible = true;
        paintFromCache();
        _redrawTimer.stop();
        _redrawTimer.start(method(:onRedrawTick), REDRAW_MS, true);
        var entry = BoardStore.load();
        var age = BoardStore.ageSeconds(entry);
        if (!_refreshing && (age == null || (age as Lang.Number) >= REFRESH_MIN_S)) {
            // Glance has no GPS: refresh fixed Lorimer board only as heartbeat.
            // Live location board comes from opening the app.
            _refreshing = true;
            var lat = Config.FALLBACK_LAT;
            var lon = Config.FALLBACK_LON;
            if (entry instanceof Lang.Dictionary && entry["board"] instanceof Lang.Dictionary) {
                var station = entry["board"]["station"];
                if (station instanceof Lang.Dictionary && station["lat"] != null && station["lon"] != null) {
                    lat = station["lat"];
                    lon = station["lon"];
                }
            }
            MtaClient.fetchBoard(lat, lon, method(:onBoard));
        }
    }

    function onHide() {
        _visible = false;
        _redrawTimer.stop();
    }

    function onRedrawTick() {
        if (_visible) {
            WatchUi.requestUpdate();
        } else {
            _redrawTimer.stop();
        }
    }

    function onBoard(code as Lang.Number, data as Lang.Dictionary or Lang.String or PersistedContent.Iterator or Null) as Void {
        _refreshing = false;
        if (code == 200 && data instanceof Lang.Dictionary) {
            var stations = data["stations"];
            if (stations instanceof Array && stations.size() > 0) {
                BoardStore.save(stations[0]);
            }
        }
        paintFromCache();
        if (_visible) {
            WatchUi.requestUpdate();
        }
    }

    function paintFromCache() {
        _route = null;
        var entry = BoardStore.load();
        if (!(entry instanceof Lang.Dictionary) || !(entry["board"] instanceof Lang.Dictionary)) {
            _primary = "MTA";
            _stationName = null;
            return;
        }
        var b = entry["board"] as Lang.Dictionary;
        var station = b["station"];
        _stationName = MtaFormat.safeText(station != null ? station["name"] : null, "MTA");
        var arrs = b["arrivals"];
        var upcoming = [] as Lang.Array;
        if (arrs instanceof Array) {
            for (var i = 0; i < arrs.size(); i += 1) {
                if (MtaFormat.upcoming(arrs[i])) { upcoming.add(arrs[i]); }
            }
        }
        arrs = upcoming as Lang.Array;
        if (arrs instanceof Array && arrs.size() > 0 && arrs[0] instanceof Lang.Dictionary) {
            _route = MtaFormat.safeText(arrs[0]["route"], "?");
            _primary = MtaFormat.arrivalWhen(arrs[0]) + " " + MtaFormat.safeText(arrs[0]["dest"], "");
        } else {
            _primary = "No trains";
        }
    }

    function secondaryText() {
        if (_stationName == null) {
            return "Open app";
        }
        var age = BoardStore.ageSeconds(BoardStore.load());
        return (age != null ? MtaFormat.ageText(age) + " " : "") + _stationName;
    }

    function onUpdate(dc) {
        paintFromCache();
        var w = dc.getWidth();
        var h = dc.getHeight();
        var f1 = Graphics.FONT_GLANCE_NUMBER;
        var f2 = Graphics.FONT_GLANCE;
        var left = _route != null ? 54 : 10;
        var p = MtaFormat.clip(_primary, w - left - 10, dc, f1);
        var s = MtaFormat.clip(secondaryText(), w - left - 10, dc, f2);
        var h1 = dc.getFontHeight(f1);
        var h2 = dc.getFontHeight(f2);
        var y = (h - h1 - 4 - h2) / 2;
        if (_route != null) { MtaFormat.drawBadge(dc, _route, 24, h/2, 17); }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left, y + h1 / 2, f1, p,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(left, y + h1 + 4 + h2 / 2, f2, s,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
