pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Prism's side of the clock. The clock itself is a Python app
// (apps/prism-clock): it keeps time, rings alarms and owns its window. Prism
// sends it commands and reads its status file for the bar button and drawer.
Singleton {
    id: root

    readonly property string app: Config.shellDir + "/apps/prism-clock/prism_clock.py"
    readonly property string statusPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/prism-clock.status.json"

    // the app's status (see apps/prism-clock/prismclock/core.py write_status)
    property var s: ({})
    readonly property bool loaded: true
    readonly property bool running: s.pid !== undefined
    readonly property bool open: s.visible ?? false
    readonly property bool timerRunning: s.timer?.running ?? false
    readonly property bool timerPaused: s.timer?.paused ?? false
    readonly property bool swRunning: s.stopwatch?.running ?? false
    readonly property var ringing: s.ringing ?? null

    property real now: Date.now()
    readonly property real timerLeft: timerRunning ? Math.max(0, s.timer.endsAt - now) : (s.timer?.left ?? 0)
    readonly property real swElapsed: (s.stopwatch?.banked ?? 0) + (swRunning ? now - s.stopwatch.startedAt : 0)
    readonly property var nextAlarm: s.nextAlarm ? { alarm: { label: s.nextAlarm.label }, inMs: Math.max(0, s.nextAlarm.at - now) } : null

    Timer {
        interval: 1000
        repeat: true
        running: root.timerRunning || root.swRunning || root.nextAlarm !== null
        onTriggered: root.now = Date.now()
    }

    FileView {
        id: status
        path: root.statusPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.s = JSON.parse(text());
                root.now = Date.now();
            } catch (e) {}
        }
        onLoadFailed: root.s = ({})
    }
    // the app replaces the file atomically; re-read now and then in case a watch was lost
    Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: status.reload()
    }

    // ---- commands ----
    function cmd(c) {
        Quickshell.execDetached(["python3", root.app].concat(c.split(" ")));
    }
    function toggle() {
        cmd("toggle");
    }
    function show(tab) {
        cmd("show" + (tab ? " " + tab : ""));
    }
    function hide() {
        cmd("hide");
    }
    function timer(minutes) {
        cmd("timer " + minutes);
    }
    function stopwatch() {
        cmd("stopwatch");
    }
    function stopRinging() {
        cmd("stop");
    }
    function snooze() {
        cmd("snooze");
    }

    // alarms need the app running: start it (hidden) if it isn't. "daemon" is a
    // no-op for a running app, so a periodic nudge also restarts it after a crash.
    Timer {
        interval: 60000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.cmd("daemon")
    }
}
