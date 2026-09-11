using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Lang;

module StationMenu {
    function routes(station) {
        var result = [] as Lang.Array;
        var seen = {} as Lang.Dictionary;
        var values = station["routes"];
        if (!(values instanceof Lang.Array)) { return result; }
        for (var i = 0; i < values.size(); i += 1) {
            var r = values[i];
            if (!(r instanceof Lang.String) || r.length() == 0 || seen.hasKey(r)) { continue; }
            seen[r] = true;
            result.add(r);
        }
        return result;
    }

    function create(title, entries) {
        var count = 0;
        for (var i = 0; i < entries.size(); i += 1) {
            var n = routes(entries[i]["station"]).size();
            if (n > count) { count = n; }
        }
        var rows = count == 0 ? 1 : (count + 6) / 7;
        return new WatchUi.CustomMenu(88 + rows * 40, Graphics.COLOR_BLACK,
            {:title => new StationMenuTitle(title), :titleItemHeight => 70});
    }

    function item(name, detail, id, station) {
        return new WatchUi.CustomMenuItem(id,
            {:drawable => new StationMenuRow(name, detail, routes(station))});
    }
}

class StationMenuTitle extends WatchUi.Drawable {
    var text;
    function initialize(value) { Drawable.initialize({}); text = value; }
    function draw(dc) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth()/2, dc.getHeight()/2, Graphics.FONT_SMALL,
            MtaFormat.clip(text, dc.getWidth()-100, dc, Graphics.FONT_SMALL),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class StationMenuRow extends WatchUi.Drawable {
    var name;
    var detail;
    var lines;
    function initialize(n, d, r) { Drawable.initialize({}); name = n; detail = d; lines = r; }
    function draw(dc) {
        var left = 50;
        var width = dc.getWidth()-2*left;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left, 6, Graphics.FONT_TINY, MtaFormat.clip(name, width, dc, Graphics.FONT_TINY), Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left, 40, Graphics.FONT_XTINY, MtaFormat.clip(detail, width, dc, Graphics.FONT_XTINY), Graphics.TEXT_JUSTIFY_LEFT);
        for (var i = 0; i < lines.size(); i += 1) {
            MtaFormat.drawBadge(dc, lines[i], left + 18 + (i % 7)*42, 94 + (i/7)*40, 17);
        }
        if (lines.size() == 0) {
            dc.drawText(left, 80, Graphics.FONT_XTINY, "Lines unavailable", Graphics.TEXT_JUSTIFY_LEFT);
        }
    }
}
