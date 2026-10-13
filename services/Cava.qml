pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Real-time audio spectrum from cava's raw ASCII output. Runs only while
// something is playing (and something wants it).
Singleton {
    id: root

    readonly property int bars: 48
    property var values: new Array(bars).fill(0)
    property real level: 0 // smoothed overall loudness 0..1
    property real bass: 0
    property int consumers: 0
    // big visualizers ask for 60 fps; the bar island is happy with 30
    property int hifiConsumers: 0
    readonly property int fps: hifiConsumers > 0 ? 60 : 30
    readonly property bool active: consumers > 0 && Media.playing
    property int frame: 0
    onFpsChanged: if (proc.running) {
        proc.running = false;
        Qt.callLater(() => proc.running = root.active);
    }

    readonly property string confPath: Config.cacheDir + "/cava.conf"
    readonly property string conf: ["[general]", "bars = " + bars, "framerate = " + fps, "autosens = 1", "sleep_timer = 3", "[input]", "method = pipewire", "source = auto", "[output]", "method = raw", "raw_target = /dev/stdout", "data_format = ascii", "ascii_max_range = 1000", "bar_delimiter = 59", "frame_delimiter = 10", "[smoothing]", "monstercat = 1", "noise_reduction = 70", ""].join("\n")

    Process {
        id: proc
        running: root.active
        command: ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\" && exec cava -p \"$1\"", "cava", root.confPath, root.conf]
        stdout: SplitParser {
            onRead: data => {
                const parts = data.split(";");
                const n = root.bars;
                const out = new Array(n);
                let sum = 0, low = 0;
                for (let i = 0; i < n; i++) {
                    const v = (parseInt(parts[i]) || 0) / 1000;
                    out[i] = v;
                    sum += v;
                    if (i < 6)
                        low += v;
                }
                root.values = out;
                root.frame++;
                Motion.advance(1000 / root.fps);
                root.level = root.level * 0.7 + (sum / n) * 0.3;
                root.bass = root.bass * 0.5 + (low / 6) * 0.5;
            }
        }
        onRunningChanged: {
            Motion.driven = running;
            if (running)
                return;
            root.values = new Array(root.bars).fill(0);
            root.level = 0;
            root.bass = 0;
        }
    }
}
