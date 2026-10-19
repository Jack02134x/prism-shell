import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.services

// `qs ipc call <target> <function> [args]` — see README.md for the full list.
Scope {
    IpcHandler {
        target: "launcher"
        function toggle(): void {
            Panels.toggle("launcher");
        }
        function open(): void {
            Panels.openLauncher("");
        }
        function close(): void {
            Panels.launcher = false;
        }
        function search(query: string): void {
            Panels.openLauncher(query);
        }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void {
            if (Panels.launcher)
                Panels.launcher = false;
            else
                Panels.openLauncher(">");
        }
    }

    IpcHandler {
        target: "emoji"
        function toggle(): void {
            if (Panels.launcher)
                Panels.launcher = false;
            else
                Panels.openLauncher(":");
        }
    }

    IpcHandler {
        target: "dashboard"
        function toggle(): void {
            Panels.toggle("dashboard");
        }
        // home media system screentime network audio settings
        function tab(name: string): void {
            const tabs = ["home", "media", "system", "screentime", "network", "audio", "settings"];
            const i = tabs.indexOf(name);
            Panels.openDashboard(i < 0 ? 0 : i);
        }
    }

    IpcHandler {
        target: "sidebar"
        function toggle(): void {
            Panels.toggle("sidebar");
        }
    }

    IpcHandler {
        target: "controls"
        function toggle(): void {
            Panels.toggle("controls");
        }
    }

    IpcHandler {
        target: "edit"
        function toggle(): void {
            Panels.toggle("edit");
        }
    }

    IpcHandler {
        target: "switcher"
        function toggle(): void {
            Panels.toggle("switcher");
        }
    }

    // the clock is a Python app (apps/prism-clock); these just forward to it
    IpcHandler {
        target: "clock"
        function toggle(): void {
            Chrono.toggle();
        }
        function open(): void {
            Chrono.show("");
        }
        function close(): void {
            Chrono.hide();
        }
        // clock | timer | stopwatch | alarms | settings
        function tab(name: string): void {
            Chrono.show(name);
        }
        // start a timer, e.g. `qs ipc call clock timer 25`
        function timer(minutes: int): void {
            Chrono.timer(minutes);
            Osd.show("toggle", "timer_sand", "Timer · " + minutes + " min", -1);
        }
        function stopwatch(): void {
            Chrono.stopwatch();
        }
        // stop whatever is ringing
        function stop(): void {
            Chrono.stopRinging();
        }
        function snooze(): void {
            Chrono.snooze();
        }
    }

    IpcHandler {
        target: "focus"
        function toggle(): void {
            Focus.toggle();
        }
        function pause(): void {
            Focus.pause();
        }
        function skip(): void {
            Focus.skip();
        }
    }

    IpcHandler {
        target: "theme"
        function toggle(): void {
            Wallpapers.toggleMode();
        }
        function light(): void {
            Wallpapers.setMode("light");
        }
        function dark(): void {
            Wallpapers.setMode("dark");
        }
    }

    IpcHandler {
        target: "overview"
        function toggle(): void {
            Panels.toggle("overview");
        }
    }

    IpcHandler {
        target: "power"
        function toggle(): void {
            Panels.toggle("power");
        }
    }

    IpcHandler {
        target: "cheatsheet"
        function toggle(): void {
            Panels.toggle("cheatsheet");
        }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void {
            Panels.toggle("wallpapers");
        }
        function random(): void {
            Wallpapers.random();
        }
        function set(path: string): void {
            Wallpapers.apply(path);
        }
    }

    IpcHandler {
        target: "screenshot"
        function menu(): void {
            Panels.toggle("screenshot");
        }
        function region(): void {
            Shot.capture("region", "both", 0);
        }
        function window(): void {
            Shot.capture("window", "both", 0);
        }
        function full(): void {
            Shot.capture("full", "both", 0);
        }
    }

    IpcHandler {
        target: "record"
        function menu(): void {
            Panels.toggle("record");
        }
        function toggle(): void {
            Toggles.toggleRecording();
        }
        function region(): void {
            Toggles.startRecording("region");
        }
        function window(): void {
            Toggles.startRecording("window");
        }
        function full(): void {
            Toggles.startRecording("full");
        }
        function stop(): void {
            Toggles.stopRecording();
        }
    }

    IpcHandler {
        target: "osd"
        function volumeUp(): void {
            Audio.nudge(0.05);
        }
        function volumeDown(): void {
            Audio.nudge(-0.05);
        }
        function mute(): void {
            Audio.toggleMute();
        }
        function micMute(): void {
            Audio.toggleMic();
        }
        function brightnessUp(): void {
            Brightness.nudge(0.05);
        }
        function brightnessDown(): void {
            Brightness.nudge(-0.05);
        }
        // absolute levels in percent, e.g. from a slider on the phone (volume stops at 100)
        function setVolume(percent: int): void {
            Audio.setVolume(Utils.clamp(percent, 0, 100) / 100);
        }
        function setBrightness(percent: int): void {
            if (Brightness.available)
                Brightness.set(Utils.clamp(percent, 1, 100) / 100);
        }
    }

    IpcHandler {
        target: "media"
        function playPause(): void {
            Media.toggle();
        }
        function next(): void {
            Media.next();
        }
        function previous(): void {
            Media.previous();
        }
        // read-only: what's playing and whether the visualizer feed (cava) runs
        function status(): string {
            return JSON.stringify({
                player: Media.identity,
                playing: Media.playing,
                players: Media.players.map(p => p.identity + (p.isPlaying ? " (playing)" : "")),
                cava: { active: Cava.active, consumers: Cava.consumers, hifi: Cava.hifiConsumers, frame: Cava.frame, bass: Math.round(Cava.bass * 1000) / 1000, level: Math.round(Cava.level * 1000) / 1000 }
            });
        }
    }

    IpcHandler {
        target: "toggle"
        function caffeine(): void {
            Toggles.toggleCaffeine();
        }
        function dnd(): void {
            Notifs.dnd = !Notifs.dnd;
        }
        function noise(): void {
            Toggles.cycleNoise();
        }
        function gamemode(): void {
            Toggles.toggleGameMode();
        }
        function warm(): void {
            Toggles.toggleWarm();
        }
        function easyeffects(): void {
            Toggles.toggleEasyEffects();
        }
        function glava(): void {
            Toggles.toggleGlava();
        }
        function profile(): void {
            Power.cycleProfile();
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void {
            Session.lock();
        }
        function preview(): void {
            Session.preview = !Session.preview;
        }
        // what the shell thinks about locking and idling (read-only, for debugging)
        function status(): string {
            return JSON.stringify({
                locked: Session.locked,
                prismLock: Config.lock.enabled,
                idle: { active: Idle.active, counting: Idle.counting, busy: Idle.busy, hypridle: Idle.hypridleRunning, dimmed: Idle.dimmed, screensOff: Idle.screensOff },
                times: { dim: Config.idle.dimAfter, lock: Config.idle.lockAfter, off: Config.idle.screenOffAfter }
            });
        }
    }

    IpcHandler {
        target: "notify"
        function test(): void {
            Notifs.local("Hello from Prism ✨", "This is a <b>test</b> notification with an action.", "creation", 1, "", [{ text: "Open dashboard", run: () => Panels.openDashboard(0) }, { text: "Nice", run: () => {} }]);
        }
        function critical(): void {
            Notifs.local("Critical test", "Critical notifications stay until dismissed.", "alert", 2);
        }
        function clear(): void {
            Notifs.clear();
        }
    }
}
