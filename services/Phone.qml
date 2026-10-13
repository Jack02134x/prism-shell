pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// KDE Connect: first reachable device, its battery, and a few actions.
Singleton {
    id: root

    property string deviceId: ""
    property string name: ""
    property bool reachable: false
    property int battery: -1
    property bool charging: false

    readonly property bool available: deviceId !== ""

    Process {
        id: listProc
        command: ["kdeconnect-cli", "-a", "--id-name-only"]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim().split("\n")[0] ?? "";
                const i = line.indexOf(" ");
                if (i > 0) {
                    root.deviceId = line.slice(0, i);
                    root.name = line.slice(i + 1).trim();
                    root.reachable = true;
                    batProc.running = true;
                } else {
                    root.reachable = false;
                }
            }
        }
    }

    Process {
        id: batProc
        command: ["busctl", "--user", "get-property", "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + root.deviceId + "/battery", "org.kde.kdeconnect.device.battery", "charge", "isCharging"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n");
                const c = parseInt((l[0] ?? "").replace(/^i\s+/, ""));
                root.battery = isNaN(c) ? -1 : c;
                root.charging = (l[1] ?? "").includes("true");
            }
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: if (!listProc.running) listProc.running = true
    }

    function ring() {
        if (available)
            Quickshell.execDetached(["kdeconnect-cli", "-d", deviceId, "--ring"]);
    }
    function ping() {
        if (available)
            Quickshell.execDetached(["kdeconnect-cli", "-d", deviceId, "--ping-msg", "👋 from Prism"]);
    }
    function sendClipboard() {
        if (available)
            Quickshell.execDetached(["sh", "-c", "kdeconnect-cli -d \"$1\" --share-text \"$(wl-paste -n)\"", "kc", deviceId]);
    }
    function sendFile() {
        if (available)
            Quickshell.execDetached(["sh", "-c", "f=$(zenity --file-selection --title='Send to phone') && kdeconnect-cli -d \"$1\" --share \"$f\"", "kc", deviceId]);
    }
}
