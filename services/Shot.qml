pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Screenshots with grim/slurp, region / window / screen modes, with
// a delay option and a preview notification afterwards.
Singleton {
    id: root

    property bool busy: false
    property string lastFile: ""

    // mode: region | window | full    action: copy | save | both
    function capture(mode, action, delay) {
        if (busy)
            return;
        Panels.closeAll();
        Panels.capturing = true;
        busy = true;
        const ts = Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss");
        const save = action !== "copy";
        const file = save ? Config.paths.screenshots + "/screenshot_" + ts + ".png" : Config.cacheDir + "/last-shot.png";
        lastFile = file;
        const mon = Hypr.focusedWorkspace?.monitor?.name ?? "";
        const geo = mode === "region" ? "g=$(slurp) || exit 1; " : mode === "window" ? "g=$(hyprctl activewindow -j | jq -r '\"\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])\"'); " : "g=''; ";
        const grim = mode === "full" ? "grim " + (mon !== "" ? "-o \"$3\" " : "") + "\"$1\"" : "grim -g \"$g\" \"$1\"";
        const copy = action !== "save" ? " && wl-copy < \"$1\"" : "";
        // setsid: grim/slurp run in their own session, fully detached from the shell
        proc.command = ["setsid", "-w", "sh", "-c", "mkdir -p \"$(dirname \"$1\")\"; sleep \"$2\"; " + geo + grim + copy, "shot", file, String(0.5 + (delay ?? 0)), mon];
        proc.action = action;
        proc.running = true;
    }

    Process {
        id: proc
        property string action: "both"
        onExited: code => {
            root.busy = false;
            Panels.capturing = false;
            if (code !== 0)
                return;
            const f = root.lastFile;
            const saved = action !== "copy";
            Notifs.local(saved ? "Screenshot saved" : "Screenshot copied", saved ? f.replace(Config.home, "~") : "In your clipboard", "monitor_screenshot", 1, "file://" + f, saved ? [
                { text: "Open", run: () => Quickshell.execDetached(["xdg-open", f]) },
                { text: "Folder", run: () => Quickshell.execDetached(["xdg-open", Config.paths.screenshots]) },
                { text: "Copy", run: () => Quickshell.execDetached(["sh", "-c", "wl-copy < \"$1\"", "c", f]) }
            ] : []);
        }
    }

    function pickColor() {
        Panels.closeAll();
        Panels.capturing = true;
        if (!picker.running)
            picker.running = true;
    }

    Process {
        id: picker
        command: ["setsid", "-w", "sh", "-c", "sleep 0.5; hyprpicker -a -f hex"]
        onExited: Panels.capturing = false
        stdout: StdioCollector {
            onStreamFinished: {
                const hex = text.trim();
                if (/^#[0-9a-fA-F]{6}/.test(hex))
                    Notifs.local("Colour copied", hex, "eyedropper", 1, "", [{ text: "Copy rgb()", run: () => {
                                const v = parseInt(hex.slice(1, 7), 16);
                                Quickshell.execDetached(["wl-copy", "rgb(" + ((v >> 16) & 255) + ", " + ((v >> 8) & 255) + ", " + (v & 255) + ")"]);
                            } }]);
            }
        }
    }
}
