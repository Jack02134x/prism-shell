import QtQuick
import Quickshell

// Builds a panel only while it's wanted and frees it `keepMs` after it closes:
// long enough for the close animation (and instant reopening), short enough that
// a closed panel doesn't hold its window, GPU context and objects forever.
LazyLoader {
    id: root

    property bool want: false
    property int keepMs: 20000
    property bool held: false

    active: want || held

    onWantChanged: {
        if (want) {
            held = true;
            release.stop();
        } else {
            release.restart();
        }
    }

    property Timer release: Timer {
        interval: root.keepMs
        onTriggered: root.held = false
    }
}
