import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class GarminWatchFaceView extends WatchUi.WatchFace {

    // Layout – proporce podle referenčního ciferníku (doladěné)
    const OUTER_RING_INNER = 6;
    const TICK_MAJOR_LEN = 12;
    const TICK_MINOR_LEN = 6;
    const COMPLICATION_RADIUS = 20;
    const GAUGE_STROKE = 2;
    const COMPASS_ROSE_R = 16;
    const H_SCALE_H = 16;
    const ORANGE = 0xFF8800;
    const GAUGE_GREEN = 0x00CC44;
    const GAUGE_PURPLE = 0xAA44CC;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onUpdate(dc as Dc) as Void {
        var clock = System.getClockTime();
        var dateInfo = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var timeText = _formatTime(clock);
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
        var r = ((w < h ? w : h) / 2).toNumber() - 2;

        // Černé pozadí
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Vnější prstenec – tick marks (jako na Ultra)
        _drawOuterBezel(dc, cx, cy, r);

        // Rozložení: horní řada u okraje, čas uprostřed, spodní řada dole (bez překrývání)
        var topY = (h * 0.14).toNumber();
        var timeY = (h * 0.42).toNumber();
        var dateY = timeY + 32;
        var scaleY = (h * 0.58).toNumber();
        var bottomY = (h * 0.82).toNumber();
        var leftX = (cx - (r * 0.50)).toNumber();
        var rightX = (cx + (r * 0.50)).toNumber();

        // Horní řada: baterie (gauge), kompas, lokace
        _drawGaugeComplication(dc, leftX, topY, battery, 0, 100, "BAT", GAUGE_GREEN, ORANGE);
        _drawCompassRose(dc, cx, topY);
        _drawIconComplication(dc, rightX, topY, "LOC", "");

        // Hlavní čas – velké bílé číslice (jako na obrázku)
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, timeY, Graphics.FONT_NUMBER_THAI_HOT, timeText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Datum pod časem (formát 10. 3. 2025, světle šedá, čitelné)
        var dateText = _formatDate(dateInfo);
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, dateY, Graphics.FONT_MEDIUM, dateText, Graphics.TEXT_JUSTIFY_CENTER);

        // Střed: bearing + horizontální stupnice (kompas; bez Sensoru na watch face)
        _drawBearingAndScale(dc, cx, scaleY, w, null);

        // Spodní řada: kroky (ikona), východ/západ slunce, kalorie (gauge)
        _drawIconComplication(dc, leftX, bottomY, "STP", _shortNum(steps));
        _drawSunComplication(dc, cx, bottomY);
        _drawGaugeComplication(dc, rightX, bottomY, calories, 0, 500, "KCAL", GAUGE_GREEN, GAUGE_PURPLE);

        // Spodní text: výška / patra
        var altText = _getAltitudeText(floors);
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h - 14), Graphics.FONT_XTINY, altText, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function _drawOuterBezel(dc as Dc, cx as Number, cy as Number, radius as Number) as Void {
        var twoPi = 6.283185307;
        var start = -1.570796327; // začátek nahoře

        for (var i = 0; i < 60; i += 1) {
            var angle = start + (i * twoPi / 60.0);
            var isMajor = (i % 5 == 0);
            var len = isMajor ? TICK_MAJOR_LEN : TICK_MINOR_LEN;
            var inner = radius - OUTER_RING_INNER - len;
            var outer = radius - OUTER_RING_INNER;

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            var x1 = (cx + Math.cos(angle) * inner).toNumber();
            var y1 = (cy + Math.sin(angle) * inner).toNumber();
            var x2 = (cx + Math.cos(angle) * outer).toNumber();
            var y2 = (cy + Math.sin(angle) * outer).toNumber();
            dc.drawLine(x1, y1, x2, y2);
        }
        // Jednotky v rozích (FT / M) – zjednodušeně malý text
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText((cx - radius + 12).toNumber(), (cy + radius - 20).toNumber(), Graphics.FONT_XTINY, "FT", Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText((cx + radius - 18).toNumber(), (cy + radius - 20).toNumber(), Graphics.FONT_XTINY, "M", Graphics.TEXT_JUSTIFY_RIGHT);
    }

    function _drawGaugeComplication(dc as Dc, x as Number, y as Number, value as Number, minVal as Number, maxVal as Number, label as String, colorLow as Number, colorHigh as Number) as Void {
        var r = COMPLICATION_RADIUS;
        // Kruh – bílý obrys
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawCircle(x, y, r);
        dc.drawCircle(x, y, r - 1);

        // Polokruhový oblouk (dole: zelená → oranžová/fialová)
        var range = (maxVal > minVal) ? (maxVal - minVal) : 1.0;
        var t = (value - minVal).toFloat() / range;
        if (t > 1.0) { t = 1.0; }
        if (t < 0.0) { t = 0.0; }
        var arcEndAngle = 180 + (180 * t); // 180° = min, 360° = max (polokruh dole)

        dc.setPenWidth(GAUGE_STROKE);
        var step = 2;
        for (var deg = 180; deg <= arcEndAngle; deg += step) {
            var frac = (deg - 180).toFloat() / 180.0;
            var c = (frac < 0.5) ? colorLow : colorHigh;
            dc.setColor(c, Graphics.COLOR_TRANSPARENT);
            var rad = (deg * 3.14159265 / 180.0) - 1.570796327;
            var x1 = (x + Math.cos(rad) * (r - 4)).toNumber();
            var y1 = (y + Math.sin(rad) * (r - 4)).toNumber();
            var x2 = (x + Math.cos(rad) * (r - 1)).toNumber();
            var y2 = (y + Math.sin(rad) * (r - 1)).toNumber();
            dc.drawLine(x1, y1, x2, y2);
        }

        // Oranžová tečka na aktuální hodnotě
        var dotRad = (arcEndAngle * 3.14159265 / 180.0) - 1.570796327;
        var dotR = r - 2;
        dc.setColor(ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle((x + Math.cos(dotRad) * dotR).toNumber(), (y + Math.sin(dotRad) * dotR).toNumber(), 3);

        // Hlavní hodnota uprostřed (bez min/max kvůli přehlednosti)
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, (y + 1).toNumber(), Graphics.FONT_NUMBER_MEDIUM, value.format("%d"), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function _drawCompassRose(dc as Dc, cx as Number, cy as Number) as Void {
        var r = COMPASS_ROSE_R;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r);
        dc.drawCircle(cx, cy, r - 1);
        // Jen 4 hlavní směry, aby se nepřekrývaly
        var labels = ["N", "E", "S", "W"];
        var step = 90.0 * 3.14159265 / 180.0;
        var start = -1.570796327;
        for (var i = 0; i < 4; i += 1) {
            var a = start + (i * step);
            var lr = r - 5;
            var tx = (cx + Math.cos(a) * lr).toNumber();
            var ty = (cy + Math.sin(a) * lr).toNumber();
            dc.drawText(tx, ty, Graphics.FONT_XTINY, labels[i], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        dc.drawLine(cx - 3, cy, cx + 3, cy);
        dc.drawLine(cx, cy - 3, cx, cy + 3);
    }

    function _drawIconComplication(dc as Dc, x as Number, y as Number, label as String, value as String) as Void {
        var r = COMPLICATION_RADIUS - 2;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x, y, r);
        dc.setColor(0xFFCC00, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, (y - 3).toNumber(), Graphics.FONT_SMALL, "•", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        if (value != null && value.length() > 0) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, (y + 4).toNumber(), Graphics.FONT_XTINY, value, Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, (y + r + 4).toNumber(), Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function _drawSunComplication(dc as Dc, cx as Number, cy as Number) as Void {
        var r = COMPLICATION_RADIUS - 2;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r);
        var sunRiseSet = _getSunRiseSet();
        dc.setColor(0xFFCC00, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (cy - 2).toNumber(), Graphics.FONT_XTINY, sunRiseSet, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (cy + r + 4).toNumber(), Graphics.FONT_XTINY, "SUN", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function _drawBearingAndScale(dc as Dc, cx as Number, scaleY as Number, w as Number, heading as Number?) as Void {
        var bearingText = "—° —";
        if (heading != null) {
            bearingText = heading.format("%d") + "° " + _headingToDir(heading);
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (scaleY - 8).toNumber(), Graphics.FONT_SMALL, bearingText, Graphics.TEXT_JUSTIFY_CENTER);

        // Horizontální stupnice: 240° vlevo, 0° (360°) vpravo, správné pozice
        var scaleW = (w * 0.48).toNumber();
        var left = cx - scaleW / 2;
        var right = cx + scaleW / 2;
        var degs = [240, 270, 300, 330, 0];
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < degs.size(); i += 1) {
            var deg = degs[i];
            var t = (deg == 0) ? 1.0 : ((deg - 240).toFloat() / 120.0);
            var px = (left + (scaleW * t)).toNumber();
            dc.drawText(px, scaleY + 1, Graphics.FONT_XTINY, deg.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i <= 12; i += 1) {
            var px = left + (i * scaleW / 12);
            var len = (i % 3 == 0) ? 5 : 2;
            dc.drawLine(px, scaleY + H_SCALE_H, px, scaleY + H_SCALE_H - len);
        }
        if (heading != null) {
            var h = heading + 120;
            if (h >= 360) { h = h - 360; }
            var th = h.toFloat() / 120.0;
            if (th > 1.0) { th = 1.0; }
            var px = (left + (scaleW * th)).toNumber();
            dc.setColor(ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[px, scaleY + 2], [px - 3, scaleY + H_SCALE_H], [px + 3, scaleY + H_SCALE_H]]);
        }
        dc.setPenWidth(1);
        dc.setColor(ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(left, scaleY + H_SCALE_H + 1, right, scaleY + H_SCALE_H + 1);
    }

    function _headingToDir(deg as Number) as String {
        if (deg >= 337 || deg < 22) { return "N"; }
        if (deg >= 22 && deg < 67) { return "NE"; }
        if (deg >= 67 && deg < 112) { return "E"; }
        if (deg >= 112 && deg < 157) { return "SE"; }
        if (deg >= 157 && deg < 202) { return "S"; }
        if (deg >= 202 && deg < 247) { return "SW"; }
        if (deg >= 247 && deg < 292) { return "W"; }
        return "NW";
    }

    function _getAltitudeText(floors as Number) as String {
        // Zobrazíme patra jako přibližnou „výšku“ (1 patro ≈ 10 ft) nebo — FT
        if (floors != null && floors > 0) {
            var approxFt = floors * 10;
            return "∼ " + approxFt.format("%d") + " FL";
        }
        return "— FT";
    }

    function _getSunRiseSet() as String {
        var now = Time.now();
        var info = Gregorian.info(now, Time.FORMAT_SHORT);
        var day = (info != null && info.day != null) ? info.day : 15;
        var month = (info != null && info.month != null) ? info.month : 6;
        // Zjednodušený odhad: letní 5:30–20:30, zimní 7:30–16:30
        var isSummer = (month >= 4 && month <= 9);
        var rise = isSummer ? "5:30" : "7:30";
        var set = isSummer ? "20:30" : "16:30";
        return rise + "|" + set;
    }

    function _formatTime(clock as System.ClockTime) as String {
        var hours = clock.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hours = hours % 12;
            if (hours == 0) { hours = 12; }
        }
        return Lang.format("$1$:$2$", [hours, clock.min.format("%02d")]);
    }

    function _formatDate(dateInfo as Gregorian.Info) as String {
        return Lang.format("$1$. $2$. $3$", [
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
