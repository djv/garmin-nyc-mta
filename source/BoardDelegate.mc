using Toybox.WatchUi;

class BoardDelegate extends WatchUi.BehaviorDelegate {
    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() {
        _view.openPicker();
        return true;
    }

    function onMenu() {
        _view.openPicker();
        return true;
    }

    function onTap(event) {
        _view.refresh();
        return true;
    }

    function onNextPage() {
        _view.cycleRecent(1);
        return true;
    }

    function onPreviousPage() {
        _view.cycleRecent(-1);
        return true;
    }
}
