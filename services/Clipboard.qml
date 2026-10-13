pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// cliphist front-end. Image entries are decoded into .cache/clip for previews.
Singleton {
    id: root

    property var entries: []    // [{ id, text, image, line }]
    property bool loading: false
    property int previewVersion: 0
    readonly property string clipDir: Config.cacheDir + "/clip"

    function refresh() {
        if (!listProc.running)
            listProc.running = true;
    }

    function preview(e) {
        return "file://" + clipDir + "/" + e.id + ".png?v=" + previewVersion;
    }

    Process {
        id: listProc
        command: ["sh", "-c", "cliphist list | head -n 300"]
        onRunningChanged: root.loading = running
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    const t = line.indexOf("\t");
                    if (t < 0)
                        continue;
                    const id = line.slice(0, t);
                    const body = line.slice(t + 1);
                    const image = /^\[\[ binary data .* (png|jpe?g|webp|bmp|gif) /i.test(body);
                    out.push({ id: id, text: body, image: image, line: line });
                }
                root.entries = out;
                root.decodePreviews();
            }
        }
    }

    Process {
        id: decodeProc
        onExited: root.previewVersion++
    }

    function decodePreviews() {
        const ids = entries.filter(e => e.image).slice(0, 40).map(e => e.id);
        if (ids.length === 0 || decodeProc.running)
            return;
        decodeProc.command = ["sh", "-c", "d=\"$1\"; shift; mkdir -p \"$d\"; for id in \"$@\"; do [ -s \"$d/$id.png\" ] || printf '%s\\t\\n' \"$id\" | cliphist decode > \"$d/$id.png\"; done", "clip", clipDir].concat(ids);
        decodeProc.running = true;
    }

    function copy(e) {
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "clip", e.line]);
    }
    function remove(e) {
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist delete", "clip", e.line]);
        entries = entries.filter(x => x.id !== e.id);
    }
    function wipe() {
        Quickshell.execDetached(["cliphist", "wipe"]);
        entries = [];
    }
}
