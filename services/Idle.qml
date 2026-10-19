pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import qs.common

// Prism's idle manager (does what hypridle did): dim -> lock -> screens off ->
// suspend after the times in Config.idle. Like the screen-time tracker, it only
// calls the machine idle when it truly is: playing media counts as being in use,
// and so do caffeine and apps holding an idle inhibitor (fullscreen video).
// Also locks before the system sleeps and answers `loginctl lock-session`.
// Steps aside while hypridle is running, so the two never fight.
Singleton {
    id: root

    property bool hypridleRunning: false
    readonly property bool mediaPlaying: Mpris.players.values.some(p => p.isPlaying)
    // in use even without keyboard / mouse input
    readonly property bool busy: Toggles.caffeine || (Config.idle.mediaKeepsAwake && mediaPlaying)
    readonly property bool active: Config.idle.enabled && !hypridleRunning
    readonly property bool counting: active && !busy

    property bool dimmed: false
    property bool screensOff: false
    property real savedBrightness: 1

    // ---- stages ----
    // Quickshell's IdleMonitor reads `timeout` only when it registers, so each stage
    // is (re)created through Variants whenever its time changes or counting
    // pauses/resumes: the model is [seconds] while active, [] while off.
    function stage(seconds, on) {
        return root.counting && on && seconds > 0 ? [seconds] : [];
    }
    Variants {
        model: root.stage(Config.idle.dimAfter, Brightness.available)
        IdleMonitor {
            required property var modelData
            timeout: modelData
            onIsIdleChanged: isIdle ? root.dim() : root.undim()
        }
    }
    Variants {
        model: root.stage(Config.idle.lockAfter, true)
        IdleMonitor {
            required property var modelData
            timeout: modelData
            onIsIdleChanged: if (isIdle) Session.lock()
        }
    }
    Variants {
        model: root.stage(Config.idle.screenOffAfter, true)
        IdleMonitor {
            required property var modelData
            timeout: modelData
            onIsIdleChanged: root.screens(!isIdle)
        }
    }
    Variants {
        model: root.stage(Config.idle.suspendAfter, true)
        IdleMonitor {
            required property var modelData
            timeout: modelData
            onIsIdleChanged: if (isIdle) Session.suspend()
        }
    }

    // media started, caffeine on, or the manager was switched off: undo everything
    onCountingChanged: if (!counting) root.wake()

    function dim() {
        if (dimmed || !Brightness.available)
            return;
        const to = Config.idle.dimTo / 100;
        if (Brightness.value <= to)
            return;
        savedBrightness = Brightness.value;
        dimmed = true;
        Brightness.quiet = true;
        Quickshell.execDetached(["brightnessctl", "-q", "set", Config.idle.dimTo + "%"]);
    }
    function undim() {
        if (!dimmed)
            return;
        dimmed = false;
        Quickshell.execDetached(["brightnessctl", "-q", "set", Math.round(savedBrightness * 100) + "%"]);
        quietOff.restart();
    }
    function screens(on) {
        if (on === !screensOff)
            return;
        screensOff = !on;
        // through hyprctl so it still runs while the shell is reloading
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.dpms({ action = \"" + (on ? "enable" : "disable") + "\" })"]);
    }
    function wake() {
        undim();
        screens(true);
    }

    Timer {
        id: quietOff
        interval: 2500
        onTriggered: Brightness.quiet = false
    }

    // never leave the screen dark or dimmed behind a reload / quit
    Component.onDestruction: wake()

    // ---- hypridle still around? then it's in charge ----
    Process {
        id: hypridleCheck
        command: ["pgrep", "-x", "hypridle"]
        onExited: code => root.hypridleRunning = code === 0
    }
    Timer {
        interval: 15000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: hypridleCheck.running = true
    }

    // ---- logind: lock before sleep, `loginctl lock-session`, wake-up ----
    function busEscape(s) {
        let out = "";
        for (let i = 0; i < s.length; i++) {
            const c = s[i];
            if (/[A-Za-z]/.test(c) || (/[0-9]/.test(c) && i > 0))
                out += c;
            else
                out += "_" + c.charCodeAt(0).toString(16).padStart(2, "0");
        }
        return out;
    }
    readonly property string sessionPath: "/org/freedesktop/login1/session/" + busEscape(Quickshell.env("XDG_SESSION_ID") ?? "")

    function onLogind(line) {
        if (line.includes(".Manager.PrepareForSleep (true")) {
            if (Config.idle.lockBeforeSleep)
                Session.lock();
            // give the lock surface a moment, then let the system sleep
            releaseSleep.restart();
        } else if (line.includes(".Manager.PrepareForSleep (false")) {
            holdSleep = true;
            root.wake();
        } else if (line.startsWith(sessionPath + ":") && line.includes(".Session.Lock ")) {
            Session.lock();
        } else if (line.startsWith(sessionPath + ":") && line.includes(".Session.Unlock ")) {
            Session.locked = false;
        }
    }

    Process {
        id: logind
        running: root.active
        // exits with the shell: a restarted shell used to leave these behind
        command: ["sh", "-c", "qs=$PPID; gdbus monitor --system --dest org.freedesktop.login1 & g=$!; trap 'kill $g 2>/dev/null' EXIT TERM INT; while kill -0 $qs 2>/dev/null && kill -0 $g 2>/dev/null; do sleep 10 & wait $!; done"]
        stdout: SplitParser {
            onRead: line => root.onLogind(line)
        }
        onExited: if (root.active) relaunch.restart()
    }
    Timer {
        id: relaunch
        interval: 3000
        onTriggered: logind.running = root.active
    }

    // a sleep "delay" lock: logind waits (up to a few seconds) for us to lock first
    property bool holdSleep: true
    Process {
        running: root.active && Config.idle.lockBeforeSleep && root.holdSleep
        // held until released, or until the shell itself goes away
        command: ["sh", "-c", "qs=$PPID; exec systemd-inhibit --what=sleep --mode=delay --who=Prism '--why=Lock the screen before sleeping' sh -c \"while kill -0 $qs 2>/dev/null; do sleep 10; done\""]
    }
    Timer {
        id: releaseSleep
        interval: 700
        onTriggered: root.holdSleep = false
    }
}
