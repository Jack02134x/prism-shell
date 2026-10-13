import QtQuick

// A drawer's contents, built only while the drawer is (partly) out and freed
// 20 s after it closes.
Loader {
    id: root

    required property bool shown
    property bool held: false

    anchors.fill: parent
    active: shown || held

    onShownChanged: {
        if (shown) {
            held = true;
            release.stop();
        } else {
            release.restart();
        }
    }

    property Timer release: Timer {
        interval: 20000
        onTriggered: root.held = false
    }
}
