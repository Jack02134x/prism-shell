pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// The clock: alarms (with groups and repeats), world clock, timer, interval
// timer and stopwatch. Everything lives here, so alarms ring with the window
// closed; modules/clock draws it. State is saved to .state/clock.json.
Singleton {
    id: root

    readonly property bool loaded: ready
    property bool ready: false
    readonly property string path: Config.shellDir + "/.state/clock.json"

    // ---- state (one object, saved whole; call touch() after changing it) ----
    property var d: defaults()

    function defaults() {
        return {
            v: 2,
            nextId: 1,
            settings: {
                h24: true, secs: true,
                fast: false, fastMin: 3, fastMax: 9, offset: -1, offsetDay: "",
                remind: 30, snooze: 10, silence: 5,
                tone: "builtin:digital", volume: 80
            },
            alarms: [], // {id, h, m, label, on, days (bit 0 = Sunday), rep, skip, snoozeTo, due, reminded, group, tone}
            groups: [], // {id, name, tone}
            cities: [], // time zone names
            timer: { status: "idle", end: 0, remaining: 0, total: 0, digits: "" },
            iv: { steps: [{ name: "Work", secs: 40 }, { name: "Rest", secs: 20 }], loops: 3, presets: [], status: "idle", runSteps: [], runStart: 0, elapsedPause: 0 },
            sw: { running: false, start: 0, acc: 0, laps: [] },
            win: { open: false, x: -1, y: -1, mini: false, pinWs: 0, screen: "", tab: "clock", tmode: "timer", openGroups: [] }
        };
    }

    function touch() {
        d = JSON.parse(JSON.stringify(d));
        if (ready)
            saver.restart();
    }

    property real now: Date.now()

    // ---- what the bar, drawer and lock screen read ----
    readonly property bool open: d.win.open
    readonly property bool timerRunning: d.timer.status === "running"
    readonly property bool timerPaused: d.timer.status === "paused"
    readonly property bool ivRunning: d.iv.status === "running"
    readonly property bool ivPaused: d.iv.status === "paused"
    readonly property bool swRunning: d.sw.running
    readonly property var ringing: ring
    readonly property real timerLeft: timerRunning ? Math.max(0, d.timer.end - now) : d.timer.remaining
    readonly property real swElapsed: d.sw.acc + (swRunning ? now - d.sw.start : 0)
    readonly property var nextAlarm: {
        let best = null;
        for (const a of d.alarms)
            if (a.on && a.due && (!best || a.due < best.due))
                best = a;
        return best ? { at: best.due, label: best.label || "Alarm", inMs: Math.max(0, best.due - now) } : null;
    }

    // ---- window ----
    function show(tab) {
        if (tab)
            setTab(tab);
        d.win.open = true;
        d.win.mini = false;
        touch();
    }
    function hide() {
        d.win.open = false;
        touch();
    }
    function toggle() {
        d.win.open ? hide() : show("");
    }
    function setTab(tab) {
        const map = { alarms: "alarm", alarm: "alarm", clock: "clock", timer: "timer", stopwatch: "stopwatch", intervals: "timer", settings: d.win.tab };
        d.win.tab = map[tab] ?? "clock";
        if (tab === "intervals")
            d.win.tmode = "interval";
        touch();
    }

    // ============================================================== alarms ===
    readonly property var dayShort: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    function pad(n) {
        return (n < 10 ? "0" : "") + n;
    }
    function ymd(dt) {
        return dt.getFullYear() + "-" + pad(dt.getMonth() + 1) + "-" + pad(dt.getDate());
    }
    function parseYmd(s) {
        const p = String(s || "").split("-").map(Number);
        return p[0] ? { y: p[0], mo: p[1], d: p[2] } : null;
    }
    // a day number that ignores daylight-saving shifts
    function epochDay(y, mo, dd) {
        return Math.floor(Date.UTC(y, mo - 1, dd) / 86400000);
    }
    function fmt(h, m) {
        if (d.settings.h24)
            return { t: pad(h) + ":" + pad(m), ap: "" };
        return { t: (h % 12 || 12) + ":" + pad(m), ap: h < 12 ? "AM" : "PM" };
    }
    function fmtClock(h, m) {
        const f = fmt(h, m);
        return f.ap ? f.t + " " + f.ap : f.t;
    }
    function fmtWhen(ms) {
        const dt = new Date(ms);
        const t = fmtClock(dt.getHours(), dt.getMinutes());
        return dt.toDateString() === new Date().toDateString() ? t : dayShort[dt.getDay()] + " " + t;
    }
    function untilText(ms) {
        const min = Math.max(1, Math.ceil(ms / 60000));
        const dd = Math.floor(min / 1440), h = Math.floor((min % 1440) / 60), m = min % 60;
        return [dd ? dd + " d" : "", h ? h + " h" : "", m ? m + " min" : ""].filter(s => s).join(" ");
    }

    // does it stay on after ringing?
    function repeats(a) {
        if (a.rep) {
            if (a.rep.k === "interval")
                return true;
            if (a.rep.k === "date")
                return false;
        }
        return !!a.days;
    }
    function repeatText(a) {
        if (a.rep && a.rep.k === "date") {
            const p = parseYmd(a.rep.date);
            if (!p)
                return "Once";
            const dt = new Date(p.y, p.mo - 1, p.d);
            return Qt.formatDate(dt, dt.getFullYear() === new Date().getFullYear() ? "d MMM" : "d MMM yyyy");
        }
        if (a.rep && a.rep.k === "interval") {
            const n = a.rep.n || 1;
            return n === 1 ? "Every day" : n === 2 ? "Every other day" : "Every " + n + " days";
        }
        const dd = a.days;
        if (!dd)
            return "Once";
        if (dd === 127)
            return "Every day";
        if (dd === 62)
            return "Weekdays";
        if (dd === 65)
            return "Weekends";
        return [1, 2, 3, 4, 5, 6, 0].filter(i => dd & (1 << i)).map(i => dayShort[i]).join(", ");
    }

    // the next time it rings by its schedule (not counting snooze), or 0
    function nextTime(a, t) {
        const skip = a.skip || 0;
        if (a.rep && a.rep.k === "date") {
            const p = parseYmd(a.rep.date);
            if (!p)
                return 0;
            const at = new Date(p.y, p.mo - 1, p.d, a.h, a.m, 0, 0).getTime();
            return at > t && at > skip ? at : 0;
        }
        if (a.rep && a.rep.k === "interval") {
            const n = Math.max(1, a.rep.n || 1);
            const s = parseYmd(a.rep.start);
            if (!s)
                return 0;
            const nd = new Date(t);
            const dd = epochDay(nd.getFullYear(), nd.getMonth() + 1, nd.getDate()) - epochDay(s.y, s.mo, s.d);
            const base = dd < 0 ? -dd : (dd % n === 0 ? 0 : n - dd % n);
            for (let off = base; off <= base + 2 * n; off += n) {
                const dt = new Date(t);
                dt.setHours(a.h, a.m, 0, 0);
                dt.setDate(dt.getDate() + off);
                if (dt.getTime() > t && dt.getTime() > skip)
                    return dt.getTime();
            }
            return 0;
        }
        const dt = new Date(t);
        for (let i = 0; i < 9; i++) {
            dt.setHours(a.h, a.m, 0, 0);
            if (dt.getTime() > t && dt.getTime() > skip && (!a.days || (a.days & (1 << dt.getDay()))))
                return dt.getTime();
            dt.setDate(dt.getDate() + 1);
        }
        return 0;
    }
    // the plain schedule, ignoring a skipped ring (for "skip next")
    function scheduled(a, t) {
        return nextTime(Object.assign({}, a, { skip: 0 }), t);
    }
    function reschedule(a, t) {
        let due = nextTime(a, t);
        if (a.snoozeTo > t && (!due || a.snoozeTo < due))
            due = a.snoozeTo;
        a.due = a.on ? due : 0;
    }

    function alarmById(id) {
        return d.alarms.find(a => a.id === id) ?? null;
    }
    function groupById(id) {
        return d.groups.find(g => g.id === id) ?? null;
    }
    function members(gid) {
        return d.alarms.filter(a => a.group === gid).sort((a, b) => a.h * 60 + a.m - b.h * 60 - b.m);
    }

    // a: a draft from the editor ({id: 0} for a new one)
    function saveAlarm(a) {
        const t = Date.now();
        let x = a.id ? alarmById(a.id) : null;
        if (!x) {
            x = { id: d.nextId++, skip: 0, snoozeTo: 0, due: 0, reminded: 0 };
            d.alarms.push(x);
        }
        for (const k of ["h", "m", "label", "days", "rep", "group", "tone"])
            x[k] = a[k];
        x.on = true;
        x.snoozeTo = 0;
        x.skip = a.skip ?? 0;
        if (x.rep && x.rep.k === "interval" && !x.rep.start)
            x.rep.start = ymd(new Date());
        reschedule(x, t);
        touch();
        return x.due;
    }
    function deleteAlarm(id) {
        d.alarms = d.alarms.filter(a => a.id !== id);
        touch();
    }
    function setAlarmOn(id, on) {
        const a = alarmById(id);
        if (!a)
            return 0;
        a.on = on;
        a.snoozeTo = 0;
        reschedule(a, Date.now());
        touch();
        return a.due;
    }
    // skip the next ring of a repeating alarm (again: un-skip)
    function toggleSkip(id) {
        const a = alarmById(id);
        if (!a)
            return;
        const t = Date.now();
        a.skip = a.skip > t ? 0 : scheduled(a, t);
        reschedule(a, t);
        touch();
    }

    function saveGroup(g) {
        let x = g.id ? groupById(g.id) : null;
        if (!x) {
            x = { id: d.nextId++ };
            d.groups.push(x);
        }
        x.name = g.name || "Group";
        x.tone = g.tone || "";
        touch();
        return x.id;
    }
    function deleteGroup(id, withAlarms) {
        d.groups = d.groups.filter(g => g.id !== id);
        if (withAlarms)
            d.alarms = d.alarms.filter(a => a.group !== id);
        else
            for (const a of d.alarms)
                if (a.group === id)
                    a.group = 0;
        touch();
    }
    // tap a group's name: everything on (or, if all are on, off)
    function toggleGroup(id) {
        const m = members(id);
        if (!m.length)
            return "";
        const turnOn = m.some(a => !a.on);
        const t = Date.now();
        for (const a of d.alarms)
            if (a.group === id) {
                a.on = turnOn;
                a.snoozeTo = 0;
                reschedule(a, t);
            }
        touch();
        const g = groupById(id);
        if (!turnOn)
            return g.name + " off";
        const next = Math.min(...d.alarms.filter(a => a.group === id && a.due).map(a => a.due));
        return g.name + " on · next in " + untilText(next - t);
    }
    function setGroupOpen(id, open) {
        const s = d.win.openGroups.filter(x => x !== id);
        if (open)
            s.push(id);
        d.win.openGroups = s;
        touch();
    }

    // ============================================================ fast mode ===
    // the Clock tab runs ahead by a secret number of seconds (between the
    // minimum and maximum minutes), reshuffled every day. Alarms use real time.
    function reroll() {
        const lo = d.settings.fastMin * 60, hi = Math.max(lo, d.settings.fastMax * 60);
        d.settings.offset = lo + Math.floor(Math.random() * (hi - lo + 1));
        d.settings.offsetDay = ymd(new Date());
        touch();
    }
    function fastOffset() {
        const s = d.settings;
        if (!s.fast)
            return 0;
        if (s.offset < s.fastMin * 60 || s.offset > Math.max(s.fastMin, s.fastMax) * 60 || s.offsetDay !== ymd(new Date(now)))
            Qt.callLater(reroll);
        return Math.max(0, s.offset) * 1000;
    }

    // ============================================================== timer ===
    function timerStart(ms) {
        const t = d.timer;
        t.total = ms;
        t.remaining = ms;
        t.end = Date.now() + ms;
        t.status = "running";
        touch();
    }
    function timerPause() {
        const t = d.timer;
        if (t.status === "running") {
            t.remaining = Math.max(0, t.end - Date.now());
            t.status = "paused";
        } else if (t.status === "paused") {
            t.end = Date.now() + t.remaining;
            t.status = "running";
        }
        touch();
    }
    function timerAdd(ms) {
        const t = d.timer;
        if (t.status === "running")
            t.end += ms;
        else
            t.remaining += ms;
        t.total += ms;
        touch();
    }
    function timerReset() {
        d.timer.status = "idle";
        d.timer.remaining = 0;
        touch();
    }
    // for IPC / the launcher: start a timer of n minutes
    function timer(minutes) {
        if (minutes <= 0)
            return timerReset();
        timerStart(minutes * 60000);
    }

    // =========================================================== intervals ===
    function ivFlat(steps, loops) {
        const base = steps.filter(s => s.secs > 0);
        const out = [];
        for (let l = 0; l < Math.max(1, loops); l++)
            for (const s of base)
                out.push({ name: s.name || "Step", secs: s.secs, loop: l + 1 });
        return out;
    }
    function ivTotal(flat) {
        return flat.reduce((a, s) => a + s.secs, 0);
    }
    function ivElapsed() {
        return (d.iv.status === "running" ? now - d.iv.runStart : d.iv.elapsedPause) / 1000;
    }
    // {index, left (s), step, next, done (s), total (s)}
    function ivState() {
        const flat = d.iv.runSteps;
        const el = ivElapsed();
        let cum = 0;
        for (let i = 0; i < flat.length; i++) {
            cum += flat[i].secs;
            if (el < cum)
                return { index: i, left: cum - el, step: flat[i], next: flat[i + 1] ?? null, done: el, total: cum + flat.slice(i + 1).reduce((a, s) => a + s.secs, 0) };
        }
        return { index: flat.length - 1, left: 0, step: flat[flat.length - 1] ?? null, next: null, done: el, total: el };
    }
    function ivStart() {
        const flat = ivFlat(d.iv.steps, d.iv.loops);
        if (!flat.length)
            return;
        d.iv.runSteps = flat;
        d.iv.runStart = Date.now();
        d.iv.elapsedPause = 0;
        d.iv.status = "running";
        lastIvIndex = 0;
        touch();
    }
    function ivPause() {
        const v = d.iv;
        if (v.status === "running") {
            v.elapsedPause = Date.now() - v.runStart;
            v.status = "paused";
        } else if (v.status === "paused") {
            v.runStart = Date.now() - v.elapsedPause;
            v.status = "running";
        }
        touch();
    }
    function ivSkip() {
        const st = ivState();
        const jump = st.left * 1000 + 10;
        if (d.iv.status === "running")
            d.iv.runStart -= jump;
        else
            d.iv.elapsedPause += jump;
        touch();
    }
    function ivReset() {
        d.iv.status = "idle";
        touch();
    }
    function ivSavePreset(name) {
        d.iv.presets = d.iv.presets.filter(p => p.name !== name);
        d.iv.presets.push({ name: name, steps: d.iv.steps, loops: d.iv.loops });
        touch();
    }
    function ivLoadPreset(i) {
        const p = d.iv.presets[i];
        if (!p)
            return;
        d.iv.steps = JSON.parse(JSON.stringify(p.steps));
        d.iv.loops = p.loops;
        touch();
    }
    function ivDeletePreset(i) {
        d.iv.presets.splice(i, 1);
        touch();
    }
    property int lastIvIndex: 0

    // ========================================================== stopwatch ===
    function swToggle() {
        const w = d.sw;
        if (w.running) {
            w.acc += Date.now() - w.start;
            w.running = false;
        } else {
            w.start = Date.now();
            w.running = true;
        }
        touch();
    }
    function swLap() {
        const total = d.sw.acc + (d.sw.running ? Date.now() - d.sw.start : 0);
        const prev = d.sw.laps.length ? d.sw.laps[0].total : 0;
        d.sw.laps.unshift({ total: total, split: total - prev });
        touch();
    }
    function swReset() {
        d.sw = { running: false, start: 0, acc: 0, laps: [] };
        touch();
    }
    function stopwatch() {
        swToggle();
    }

    // ============================================================= ringing ===
    property var ring: null // {kind: alarm | timer | interval, title, sub, id, since}

    function startRing(r) {
        stopSound();
        r.since = Date.now();
        ring = r;
        const a = r.kind === "alarm" ? alarmById(r.id) : null;
        const g = a && a.group ? groupById(a.group) : null;
        playLoop((a && a.tone) || (g && g.tone) || d.settings.tone);
        silencer.interval = Math.max(1, d.settings.silence) * 60000;
        silencer.restart();
    }
    function stopRinging() {
        ring = null;
        silencer.stop();
        stopSound();
    }
    function snooze() {
        const r = ring;
        if (!r)
            return;
        stopRinging();
        if (r.kind === "alarm") {
            const a = alarmById(r.id);
            if (!a)
                return;
            const t = Date.now();
            a.on = true;
            a.snoozeTo = t + d.settings.snooze * 60000;
            reschedule(a, t);
            touch();
        } else if (r.kind === "timer") {
            timerStart(60000);
        }
    }
    Timer {
        id: silencer
        onTriggered: root.stopRinging()
    }

    // ---- sounds: ffmpeg makes the built-in tones, no sound files needed ----
    readonly property var builtinTones: [
        { id: "builtin:digital", name: "Digital", expr: "0.45*sin(2*PI*2000*t)*lt(mod(t,0.25),0.09)*lt(mod(t,1.6),1)" },
        { id: "builtin:beep", name: "Beep", expr: "0.45*sin(2*PI*880*t)*lt(mod(t,0.6),0.18)" },
        { id: "builtin:chime", name: "Chime", expr: "0.35*sin(2*PI*(660+330*lt(mod(t,1.2),0.6))*t)*exp(-4*mod(t,0.6))" },
        { id: "builtin:gentle", name: "Gentle rise", expr: "min(1,t/20)*0.4*sin(2*PI*523*t)*(0.6+0.4*sin(2*PI*0.5*t))" }
    ]
    function toneName(tid) {
        if (!tid)
            return "Default";
        const b = builtinTones.find(x => x.id === tid);
        if (b)
            return b.name;
        const s = String(tid).split("/").pop().replace(/\.[a-z0-9]+$/, "").replace(/[-_]/g, " ");
        return s.charAt(0).toUpperCase() + s.slice(1);
    }
    function ffArgs(tid, loop) {
        const args = ["ffplay", "-nodisp", "-loglevel", "quiet", "-volume", String(Math.round(d.settings.volume))];
        const b = builtinTones.find(x => x.id === tid) ?? (String(tid).startsWith("/") ? null : builtinTones[0]);
        if (b)
            return args.concat(["-f", "lavfi", "-i", "aevalsrc=" + b.expr.replace(/,/g, "\\,") + ":s=44100"]);
        return args.concat(loop ? ["-loop", "0", tid] : ["-autoexit", tid]);
    }
    function playLoop(tid) {
        player.command = ffArgs(tid, true);
        player.running = true;
    }
    function stopSound() {
        player.running = false;
    }
    // a few seconds of a tone, for the picker
    function preview(tid) {
        previewer.running = false;
        previewer.command = ["timeout", "4"].concat(ffArgs(tid, false));
        previewer.running = true;
    }
    function beep(final) {
        beeper.running = false;
        beeper.command = ["timeout", final ? "1.2" : "0.45"].concat(ffArgs("builtin:beep", false));
        beeper.running = true;
    }
    Process { id: player }
    Process { id: previewer }
    Process { id: beeper }

    // system sounds for the tone picker (read once, when the picker opens)
    property var systemTones: []
    function loadTones() {
        if (!systemTones.length && !tonesProc.running)
            tonesProc.running = true;
    }
    Process {
        id: tonesProc
        command: ["sh", "-c", "find /usr/share/sounds -type f \\( -name '*.oga' -o -name '*.ogg' -o -name '*.wav' \\) 2>/dev/null | grep -Ev 'audio-channel|audio-test|audio-volume|camera|device-|power-|service-|suspend|trash|screen-capture' | sort | head -n 40"]
        stdout: StdioCollector {
            onStreamFinished: root.systemTones = text.split("\n").filter(s => s !== "")
        }
    }

    // ========================================================== world clock ===
    property var zoneOffsets: ({}) // tz -> minutes east of UTC
    property var allZones: []
    function addCity(tz) {
        if (d.cities.indexOf(tz) < 0) {
            d.cities.push(tz);
            touch();
            refreshZones();
        }
    }
    function removeCity(tz) {
        d.cities = d.cities.filter(c => c !== tz);
        touch();
    }
    function cityName(tz) {
        return String(tz).split("/").pop().replace(/_/g, " ");
    }
    function loadZones() {
        if (!allZones.length && !zonesProc.running)
            zonesProc.running = true;
    }
    function refreshZones() {
        if (d.cities.length && !offsetsProc.running) {
            offsetsProc.command = ["python3", "-c", "import sys,json,datetime\nfrom zoneinfo import ZoneInfo\nn=datetime.datetime.now(datetime.timezone.utc)\nout={}\nfor z in sys.argv[1:]:\n  try: out[z]=int(n.astimezone(ZoneInfo(z)).utcoffset().total_seconds()//60)\n  except Exception: pass\nprint(json.dumps(out))"].concat(d.cities);
            offsetsProc.running = true;
        }
    }
    Process {
        id: zonesProc
        command: ["timedatectl", "list-timezones"]
        stdout: StdioCollector {
            onStreamFinished: root.allZones = text.split("\n").filter(s => s.indexOf("/") > 0)
        }
    }
    Process {
        id: offsetsProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.zoneOffsets = JSON.parse(text);
                } catch (e) {}
            }
        }
    }
    Timer {
        interval: 30 * 60000 // daylight saving
        repeat: true
        running: root.d.cities.length > 0
        onTriggered: root.refreshZones()
    }

    // =============================================================== engine ===
    // once a second, on the second
    Timer {
        id: ticker
        interval: 1000
        running: root.ready
        onTriggered: {
            root.tick();
            interval = 1000 - Date.now() % 1000 + 5;
            restart();
        }
    }

    function tick() {
        const t = Date.now();
        now = t;
        let changed = false;

        for (const a of d.alarms) {
            if (!a.on || !a.due)
                continue;
            // a heads-up before it rings, with a way to skip just this one
            const lead = d.settings.remind * 60000;
            if (lead > 0 && a.reminded !== a.due && a.due !== a.snoozeTo && a.due - t <= lead && a.due - t > 60000) {
                a.reminded = a.due;
                changed = true;
                const id = a.id, at = a.due;
                Notifs.local((a.label || "Alarm") + " at " + fmtClock(a.h, a.m), "Rings in " + untilText(at - t), "alarm", 1, "", [{ text: "Skip this one", run: () => root.skipAt(id, at) }]);
            }
            if (t < a.due)
                continue;
            const late = t - a.due;
            a.snoozeTo = 0;
            if (late < 10 * 60000)
                startRing({ kind: "alarm", id: a.id, title: a.label || "Alarm", sub: fmtClock(a.h, a.m) + (repeats(a) ? " · " + repeatText(a) : "") });
            else
                Notifs.local("Missed alarm", (a.label || "Alarm") + " at " + fmtClock(a.h, a.m), "alarm_off", 1, "", []);
            if (repeats(a))
                reschedule(a, t + 1000);
            else {
                a.on = false;
                a.due = 0;
            }
            changed = true;
        }

        if (d.timer.status === "running" && t >= d.timer.end) {
            d.timer.status = "idle";
            d.timer.remaining = 0;
            changed = true;
            startRing({ kind: "timer", title: "Time's up", sub: "Timer · " + Utils.hms(d.timer.total / 1000) });
        }

        if (d.iv.status === "running") {
            const st = ivState();
            if (st.left <= 0) {
                d.iv.status = "idle";
                changed = true;
                startRing({ kind: "interval", title: "Intervals done", sub: d.iv.runSteps.length + " steps · " + Utils.hms(ivTotal(d.iv.runSteps)) });
            } else if (st.index !== lastIvIndex) {
                lastIvIndex = st.index;
                beep(false);
                Osd.show("toggle", "timer_sand", st.step.name + " · " + Utils.hms(st.step.secs), -1);
            } else if (st.left <= 3.05 && st.left > 0.5) {
                beep(false); // 3, 2, 1
            }
        }

        if (changed)
            touch();
    }
    function skipAt(id, at) {
        const a = alarmById(id);
        if (!a || !a.on)
            return;
        a.skip = Math.max(a.skip || 0, at);
        reschedule(a, Date.now());
        touch();
    }

    // =============================================================== saving ===
    FileView {
        id: file
        path: root.path
        atomicWrites: true
        printErrors: false
        onLoaded: root.load(text())
        onLoadFailed: root.load("")
    }
    Timer {
        id: saver
        interval: 400
        onTriggered: file.setText(JSON.stringify(root.d, null, 1))
    }

    function load(text) {
        let s = null;
        try {
            s = JSON.parse(text);
        } catch (e) {}
        const out = defaults();
        if (s && s.v === 2) {
            for (const k in out)
                if (s[k] !== undefined)
                    out[k] = (typeof out[k] === "object" && !Array.isArray(out[k])) ? Object.assign(out[k], s[k]) : s[k];
        } else if (s) {
            migrate(s, out); // the old Python clock's file
        }
        out.win.open = false;
        d = out;
        const t = Date.now();
        for (const a of d.alarms)
            if (a.on && (!a.due || a.due < t - 10 * 60000))
                reschedule(a, t);
        lastIvIndex = d.iv.status === "idle" ? 0 : ivState().index;
        ready = true;
        touch();
        refreshZones();
    }
    function migrate(s, out) {
        for (const a of s.alarms ?? []) {
            let bits = 0;
            for (const x of a.days ?? [])
                bits |= 1 << x;
            out.alarms.push({ id: out.nextId++, h: a.h, m: a.m, label: a.label ?? "", on: !!a.enabled, days: bits, rep: null, skip: 0, snoozeTo: 0, due: 0, reminded: 0, group: 0, tone: "" });
        }
        const st = s.settings ?? {};
        if (st.tone)
            out.settings.tone = st.tone;
        if (st.volume !== undefined)
            out.settings.volume = st.volume;
        if (st.snoozeMin)
            out.settings.snooze = st.snoozeMin;
        if (st.ringSec)
            out.settings.silence = Math.max(1, Math.round(st.ringSec / 60));
        const w = s.window ?? {};
        if (w.x >= 0)
            out.win.x = w.x;
        if (w.y >= 0)
            out.win.y = w.y;
        if (w.tab)
            out.win.tab = w.tab === "alarms" ? "alarm" : w.tab;
    }
}
