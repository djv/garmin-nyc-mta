using Toybox.Graphics;
using Toybox.Lang;
using Toybox.PersistedContent;
using Toybox.Timer;
using Toybox.WatchUi;
using Toybox.System;
using Toybox.Time;

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
    hidden var _alert = false;
    hidden var _scheduledGlance = false;
    // Storage reads copy the whole value into the small glance heap: read once per show.
    hidden var _entry = null;
    hidden var _pack = null;
    hidden var _packStation = null;

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
        _entry = BoardStore.load();
        loadPack();
        var cached = _entry;
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
        var entry = _entry;
        var age = BoardStore.ageSeconds(entry);
        if (entry == null) { return; }
        if (!_refreshing && now >= _retryAt && (_forceRefresh || age == null || age < 0 || (age as Lang.Number) >= REFRESH_MIN_S)) {
            // Glance has no GPS; use the last cached station.
            _refreshing = true;
            _forceRefresh = false;
            _generation += 1;
            _deadline = now + 15000;
            var station = entry["board"]["station"];
            var lat = station["lat"];
            var lon = station["lon"];
            var target = {"station" => station, "route" => _selection == null ? null : _selection["route"],
                "dir" => _selection == null ? null : _selection["dir"]};
            var request = new GlanceRequest(self, _generation);
            MtaClient.fetchSelection(lat, lon, target, request.method(:onResponse));
        }
    }

    function onHide() {
        _visible = false;
        _generation += 1;
        _refreshing = false;
        _redrawTimer.stop();
        _entry = null;
        _pack = null;
        _packStation = null;
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
                Config.station(stations[0]["station"]) &&
                stations[0]["arrivals"] instanceof Lang.Array) {
                var saved = BoardStore.savePrimary(stations[0]);
                if (saved != null) { _entry = saved; }
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
        _scheduledGlance = false;
        var entry = _entry;
        // Offline (e.g. mid-run without the phone), the run pack beats a stale home board.
        if (_offline && paintFromPack()) { return; }
        if (!(entry instanceof Lang.Dictionary) || !(entry["board"] instanceof Lang.Dictionary)) {
            _primary = "MTA";
            _stationName = null;
            paintFromPack();
            return;
        }
        var b = entry["board"] as Lang.Dictionary;
        var station = b["station"];
        _stationName = MtaFormat.safeText(station instanceof Lang.Dictionary ? station["name"] : null, "MTA");
        _alert = Config.alerts(station instanceof Lang.Dictionary ? station : null).size() > 0;
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

    // The run pack and its station nearest the watch's last known position (the run just
    // finished), else the run's destination.
    function loadPack() {
        _pack = PackStore.load();
        _packStation = null;
        if (_pack == null) { return; }
        var fix = LastFix.recent();
        if (fix != null) { _packStation = PackStore.nearest(_pack, fix[0], fix[1], null); }
        if (_packStation == null) { _packStation = PackStore.destination(_pack); }
    }

    // Next scheduled train home from the pack station: "4m Parkside Av" over "Home by 23:34".
    function paintFromPack() {
        var station = _packStation;
        if (station == null) { return false; }
        var rows = PackStore.board(station, Time.now().value())["arrivals"] as Lang.Array;
        if (rows.size() == 0) { return false; }
        _route = MtaFormat.safeText(rows[0]["route"], "?");
        _primary = MtaFormat.arrivalWhen(rows[0]) + " " + MtaFormat.safeText(station["name"], "");
        _stationName = "Home by " + PackStore.clock(rows[0]["home_at"]);
        _alert = false;
        _scheduledGlance = true;
        return true;
    }

    function secondaryText() {
        if (_stationName == null) {
            return "Open app";
        }
        if (_scheduledGlance) { return _stationName; }
        var age = BoardStore.ageSeconds(_entry);
        return (_alert ? "! " : "") + (_refreshing ? "Updating " : (_offline ? "Offline " : "")) +
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
