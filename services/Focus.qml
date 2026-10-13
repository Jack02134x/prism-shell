pragma Singleton

import QtQuick
import Quickshell
import qs.common

// Pomodoro focus timer. Work → short break → … → long break every 4th round.
// Optionally plays study noise during work sessions and silences popups.
Singleton {
    id: root

    property string phase: "idle"     // idle | work | break | longbreak
    property bool paused: false
    property int round: 0             // completed work sessions
    property real endsAt: 0           // ms epoch
    property real remainingMs: 0      // while paused
    property real totalMs: 1

    readonly property bool active: phase !== "idle"
    readonly property bool working: phase === "work"
    readonly property int workMin: Config.focus.workMinutes
    readonly property int breakMin: Config.focus.breakMinutes
    readonly property int longBreakMin: Config.focus.longBreakMinutes

    property real now: Date.now()
    readonly property real left: !active ? 0 : paused ? remainingMs : Math.max(0, endsAt - now)
    readonly property real progress: active ? 1 - left / totalMs : 0
    readonly property string leftText: Utils.mmss(left / 1000)
    readonly property string label: phase === "work" ? "Focus" : phase === "break" ? "Break" : phase === "longbreak" ? "Long break" : "Focus"
    readonly property color tint: phase === "work" ? Theme.accent(0) : Theme.accent(4)

    property string noiseBefore: "off"
    property bool dndBefore: false

    function startPhase(p) {
        const min = p === "work" ? workMin : p === "break" ? breakMin : longBreakMin;
        phase = p;
        paused = false;
        totalMs = min * 60000;
        endsAt = Date.now() + totalMs;
        now = Date.now();
        if (p === "work") {
            if (Config.focus.noise !== "off")
                Toggles.noise = Config.focus.noise;
            if (Config.focus.silence)
                Notifs.dnd = true;
        } else {
            if (Config.focus.noise !== "off")
                Toggles.noise = "off";
            if (Config.focus.silence)
                Notifs.dnd = dndBefore;
        }
        Osd.show("toggle", p === "work" ? "timer_outline" : "coffee", label + " · " + min + " min", -1);
    }

    function start() {
        if (active)
            return;
        noiseBefore = Toggles.noise;
        dndBefore = Notifs.dnd;
        round = 0;
        startPhase("work");
    }
    function stop() {
        if (!active)
            return;
        phase = "idle";
        paused = false;
        Toggles.noise = noiseBefore;
        Notifs.dnd = dndBefore;
        Osd.show("toggle", "timer_off_outline", "Focus stopped", -1);
    }
    function toggle() {
        if (active)
            stop();
        else
            start();
    }
    function pause() {
        if (!active)
            return;
        if (paused) {
            endsAt = Date.now() + remainingMs;
            paused = false;
        } else {
            remainingMs = Math.max(0, endsAt - Date.now());
            paused = true;
        }
    }
    function skip() {
        if (active)
            finish();
    }

    function finish() {
        if (phase === "work") {
            round++;
            const longOne = round % 4 === 0;
            const nb = Notifs.dnd;
            Notifs.dnd = false; // always let the timer itself through
            Notifs.local(longOne ? "Long break time ☕" : "Break time", "Round " + round + " done. " + (longOne ? longBreakMin : breakMin) + " minutes off — stand up, drink water.", "coffee", 1, "", [{ text: "Skip break", run: () => root.startPhase("work") }, { text: "Stop", run: () => root.stop() }]);
            startPhase(longOne ? "longbreak" : "break");
            if (!Config.focus.silence)
                Notifs.dnd = nb;
        } else {
            Notifs.local("Back to focus", "Round " + (round + 1) + " · " + workMin + " minutes", "timer_outline", 1, "", [{ text: "Stop", run: () => root.stop() }]);
            startPhase("work");
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.active && !root.paused
        onTriggered: {
            root.now = Date.now();
            if (root.endsAt - root.now <= 0)
                root.finish();
        }
    }
}
