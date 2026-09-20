using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

// Scrollable detail for one service alert: title then description, wrapped.
class AlertView extends WatchUi.View {
    const LINES_PER_PAGE = 6;
    const LEFT = 78;
    const TOP = 72;
    hidden var _alert;
    hidden var _page = 0;
    hidden var _built = false;
    hidden var _lines = [];

    function initialize(alert) {
        View.initialize();
        _alert = alert;
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        if (!_built) { _lines = build(dc); _built = true; }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var font = Graphics.FONT_XTINY;
        var lead = dc.getFontHeight(font) + 3;
        var pages = pageCount();
        var start = _page * LINES_PER_PAGE;
        for (var i = 0; i < LINES_PER_PAGE && start + i < _lines.size(); i += 1) {
            dc.drawText(LEFT, TOP + i * lead, font, _lines[start + i], Graphics.TEXT_JUSTIFY_LEFT);
        }
        if (pages > 1) {
            dc.setColor(0xA8A8A8, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h - 22, font, (_page + 1).toString() + "/" + pages.toString(),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    function build(dc) {
        var width = dc.getWidth() - LEFT * 2;
        var lines = MtaFormat.wrap(MtaFormat.safeText(_alert["title"], "Alert"), width, dc, Graphics.FONT_XTINY);
        if (_alert["desc"] instanceof Lang.String && (_alert["desc"] as Lang.String).length() > 0) {
            var body = MtaFormat.wrap(_alert["desc"], width, dc, Graphics.FONT_XTINY);
            for (var i = 0; i < body.size(); i += 1) { lines.add(body[i]); }
        }
        return lines;
    }

    function pageCount() {
        var pages = (_lines.size() + LINES_PER_PAGE - 1) / LINES_PER_PAGE;
        return pages < 1 ? 1 : pages;
    }

    function next() {
        if (_page + 1 < pageCount()) { _page += 1; WatchUi.requestUpdate(); }
        return true;
    }

    function previous() {
        if (_page > 0) { _page -= 1; WatchUi.requestUpdate(); }
        return true;
    }
}

class AlertDelegate extends WatchUi.BehaviorDelegate {
    hidden var _view;
    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }
    function onNextPage() { return _view.next(); }
    function onPreviousPage() { return _view.previous(); }
    function onSelect() { return _view.next(); }
    function onTap(event) { return _view.next(); }
}

class AlertMenuDelegate extends WatchUi.Menu2InputDelegate {
    hidden var _alerts;
    function initialize(alerts) {
        Menu2InputDelegate.initialize();
        _alerts = alerts;
    }
    function onSelect(item) {
        var index = item.getId();
        if (index instanceof Lang.Number && index >= 0 && index < _alerts.size()) {
            var view = new AlertView(_alerts[index]);
            WatchUi.pushView(view, new AlertDelegate(view), WatchUi.SLIDE_LEFT);
        }
    }
}
