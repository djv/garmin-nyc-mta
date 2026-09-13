using Toybox.Lang;

module DirectionLabels {
    function destinations(options, route, dir) {
        if (!(options instanceof Lang.Array) || route == null || dir == null) { return null; }
        var seen = {} as Lang.Dictionary;
        var result = "";
        for (var i = 0; i < options.size(); i += 1) {
            var o = options[i];
            if (!(o instanceof Lang.Dictionary) || !RecentCommutes.equalText(o["route"], route) ||
                !RecentCommutes.equalText(o["dir"], dir) || !(o["dest"] instanceof Lang.String) || o["dest"].length() == 0) { continue; }
            var name = MtaFormat.shortDestination(o["dest"]);
            if (seen.hasKey(name)) { continue; }
            seen[name] = true;
            result += (result.length() > 0 ? " / " : "") + name;
        }
        return result.length() > 0 ? result : null;
    }

    function direction(value) {
        if (value["dir"] == null) { return "All directions"; }
        var name = value["directionLabel"];
        return name instanceof Lang.String && name.length() > 0 ? name : "Direction " + value["dir"];
    }

    function selection(value) {
        if (value["route"] == null) { return "All lines"; }
        // ASCII wording works with every device font, unlike an arrow glyph.
        var join = value["dir"] != null && value["directionLabel"] instanceof Lang.String &&
            value["directionLabel"].length() > 0 ? " to " : " / ";
        return value["route"] + join + direction(value);
    }

    function update(value, options) {
        var name = destinations(options, value["route"], value["dir"]);
        if (name == null || RecentCommutes.equalText(value["directionLabel"], name)) { return false; }
        value["directionLabel"] = name;
        return true;
    }
}
