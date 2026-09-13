using Toybox.Application;
using Toybox.Lang;
using Toybox.Time;

(:glance)
module BoardStore {
    const KEY = "board";

    function save(board) {
        try {
            Application.Storage.setValue(KEY, {
                "time" => Time.now().value(),
                "board" => board
            });
        } catch (ex) {}
    }

    function load() {
        try {
            var stored = Application.Storage.getValue(KEY);
            if (!(stored instanceof Lang.Dictionary)) { return null; }
            var entry = stored as Lang.Dictionary;
            if (entry instanceof Lang.Dictionary && entry["board"] instanceof Lang.Dictionary &&
                Config.station(entry["board"]["station"]) && entry["board"]["arrivals"] instanceof Lang.Array) { return entry; }
            return null;
        } catch (ex) {
            return null;
        }
    }

    function ageSeconds(entry) {
        if (!(entry instanceof Lang.Dictionary) || !Config.numeric(entry["time"])) {
            return null;
        }
        return Time.now().value() - (entry["time"] as Lang.Number);
    }
}
