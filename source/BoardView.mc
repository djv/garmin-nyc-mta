using Toybox.Graphics;
using Toybox.Lang;
using Toybox.PersistedContent;
using Toybox.Timer;
using Toybox.WatchUi;
using Toybox.System;

class BoardView extends WatchUi.View {
    static const REFRESH_MS = 60000;
    static const LOCATION_MS = 120000;
    hidden var _nextLocation = 0;
    hidden var _requestSelection = null;

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
        if (_boardName == null && selection == null) {
            var cached = BoardStore.load();
            if (cached != null) {
                _staleTag = "Last station";
                _partial = cached["board"]["partial"] == true;
                render(cached["board"]["station"]["name"], _staleTag, cached["board"]["arrivals"]);
            }
        }
        refresh();
        _nextRefresh = System.getTimer() + REFRESH_MS;
        _redrawTimer.stop();
        _redrawTimer.start(method(:onRedrawTick), 1000, true);
    }

    function onHide() {
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
            if (_refreshError != null) { tag += " / Offline"; }
            else if (_fetching) { tag += " / Updating"; }
            var age = BoardStore.ageSeconds(BoardStore.load());
            meta = tag + (age != null ? " | " + MtaFormat.ageText(age) : "");
            if (selection != null && selection["route"] != null) {
                meta = selection["route"] + " / " + (selection["dir"] != null ? selection["dir"] + " bound" : "All directions") + " | " + meta;
            }
        }
        MtaBoardRenderer.draw(dc, _boardName != null ? _boardName : _statusTitle,
            meta, _boardArrivals);
    }

    // ---- public (delegate) ----

    function refresh() {
        if (!_visible || _fetching) {
            return;
        }
        _fetching = true;
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
            clearLocation();
            fetchLastStation();
            return;
        }
        locationLat = lat;
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
            return;
        }
        BoardStore.save(parsed[:raw]);
        if (_requestSelection == null) {
            nearby = [];
            for (var i = 0; i < data["stations"].size(); i += 1) {
                var item = data["stations"][i];
                if (item instanceof Lang.Dictionary && Config.station(item["station"])) { nearby.add(item); }
            }
        }
        _partial = parsed[:raw]["partial"] == true;
        render(parsed[:name], _staleTag, parsed[:arrivals]);
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
        if (!_fetching && (now >= _nextRefresh || (selection == null && now >= _nextLocation))) {
            _nextRefresh = now + REFRESH_MS;
            onRefreshTick();
        }
        WatchUi.requestUpdate();
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
