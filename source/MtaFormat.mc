using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;
using Toybox.Time;

(:glance)
module MtaFormat {
    const WALK_MPS = 1.35;
    const FT_PER_M = 3.28084;
    const M_PER_MI = 1609.344;

    function isDiamond(route) {
        return route != null && (route.equals("6X") || route.equals("7X") || route.equals("FX"));
    }

    function routeLabel(route) {
        var r = safeText(route, "?");
        if (isDiamond(r)) { return r.substring(0, 1); }
        if (r.equals("GS") || r.equals("FS") || r.equals("H")) { return "S"; }
        return r;
    }

    function drawBadge(dc, route, x, y, radius) {
        dc.setColor(routeColor(route), Graphics.COLOR_TRANSPARENT);
        if (isDiamond(route)) {
            var tip = radius + 5;
            dc.fillPolygon([[x, y-tip], [x+tip, y], [x, y+tip], [x-tip, y]]);
        } else {
            dc.fillCircle(x, y, radius);
        }
        var r = routeLabel(route);
        var dark = r.equals("N") || r.equals("Q") || r.equals("R") || r.equals("W");
        dc.setColor(dark ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var font = Graphics.FONT_XTINY;
        dc.drawText(x, y, font, r, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function routeColor(route) {
        var r = routeLabel(route).toUpper();
        if (r.equals("1") || r.equals("2") || r.equals("3")) {
            return 0xD82233;
        } else if (r.equals("4") || r.equals("5") || r.equals("6")) {
            return 0x009952;
        } else if (r.equals("N") || r.equals("Q") || r.equals("R") || r.equals("W")) {
            return 0xF6BC26;
        } else if (r.equals("A") || r.equals("C") || r.equals("E")) {
            return 0x0062CF;
        } else if (r.equals("B") || r.equals("D") || r.equals("F") || r.equals("M")) {
            return 0xEB6800;
        } else if (r.equals("7")) {
            return 0x9A38A1;
        } else if (r.equals("J") || r.equals("Z")) {
            return 0x8E5C33;
        } else if (r.equals("G")) {
            return 0x799534;
        } else if (r.equals("SI")) {
            return 0x08179C;
        } else if (r.equals("L") || r.equals("S")) {
            return 0x7C858C;
        }
        return 0x7C858C;
    }

    function arrivalText(arrival) {
        var route = safeText(arrival["route"], "?");
        var dest = safeText(arrival["dest"], "");
        if (dest.length() > 10) {
            dest = dest.substring(0, 9) + ".";
        }
        return route + " " + arrivalWhen(arrival) + " " + dest;
    }

    // Compact terminal names for the small watch display; full names stay in menus.
    function shortDestination(value) {
        var text = safeText(value, "Unknown");
        if (text.equals("Canarsie-Rockaway Pkwy")) { return "Canarsie"; }
        if (text.equals("Forest Hills-71 Av")) { return "Forest Hills"; }
        if (text.equals("Coney Island-Stillwell Av")) { return "Coney Island"; }
        if (text.equals("Jamaica-179 St")) { return "Jamaica 179 St"; }
        if (text.equals("Flatbush Av-Brooklyn College")) { return "Flatbush Av"; }
        if (text.equals("Jamaica Center-Parsons/Archer")) { return "Parsons/Archer"; }
        if (text.equals("Middle Village-Metropolitan Av")) { return "Metropolitan Av"; }
        if (text.equals("Crown Hts-Utica Av")) { return "Utica Av"; }
        if (text.equals("Astoria-Ditmars Blvd")) { return "Ditmars Blvd"; }
        if (text.equals("Ozone Park-Lefferts Blvd")) { return "Lefferts Blvd"; }
        if (text.equals("Far Rockaway-Mott Av")) { return "Mott Av"; }
        if (text.equals("Eastchester-Dyre Av")) { return "Dyre Av"; }
        if (text.equals("Wakefield-241 St")) { return "241 St"; }
        if (text.equals("Norwood-205 St")) { return "205 St"; }
        if (text.equals("34 St-Hudson Yards")) { return "Hudson Yards"; }
        if (text.equals("Grand Central-42 St")) { return "Grand Central"; }
        if (text.equals("Flushing-Main St")) { return "Main St"; }
        return text;
    }

    // "3 min walk" (default), "350 ft", "0.3 mi" or "123 m"; null when unknown.
    function distanceText(meters, unit) {
        if (!Config.numeric(meters) || (meters as Lang.Number) < 0) { return null; }
        var m = (meters as Lang.Number).toDouble();
        if (unit != null && unit.equals("meters")) { return m.format("%.0f") + " m"; }
        if (unit != null && unit.equals("feet")) {
            if (m / M_PER_MI >= 0.2) { return (m / M_PER_MI).format("%.1f") + " mi"; }
            return (m * FT_PER_M).format("%.0f") + " ft";
        }
        if (unit != null && unit.equals("miles")) { return (m / M_PER_MI).format("%.1f") + " mi"; }
        var mins = Math.ceil(m / WALK_MPS / 60.0).toNumber();
        if (mins < 1) { mins = 1; }
        return mins.toString() + " min walk";
    }

    function distanceLabel(meters, unit) {
        var text = distanceText(meters, unit);
        return text == null ? null : "~" + text;
    }

    function upcoming(arrival) {
        if (!(arrival instanceof Lang.Dictionary)) { return false; }
        var at = arrival["arrival_at"];
        return !(at instanceof Lang.Number) || at >= Time.now().value();
    }

    // Seconds until the soonest future arrival, or null when none.
    function soonestSeconds(arrivals, now) {
        if (!(arrivals instanceof Lang.Array)) { return null; }
        var soonest = null;
        for (var i = 0; i < arrivals.size(); i += 1) {
            var a = arrivals[i];
            if (!(a instanceof Lang.Dictionary) || !(a["arrival_at"] instanceof Lang.Number)) { continue; }
            var seconds = (a["arrival_at"] as Lang.Number) - now;
            if (seconds < 0) { continue; }
            if (soonest == null || seconds < soonest) { soonest = seconds; }
        }
        return soonest;
    }

    // The soonest future arrival dictionary, or null.
    function nextArrival(arrivals, now) {
        if (!(arrivals instanceof Lang.Array)) { return null; }
        var next = null;
        for (var i = 0; i < arrivals.size(); i += 1) {
            var a = arrivals[i];
            if (!(a instanceof Lang.Dictionary) || !(a["arrival_at"] instanceof Lang.Number)) { continue; }
            if ((a["arrival_at"] as Lang.Number) < now) { continue; }
            if (next == null || (a["arrival_at"] as Lang.Number) < (next["arrival_at"] as Lang.Number)) { next = a; }
        }
        return next;
    }

    function arrivalWhen(arrival) {
        var mins = arrival["mins"];
        var at = arrival["arrival_at"];
        if (at instanceof Lang.Number) {
            var seconds = at - Time.now().value();
            if (seconds < 0) { return "Passed"; }
            if (seconds <= 45) { return "Now"; }
            mins = seconds / 60;
        }
        var when = (mins == null || (mins as Lang.Number) <= 0) ? "Due"
            : (mins as Lang.Number).toString() + "m";
        return when;
    }

    function ageText(ageS) {
        if (ageS == null) {
            return "";
        }
        var s = ageS as Lang.Number;
        if (s < 60) {
            return s.toString() + "s ago";
        }
        return (s / 60).toString() + "m ago";
    }

    function safeText(v, fallback) {
        if (v == null) {
            return fallback;
        }
        return v.toString();
    }

    // Split on single spaces, dropping empty tokens (no String.split dependency).
    function words(text) {
        var result = [] as Lang.Array;
        var value = safeText(text, "");
        var start = 0;
        for (var i = 0; i <= value.length(); i += 1) {
            if (i == value.length() || value.substring(i, i + 1).equals(" ")) {
                if (i > start) { result.add(value.substring(start, i)); }
                start = i + 1;
            }
        }
        return result;
    }

    // Greedy word wrap for the alert detail view; first word always placed.
    function wrap(text, maxPx, dc, font) {
        var lines = [] as Lang.Array;
        var tokens = words(text);
        var current = "";
        for (var i = 0; i < tokens.size(); i += 1) {
            var candidate = current.length() == 0 ? tokens[i] : current + " " + tokens[i];
            if (current.length() == 0 || dc.getTextWidthInPixels(candidate, font) <= maxPx) {
                current = candidate;
            } else {
                lines.add(current);
                current = tokens[i];
            }
        }
        if (current.length() > 0) { lines.add(current); }
        return lines;
    }

    function clip(text, maxPx, dc, font) {
        if (text == null) {
            return "";
        }
        if (dc.getTextWidthInPixels(text, font) <= maxPx) {
            return text;
        }
        var t = text;
        while (t.length() > 0) {
            t = t.substring(0, t.length() - 1);
            if (dc.getTextWidthInPixels(t + "...", font) <= maxPx) {
                return t + "...";
            }
        }
        return "";
    }
}
