pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// wttr.in JSON, refreshed every 30 min and cached under .cache/weather.json.
Singleton {
    id: root

    property bool ready: false
    property string location: ""
    property real temp: 0
    property real feels: 0
    property string desc: ""
    property int code: 113
    property int humidity: 0
    property real wind: 0
    property real uv: 0
    property bool isDay: true
    property var days: []   // [{ date, max, min, code, desc, hours: [{ time, temp, code, rain }] }]
    property var hourly: [] // next 24h, 3-hourly

    readonly property string unit: Config.weather.fahrenheit ? "°F" : "°C"
    readonly property string tempText: Math.round(temp) + "°"
    readonly property string icon: iconFor(code, isDay)
    readonly property color tint: tintFor(code)

    function iconFor(c, day) {
        if (c === 113)
            return day ? "weather-day_sunny" : "weather-night_clear";
        if (c === 116)
            return day ? "weather-day_cloudy" : "weather-night_alt_cloudy";
        if (c === 119 || c === 122)
            return "weather-cloudy";
        if ([143, 248, 260].includes(c))
            return "weather-fog";
        if ([176, 263, 266, 293, 296, 353].includes(c))
            return day ? "weather-day_showers" : "weather-night_alt_showers";
        if ([299, 302, 305, 308, 356, 359, 311, 314, 281, 284].includes(c))
            return "weather-rain";
        if ([200, 386, 389, 392, 395].includes(c))
            return "weather-thunderstorm";
        if ([179, 182, 185, 317, 320, 350, 362, 365, 374, 377].includes(c))
            return "weather-sleet";
        if ([227, 230, 323, 326, 329, 332, 335, 338, 368, 371].includes(c))
            return "weather-snow";
        return "weather-cloud";
    }

    function tintFor(c) {
        if (c === 113)
            return isDay ? "#ffcf5c" : "#9fa8ff";
        if (c === 116)
            return "#ffd98a";
        if ([200, 386, 389, 392, 395].includes(c))
            return "#c792ff";
        if ([227, 230, 323, 326, 329, 332, 335, 338, 368, 371].includes(c))
            return "#d6f1ff";
        if (c >= 176)
            return "#6cb8ff";
        return "#b8c6d9";
    }

    function parse(text) {
        try {
            const j = JSON.parse(text);
            const cur = j.current_condition[0];
            const f = Config.weather.fahrenheit;
            temp = Number(f ? cur.temp_F : cur.temp_C);
            feels = Number(f ? cur.FeelsLikeF : cur.FeelsLikeC);
            desc = cur.weatherDesc?.[0]?.value?.trim() ?? "";
            code = Number(cur.weatherCode);
            humidity = Number(cur.humidity);
            wind = Number(cur.windspeedKmph);
            uv = Number(cur.uvIndex ?? 0);
            const area = j.nearest_area?.[0];
            location = Config.weather.location !== "" ? Config.weather.location : (area?.areaName?.[0]?.value ?? "");
            const astro = j.weather?.[0]?.astronomy?.[0];
            if (astro) {
                const now = new Date();
                const toMin = s => {
                    const m = String(s).match(/(\d+):(\d+)\s*(AM|PM)/i);
                    if (!m)
                        return -1;
                    let h = parseInt(m[1]) % 12;
                    if (m[3].toUpperCase() === "PM")
                        h += 12;
                    return h * 60 + parseInt(m[2]);
                };
                const nm = now.getHours() * 60 + now.getMinutes();
                isDay = nm >= toMin(astro.sunrise) && nm < toMin(astro.sunset);
            }
            days = (j.weather ?? []).map(d => ({
                        date: d.date,
                        max: Number(f ? d.maxtempF : d.maxtempC),
                        min: Number(f ? d.mintempF : d.mintempC),
                        code: Number(d.hourly?.[4]?.weatherCode ?? 113),
                        desc: d.hourly?.[4]?.weatherDesc?.[0]?.value?.trim() ?? "",
                        hours: (d.hourly ?? []).map(h => ({
                                    time: parseInt(h.time) / 100,
                                    temp: Number(f ? h.tempF : h.tempC),
                                    code: Number(h.weatherCode),
                                    rain: Number(h.chanceofrain ?? 0)
                                }))
                    }));
            const hrs = [];
            const nowH = new Date().getHours();
            for (let di = 0; di < days.length && hrs.length < 8; di++)
                for (const h of days[di].hours)
                    if ((di > 0 || h.time >= nowH - 1) && hrs.length < 8)
                        hrs.push(Object.assign({ day: di }, h));
            hourly = hrs;
            ready = true;
            return true;
        } catch (e) {
            return false;
        }
    }

    FileView {
        id: cache
        path: Config.cacheDir + "/weather.json"
        onLoaded: root.parse(text())
    }

    Process {
        id: fetch
        command: ["curl", "-sf", "--max-time", "15", "https://wttr.in/" + encodeURIComponent(Config.weather.location) + "?format=j1"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length > 100 && root.parse(text))
                    cache.setText(text);
            }
        }
    }

    function refresh() {
        if (!fetch.running)
            fetch.running = true;
    }

    Timer {
        interval: 30 * 60 * 1000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }
    Timer {
        interval: 3000
        running: true
        onTriggered: root.refresh()
    }
}
