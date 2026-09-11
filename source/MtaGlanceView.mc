using Toybox.Graphics;
using Toybox.Lang;
using Toybox.PersistedContent;
using Toybox.Timer;
using Toybox.WatchUi;
using Toybox.System;

(:glance)
class MtaGlanceView extends WatchUi.GlanceView {
    static const REFRESH_MIN_S = 60;
    static const REDRAW_MS = 5000;

    hidden var _primary;
    hidden var _stationName;
    hidden var _visible;
    hidden var _refreshing;
    hidden var _redrawTimer;
    hidden var _route;
    hidden var _generation = 0;
    hidden var _deadline = 0;
    hidden var _retryAt = 0;
    hidden var _offline = false;
    hidden var _selection = null;
    hidden var _forceRefresh = false;

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
        var cached = BoardStore.load();
        _selection = null;
        if (cached instanceof Lang.Dictionary && cached["board"] instanceof Lang.Dictionary) {
            _selection = GlanceSelection.forStation(cached["board"]["station"]);
        }
        // Cached first-eight arrivals may omit this direction: fetch it explicitly.
        _forceRefresh = _selection != null;
        paintFromCache();
        _redrawTimer.stop();
        _redrawTimer.start(method(:onRedrawTick), REDRAW_MS, true);
        refreshIfDue();
    }

    function refreshIfDue() {
        if (!_visible) { return; }
        var now = System.getTimer();
        if (_refreshing && now >= _deadline) {
            _generation += 1;
            _refreshing = false;
            _offline = true;
            _forceRefresh = true;
            _retryAt = now + 30000;
        }
        var entry = BoardStore.load();
        var age = BoardStore.ageSeconds(entry);
        if (!_refreshing && now >= _retryAt && (_forceRefresh || age == null || age < 0 || (age as Lang.Number) >= REFRESH_MIN_S)) {
            // Glance has no GPS; use the last cached station.
            _refreshing = true;
            _forceRefresh = false;
            _generation += 1;
            _deadline = now + 15000;
            var lat = Config.FALLBACK_LAT;
            var lon = Config.FALLBACK_LON;
            if (entry instanceof Lang.Dictionary && entry["board"] instanceof Lang.Dictionary) {
                var station = entry["board"]["station"];
                if (station instanceof Lang.Dictionary && station["lat"] != null && station["lon"] != null) {
                    lat = station["lat"];
                    lon = station["lon"];
                }
            }
            var request = new GlanceRequest(self, _generation);
            MtaClient.fetchSelection(lat, lon, _selection, request.method(:onResponse));
        }
    }

    function onHide() {
        _visible = false;
        _generation += 1;
        _refreshing = false;
        _redrawTimer.stop();
    }

    function onRedrawTick() {
        if (_visible) {
            refreshIfDue();
            WatchUi.requestUpdate();
        } else {
            _redrawTimer.stop();
        }
    }

    function onBoard(generation, code, data) {
        if (!_visible || !_refreshing || generation != _generation) { return; }
        _refreshing = false;
        _offline = true;
        _forceRefresh = true;
        _retryAt = System.getTimer() + 30000;
        if (code == 200 && data instanceof Lang.Dictionary) {
            var stations = data["stations"];
            if (stations instanceof Array && stations.size() > 0 &&
                stations[0] instanceof Lang.Dictionary &&
                stations[0]["station"] instanceof Lang.Dictionary &&
                stations[0]["arrivals"] instanceof Lang.Array) {
                BoardStore.save(stations[0]);
                _offline = false;
                _forceRefresh = false;
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
        _stationName = MtaFormat.safeText(station instanceof Lang.Dictionary ? station["name"] : null, "MTA");
        var arrs = b["arrivals"];
        var upcoming = [] as Lang.Array;
        if (arrs instanceof Array) {
            for (var i = 0; i < arrs.size(); i += 1) {
                if (GlanceSelection.matches(arrs[i], _selection) && MtaFormat.upcoming(arrs[i])) { upcoming.add(arrs[i]); }
            }
        }
        arrs = upcoming as Lang.Array;
        if (arrs instanceof Array && arrs.size() > 0 && arrs[0] instanceof Lang.Dictionary) {
            _route = MtaFormat.safeText(arrs[0]["route"], "?");
            _primary = MtaFormat.arrivalWhen(arrs[0]) + " " + MtaFormat.shortDestination(arrs[0]["dest"]);
        } else {
            var age = BoardStore.ageSeconds(entry);
            _primary = _offline ? "Offline" : (_refreshing ? "Refreshing" :
                (age == null || age >= REFRESH_MIN_S ? "Stale data" : "No trains"));
        }
    }

    function secondaryText() {
        if (_stationName == null) {
            return "Open app";
        }
        var age = BoardStore.ageSeconds(BoardStore.load());
        return (_refreshing ? "Updating " : (_offline ? "Offline " : "")) +
            (age != null ? MtaFormat.ageText(age) + " " : "") + _stationName;
    }

    function onUpdate(dc) {
        paintFromCache();
        var w = dc.getWidth();
        var h = dc.getHeight();
        var f1 = Graphics.FONT_GLANCE;
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
        dc.setColor(0xA8A8A8, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left, y + h1 + 4 + h2 / 2, f2, s,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

(:glance)
class GlanceRequest {
    hidden var _view;
    hidden var _generation;
    function initialize(view, generation) {
        _view = view;
        _generation = generation;
    }
    function onResponse(code as Lang.Number, data as Lang.Dictionary or Lang.String or PersistedContent.Iterator or Null) as Void {
        _view.onBoard(_generation, code, data);
    }
}
