pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.common

// Small system toggles: caffeine, study noise, glava, game mode, screen
// recording, warm screen.
Singleton {
    id: root

    // ---- caffeine (the IdleInhibitor lives in the bar window) ----
    property bool caffeine: false
    function toggleCaffeine() {
        caffeine = !caffeine;
        Osd.show("toggle", caffeine ? "coffee" : "coffee_outline", caffeine ? "Caffeine on · staying awake" : "Caffeine off", -1);
    }

    // ---- study noise (ffplay, no window) ----
    readonly property var noiseKinds: ["off", "brown", "pink", "white"]
    property string noise: "off"
    property real noiseVolume: 0.35
    function cycleNoise() {
        const i = noiseKinds.indexOf(noise);
        setNoise(noiseKinds[(i + 1) % noiseKinds.length]);
    }
    function setNoise(kind) {
        noise = kind;
        Osd.show("toggle", kind === "off" ? "volume_off" : "waves", kind === "off" ? "Noise off" : Utils.capitalize(kind) + " noise", -1);
    }
    Process {
        running: root.noise !== "off"
        command: ["ffplay", "-nodisp", "-loglevel", "quiet", "-f", "lavfi", "-i", "anoisesrc=c=" + root.noise + ":a=" + root.noiseVolume.toFixed(2)]
    }

    // ---- EasyEffects: on = running in the background, off = fully killed ----
    // state comes from PipeWire (its virtual sink exists only while it runs)
    readonly property bool easyEffects: (Pipewire.nodes?.values ?? []).some(n => n?.name === "easyeffects_sink")
    function toggleEasyEffects() {
        if (easyEffects) {
            Quickshell.execDetached(["sh", "-c", "easyeffects -q; sleep 2; pkill -x easyeffects; pkill -f '^easyeffects'"]);
            Osd.show("toggle", "tune_variant", "EasyEffects off", -1);
        } else {
            Quickshell.execDetached(["sh", "-c", "setsid -f easyeffects -w >/dev/null 2>&1"]);
            Osd.show("toggle", "tune_variant", "EasyEffects on", -1);
        }
    }

    // ---- glava visualizer ----
    property bool glava: false
    function toggleGlava() {
        if (glava) {
            Quickshell.execDetached(["pkill", "glava"]);
            glava = false;
        } else {
            Quickshell.execDetached(["sh", "-c", "pkill glava; exec glava"]);
            glava = true;
        }
    }

    // ---- game mode: strip Hyprland eye-candy + pause ambient effects ----
    property bool gameMode: false
    onGameModeChanged: Motion.calm = gameMode
    function toggleGameMode() {
        gameMode = !gameMode;
        if (gameMode)
            Hypr.evalLua("hl.config({ animations = { enabled = false }, decoration = { shadow = { enabled = false }, blur = { enabled = false }, rounding = 0, dim_inactive = false }, general = { gaps_in = 0, gaps_out = 0, border_size = 1 } })");
        else
            Quickshell.execDetached(["hyprctl", "reload"]);
        Osd.show("toggle", "gamepad_variant", gameMode ? "Game mode on" : "Game mode off", -1);
    }

    // ---- warm screen (overlay tint; there is no hyprsunset here) ----
    property bool warm: false
    property real warmStrength: 0.16
    function toggleWarm() {
        warm = !warm;
        Osd.show("toggle", "weather_night", warm ? "Warm screen on" : "Warm screen off", -1);
    }

    // ---- screen recording (wf-recorder) ----
    property bool recording: false
    property bool recordAudio: false
    property string recordFile: ""
    property real recordStart: 0
    Process {
        id: rec
        onExited: code => {
            root.recording = false;
            Panels.capturing = false;
            if (root.recordFile !== "")
                Notifs.local("Recording saved", root.recordFile, "video", 1, "", [{ text: "Open folder", run: () => Quickshell.execDetached(["xdg-open", Config.paths.recordings]) }, { text: "Play", run: () => Quickshell.execDetached(["xdg-open", root.recordFile]) }]);
        }
    }
    // mode: true/"region" | false/"full" | "window"
    function startRecording(mode) {
        if (recording)
            return;
        if (mode === true)
            mode = "region";
        else if (mode === false || mode === undefined)
            mode = "full";
        Panels.closeAll();
        const ts = Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss");
        recordFile = Config.paths.recordings + "/recording_" + ts + ".mp4";
        const audio = recordAudio ? " --audio" : "";
        let geo = "";
        if (mode === "region")
            geo = "g=$(slurp) || exit 1; ";
        else if (mode === "window")
            geo = "g=$(hyprctl activewindow -j | jq -r '\"\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])\"'); ";
        const mon = Hypr.focusedWorkspace?.monitor?.name ?? "";
        const g = mode === "full" ? (mon !== "" ? " -o \"$2\"" : "") : " -g \"$g\"";
        if (mode === "region")
            Panels.capturing = true;
        rec.command = ["setsid", "-w", "sh", "-c", "mkdir -p \"$(dirname \"$1\")\"; sleep 0.4; " + geo + "touch \"$1.started\"; exec wf-recorder" + audio + g + " -f \"$1\"", "rec", recordFile, mon];
        rec.running = true;
        recording = true;
        recordStart = Date.now();
        unhide.restart();
    }
    // slurp is done once the selection exists; bring the shell back after a moment
    Timer {
        id: unhide
        interval: 1200
        repeat: true
        onTriggered: {
            if (!root.recording) {
                Panels.capturing = false;
                stop();
            } else {
                startedCheck.running = true;
            }
        }
    }
    Process {
        id: startedCheck
        command: ["sh", "-c", "[ -e \"$1.started\" ] && rm -f \"$1.started\"", "c", root.recordFile]
        onExited: code => {
            if (code === 0) {
                Panels.capturing = false;
                unhide.stop();
                root.recordStart = Date.now();
            }
        }
    }
    function stopRecording() {
        // wf-recorder runs under setsid, so signal it directly (SIGINT finalises the file)
        Quickshell.execDetached(["pkill", "-INT", "-x", "wf-recorder"]);
    }
    function toggleRecording() {
        if (recording)
            stopRecording();
        else
            Panels.show("record");
    }

    Process {
        running: true
        command: ["pgrep", "-x", "glava"]
        onExited: code => root.glava = code === 0
    }
}
