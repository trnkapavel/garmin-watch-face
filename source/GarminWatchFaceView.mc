import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.Weather;

class GarminWatchFaceView extends WatchUi.WatchFace {

    // Layout – 454x454 (epix Pro Gen 2 51mm)
    const RING_R = 218;          // poloměr slunečního prstence
    const RING_STROKE = 7;
    const TICK_OUTER = 210;
    const TICK_MAJOR_LEN = 17;
    const TICK_MINOR_LEN = 7;
    const TICK_FAINT = 0x555555;   // vlásečnicové ticky mezi indexy

    const ORANGE = 0xFF8800;
    const DAYLIGHT = 0x996600;   // denní část oblouku (tlumená, šetří pixely)
    const NIGHT = 0x1A2340;      // noc – tmavá indigová
    const DAWN = 0xFF6600;       // úsvit / soumrak
    const MIDDAY = 0xFFCC44;     // poledne
    const DIM = 0x888888;
    const HR_RED = 0xFF4444;
    const TRACK = 0x2A2A2A;      // podklad kroužku
    const GAUGE_R = 32;
    const GAUGE_STROKE = 4;
    const HR_MIN = 40;           // rozsah pro kroužek tepu
    const HR_MAX = 180;
    const CALORIE_GOAL = 2500;
    const BAT_GREEN = 0x44CC66;
    const AOD_GRAY = 0xAAAAAA;
    const GOLD_TOP = 0xFFDD88;   // přechod na hodinách: shora dolů
    const GOLD_BOT = 0xFF8800;
    const OUTLINE = 2;           // tloušťka obrysu minut
    const GRAPH_GRAY = 0x4A4A4A;   // podkladová křivka tlaku
const GRAPH_H = 32;
const GRAPH_MIN_SPAN = 120.0;  // minimální rozpětí 1,2 hPa – pod tím už kreslíme jen šum senzoru
const GRAPH_MAX_SAMPLES = 96;
const CONTENT_R = 193;         // vnitřní hrana ticků
const AOD_LEVEL = 0.6;       // ztlumení barev v AOD   // světle šedá dle Garmin AMOLED guidelines

    private var _lowPower as Boolean = false;

    // Cache slunce – přepočítá se jen při změně dne
    private var _sunDay as Number = -1;
    private var _sunriseMin as Number or Null = null;
    private var _sunsetMin as Number or Null = null;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onEnterSleep() as Void {
        _lowPower = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _lowPower = false;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        var clock = System.getClockTime();
        var nowMin = clock.hour * 60 + clock.min;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var aod = _lowPower && System.getDeviceSettings().requiresBurnInProtection;
        _drawFace(dc, clock, nowMin, aod);
    }

    // --- Ciferník ---

    // AOD kreslí stejné rozvržení jako plný režim, jen bez naměřených hodnot,
    // ztlumeně a posunuté o pár pixelů proti vypálení.
    function _drawFace(dc as Dc, clock as System.ClockTime, nowMin as Number,
            aod as Boolean) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var ox = 0;
        var oy = 0;
        if (aod) {
            var shift = nowMin % 49;
            ox = (shift % 7) - 3;
            oy = (shift / 7) - 3;
        }
        var cx = w / 2 + ox;
        var cy = h / 2 + oy;

        var now = Time.now();
        var dateInfo = Gregorian.info(now, Time.FORMAT_MEDIUM);
        _updateSun(now, dateInfo);

        _drawSunRing(dc, cx, cy, nowMin, aod);
        _drawHourTicks(dc, cx, cy, aod);
        _drawSunMarkers(dc, cx, cy, aod);

        // Svislý stack: kroužky / čas / datum / kroužky.
        // Odsazení kroužků je limitované kruhem displeje – dál než 78 px by vylezly za ticky.
        var timeH = dc.getFontHeight(Graphics.FONT_NUMBER_HOT);
        var dateH = dc.getFontHeight(Graphics.FONT_TINY);
        var gaugeD = 2 * GAUGE_R;
        var gap = 6;
        // FONT_NUMBER_HOT má pod číslicemi široké prázdné pásmo, takže datum musí
        // box času překrývat – jinak vypadá mezera zhruba dvakrát větší, než je.
        var dateOverlap = 22;

        var total = gaugeD + gap + timeH - dateOverlap + dateH + gap + gaugeD;
        var top = (h - total) / 2 + oy;
        var topGaugeCY = top + GAUGE_R;
        var timeTop = top + gaugeD + gap;
        var dateY = timeTop + timeH - dateOverlap;
        var botGaugeCY = dateY + dateH + gap + GAUGE_R;

        _drawTime(dc, cx, timeTop, clock, aod);

        if (!aod) {
            dc.setColor(DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, dateY, Graphics.FONT_TINY, _formatDate(dateInfo),
                Graphics.TEXT_JUSTIFY_CENTER);
        }

        _drawGauges(dc, cx, 76, topGaugeCY, botGaugeCY, aod);
        _drawPressureGraph(dc, cx, cy, topGaugeCY + GAUGE_R + 4, aod);
    }

    // Hodiny mají svislý zlatý přechod, minuty jsou duté. Monkey C neumí ani jedno,
    // takže obojí vzniká opakovaným vykreslením téhož textu.
    function _drawTime(dc as Dc, cx as Number, top as Number,
            clock as System.ClockTime, aod as Boolean) as Void {
        var font = Graphics.FONT_NUMBER_HOT;
        var text = _formatTime(clock);
        var sep = text.find(":");
        if (sep == null) { return; }
        var hh = text.substring(0, sep);
        var mm = text.substring(sep + 1, text.length());

        var wHH = dc.getTextWidthInPixels(hh, font);
        var wSep = dc.getTextWidthInPixels(":", font);
        var wMM = dc.getTextWidthInPixels(mm, font);
        var x = cx - (wHH + wSep + wMM) / 2;

        if (aod) {
            _drawOutlineText(dc, x, top, font, hh, _dim(GOLD_BOT));
        } else {
            _drawGradientText(dc, x, top, font, hh, GOLD_TOP, GOLD_BOT);
        }

        dc.setColor(aod ? _dim(GOLD_BOT) : GOLD_BOT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + wHH, top, font, ":", Graphics.TEXT_JUSTIFY_LEFT);

        _drawOutlineText(dc, x + wHH + wSep, top, font, mm,
            aod ? _dim(AOD_GRAY) : Graphics.COLOR_WHITE);
    }

    function _drawGradientText(dc as Dc, x as Number, y as Number, font as Graphics.FontType,
            text as String, from as Number, to as Number) as Void {
        var h = dc.getFontHeight(font);
        var w = dc.getTextWidthInPixels(text, font);
        var bands = 12;
        for (var i = 0; i < bands; i += 1) {
            var y0 = y + (h * i) / bands;
            var y1 = y + (h * (i + 1)) / bands;
            dc.setClip(x, y0, w, y1 - y0 + 1);
            dc.setColor(_lerpColor(from, to, i.toFloat() / (bands - 1)),
                Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y, font, text, Graphics.TEXT_JUSTIFY_LEFT);
        }
        dc.clearClip();
    }

    // Obrys = tentýž text osmkrát rozesazený do stran, přes něj kopie v barvě pozadí.
    function _drawOutlineText(dc as Dc, x as Number, y as Number, font as Graphics.FontType,
            text as String, color as Number) as Void {
        var o = OUTLINE;
        var offsets = [[-o, 0], [o, 0], [0, -o], [0, o],
            [-o, -o], [o, o], [-o, o], [o, -o]];
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < offsets.size(); i += 1) {
            dc.drawText(x + offsets[i][0], y + offsets[i][1], font, text,
                Graphics.TEXT_JUSTIFY_LEFT);
        }
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, text, Graphics.TEXT_JUSTIFY_LEFT);
    }

    function _dim(color as Number) as Number {
        return _lerpColor(Graphics.COLOR_BLACK, color, AOD_LEVEL);
    }

    // 24 h namapovaných na 360°, půlnoc nahoře, čas běží po směru hodin
    function _timeToAngle(minutes as Number) as Float {
        var deg = 90.0 - (minutes.toFloat() / 1440.0) * 360.0;
        while (deg < 0.0) { deg += 360.0; }      // drawArc chce úhel v <0, 360)
        while (deg >= 360.0) { deg -= 360.0; }
        return deg;
    }

    function _drawSunRing(dc as Dc, cx as Number, cy as Number, nowMin as Number,
            aod as Boolean) as Void {
        dc.setPenWidth(aod ? 3 : RING_STROKE);

        // V AOD se noční část prstence nekreslí vůbec – jen by svítila bez užitku.
        if (!aod) {
            dc.setColor(NIGHT, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy, RING_R);
        }

        if (_sunriseMin != null && _sunsetMin != null) {
            var span = _sunsetMin - _sunriseMin;
            if (span < 0) { span += 1440; }   // den přesahující půlnoc
            var segments = aod ? 1 : 24;
            for (var i = 0; i < segments; i += 1) {
                var t0 = i.toFloat() / segments;
                var t1 = (i + 1).toFloat() / segments;
                dc.setColor(aod ? _dim(DAYLIGHT) : _dayColor((t0 + t1) / 2.0),
                    Graphics.COLOR_TRANSPARENT);
                dc.drawArc(cx, cy, RING_R, Graphics.ARC_CLOCKWISE,
                    _timeToAngle(_sunriseMin + (span * t0).toNumber()),
                    _timeToAngle(_sunriseMin + (span * t1).toNumber()) - 0.6);
            }
        }

        var a = _timeToAngle(nowMin) * Math.PI / 180.0;
        var mx = (cx + Math.cos(a) * RING_R).toNumber();
        var my = (cy - Math.sin(a) * RING_R).toNumber();
        if (aod) {
            dc.setColor(_dim(ORANGE), Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(mx, my, 6);
        } else {
            dc.setColor(ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(mx, my, 8);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(mx, my, 3);
        }
        dc.setPenWidth(1);
    }

    // t = 0 úsvit, 0.5 poledne, 1 soumrak
    function _dayColor(t as Float) as Number {
        var k = 1.0 - (2.0 * t - 1.0).abs();
        return _lerpColor(DAWN, MIDDAY, k);
    }

    function _lerpColor(from as Number, to as Number, t as Float) as Number {
        var r = ((from >> 16) & 0xFF) + ((((to >> 16) & 0xFF) - ((from >> 16) & 0xFF)) * t).toNumber();
        var g = ((from >> 8) & 0xFF) + ((((to >> 8) & 0xFF) - ((from >> 8) & 0xFF)) * t).toNumber();
        var b = (from & 0xFF) + (((to & 0xFF) - (from & 0xFF)) * t).toNumber();
        return (r << 16) | (g << 8) | b;
    }

    // Indexy na 12/3/6/9 nesou hierarchii jako na ručičkovém ciferníku: krátké
    // vlásečnice mezi nimi, výrazné značky na čtvrtinách.
    function _drawHourTicks(dc as Dc, cx as Number, cy as Number, aod as Boolean) as Void {
        for (var hour = 0; hour < 24; hour += 1) {
            var isMajor = (hour % 6 == 0);
            var a = _timeToAngle(hour * 60) * Math.PI / 180.0;
            var len = isMajor ? TICK_MAJOR_LEN : TICK_MINOR_LEN;
            var color = isMajor ? Graphics.COLOR_WHITE : TICK_FAINT;

            dc.setPenWidth(isMajor ? 4 : 1);
            dc.setColor(aod ? _dim(color) : color, Graphics.COLOR_TRANSPARENT);

            var co = Math.cos(a);
            var si = Math.sin(a);
            dc.drawLine(
                (cx + co * TICK_OUTER).toNumber(), (cy - si * TICK_OUTER).toNumber(),
                (cx + co * (TICK_OUTER - len)).toNumber(), (cy - si * (TICK_OUTER - len)).toNumber());
        }
        dc.setPenWidth(1);
    }

    // Textové popisky se vedle kroužků komplikací nevejdou (mezi ně a ticky zbývají
    // 3 px), takže východ a západ značí čárky přes prstenec.
    function _drawSunMarkers(dc as Dc, cx as Number, cy as Number, aod as Boolean) as Void {
        if (_sunriseMin == null || _sunsetMin == null) { return; }
        dc.setPenWidth(3);
        dc.setColor(aod ? _dim(AOD_GRAY) : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        _drawRadialMark(dc, cx, cy, _timeToAngle(_sunriseMin));
        _drawRadialMark(dc, cx, cy, _timeToAngle(_sunsetMin));
        dc.setPenWidth(1);
    }

    function _drawRadialMark(dc as Dc, cx as Number, cy as Number, angle as Float) as Void {
        var a = angle * Math.PI / 180.0;
        var inner = RING_R - RING_STROKE;
        var outer = RING_R + RING_STROKE;
        dc.drawLine(
            (cx + Math.cos(a) * inner).toNumber(), (cy - Math.sin(a) * inner).toNumber(),
            (cx + Math.cos(a) * outer).toNumber(), (cy - Math.sin(a) * outer).toNumber());
    }

    function _drawGauges(dc as Dc, cx as Number, dx as Number,
            topCY as Number, botCY as Number, aod as Boolean) as Void {
        var stats = System.getSystemStats();
        var actInfo = ActivityMonitor.getInfo();
        var battery = stats.battery.toNumber();
        var steps = (actInfo != null && actInfo.steps != null) ? actInfo.steps : 0;
        var cals = (actInfo != null && actInfo.calories != null) ? actInfo.calories : 0;
        var stepGoal = (actInfo != null && actInfo.stepGoal != null && actInfo.stepGoal > 0)
            ? actInfo.stepGoal : 10000;
        var hr = _latestHeartRate();

        _drawGauge(dc, cx - dx, topCY, aod, battery < 20 ? ORANGE : BAT_GREEN,
            battery / 100.0, battery.format("%d") + "%");
        _drawGauge(dc, cx + dx, topCY, aod, HR_RED,
            hr == null ? 0.0 : (hr - HR_MIN).toFloat() / (HR_MAX - HR_MIN),
            hr == null ? "--" : hr.format("%d"));
        _drawGauge(dc, cx - dx, botCY, aod, Graphics.COLOR_WHITE,
            steps.toFloat() / stepGoal, _shortNum(steps));
        _drawGauge(dc, cx + dx, botCY, aod, ORANGE,
            cals.toFloat() / CALORIE_GOAL, _shortNum(cals));
    }

    function _drawGauge(dc as Dc, x as Number, y as Number, aod as Boolean,
            color as Number, progress as Float, value as String) as Void {
        // Track je vlásečnice pod silnějším obloukem – dá kroužku hloubku.
        if (!aod) {
            dc.setPenWidth(2);
            dc.setColor(TRACK, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(x, y, GAUGE_R);
        }

        var filled = progress;
        if (filled > 0.999) { filled = 0.999; }
        if (filled > 0.0) {
            var end = 90.0 - 360.0 * filled;
            while (end < 0.0) { end += 360.0; }
            dc.setPenWidth(GAUGE_STROKE);
            dc.setColor(aod ? _dim(color) : color, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(x, y, GAUGE_R, Graphics.ARC_CLOCKWISE, 90.0, end);

            // Kulatý hrot na konci oblouku.
            var a = end * Math.PI / 180.0;
            dc.fillCircle((x + Math.cos(a) * GAUGE_R).toNumber(),
                (y - Math.sin(a) * GAUGE_R).toNumber(), GAUGE_STROKE / 2);
        }
        dc.setPenWidth(1);

        // V AOD zůstává jen oblouk – naměřená čísla se nezobrazují.
        if (!aod) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y, Graphics.FONT_XTINY, value,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // Poslední vzorek z historie – nebudí optický senzor
    // Podkladová křivka barometrického trendu za 12 h. Šedá tak, aby působila jako
    // textura pozadí – hodnotu nese tvar křivky, ne číslo.
    function _drawPressureGraph(dc as Dc, cx as Number, cy as Number, top as Number,
            aod as Boolean) as Void {
        if (aod) { return; }
        var samples = _pressureSamples();
        if (samples == null) { return; }

        // Kruh se ke krajům zužuje, o šířce rozhoduje ta hrana, která je dál od středu.
        var dyTop = top - cy;
        var dyBot = top + GRAPH_H - cy;
        var dy = (dyTop.abs() > dyBot.abs()) ? dyTop : dyBot;
        var limit = CONTENT_R * CONTENT_R - dy * dy;
        if (limit <= 0) { return; }
        var halfW = Math.sqrt(limit.toFloat()).toNumber() - 6;
        if (halfW < 40) { return; }

        var lo = samples[0];
        var hi = samples[0];
        for (var i = 1; i < samples.size(); i += 1) {
            if (samples[i] < lo) { lo = samples[i]; }
            if (samples[i] > hi) { hi = samples[i]; }
        }
        var span = hi - lo;
        if (span < GRAPH_MIN_SPAN) {
            var mid = (hi + lo) / 2.0;
            lo = mid - GRAPH_MIN_SPAN / 2.0;
            span = GRAPH_MIN_SPAN;
        }

        dc.setPenWidth(3);
        dc.setColor(GRAPH_GRAY, Graphics.COLOR_TRANSPARENT);
        // vzorky jdou od nejnovějšího, takže je kreslíme zprava doleva
        var n = samples.size();
        var x1 = cx + halfW;
        var y1 = top + GRAPH_H - ((samples[0] - lo) / span * GRAPH_H).toNumber();
        for (var i = 1; i < n; i += 1) {
            var x0 = cx + halfW - (2 * halfW * i) / (n - 1);
            var y0 = top + GRAPH_H - ((samples[i] - lo) / span * GRAPH_H).toNumber();
            dc.drawLine(x0, y0, x1, y1);
            x1 = x0;
            y1 = y0;
        }
        dc.setPenWidth(1);
    }

    function _pressureSamples() as Array<Float>? {
        if (!(Toybox has :SensorHistory)
            || !(Toybox.SensorHistory has :getPressureHistory)) { return null; }
        var iter = Toybox.SensorHistory.getPressureHistory({
            :period => new Time.Duration(12 * 3600),
            :order => Toybox.SensorHistory.ORDER_NEWEST_FIRST
        });
        var out = [] as Array<Float>;
        var sample = iter.next();
        while (sample != null && out.size() < GRAPH_MAX_SAMPLES) {
            if (sample.data != null) { out.add(sample.data); }
            sample = iter.next();
        }
        return out.size() >= 2 ? out : null;
    }

    function _latestHeartRate() as Number? {
        if (!(ActivityMonitor has :getHeartRateHistory)) { return null; }
        var it = ActivityMonitor.getHeartRateHistory(1, true);
        if (it == null) { return null; }
        var sample = it.next();
        if (sample == null || sample.heartRate == null
            || sample.heartRate == ActivityMonitor.INVALID_HR_SAMPLE) { return null; }
        return sample.heartRate;
    }

    // Východ/západ se počítá jednou denně z poslední známé polohy (bez zapínání GPS)
    function _updateSun(now as Time.Moment, dateInfo as Gregorian.Info) as Void {
        if (dateInfo.day == _sunDay) { return; }
        _sunDay = dateInfo.day;
        _sunriseMin = null;
        _sunsetMin = null;

        // Poslední GPS fix; když žádný není (čerstvá instalace), vezmi polohu z počasí
        var location = _validLocation(Position.getInfo());
        if (location == null) {
            var conditions = Weather.getCurrentConditions();
            if (conditions != null) {
                location = _validCoordinates(conditions.observationLocationPosition);
            }
        }
        if (location == null) {
            _sunDay = -1;   // zkusit znovu, až bude poloha známá
            return;
        }

        _computeSun(location, now);
    }

    // Bez GPS fixu vrací Position.getInfo() polohu 180/180, ne null – musí se odfiltrovat
    function _validLocation(posInfo as Position.Info?) as Position.Location? {
        if (posInfo == null) { return null; }
        return _validCoordinates(posInfo.position);
    }

    function _validCoordinates(location as Position.Location?) as Position.Location? {
        if (location == null) { return null; }
        var degrees = location.toDegrees();
        var lat = degrees[0];
        var lon = degrees[1];
        if (lat < -90.0 || lat > 90.0 || lon < -180.0 || lon > 180.0) { return null; }
        if (lat == 0.0 && lon == 0.0) { return null; }
        return location;
    }

    // Východ a západ slunce z polohy a data ("sunrise equation", NOAA).
    // Počítá se jednou denně, nezávisle na Weather API.
    function _computeSun(location as Position.Location, now as Time.Moment) as Void {
        var degrees = location.toDegrees();
        var lat = degrees[0].toDouble();
        var lon = degrees[1].toDouble();
        var rad = Math.PI / 180.0;

        var julianDay = now.value() / 86400.0 + 2440587.5;
        var n = Math.floor(julianDay - 2451545.0 + 0.0008 + 0.5);
        var meanNoon = n - lon / 360.0;   // východní délka = dřívější poledne v UTC

        var anomaly = _wrap360(357.5291 + 0.98560028 * meanNoon);
        var ar = anomaly * rad;
        var center = 1.9148 * Math.sin(ar) + 0.02 * Math.sin(2 * ar) + 0.0003 * Math.sin(3 * ar);
        var lambda = _wrap360(anomaly + center + 282.9372) * rad;

        var transit = meanNoon + 0.0053 * Math.sin(ar) - 0.0069 * Math.sin(2 * lambda);

        var sinDecl = Math.sin(lambda) * Math.sin(23.44 * rad);
        var cosDecl = Math.cos(Math.asin(sinDecl));
        var cosHour = (Math.sin(-0.833 * rad) - Math.sin(lat * rad) * sinDecl)
            / (Math.cos(lat * rad) * cosDecl);
        if (cosHour > 1.0 || cosHour < -1.0) {
            return;   // polární den nebo noc – slunce dnes nevychází ani nezapadá
        }

        var hourAngle = (Math.acos(cosHour) / rad) / 360.0;
        _sunriseMin = _julianToLocalMinutes(transit - hourAngle);
        _sunsetMin = _julianToLocalMinutes(transit + hourAngle);
    }

    function _wrap360(value as Double) as Double {
        return value - Math.floor(value / 360.0) * 360.0;
    }

    // Vstup: dny od J2000. Výstup: minuty od lokální půlnoci.
    function _julianToLocalMinutes(daysFromJ2000 as Double) as Number {
        var unix = (daysFromJ2000 + 10957.5) * 86400.0;
        var local = unix + System.getClockTime().timeZoneOffset;
        var secondsOfDay = local - Math.floor(local / 86400.0) * 86400.0;
        return (secondsOfDay / 60.0).toNumber();
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
        return Lang.format("$1$. $2$. $3$", [dateInfo.day, dateInfo.month, dateInfo.year]);
    }

    function _shortNum(n as Number) as String {
        if (n >= 10000) { return (n / 1000).format("%d") + "k"; }
        if (n >= 1000) { return (n / 1000).format("%d") + "." + ((n % 1000) / 100).format("%d") + "k"; }
        return n.format("%d");
    }
}
