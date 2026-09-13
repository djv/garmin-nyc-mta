using Toybox.Test;

(:test)
function glanceSelectionRules(logger) {
    var station = {"id" => "L10"};
    var north = {"station" => station, "route" => "L", "dir" => "N"};
    var south = {"station" => station, "route" => "L", "dir" => "S"};
    var other = {"station" => {"id" => "G29"}, "route" => "G", "dir" => "S"};
    var pick = GlanceSelection.newest(station, [other, south, north]);
    Test.assert(pick["dir"].equals("S"));
    Test.assert(GlanceSelection.newest({"id" => "none"}, [north]) == null);
    Test.assert(GlanceSelection.matches({"route" => "L", "dir" => "S"}, pick));
    Test.assert(!GlanceSelection.matches({"route" => "L", "dir" => "N"}, pick));
    Test.assert(!GlanceSelection.matches({"route" => "G", "dir" => "S"}, pick));
    Test.assert(GlanceSelection.matches({"route" => "G"}, null));
    Test.assert(GlanceSelection.newest(null, null) == null);
    return true;
}
