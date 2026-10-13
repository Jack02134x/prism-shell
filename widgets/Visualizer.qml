pragma ComponentBehavior: Bound

import QtQuick
import qs.common
import qs.services

// Spectrum bars from cava, coloured with the wallpaper palette.
// mirror: bars grow from the centre line both ways.
Item {
    id: root

    property int count: 24
    property real spacing: 2
    property bool mirror: false
    property real minBar: 2
    property real gain: 1
    property bool rainbow: true
    property color color: Theme.primary
    property real radius: -1
    // request 60 fps from cava while visible (large visualizers)
    property bool hifi: false
    readonly property bool live: visible && opacity > 0

    property bool registered: false
    property bool registeredHifi: false
    onLiveChanged: reg()
    onHifiChanged: reg()
    Component.onCompleted: reg()
    Component.onDestruction: {
        if (registered)
            Cava.consumers--;
        if (registeredHifi)
            Cava.hifiConsumers--;
    }
    function reg() {
        if (live && !registered) {
            Cava.consumers++;
            registered = true;
        } else if (!live && registered) {
            Cava.consumers--;
            registered = false;
        }
        const wantHifi = live && hifi;
        if (wantHifi && !registeredHifi) {
            Cava.hifiConsumers++;
            registeredHifi = true;
        } else if (!wantHifi && registeredHifi) {
            Cava.hifiConsumers--;
            registeredHifi = false;
        }
    }

    Row {
        anchors.fill: parent
        spacing: root.spacing

        Repeater {
            model: root.count
            Item {
                id: slot
                required property int index
                width: (root.width - root.spacing * (root.count - 1)) / root.count
                height: root.height
                // sample the cava bins evenly across this widget
                readonly property real v: {
                    const vals = Cava.values;
                    const n = vals.length;
                    const i = Math.min(n - 1, Math.floor(index * n / root.count));
                    return Math.min(1, (vals[i] ?? 0) * root.gain);
                }
                readonly property color c: root.rainbow ? Theme.accent(Math.floor(index * Theme.spectrumSize / root.count)) : root.color

                Rectangle {
                    width: parent.width
                    height: Math.max(root.minBar, slot.v * (root.mirror ? parent.height : parent.height))
                    anchors.bottom: root.mirror ? undefined : parent.bottom
                    anchors.verticalCenter: root.mirror ? parent.verticalCenter : undefined
                    radius: root.radius >= 0 ? root.radius : width / 2
                    color: slot.c
                    opacity: 0.55 + slot.v * 0.45
                }
            }
        }
    }
}
