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
