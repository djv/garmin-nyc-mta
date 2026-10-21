using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;

// MTA-style route bullets, white destinations and a fixed arrival-time column; offline
// bundled stations show their lines and platform directions instead of times.
module MtaBoardRenderer {
    const STATIC_ROWS = 6;
    const HOME_COLOR = 0x3DDC84;

    function draw(dc, name, meta, arrivals, direction, entranceLabel) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        header(dc, name, meta, direction, entranceLabel);
        var row = 0;
        if (arrivals instanceof Lang.Array) {
            for (var i = 0; i < arrivals.size() && row < 4; i += 1) {
                var a = arrivals[i];
                if (!MtaFormat.upcoming(a)) { continue; }
                var y = h * (0.46 + row * 0.115);
                MtaFormat.drawBadge(dc, a["route"], 72, y, 19);
                var when = MtaFormat.arrivalWhen(a);
                var timeWidth = dc.getTextWidthInPixels(when, Graphics.FONT_SMALL);
                var right = w-58;
                var dest = MtaFormat.clip(MtaFormat.shortDestination(a["dest"]),
                    right-104-timeWidth-12, dc, Graphics.FONT_TINY);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(104, y, Graphics.FONT_TINY, dest,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
                dc.drawText(right, y, Graphics.FONT_SMALL, when,
                    Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
                row += 1;
            }
        }
        if (row == 0 && arrivals != null) {
            dc.setColor(0xA8A8A8, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w/2, h*0.52, Graphics.FONT_SMALL, "No trains",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // Title, meta line, rule, and the entrance arrow with its walking label.
    function header(dc, name, meta, direction, entranceLabel) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var title = MtaFormat.clip(name, w - 96, dc, Graphics.FONT_SMALL);
        dc.drawText(w/2, h*0.20, Graphics.FONT_SMALL, title,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(0xA8A8A8, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, h*0.31, Graphics.FONT_XTINY,
            MtaFormat.clip(meta, w-70, dc, Graphics.FONT_XTINY),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(65, h*0.37, w-65, h*0.37);
        // Arrow and walking label centered as one group so a long label stays inside the bezel.
        var labelWidth = entranceLabel == null ? 0 : dc.getTextWidthInPixels(entranceLabel, Graphics.FONT_XTINY);
        var arrowWidth = direction == null ? 0 : (entranceLabel == null ? 30 : 38);
        var left = w/2 - (arrowWidth + labelWidth) / 2;
        if (direction != null) {
            var ax = left + 15;
            var ay = h*0.12;
            var dx = Math.sin(direction);
            var dy = -Math.cos(direction);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(3);
            dc.drawLine(ax-15*dx, ay-15*dy, ax+15*dx, ay+15*dy);
            dc.drawLine(ax+15*dx, ay+15*dy, ax+3.75*dx-8.75*dy, ay+3.75*dy+8.75*dx);
            dc.drawLine(ax+15*dx, ay+15*dy, ax+3.75*dx+8.75*dy, ay+3.75*dy-8.75*dx);
            dc.setPenWidth(1);
        }
        if (entranceLabel != null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(left + arrowWidth, h*0.12, Graphics.FONT_XTINY, entranceLabel,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // Bundled offline station (no times): one row per line group and platform direction,
    // rides home first with the label in green, e.g. [6] Downtown.
    function drawStatic(dc, name, meta, footer, station, direction, entranceLabel) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        header(dc, name, meta, direction, entranceLabel);
        var rows = staticRows(station);
        for (var i = 0; i < rows.size() && i < STATIC_ROWS; i += 1) {
            var y = h * (0.44 + i * 0.075);
            var routes = MtaFormat.words(rows[i][0]);
            var x = 66;
            for (var r = 0; r < routes.size() && r < 4; r += 1) {
                MtaFormat.drawBadge(dc, routes[r], x, y, 14);
                x += 31;
            }
            var dy = y - h / 2;
            var right = w / 2 + Math.sqrt(h * h / 4 - dy * dy) - 16;  // inside the round bezel
            dc.setColor(rows[i][2] ? HOME_COLOR : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x - 5, y, Graphics.FONT_XTINY, MtaFormat.clip(rows[i][1], right - x + 5, dc, Graphics.FONT_XTINY),
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        dc.setColor(0xA8A8A8, Graphics.COLOR_TRANSPARENT);
        if (rows.size() == 0) {
            dc.drawText(w/2, h*0.52, Graphics.FONT_SMALL, "No lines",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        dc.drawText(w/2, h*0.89, Graphics.FONT_XTINY, MtaFormat.clip(footer, w - 170, dc, Graphics.FONT_XTINY),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // [[routes, direction label, rides home], ...]: home rides first, then the other
    // lines per direction in Stations.csv order. Home stations list every direction plainly.
    function staticRows(station) {
        var home = [] as Lang.Array;
        var other = [] as Lang.Array;
        if (!(station instanceof Lang.Dictionary) || !(station["groups"] instanceof Lang.Array)) { return other; }
        var g = station["groups"] as Lang.Array;
        var homeStation = station["home"] == true;
        for (var i = 0; i + 4 < g.size(); i += 5) {
            for (var d = 0; d < 2; d += 1) {
                var label = g[i + 1 + d] as Lang.String;
                if (label.length() == 0) { continue; }
                var all = MtaFormat.words(g[i]);
                var homeRoutes = homeStation ? [] : MtaFormat.words(g[i + 3 + d]);
                var rest = "";
                for (var r = 0; r < all.size(); r += 1) {
                    var rides = false;
                    for (var k = 0; k < homeRoutes.size(); k += 1) { if (homeRoutes[k].equals(all[r])) { rides = true; } }
                    if (!rides) { rest += (rest.length() > 0 ? " " : "") + all[r]; }
                }
                if (homeRoutes.size() > 0) { home.add([g[i + 3 + d], label, true]); }
                if (rest.length() > 0) { other.add([rest, label, false]); }
            }
        }
        home.addAll(other);
        return home;
    }
}