using Toybox.Application;
using Toybox.Test;

(:test)
function boardStoreRules(logger) {
    var prevAll = Application.Storage.getValue("boards");
    var prevPrimary = Application.Storage.getValue("board");
    try {
        Application.Storage.deleteValue("boards");
        Application.Storage.deleteValue("board");
        var s1 = {"id" => "L03", "name" => "Union", "lat" => 40.7, "lon" => -73.9};
        var s2 = {"id" => "L10", "name" => "Lorimer", "lat" => 40.71, "lon" => -73.95};
        BoardStore.save({"station" => s1, "arrivals" => []});
        BoardStore.save({"station" => s2, "arrivals" => []});
        Test.assert(BoardStore.forStation("L10") != null);
        Test.assert(BoardStore.forStation("L03") != null);
        Test.assert(BoardStore.forStation("missing") == null);
        var all = BoardStore.loadAll();
        Test.assert(all.size() == 2);
        Test.assert(all[0]["board"]["station"]["id"].equals("L10"));
        for (var i = 0; i < 10; i += 1) {
            BoardStore.save({"station" => {"id" => "S" + i.toString(), "name" => "St " + i.toString(),
                "lat" => 40.7, "lon" => -73.9}, "arrivals" => []});
        }
        Test.assert(BoardStore.loadAll().size() <= 8);
        Application.Storage.deleteValue("boards");
        Test.assert(BoardStore.loadAll().size() == 1);
        Test.assert(BoardStore.forStation("S9") != null);
    } finally {
        if (prevAll == null) { Application.Storage.deleteValue("boards"); }
        else { Application.Storage.setValue("boards", prevAll); }
        if (prevPrimary == null) { Application.Storage.deleteValue("board"); }
        else { Application.Storage.setValue("board", prevPrimary); }
    }
    return true;
}
