using Toybox.Application;
using Toybox.Lang;
using Toybox.Test;
using Toybox.Time;

(:test)
function packStoreRules(logger) {
    var prev = Application.Storage.getValue("pack");
    try {
        var now = Time.now().value();
        var dest = {"id" => "R39", "name" => "45 St", "lat" => 40.6490, "lon" => -74.0100,
            "routes" => ["N", "R"], "entrances" => [{"lat" => 40.6493, "lon" => -74.0098}],
            "alerts" => [{"title" => "Delays"}],
            "d" => [now - 120, 0, 20, now + 300, 1, 21, now + 900, 0, 20]};
        var bail = {"id" => "D27", "name" => "Parkside Av", "lat" => 40.6551, "lon" => -73.9616,
            "routes" => ["Q"], "d" => [now + 60, 0, 14]};
        var pack = {"v" => 1, "generated" => now, "expires" => now + 3600, "stations" => [dest, bail, "junk"]};

        Test.assert(!PackStore.save({"stations" => []}));  // no expiry: rejected
        Test.assert(PackStore.save(pack));
        var loaded = PackStore.load();
        Test.assert(loaded != null);
        Test.assert(PackStore.stations(loaded).size() == 2);  // junk entry dropped

        // Passed departures are hidden; route index maps to the station's routes.
        var b = PackStore.board(PackStore.destination(loaded), now);
        var rows = b["arrivals"] as Lang.Array;
        Test.assert(rows.size() == 2);
        Test.assert(rows[0]["route"].equals("R"));
        Test.assert(rows[0]["arrival_at"] == now + 300);
        Test.assert((rows[0]["dest"] as Lang.String).find("by ") == 0);
        Test.assert(rows[0]["home_at"] > rows[0]["arrival_at"]);
        Test.assert(b["station"]["entrances"].size() == 1);
        Test.assert(Config.alerts(b["station"]).size() == 1);

        // Lookup by id, by complex name, and nearest to a fix.
        Test.assert(PackStore.find(loaded, {"id" => "D27"})["name"].equals("Parkside Av"));
        Test.assert(PackStore.find(loaded, {"id" => "X99", "name" => "45 St"})["id"].equals("R39"));
        Test.assert(PackStore.find(loaded, {"id" => "X99", "name" => "Nowhere"}) == null);
        Test.assert(PackStore.nearest(loaded, 40.6550, -73.9620, 1500)["id"].equals("D27"));
        Test.assert(PackStore.nearest(loaded, 40.7500, -73.9900, 1500) == null);
        Test.assert(PackStore.nearest(loaded, 40.7500, -73.9900, null) != null);

        // Expired packs are ignored.
        pack["expires"] = now - 1;
        PackStore.save(pack);
        Test.assert(PackStore.load() == null);
    } finally {
        if (prev == null) { Application.Storage.deleteValue("pack"); }
        else { Application.Storage.setValue("pack", prev); }
    }
    return true;
}
