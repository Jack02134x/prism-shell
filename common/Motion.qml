pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Durations, Material 3 expressive curves, and one shared ambient clock.
Singleton {
    id: root

    readonly property int fast: 160
    readonly property int normal: 320
    readonly property int slow: 520
    readonly property int slower: 800

    readonly property list<real> standard: [0.2, 0, 0, 1, 1, 1]
    readonly property list<real> emphasized: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82, 0.25, 1, 1, 1]
    readonly property list<real> decel: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property list<real> accel: [0.3, 0, 0.8, 0.15, 1, 1]
    // springy curves that overshoot slightly
    readonly property list<real> spatial: [0.38, 1.21, 0.22, 1, 1, 1]
    readonly property list<real> spatialFast: [0.42, 1.67, 0.21, 0.9, 1, 1]
    readonly property list<real> bouncy: [0.34, 1.56, 0.64, 1, 1, 1]
    readonly property list<real> effects: [0.34, 0.8, 0.34, 1, 1, 1]

    // set by Toggles when game mode is on
    property bool calm: false

    readonly property bool ambient: Config.fx.ambient && !calm && (Config.fx.ambientOnBattery || !UPower.onBattery)

    // Looping 0..1 phase shared by every ambient effect (gradient borders,
    // aurora, orb). It ticks at ~30 fps instead of the 144 Hz panel rate, so
    // slow ambient motion stays smooth but cheap.
    readonly property real period: 24000
    property real t: 0
    // while cava runs it advances `t` on its own frames (see Cava.qml), so
    // ambient motion and the visualizer share redraws instead of interleaving
    property bool driven: false

    // One shared frame clock. Anything that moves continuously (marquees, the
    // spinning disc) steps on `tick` so every animated thing lands in the same
    // redraw. Register with tickUsers while you need it.
    signal tick(real dt)
    property int tickUsers: 0

    function advance(ms) {
        if (ambient)
            t = (t + ms / period) % 1;
        tick(ms);
    }

    Timer {
        interval: 33
        repeat: true
        running: (root.ambient || root.tickUsers > 0) && !root.driven
        onTriggered: root.advance(interval)
    }
}
