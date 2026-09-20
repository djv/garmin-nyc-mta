using Toybox.Graphics;
using Toybox.Lang;
using Toybox.PersistedContent;
using Toybox.Timer;
using Toybox.Time;
using Toybox.WatchUi;
using Toybox.System;
using Toybox.Sensor;
using Toybox.Attention;

class BoardView extends WatchUi.View {
    static const REFRESH_MS = 60000;
    static const FAST_REFRESH_MS = 30000;
    static const SOON_S = 300;
    static const LOCATION_MS = 120000;
    hidden var _nextLocation = 0;
    hidden var _requestSelection = null;
    hidden var _freshGpsPending = false;
    hidden var _heading = null;
    hidden var _headingTime = 0;
    hidden var _boardStation = null;
    hidden var _buzzedKey = null;

    hidden var _tracker;
    hidden var _redrawTimer;
    hidden var _fetching;
    hidden var _requestGen;
    hidden var _staleTag;
    hidden var _statusTitle;
    hidden var _statusMeta;
    hidden var _boardName;
    hidden var _boardArrivals;
    hidden var _parseError;
    hidden var _visible;
    hidden var _requestDeadline;
    hidden var _nextRefresh;
    hidden var _refreshError;
    hidden var _partial;
    var nearby;
    var selection;
    var locationLat;
    var locationLon;
    var locationTime;

    function initialize() {
        View.initialize();
        _tracker = new GpsTracker(method(:onFix));
        _redrawTimer = new Timer.Timer();
        _fetching = false;
        _requestGen = 0;
        _staleTag = null;
        _parseError = "Error";
        _statusTitle = "Starting...";
        _statusMeta = "";
        _boardName = null;
        _boardArrivals = null;
        _visible = false;
        _refreshError = null;
        _partial = false;
        _requestDeadline = 0;
        _nextRefresh = 0;
        nearby = [];
        selection = null;
        locationLat = null;
        locationLon = null;
        locationTime = 0;
    }

    function onShow() {
        _visible = true;
        _heading = null;
        try { Sensor.enableSensorEvents(method(:onCompass)); } catch (e) {}
        if (_boardName == null && selection == null) {
            var cached = BoardStore.load();
            if (cached != null) {
                _boardStation = cached["board"]["station"];
                _staleTag = "Last station";
                _partial = cached["board"]["partial"] == true;
                render(cached["board"]["station"]["name"], _staleTag, cached["board"]["arrivals"]);
            }
        }
        refresh();
        _nextRefresh = System.getTimer() + refreshDelay();
        _redrawTimer.stop();
        _redrawTimer.start(method(:onRedrawTick), 1000, true);
    }

    function onHide() {
        try { Sensor.enableSensorEvents(null); } catch (e) {}
        _heading = null;
        _freshGpsPending = false;
        _visible = false;
        _requestGen += 1;
        _fetching = false;
        _redrawTimer.stop();
        _tracker.stop();
    }

    function onLayout(dc) {}

    function onUpdate(dc) {
        var meta = _statusMeta != null ? _statusMeta : "";
        if (_boardName != null) {
            var tag = _staleTag != null ? _staleTag : "Live";
            if (selection != null) { tag = "Selected"; }
            if (_partial) { tag += " / Partial"; }
            if (Config.alerts(_boardStation).size() > 0) { tag += " / Alert"; }
            if (_refreshError != null) { tag += " / Offline"; }
            else if (_fetching) { tag += " / Updating"; }
            var age = BoardStore.ageSeconds(BoardStore.load());
            meta = tag + (age != null ? " | " + MtaFormat.ageText(age) : "");
            if (selection != null && selection["route"] != null) {
                meta = DirectionLabels.selection(selection) + " | " + meta;
            }
        }
        var target = stationTarget();
        var entranceLabel = target == null ? null : MtaFormat.distanceLabel(target["meters"], Config.distanceUnit());
        MtaBoardRenderer.draw(dc, _boardName != null ? _boardName : _statusTitle,
            meta, _boardArrivals, stationDirection(target), entranceLabel);
    }

    function onCompass(info as Sensor.Info) as Void {
        if (!_visible) { return; }
        _heading = info.heading;
        _headingTime = System.getTimer();
    }

    function stationTarget() {
        if (_boardName == null || !Config.fixAge((System.getTimer() - locationTime) / 1000.0)) { return null; }
        return StationCompass.target(locationLat, locationLon, _boardStation);
    }

    function stationDirection(target) {
        if (target == null || System.getTimer() - _headingTime > 3000) { return null; }
        return StationCompass.direction(locationLat, locationLon, target["point"], _heading);
    }

    // ---- public (delegate) ----

    function alerts() {
        return Config.alerts(_boardStation);
    }

    // Apply a recent-commute selection without the menu stack (used by UP/DOWN).
    function select(value) {
        if (value == null || !Config.station(value["station"])) { return; }
        selection = value;
        RecentCommutes.use(value);
        _boardName = null;
        _boardArrivals = null;
        _fetching = false;
        _requestGen += 1;
        refresh();
        WatchUi.requestUpdate();
    }

    // Cycle recent commutes; with no current selection, +1 starts at the first.
    function cycleRecent(delta) {
        var items = RecentCommutes.sorted(locationLat, locationLon);
        if (items.size() == 0) { return; }
        var index = -1;
        if (selection != null) {
            for (var i = 0; i < items.size(); i += 1) {
                if (RecentCommutes.same(items[i], selection)) { index = i; break; }
            }
        }
        if (index < 0) { index = delta > 0 ? 0 : items.size() - 1; }
        else { index = (index + delta + items.size()) % items.size(); }
        select(items[index]);
    }

    function refresh() {
        if (!_visible || _fetching) {
            return;
        }
        _fetching = true;
        _freshGpsPending = false;
        _requestGen += 1;
        _refreshError = null;
        _requestDeadline = System.getTimer() + 25000;
        if (_boardName == null) {
            showStatus("Waiting for GPS", "START: recent commutes");
        }
        _requestSelection = selection;
        if (selection != null) {
            fetch(selection["station"]["lat"], selection["station"]["lon"], "Selected", _requestGen);
        } else { _nextLocation = System.getTimer() + LOCATION_MS; _tracker.start(); }
    }

    // ---- fix handling ----

    function onFix(lat, lon, staleAge) {
        if (!_visible || !_fetching) { return; }
        if (!Config.coordinates(lat, lon) || (staleAge != null && !Config.fixAge(staleAge))) {
            validateLocation();
            if (locationLat != null) {
                _requestSelection = null;
                fetch(locationLat, locationLon, "Saved GPS", _requestGen);
                return;
            }
            fetchLastStation();
            return;
        }
        locationLat = lat;
        _freshGpsPending = _tracker.usedCache;
        locationLon = lon;
        locationTime = System.getTimer() - (staleAge == null ? 0 : staleAge * 1000);
        _requestSelection = null;
        fetch(lat, lon, staleAge == null ? null : "Saved GPS", _requestGen);
    }

    function clearLocation() {
        locationLat = null;
        locationLon = null;
        _staleTag = "Last station";
    }

    function validateLocation() {
        var age = (System.getTimer() - locationTime) / 1000.0;
        if (!Config.coordinates(locationLat, locationLon) || !Config.fixAge(age)) { clearLocation(); }
    }

    function fetchLastStation() {
        var cached = BoardStore.load();
        if (cached == null) {
            _fetching = false;
            showStatus("Waiting for GPS", "Tap retry / START recents");
            return;
        }
        var station = cached["board"]["station"];
        _requestSelection = {"station" => station, "route" => null, "dir" => null};
        fetch(station["lat"], station["lon"], "Last station", _requestGen);
    }

    // ---- fetch ----

    function fetch(lat, lon, stale, gen) {
        // Station coordinates are only API parameters, never a personal location.
        _staleTag = stale;
        if (_boardName == null) {
            showStatus("Loading trains...", stale == null ? "" : stale);
        } else {
            WatchUi.requestUpdate();
        }
        var request = new BoardRequest(self, gen);
        MtaClient.fetchSelection(lat, lon, _requestSelection, request.method(:onResponse));
    }

    function onBoard(gen, code, data) {
        if (!_visible || gen != _requestGen || !_fetching) {
            return; // stale response from an earlier request
        }
        _fetching = false;
        var parsed = parseBoard(code, data);
        if (parsed == null) {
            showFailure(_parseError);
            refreshGpsAfterCache();
            return;
        }
        BoardStore.save(parsed[:raw]);
        RecentCommutes.refreshLabels(parsed[:raw]);
        if (selection != null) { DirectionLabels.update(selection, parsed[:raw]["options"]); }
        if (_requestSelection == null) {
            nearby = [];
            for (var i = 0; i < data["stations"].size(); i += 1) {
                var item = data["stations"][i];
                if (item instanceof Lang.Dictionary && Config.station(item["station"])) { nearby.add(item); }
            }
        }
        _partial = parsed[:raw]["partial"] == true;
        _boardStation = parsed[:raw]["station"];
        render(parsed[:name], _staleTag, parsed[:arrivals]);
        refreshGpsAfterCache();
    }

    function refreshGpsAfterCache() {
        if (!_freshGpsPending || !_visible || selection != null) { return; }
        _freshGpsPending = false;
        _fetching = true;
        _requestGen += 1;
        _requestDeadline = System.getTimer() + 25000;
        _tracker.startFresh();
    }

    function onRequestTimeout() {
        _requestGen += 1;
        _fetching = false;
        _tracker.stop();
        showFailure("Request timed out");
    }

    function openPicker() {
        validateLocation();
        CommuteMenus.open(self);
    }

    function choose(value) {
        if (value != null && !Config.station(value["station"])) { return; }
        selection = value;
        if (value != null) { RecentCommutes.use(value); }
        _boardName = null;
        _boardArrivals = null;
        // Popping the picker invokes onShow, which starts the new request.
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function showFailure(message) {
        _refreshError = message;
        if (_boardName == null) {
            showStatus(message, "tap to retry");
        } else {
            WatchUi.requestUpdate();
        }
    }

    // Returns {:name, :arrivals, :raw} or null (sets _parseError).
    function parseBoard(code, data) {
        if (code != 200 || !(data instanceof Lang.Dictionary)) {
            _parseError = errorTitle(code);
            return null;
        }
        var stations = data["stations"];
        if (!(stations instanceof Array) || stations.size() == 0) {
            _parseError = "No stations";
            return null;
        }
        var first = stations[0];
        if (!(first instanceof Lang.Dictionary)) {
            _parseError = "Bad response";
            return null;
        }
        var station = first["station"];
        if (!Config.station(station)) { _parseError = "Bad station"; return null; }
        var name = "Unknown";
        if (station instanceof Lang.Dictionary) {
            name = MtaFormat.safeText(station["name"], "Unknown");
        }
        var arrivals = first["arrivals"];
        if (!(arrivals instanceof Array)) {
            arrivals = [];
        }
        return {:name => name, :arrivals => arrivals, :raw => first};
    }

    function errorTitle(code) {
        if (code == 200) {
            return "Bad response";
        } else if (code == -1001) {
            return "Need HTTPS URL";
        } else if (code == -104) {
            return "Check phone link";
        } else if (code < 0) {
            return "Network error";
        }
        return "Server error";
    }

    // ---- render ----

    function showStatus(title, meta) {
        _statusTitle = title;
        _statusMeta = meta;
        _boardName = null;
        _boardArrivals = null;
        WatchUi.requestUpdate();
    }

    function render(name, stale, arrivals) {
        _boardName = name;
        _boardArrivals = arrivals;
        _statusTitle = null;
        WatchUi.requestUpdate();
    }

    function onRefreshTick() {
        if (!_visible || _fetching) { return; }
        validateLocation();
        if (selection == null && System.getTimer() >= _nextLocation) { refresh(); return; }
        _fetching = true;
        _requestGen += 1;
        _refreshError = null;
        _requestDeadline = System.getTimer() + 25000;
        _requestSelection = selection;
        if (selection != null) {
            fetch(selection["station"]["lat"], selection["station"]["lon"], "Selected", _requestGen);
        } else if (locationLat != null) {
            fetch(locationLat, locationLon, "Saved GPS", _requestGen);
        } else { fetchLastStation(); }
    }

    function onRedrawTick() {
        if (!_visible) { return; }
        var now = System.getTimer();
        if (_fetching && now >= _requestDeadline) { onRequestTimeout(); }
        validateLocation();
        maybeBuzz();
        if (!_fetching && (now >= _nextRefresh || (selection == null && now >= _nextLocation))) {
            _nextRefresh = now + refreshDelay();
            onRefreshTick();
        }
        WatchUi.requestUpdate();
    }

    // Refresh sooner while a train is close.
    function refreshDelay() {
        var entry = BoardStore.load();
        if (entry != null && entry["board"] instanceof Lang.Dictionary) {
            var soonest = MtaFormat.soonestSeconds(entry["board"]["arrivals"], Time.now().value());
            if (soonest != null && (soonest as Lang.Number) <= SOON_S) { return FAST_REFRESH_MS; }
        }
        return REFRESH_MS;
    }

    // One buzz per imminent train when the Train buzz setting is on.
    function maybeBuzz() {
        var lead = Config.vibrateLead();
        if (lead <= 0) { return; }
        var entry = BoardStore.load();
        if (entry == null || !(entry["board"] instanceof Lang.Dictionary)) { return; }
        var now = Time.now().value();
        var next = MtaFormat.nextArrival(entry["board"]["arrivals"], now);
        if (next == null) { return; }
        var key = MtaFormat.safeText(next["route"], "?") + "@" + (next["arrival_at"] as Lang.Number).toString();
        if (key.equals(_buzzedKey)) { return; }
        if ((next["arrival_at"] as Lang.Number) - now > lead) { return; }
        _buzzedKey = key;
        try { Attention.vibrate([new Attention.VibeProfile(60, 250)]); } catch (ex) {}
    }
}

// Each callback retains its own generation, including after timeout/reopening.
class BoardRequest {
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
