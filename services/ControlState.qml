pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// The current state of Prism's controls, for programs outside the shell (Relay's
// phone page). Written to .state/controls.json (atomically) about 0.3 s after
// anything changes. Stable format: fields are only added; "version" goes up if
// a field ever changes meaning. Act on it with `qs ipc call ...` (see action_commands.md).
Singleton {
    id: root

    readonly property var state: ({
            version: 1,
            audio: {
                volume: Math.round(Audio.volume * 100), // %, can be above 100 when dragged there
                muted: Audio.muted,
                micVolume: Math.round(Audio.micVolume * 100),
                micMuted: Audio.micMuted
            },
            brightness: Brightness.available ? Math.round(Brightness.value * 100) : null, // null = no backlight
            media: Media.hasPlayer ? {
                player: Media.identity,
                title: Media.title,
                artist: Media.artist,
                playing: Media.playing
            } : null,
            toggles: {
                caffeine: Toggles.caffeine,
                dnd: Notifs.dnd,
                warm: Toggles.warm,
                gamemode: Toggles.gameMode,
                easyeffects: Toggles.easyEffects,
                glava: Toggles.glava
            },
            noise: Toggles.noise, // study noise: off | brown | pink | white
            powerProfile: Power.profileName, // Power saver | Balanced | Performance
            theme: Wallpapers.light ? "light" : "dark",
            recording: Toggles.recording ? { since: Toggles.recordStart } : null, // ms epoch
            focus: Focus.active ? {
                phase: Focus.phase, // work | break | longbreak
                paused: Focus.paused,
                endsAt: Focus.paused ? null : Focus.endsAt, // ms epoch
                leftMs: Focus.paused ? Focus.remainingMs : null,
                round: Focus.round
            } : null,
            // the clock app's own state (also in $XDG_RUNTIME_DIR/prism-clock.status.json)
            clock: Chrono.running ? {
                timer: Chrono.s.timer,
                stopwatch: Chrono.s.stopwatch,
                ringing: Chrono.s.ringing,
                nextAlarm: Chrono.s.nextAlarm
            } : null
        })

    onStateChanged: writeTimer.restart()
    Timer {
        id: writeTimer
        interval: 300
        onTriggered: {
            const s = Object.assign({}, root.state);
            s.ts = Date.now() / 1000;
            file.setText(JSON.stringify(s, null, 1));
        }
    }
    FileView {
        id: file
        path: Config.stateDir + "/controls.json"
        atomicWrites: true
        blockWrites: false
        preload: false
    }
    Component.onCompleted: writeTimer.restart()
}
