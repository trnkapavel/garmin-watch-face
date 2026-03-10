import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class GarminWatchFaceView extends WatchUi.WatchFace {

    const COMPLICATION_VALUE_OFFSET = 6;
    const COMPLICATION_RADIUS = 18;
    const TOP_LABEL_GAP = 14;
    const BOTTOM_LABEL_GAP = 7;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onUpdate(dc as Dc) as Void {
        var clock = System.getClockTime();
        var dateInfo = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);

        var timeText = _formatTime(clock);
        var dateText = _formatDate(dateInfo);

        var stats = System.getSystemStats();
        var battery = stats.battery.toNumber();

        var actInfo = ActivityMonitor.getInfo();
        var steps = (actInfo != null && actInfo.steps != null) ? actInfo.steps : 0;
        var calories = (actInfo != null && actInfo.calories != null) ? actInfo.calories : 0;
        var floors = (actInfo != null && actInfo.floorsClimbed != null) ? actInfo.floorsClimbed : 0;

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = (w / 2).toNumber();
        var cy = (h / 2).toNumber();
        var r = ((w < h ? w : h) / 2).toNumber();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        _drawOuterTicks(dc, cx, cy, r - 6);

        var leftX = (cx - (r * 0.30)).toNumber();
        var rightX = (cx + (r * 0.30)).toNumber();
        var topY = (h * 0.22).toNumber();
        var bottomY = (h * 0.76).toNumber();

        _drawComplication(dc, leftX, topY, _shortNum(steps), "STP", Graphics.COLOR_YELLOW, true);
        _drawComplication(dc, rightX, topY, battery.format("%d") + "%", "BAT", Graphics.COLOR_ORANGE, true);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(cx, (h * 0.33).toNumber(), Graphics.FONT_NUMBER_HOT, timeText, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(cx, ((h * 0.59) + 2).toNumber(), Graphics.FONT_MEDIUM, dateText, Graphics.TEXT_JUSTIFY_CENTER);

        _drawComplication(dc, leftX, bottomY, _shortNum(calories), "KCAL", Graphics.COLOR_GREEN, false);
        _drawComplication(dc, rightX, bottomY, floors.format("%d"), "FLRS", 0x00A0FF, false);
    }

    function _drawOuterTicks(dc as Dc, cx as Number, cy as Number, radius as Number) as Void {
        var full = 6.283185307;
        var start = -1.570796327;

        for (var i = 0; i < 60; i += 1) {
            var angle = start + (i * full / 60.0);
            var isMajor = (i % 5 == 0);
            var inner = isMajor ? radius - 12 : radius - 7;

            dc.setColor(isMajor ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);

            var x1 = (cx + Math.cos(angle) * inner).toNumber();
            var y1 = (cy + Math.sin(angle) * inner).toNumber();
            var x2 = (cx + Math.cos(angle) * radius).toNumber();
            var y2 = (cy + Math.sin(angle) * radius).toNumber();
            dc.drawLine(x1, y1, x2, y2);
        }
    }

    function _drawComplication(dc as Dc, x as Number, y as Number, value as String, label as String, accent as Number, labelOnTop as Boolean) as Void {
        dc.setColor(0x555555, Graphics.COLOR_BLACK);
        dc.drawCircle(x, y, COMPLICATION_RADIUS);
        dc.drawCircle(x, y, COMPLICATION_RADIUS - 1);

        // Accent notch at the top of the complication ring.
        dc.setColor(accent, Graphics.COLOR_BLACK);
        dc.drawLine((x - 5).toNumber(), (y - COMPLICATION_RADIUS).toNumber(), (x + 5).toNumber(), (y - COMPLICATION_RADIUS).toNumber());

        dc.setColor(accent, Graphics.COLOR_BLACK);
        var labelGap = labelOnTop ? TOP_LABEL_GAP : BOTTOM_LABEL_GAP;
        var labelY = labelOnTop ? (y - COMPLICATION_RADIUS - labelGap) : (y + COMPLICATION_RADIUS + labelGap);
        dc.drawText(x, labelY.toNumber(), Graphics.FONT_TINY, label, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(x, (y + COMPLICATION_VALUE_OFFSET).toNumber(), Graphics.FONT_XTINY, value, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function _formatTime(clock as System.ClockTime) as String {
        var hours = clock.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hours = hours % 12;
            if (hours == 0) {
                hours = 12;
            }
        }

        return Lang.format("$1$:$2$", [hours, clock.min.format("%02d")]);
    }

    function _formatDate(dateInfo as Gregorian.Info) as String {
        return Lang.format("$1$.$2$.$3$", [
            dateInfo.day,
            dateInfo.month,
            dateInfo.year
        ]);
    }

    function _shortNum(n as Number) as String {
        if (n >= 1000) {
            return (n / 1000).format("%d") + "k";
        }

        return n.format("%d");
    }
}
