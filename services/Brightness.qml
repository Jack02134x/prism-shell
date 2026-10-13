pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Backlight via sysfs (read) + brightnessctl (write). Changes made elsewhere
// are picked up by a light 1 s poll so the OSD shows for them too.
Singleton {
    id: root

    property string device: ""
    property int max: 1
    property int raw: 0
    readonly property real value: max > 0 ? raw / max : 0
    readonly property bool available: device !== ""
    readonly property string icon: value > 0.66 ? "brightness_7" : value > 0.33 ? "brightness_6" : "brightness_5"

    property bool ownChange: false

    function set(v) {
        v = Utils.clamp(v, 0.01, 1);
        raw = Math.round(v * max);
        ownChange = true;
        Quickshell.execDetached(["brightnessctl", "-q", "set", Math.round(v * 100) + "%"]);
        Osd.show("brightness", icon, "Brightness", value);
    }
    function nudge(d) {
        set(value + d);
    }

    Process {
        running: true
        command: ["sh", "-c", "d=$(ls /sys/class/backlight | head -n1); [ -n \"$d\" ] && echo \"$d $(cat /sys/class/backlight/$d/max_brightness)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(" ");
                if (p.length === 2) {
                    root.max = parseInt(p[1]) || 1;
                    root.device = p[0];
                }
            }
        }
    }

    FileView {
        id: file
        path: root.device !== "" ? "/sys/class/backlight/" + root.device + "/brightness" : ""
        onLoaded: {
            const v = parseInt(text());
            if (isNaN(v) || v === root.raw)
                return;
            const external = !root.ownChange;
            root.raw = v;
            if (external)
                Osd.show("brightness", root.icon, "Brightness", root.value);
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.available
        onTriggered: {
            root.ownChange = false;
            file.reload();
        }
    }
}
