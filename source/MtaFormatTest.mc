using Toybox.Test;
using Toybox.Time;

(:test)
function distanceFormatRules(logger) {
    Test.assert(MtaFormat.distanceText(100, "meters").equals("100 m"));
    Test.assert(MtaFormat.distanceText(50, "feet").equals("164 ft"));
    Test.assert(MtaFormat.distanceText(500, "feet").equals("0.3 mi"));
    Test.assert(MtaFormat.distanceText(1609.344, "miles").equals("1.0 mi"));
    Test.assert(MtaFormat.distanceText(0, "walk").equals("1 min walk"));
    Test.assert(MtaFormat.distanceText(81, "walk").equals("1 min walk"));
    Test.assert(MtaFormat.distanceText(100, "walk").equals("2 min walk"));
    Test.assert(MtaFormat.distanceText(200, "walk").equals("3 min walk"));
    Test.assert(MtaFormat.distanceText(100, null).equals("2 min walk"));
    Test.assert(MtaFormat.distanceText(100, "bogus").equals("2 min walk"));
    Test.assert(MtaFormat.distanceText(null, "meters") == null);
    Test.assert(MtaFormat.distanceText(-5, "meters") == null);
    Test.assert(MtaFormat.distanceLabel(100, "meters").equals("~100 m"));
    Test.assert(MtaFormat.distanceLabel(null, "meters") == null);
    var unit = Config.distanceUnit();
    Test.assert(unit.equals("walk") || unit.equals("meters") || unit.equals("feet") || unit.equals("miles"));
    return true;
}

(:test)
function arrivalWhenRules(logger) {
    var now = Time.now().value();
    Test.assert(MtaFormat.arrivalWhen({"arrival_at" => now + 30}).equals("Now"));
    Test.assert(MtaFormat.arrivalWhen({"arrival_at" => now + 130}).equals("2m"));
    Test.assert(MtaFormat.arrivalWhen({"arrival_at" => now - 5}).equals("Passed"));
    Test.assert(MtaFormat.arrivalWhen({"mins" => 0}).equals("Due"));
    return true;
}

(:test)
function controlRules(logger) {
    var now = Time.now().value();
    var arrivals = [
        {"route" => "L", "arrival_at" => now + 600},
        {"route" => "A", "arrival_at" => now + 120},
        {"route" => "G", "arrival_at" => now - 30},
        {"bad" => 1}
    ];
    Test.assert(MtaFormat.soonestSeconds(arrivals, now) == 120);
    Test.assert(MtaFormat.soonestSeconds([], now) == null);
    Test.assert(MtaFormat.soonestSeconds(null, now) == null);
    Test.assert(MtaFormat.nextArrival(arrivals, now)["route"].equals("A"));
    Test.assert(MtaFormat.nextArrival([{"route" => "G", "arrival_at" => now - 1}], now) == null);
    var lead = Config.vibrateLead();
    Test.assert(lead == 0 || lead == 120 || lead == 300);
    return true;
}

(:test)
function alertRules(logger) {
    var station = {"id" => "L03", "name" => "Union", "alerts" => [
        {"title" => "L delays", "desc" => "slow"},
        {"title" => ""},
        {"desc" => "no title"},
        "bad"
    ]};
    var alerts = Config.alerts(station);
    Test.assert(alerts.size() == 1 && alerts[0]["title"].equals("L delays"));
    Test.assert(Config.alerts({"alerts" => "bad"}).size() == 0);
    Test.assert(Config.alerts(null).size() == 0);
    Test.assert(MtaFormat.words("  a  b c ").size() == 3);
    Test.assert(MtaFormat.words("a b c")[1].equals("b"));
    return true;
}
