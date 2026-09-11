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
            return Application.Storage.getValue(KEY);
        } catch (ex) {
            return null;
        }
    }

    function ageSeconds(entry) {
        if (!(entry instanceof Lang.Dictionary) || entry["time"] == null) {
            return null;
        }
        return Time.now().value() - (entry["time"] as Lang.Number);
    }
}
