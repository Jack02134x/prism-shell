pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Reads <Config.paths.screentime>/usage.json (written by tracker.py)
// and the live status file in $XDG_RUNTIME_DIR. Read-only.
Singleton {
    id: root

    property bool available: false
    property var data: ({})
    property real today: 0
    property var apps: []        // [{ name, total, details: [{ name, total }] }]
    property var hours: new Array(24).fill(0)
    property var week: []        // [{ date, label, total }]
    property real weekAvg: 0
    property string liveApp: ""
    property string liveDetail: ""
    property string liveState: ""
    // app -> accent slot, shared with the tracker's own GUI so both colour apps alike:
    // rank apps by all-time seconds (days + audio), give the top 8 their hashed slot
    // and step to the next free slot on a clash; everyone else is "Other"
    property var slots: ({})

    readonly property string usagePath: Config.loaded && Config.paths.screentime !== "" ? Config.paths.screentime + "/usage.json" : ""
    readonly property string statusPath: Quickshell.env("XDG_RUNTIME_DIR") + "/hypr-screentime.status.json"

    function dayKey(d) {
        return Qt.formatDate(d, "yyyy-MM-dd");
    }

    // one day's {app: {detail: {hour: seconds}}}, focused time plus background
    // audio time (the `audio` tree has the same layout; old files lack it)
    function dayTree(key) {
        const out = {};
        for (const tree of [data.days ?? {}, data.audio ?? {}]) {
            const d = tree[key] ?? {};
            for (const app in d)
                for (const detail in d[app])
                    for (const h in d[app][detail]) {
                        out[app] = out[app] ?? {};
                        out[app][detail] = out[app][detail] ?? {};
                        out[app][detail][h] = (out[app][detail][h] ?? 0) + d[app][detail][h];
                    }
        }
        return out;
    }

    function hashSlot(name) {
        let h = 0;
        for (let i = 0; i < name.length; i++)
            h = (h * 31 + name.charCodeAt(i)) | 0;
        return Math.abs(h) % 10;
    }
    function computeSlots() {
        const totals = {};
        for (const tree of [data.days ?? {}, data.audio ?? {}])
            for (const day in tree)
                for (const app in tree[day])
                    for (const detail in tree[day][app])
                        for (const h in tree[day][app][detail])
                            totals[app] = (totals[app] ?? 0) + tree[day][app][detail][h];
        const ranked = Object.keys(totals).sort((a, b) => totals[b] - totals[a]).slice(0, 8);
        const taken = new Array(10).fill(false);
        const out = {};
        for (const app of ranked) {
            let s = hashSlot(app);
            while (taken[s])
                s = (s + 1) % 10;
            taken[s] = true;
            out[app] = s;
        }
        slots = out;
    }
    // colour for an app; apps outside the top 8 get the neutral "Other" colour
    function colorFor(app) {
        const s = slots[app];
        return s === undefined ? Theme.outline : Theme.accent(s);
    }

    function compute() {
        computeSlots();
        const key = dayKey(new Date());
        const d = dayTree(key);
        const hrs = new Array(24).fill(0);
        const list = [];
        let total = 0;
        for (const app in d) {
            let at = 0;
            const det = [];
            for (const detail in d[app]) {
                let dt = 0;
                const hmap = d[app][detail];
                for (const h in hmap) {
                    dt += hmap[h];
                    hrs[parseInt(h)] += hmap[h];
                }
                at += dt;
                det.push({ name: detail === "" ? app : detail, total: dt });
            }
            det.sort((a, b) => b.total - a.total);
            list.push({ name: app, total: at, details: det.slice(0, 4) });
            total += at;
        }
        list.sort((a, b) => b.total - a.total);
        apps = list;
        hours = hrs;
        today = total;

        const wk = [];
        let sum = 0, n = 0;
        for (let i = 6; i >= 0; i--) {
            const dt = new Date();
            dt.setDate(dt.getDate() - i);
            const k = dayKey(dt);
            let t = 0;
            const dd = dayTree(k);
            for (const app in dd)
                for (const det in dd[app])
                    for (const h in dd[app][det])
                        t += dd[app][det][h];
            wk.push({ date: k, label: i === 0 ? "Today" : Qt.formatDate(dt, "ddd"), total: t });
            if (t > 0) {
                sum += t;
                n++;
            }
        }
        week = wk;
        weekAvg = n > 0 ? sum / n : 0;
    }

    FileView {
        id: usage
        path: root.usagePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.data = JSON.parse(text());
                root.available = true;
                root.compute();
            } catch (e) {}
        }
        onLoadFailed: root.available = false
    }

    FileView {
        id: status
        path: root.statusPath
        onLoaded: {
            try {
                const s = JSON.parse(text());
                // the tracker rewrites this at least every 5 s; older than 20 s means it's gone
                const fresh = s.ts !== undefined && Date.now() / 1000 - s.ts < 20;
                root.liveApp = fresh ? (s.app ?? "") : "";
                root.liveDetail = fresh ? (s.detail ?? "") : "";
                root.liveState = fresh ? (s.state ?? "") : "";
            } catch (e) {}
        }
        // deleted when Hyprland goes away
        onLoadFailed: {
            root.liveApp = "";
            root.liveDetail = "";
            root.liveState = "";
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: status.reload()
    }

    // recompute at midnight / periodically so "today" rolls over
    Timer {
        interval: 60000
        repeat: true
        running: root.available
        onTriggered: root.compute()
    }

    function openGui() {
        Quickshell.execDetached(["python3", Config.paths.screentime + "/gui.py"]);
    }
}
