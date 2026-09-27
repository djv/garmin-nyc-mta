using Toybox.Application;
using Toybox.Lang;
using Toybox.Test;
using Toybox.Time;

(:test)
module PolishFixture {
    function pack(now) {
        var dest = {"id" => "R39", "name" => "45 St", "lat" => 40.6490, "lon" => -74.0100,
            "routes" => ["R"], "d" => [now + 300, 0, 20, now + 900, 0, 20]};
        var bail = {"id" => "D27", "name" => "Parkside Av", "lat" => 40.6551, "lon" => -73.9616,
            "routes" => ["Q"], "d" => [now + 60, 0, 14]};
        return {"v" => 1, "generated" => now, "expires" => now + 3600, "stations" => [dest, bail]};
    }
}

(:test)
class PolishBoardProbe extends BoardView {
    var calls = 0;
    function initialize() { BoardView.initialize(); _visible = true; }
    function fetch(lat, lon, stale, gen) { calls += 1; }

    function run(logger) {
        var now = Time.now().value();
        var s1 = {"id" => "L03", "name" => "Union", "lat" => 40.7, "lon" => -73.9};
        var s2 = {"id" => "L10", "name" => "Lorimer", "lat" => 40.71, "lon" => -73.95};

        // Cached boards show their own age, not the primary board's.
        BoardStore.saveStation({"time" => now - 600, "board" => {"station" => s1, "arrivals" => []}});
        BoardStore.savePrimary({"station" => s2, "arrivals" => []});
        _requestSelection = {"station" => s1, "route" => null, "dir" => null};
        Test.assert(restoreCached());
        Test.assert(_staleTag.equals("Cached") && _boardName.equals("Union"));
        Test.assert(boardAge() >= 600 && boardAge() < 660);

        // Refresh pacing and buzz follow the shown board.
        render("Union", null, [{"route" => "G", "arrival_at" => now + 60}]);
        Test.assert(refreshDelay() == FAST_REFRESH_MS);
        render("Union", null, [{"route" => "G", "arrival_at" => now + 900}]);
        Test.assert(refreshDelay() == REFRESH_MS);
        var oldLead = Application.Properties.getValue("vibrateLead");
        Application.Properties.setValue("vibrateLead", 120);
        try {
            render("Union", null, [{"route" => "G", "arrival_at" => now + 60}]);
            _buzzedKey = null;
            maybeBuzz();
            Test.assert(_buzzedKey != null && _buzzedKey.find("G@") == 0);
        } finally {
            Application.Properties.setValue("vibrateLead", oldLead == null ? 0 : oldLead);
        }

        // A pack arriving while "No GPS fix" is shown fills the board (nearest to the
        // last known position if there is one, else the destination).
        Application.Storage.deleteValue("pack");
        _requestSelection = null;
        selection = null;
        locationLat = null;
        locationLon = null;
        showStatus("No GPS fix", "Tap: retry");
        _fetching = false;
        onPack();
        Test.assert(_boardName == null);  // no pack stored yet
        var pack = PolishFixture.pack(now);
        Test.assert(PackStore.save(pack));
        onPack();
        var fix = LastFix.recent();
        var expected = fix == null ? "45 St" : PackStore.nearest(PackStore.load(), fix[0], fix[1], null)["name"];
        logger.debug("pack board: " + _boardName + " (fix " + (fix == null ? "none" : "yes") + ")");
        Test.assert(_scheduled && _boardName.equals(expected));
        Test.assert(boardAge() == null);
        // Not while a request is running or a board is shown.
        showStatus("No GPS fix", "Tap: retry");
        _fetching = true;
        onPack();
        Test.assert(_boardName == null);
        return true;
    }
}

(:test)
class PolishGlanceProbe extends MtaGlanceView {
    function initialize() { MtaGlanceView.initialize(); }
    function run(logger) {
        var now = Time.now().value();
        var s = {"id" => "L10", "name" => "Lorimer", "lat" => 40.71, "lon" => -73.95};
        _entry = BoardStore.savePrimary({"station" => s,
            "arrivals" => [{"route" => "L", "dest" => "Canarsie-Rockaway Pkwy", "arrival_at" => now + 240}]});
        PackStore.save(PolishFixture.pack(now));
        loadPack();
        // Online: the cached live board.
        _offline = false;
        paintFromCache();
        Test.assert(!_scheduledGlance && _route.equals("L") && _primary.equals("4m Canarsie"));
        // Offline: the pack beats the cached home board.
        _offline = true;
        paintFromCache();
        logger.debug("glance: " + _primary + " / " + secondaryText());
        Test.assert(_scheduledGlance && secondaryText().find("Home by ") == 0);
        Test.assert(_primary.find(_packStation["name"]) != null);
        // Without a pack, offline falls back to the cached board.
        _packStation = null;
        paintFromCache();
        Test.assert(!_scheduledGlance && _primary.equals("4m Canarsie"));
        return true;
    }
}

(:test)
function polishRules(logger) {
    var keys = ["board", "boards", "pack"];
    var saved = {};
    for (var i = 0; i < keys.size(); i += 1) { saved[keys[i]] = Application.Storage.getValue(keys[i]); }
    try {
        new PolishBoardProbe().run(logger);
        new PolishGlanceProbe().run(logger);
        Test.assert(MtaFormat.shortDestination("Jamaica-179 St").equals("Jamaica"));
        Test.assert(MtaFormat.shortDestination("Bedford-Nostrand Avs").equals("Bedford"));
    } finally {
        for (var i = 0; i < keys.size(); i += 1) {
            if (saved[keys[i]] == null) { Application.Storage.deleteValue(keys[i]); }
            else { Application.Storage.setValue(keys[i], saved[keys[i]]); }
        }
    }
    return true;
}
