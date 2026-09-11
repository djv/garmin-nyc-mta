using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Time;

(:glance)
module MtaFormat {
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

    function upcoming(arrival) {
        if (!(arrival instanceof Lang.Dictionary)) { return false; }
        var at = arrival["arrival_at"];
        return !(at instanceof Lang.Number) || at >= Time.now().value();
    }

    function arrivalWhen(arrival) {
        var mins = arrival["mins"];
        var at = arrival["arrival_at"];
        if (at instanceof Lang.Number) {
            var seconds = at - Time.now().value();
            if (seconds < 0) { return "Passed"; }
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
