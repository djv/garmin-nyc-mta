using Toybox.Test;
using Toybox.Lang;

(:test)
function recentCommuteRules(logger) {
    var items = [] as Lang.Array;
    for (var i = 0; i < 11; i += 1) {
        items = RecentCommutes.remember(items, {"station" => {"id" => i.toString(),
            "lat" => 40.0 + i * 0.01, "lon" => -74.0}, "route" => "L", "dir" => "N"});
    }
    Test.assert(items.size() == 10);
    Test.assert(items[0]["station"]["id"].equals("10"));
    Test.assert(items[9]["station"]["id"].equals("1"));
    var reuse = items[5];
    items = RecentCommutes.remember(items, reuse);
    Test.assert(items.size() == 10);
    Test.assert(RecentCommutes.same(items[0], reuse));
    items = RecentCommutes.sortItems(items, 40.0, -74.0);
    Test.assert(items[0]["station"]["id"].equals("1"));
    Test.assert(items[9]["station"]["id"].equals("10"));
    var unchanged = RecentCommutes.sortItems(items, null, null);
    Test.assert(RecentCommutes.same(unchanged[0], items[0]));
    return true;
}
