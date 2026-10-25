pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Screenshots without grim / slurp: modules/screenshot/ThreadShot.qml freezes
// the screen (ScreencopyView), you pick a region / window on the still frame,
// and it hands back the frame as a PNG plus the crop. This crops, saves, copies
// and notifies.
Singleton {
    id: root

    // the overlay is up (it calls finish() once its closing animation is done)
    property bool active: false
    property var screen: null
    property string mode: "region" // region | window | full
    property string action: "both" // copy | save | both
    property bool busy: false
    property string lastFile: ""

    function capture(mode, action, delay) {
        if (active || busy || opener.running)
            return;
        const wasOpen = Panels.anyOpen;
        Panels.closeAll();
        root.mode = mode;
        root.action = action;
        // let closing panels animate out first: the frame is taken as it looks
        opener.interval = (wasOpen ? 450 : 30) + (delay ?? 0) * 1000;
        opener.start();
    }

    Timer {
        id: opener
        onTriggered: {
            Hypr.refresh();
            root.screen = Panels.focusedScreen;
            root.active = true;
        }
    }

    function finish() {
        active = false;
    }

    // Esc from outside (qs ipc call screenshot cancel); the overlay animates out
    signal cancelRequested
    function cancel() {
        opener.stop();
        if (active)
            cancelRequested();
    }

    // frame: the whole frozen screen as a PNG; crop: "WxH+X+Y" in its pixels ("" = all of it)
    function save(frame, crop) {
        busy = true;
        const ts = Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss");
        const keep = action !== "copy";
        const file = keep ? Config.paths.screenshots + "/screenshot_" + ts + ".png" : Config.cacheDir + "/last-shot.png";
        lastFile = file;
        const out = crop !== "" ? "magick \"$1\" -crop \"$3\" +repage \"$2\" && rm -f \"$1\"" : "mv -f \"$1\" \"$2\"";
        const copy = action !== "save" ? " && wl-copy --type image/png < \"$2\"" : "";
        writer.command = ["sh", "-c", "mkdir -p \"$(dirname \"$2\")\" && " + out + copy, "shot", frame, file, crop];
        writer.running = true;
    }

    Process {
        id: writer
        onExited: code => {
            root.busy = false;
            if (code !== 0) {
                Notifs.local("Screenshot failed", "Couldn't write " + root.lastFile.replace(Config.home, "~"), "monitor_screenshot", 2, "", []);
                return;
            }
            const f = root.lastFile;
            const saved = root.action !== "copy";
            Notifs.local(saved ? "Screenshot saved" : "Screenshot copied", saved ? f.replace(Config.home, "~") : "In your clipboard", "monitor_screenshot", 1, "file://" + f, saved ? [
                { text: "Open", run: () => Quickshell.execDetached(["xdg-open", f]) },
                { text: "Folder", run: () => Quickshell.execDetached(["xdg-open", Config.paths.screenshots]) },
                { text: "Copy", run: () => Quickshell.execDetached(["sh", "-c", "wl-copy --type image/png < \"$1\"", "c", f]) }
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
