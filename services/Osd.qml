pragma Singleton

import QtQuick
import Quickshell

// Transient on-screen display shown inside the dynamic island.
Singleton {
    id: root

    property bool visible: false
    property string kind: ""      // volume | mic | brightness | workspace | toggle | info
    property string icon: ""
    property string label: ""
    property real value: -1       // 0..1, or -1 for no bar
    property color tint: "transparent"
    property int serial: 0

    // suppress OSDs during startup while services settle
    property bool armed: false
    Timer {
        interval: 2500
        running: true
        onTriggered: root.armed = true
    }

    function show(kind, icon, label, value, tint) {
        if (!armed)
            return;
        root.kind = kind;
        root.icon = icon;
        root.label = label;
        root.value = value === undefined ? -1 : value;
        root.tint = tint === undefined ? "transparent" : tint;
        root.serial++;
        root.visible = true;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: 1700
        onTriggered: root.visible = false
    }
}
