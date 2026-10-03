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
    static const PACK_REFRESH_S = 600;
    hidden var _scheduled = false;
    // The shown board is a bundled offline station: lines and directions, no times.
    hidden var _static = false;
    static const KEEP_BOARD_M = 1000;
    hidden var _nextLocation = 0;
    hidden var _requestSelection = null;
    hidden var _freshGpsPending = false;
    hidden var _heading = null;
    hidden var _headingTime = 0;
    hidden var _boardStation = null;
    hidden var _buzzedKey = null;
    // Epoch of the shown board's data (fetch, cache or pack), for the "ago" hint.
    hidden var _boardTime = null;

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
    // Nearby browsing stays in automatic-location mode; explicit menu filters use selection.
    hidden var _nearbyStation = null;
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
            updateNearby();
            var cached = BoardStore.load();
            if (!restoreStatic() && cached != null) {
                _boardStation = cached["board"]["station"];
                _staleTag = "Last station";
                _partial = cached["board"]["partial"] == true;
                _boardTime = cached["time"];
                render(cached["board"]["station"]["name"], _staleTag, cached["board"]["arrivals"]);
            }
        }
        refreshPack();
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
        if (_boardName != null && _static) {
            var hint = OfflineStations.hint(_boardStation, null);
            var target0 = stationTarget();
            MtaBoardRenderer.drawStatic(dc, _boardName, hint != null ? hint : "No direct train home",
                _fetching ? "Updating..." : "Offline map", _boardStation,
                stationDirection(target0), target0 == null ? null : MtaFormat.distanceLabel(target0["meters"], Config.distanceUnit()));
            return;
        }
        if (_boardName != null && _scheduled) {
            // Timetable rows: the pack's age says nothing about them.
            meta = "Sched home" + (Config.alerts(_boardStation).size() > 0 ? " / Alert" : "") +
                (_partial ? " / Partial" : "") +
                (_fetching ? " / Updating" : "");
        } else if (_boardName != null) {
            var tag = _staleTag != null ? _staleTag : "Live";
            if (selection != null) { tag = "Selected"; }
            else if (_nearbyStation != null || locationLat != null) { tag = "Nearby"; }
            if (_partial) { tag += " / Partial"; }
            if (Config.alerts(_boardStation).size() > 0) { tag += " / Alert"; }
            if (_refreshError != null) { tag += " / Offline"; }
            else if (_fetching) { tag += " / Updating"; }
            // Age first: long tag combinations clip at the end.
            var age = boardAge();
            meta = (age != null ? MtaFormat.ageText(age) + " | " : "") + tag;
            if (selection != null && selection["route"] != null) {
                meta = DirectionLabels.selection(selection) + " | " + meta;
            }
        }
        var target = stationTarget();
        var entranceLabel = target == null ? null : MtaFormat.distanceLabel(target["meters"], Config.distanceUnit());
        MtaBoardRenderer.draw(dc, _boardName != null ? _boardName : _statusTitle,
            meta, _boardArrivals, stationDirection(target), entranceLabel);
    }

    function boardAge() {
        if (!Config.numeric(_boardTime)) { return null; }
        var age = Time.now().value() - (_boardTime as Lang.Number);
        return age < 0 ? 0 : age;
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

    // Five nearest bundled station complexes, available without the phone or saved commutes.
    function updateNearby() {
        var pos = offlinePosition();
        if (pos == null) { nearby = []; _nearbyStation = null; return; }
        var list = OfflineStations.nearest(pos[0], pos[1], 5);
        var previous = nearby;
        nearby = [];
        for (var i = 0; i < list.size(); i += 1) {
            var entry = {"station" => OfflineStations.station(list[i][0])};
            for (var j = 0; j < previous.size(); j += 1) {
                if (previous[j]["station"]["id"].equals(entry["station"]["id"])) {
                    entry["options"] = previous[j]["options"];
                    break;
                }
            }
            nearby.add(entry);
        }
        if (_nearbyStation != null) {
            var index = nearbyIndex(_nearbyStation);
            _nearbyStation = nearby.size() == 0 ? null : nearby[index < 0 ? 0 : index]["station"];
        }
    }

    function nearbyIndex(station) {
        if (!Config.station(station)) { return -1; }
        for (var i = 0; i < nearby.size(); i += 1) {
            var st = nearby[i]["station"];
            if (st["id"].equals(station["id"])) { return i; }
        }
        return -1;
    }

    function nearbySelection() {
        var station = _nearbyStation != null ? _nearbyStation : (nearby.size() > 0 ? nearby[0]["station"] : null);
        return station == null ? null : {"station" => station, "route" => null, "dir" => null};
    }

    // DOWN advances from the shown station, UP goes back, and both wrap. No commute filters.
    function cycleNearby(delta) {
        updateNearby();
        if (nearby.size() == 0) { refresh(); return; }
        var index = nearbyIndex(_nearbyStation != null ? _nearbyStation : _boardStation);
        if (index < 0) { index = delta > 0 ? 0 : nearby.size() - 1; }
        else { index = (index + delta + nearby.size()) % nearby.size(); }
        _nearbyStation = nearby[index]["station"];
        selection = null;
        _tracker.stop();
        _freshGpsPending = false;
        _boardName = null;
        _boardArrivals = null;
        _fetching = false;
        _requestGen += 1;
        _requestSelection = nearbySelection();
        restoreOffline();
        onRefreshTick();
        WatchUi.requestUpdate();
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
            showStatus("Waiting for GPS", "START: stations");
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
                _requestSelection = nearbySelection();
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
        updateNearby();
        _requestSelection = nearbySelection();
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
        if (_nearbyStation != null) {
            _requestSelection = nearbySelection();
            fetch(_nearbyStation["lat"], _nearbyStation["lon"], "Nearby", _requestGen);
            return;
        }
        var cached = BoardStore.load();
        if (cached == null) {
            _fetching = false;
            // No fix and no cached station (e.g. mid-run, phone at home): a run pack still helps.
            _requestSelection = null;
            if (restorePack() || restoreStatic()) { return; }
            showStatus("No GPS fix", "Tap: retry");
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
            if (restoreOffline()) {
                refreshGpsAfterCache();
                return;
            }
            showFailure(_parseError);
            refreshGpsAfterCache();
            return;
        }
        keepNearbyComplex(parsed);
        _scheduled = false;
        _boardTime = Time.now().value();
        BoardStore.save(parsed[:raw]);
        cacheStations(data["stations"]);
        RecentCommutes.refreshLabels(parsed[:raw]);
        if (selection != null) { DirectionLabels.update(selection, parsed[:raw]["options"]); }
        var nearbyAt = nearbyIndex(parsed[:raw]["station"]);
        if (nearbyAt >= 0) { nearby[nearbyAt]["options"] = parsed[:raw]["options"]; }
        if (_requestSelection == null && nearby.size() == 0) {
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

    // The proxy can merge separate same-name stations. Nearby uses the bundled official
    // complexes so another avenue's trains and entrances do not leak into this choice.
    function keepNearbyComplex(parsed) {
        if (selection != null) { return; }
        var index = nearbyIndex(parsed[:raw]["station"]);
        if (index < 0) { return; }
        var station = nearby[index]["station"];
        var raw = parsed[:raw];
        raw["station"]["routes"] = station["routes"];
        raw["station"]["entrances"] = station["entrances"];
        var arrivals = nearbyRoutes(raw["arrivals"], station["routes"]);
        raw["options"] = nearbyRoutes(raw["options"], station["routes"]);
        if (arrivals.size() < parsed[:arrivals].size()) { raw["partial"] = true; }
        raw["arrivals"] = [];
        for (var i = 0; i < arrivals.size() && i < 8; i += 1) { raw["arrivals"].add(arrivals[i]); }
        parsed[:arrivals] = raw["arrivals"];
    }

    function nearbyRoutes(values, routes) {
        var result = [];
        if (!(values instanceof Lang.Array)) { return result; }
        for (var i = 0; i < values.size(); i += 1) {
            if (!(values[i] instanceof Lang.Dictionary)) { continue; }
            for (var r = 0; r < routes.size(); r += 1) {
                if (MtaFormat.routeLabel(values[i]["route"]).equals(MtaFormat.routeLabel(routes[r]))) {
                    result.add(values[i]);
                    break;
                }
            }
        }
        return result;
    }

    // Cache every station in a multi-station response for offline browsing.
    function cacheStations(list) {
        if (!(list instanceof Lang.Array)) { return; }
        for (var i = 0; i < list.size(); i += 1) {
            var item = list[i];
            if (item instanceof Lang.Dictionary && Config.station(item["station"])) {
                BoardStore.saveStation({"time" => Time.now().value(), "board" => item});
            }
        }
    }

    // Offline with a run pack: scheduled trains home from the requested station if it is in the
    // pack, else the pack station nearest the fix or the watch's last known position (any
    // distance), else the run's destination.
    function restorePack() {
        var pack = PackStore.load();
        if (pack == null) { return false; }
        var station = null;
        if (_requestSelection != null && _requestSelection["station"] instanceof Lang.Dictionary) {
            station = PackStore.find(pack, _requestSelection["station"]);
            // Same-name stations on different avenues are distinct nearby choices.
            if (station != null && (nearby.size() > 0 || _nearbyStation != null) &&
                !station["id"].equals(_requestSelection["station"]["id"])) { return false; }
            // Browsing must keep the requested station even when its trains are not in the pack.
            if (station == null && (selection != null || nearby.size() > 0 || _nearbyStation != null)) { return false; }
        }
        if (station == null && Config.fixAge((System.getTimer() - locationTime) / 1000.0)) {
            station = PackStore.nearest(pack, locationLat, locationLon, null);
        }
        if (station == null && (selection == null || _requestSelection == null)) {
            var fix = LastFix.recent();
            if (fix != null) { station = PackStore.nearest(pack, fix[0], fix[1], null); }
        }
        if (station == null && (selection == null || _requestSelection == null)) {
            station = PackStore.destination(pack);
        }
        if (station == null) { return false; }
        var board = PackStore.board(station, Time.now().value());
        keepNearbyComplex({:raw => board, :arrivals => board["arrivals"]});
        if ((board["arrivals"] as Lang.Array).size() == 0) { return false; }
        _scheduled = true;
        _boardTime = null;
        _boardStation = board["station"];
        _staleTag = "Scheduled";
        _partial = board["partial"] == true;
        _refreshError = null;
        render(station["name"], _staleTag, board["arrivals"]);
        return true;
    }

    // Fetch the run pack while online (at most every PACK_REFRESH_S); the background service
    // keeps it fresh when the app is closed.
    function refreshPack() {
        var age = PackStore.ageSeconds();
        if (age != null && age >= 0 && age < PACK_REFRESH_S && PackStore.load() != null) { return; }
        MtaClient.fetchPack(new PackRequest(self).method(:onResponse));
    }

    // A pack that arrives while only a status is shown (no fix, no cached station) fills the board.
    function onPack() {
        if (_visible && !_fetching && _boardName == null) { restorePack(); }
    }

    // On a failed fetch, show the cached board for the requested station.
    function restoreCached() { return restoreCachedBoard(false); }

    function restoreCachedBoard(needTrains) {
        if (_requestSelection == null || !(_requestSelection["station"] instanceof Lang.Dictionary)) { return false; }
        var entry = BoardStore.forStation((_requestSelection["station"] as Lang.Dictionary)["id"]);
        if (!(entry instanceof Lang.Dictionary) || !(entry["board"] instanceof Lang.Dictionary)) { return false; }
        var board = entry["board"] as Lang.Dictionary;
        keepNearbyComplex({:raw => board, :arrivals => board["arrivals"]});
        if (needTrains && MtaFormat.soonestSeconds(board["arrivals"], Time.now().value()) == null) { return false; }
        _boardStation = board["station"];
        _scheduled = false;
        _boardTime = entry["time"];
        _staleTag = "Cached";
        _partial = board["partial"] == true;
        _refreshError = _parseError;
        render((board["station"] as Lang.Dictionary)["name"], _staleTag, board["arrivals"]);
        return true;
    }

    // A failed live request: live board > fresh run pack (times) > cached board with trains
    // still to come > the shown board while it has trains and is near > bundled offline
    // station > any cached board. False keeps the shown board, marked Offline.
    function restoreOffline() {
        if (restorePack() || restoreCachedBoard(true)) { return true; }
        if (!_static && !_scheduled && _boardName != null &&
            MtaFormat.soonestSeconds(_boardArrivals, Time.now().value()) != null && shownBoardNear()) { return false; }
        return restoreStatic() || restoreCached();
    }

    function shownBoardNear() {
        var pos = offlinePosition();
        if (selection != null || pos == null || !Config.station(_boardStation)) { return true; }
        return PackStore.meters(pos[0], pos[1], _boardStation["lat"], _boardStation["lon"]) <= KEEP_BOARD_M;
    }

    // The board's own fix while valid, else the watch's last known position (<15 min).
    function offlinePosition() {
        if (Config.coordinates(locationLat, locationLon) && Config.fixAge((System.getTimer() - locationTime) / 1000.0)) {
            return [locationLat, locationLon];
        }
        return lastKnown();
    }

    function lastKnown() { return LastFix.recent(); }

    // Bundled offline station: the selected one, else the one nearest the position, else the
    // requested (last) station. False when none applies.
    function restoreStatic() {
        var station = null;
        if (selection != null || _nearbyStation != null) {
            station = bundledAt(selection != null ? selection["station"] : _nearbyStation);
        } else {
            var pos = offlinePosition();
            if (pos != null) {
                var list = OfflineStations.nearest(pos[0], pos[1], 1);
                if (list.size() > 0) { station = OfflineStations.station(list[0][0]); }
            }
            if (station == null && _requestSelection != null) { station = bundledAt(_requestSelection["station"]); }
        }
        if (station == null) { return false; }
        _scheduled = false;
        _boardTime = null;
        _boardStation = station;
        _staleTag = "Offline";
        _partial = false;
        _refreshError = null;
        render(station["name"], _staleTag, null);
        _static = true;
        return true;
    }

    // The bundled station at a (live or saved) station's point, within 400 m.
    function bundledAt(station) {
        if (!Config.station(station)) { return null; }
        var list = OfflineStations.nearest(station["lat"], station["lon"], 1);
        return list.size() > 0 && list[0][1] <= 400 ? OfflineStations.station(list[0][0]) : null;
    }

    function refreshGpsAfterCache() {        if (!_freshGpsPending || !_visible || selection != null) { return; }
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
        _nearbyStation = null;
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
        _static = false;
        _statusTitle = title;
        _statusMeta = meta;
        _boardName = null;
        _boardArrivals = null;
        WatchUi.requestUpdate();
    }

    function render(name, stale, arrivals) {
        _static = false;
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
        _requestSelection = selection != null ? selection : nearbySelection();
        if (_requestSelection != null) {
            fetch(_requestSelection["station"]["lat"], _requestSelection["station"]["lon"], selection != null ? "Selected" : "Nearby", _requestGen);
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
        var soonest = MtaFormat.soonestSeconds(_boardArrivals, Time.now().value());
        return soonest != null && (soonest as Lang.Number) <= SOON_S ? FAST_REFRESH_MS : REFRESH_MS;
    }

    // One buzz per imminent train on the shown board (scheduled ones too) when Train buzz is on.
    function maybeBuzz() {
        var lead = Config.vibrateLead();
        if (lead <= 0) { return; }
        var now = Time.now().value();
        var next = MtaFormat.nextArrival(_boardArrivals, now);
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

class PackRequest {
    hidden var _view;
    function initialize(view) { _view = view; }
    function onResponse(code as Lang.Number, data as Lang.Dictionary or Lang.String or PersistedContent.Iterator or Null) as Void {
        if (code == 200 && PackStore.save(data)) { _view.onPack(); }
    }
}
