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

    readonly property string usagePath: Config.loaded && Config.paths.screentime !== "" ? Config.paths.screentime + "/usage.json" : ""
    readonly property string statusPath: Quickshell.env("XDG_RUNTIME_DIR") + "/hypr-screentime.status.json"

    function dayKey(d) {
        return Qt.formatDate(d, "yyyy-MM-dd");
    }

    function compute() {
        const days = data.days ?? {};
        const key = dayKey(new Date());
        const d = days[key] ?? {};
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
            const dd = days[k] ?? {};
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
                root.liveApp = s.app ?? "";
                root.liveDetail = s.detail ?? "";
                root.liveState = s.state ?? "";
            } catch (e) {}
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
