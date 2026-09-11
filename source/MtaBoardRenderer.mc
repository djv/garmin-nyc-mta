using Toybox.Graphics;
using Toybox.Lang;

// MTA-style route bullets, white destinations and a fixed arrival-time column.
module MtaBoardRenderer {
    function draw(dc, name, meta, arrivals) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var title = MtaFormat.clip(name, w - 110, dc, Graphics.FONT_MEDIUM);
        dc.drawText(w/2, h*0.20, Graphics.FONT_MEDIUM, title,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(0xA8A8A8, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, h*0.31, Graphics.FONT_XTINY,
            MtaFormat.clip(meta, w-120, dc, Graphics.FONT_XTINY),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(0x454545, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(65, h*0.37, w-65, h*0.37);
        var row = 0;
        if (arrivals instanceof Lang.Array) {
            for (var i = 0; i < arrivals.size() && row < 4; i += 1) {
                var a = arrivals[i];
                if (!MtaFormat.upcoming(a)) { continue; }
                var y = h * (0.46 + row * 0.115);
                MtaFormat.drawBadge(dc, a["route"], 82, y, 20);
                var when = MtaFormat.arrivalWhen(a);
                var timeWidth = dc.getTextWidthInPixels(when, Graphics.FONT_SMALL);
                var right = w-68;
                var dest = MtaFormat.clip(MtaFormat.safeText(a["dest"], "Unknown"),
                    right-118-timeWidth-14, dc, Graphics.FONT_TINY);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(118, y, Graphics.FONT_TINY, dest,
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
}
