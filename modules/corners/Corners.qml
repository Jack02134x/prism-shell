pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

// Rounded screen corners (click-through), the top-left hot corner, and the
// warm-screen tint, per monitor. The corners live in two thin strips (top and
// bottom edge) rather than one window each: every mapped window costs a GPU
// context and a render thread.
Scope {
    id: root

    required property var modelData

    // top edge: two corners + the hot corner (rest the pointer top-left to open the overview)
    CornerStrip {
        id: top
        screen: root.modelData
        isTop: true
        visible: Config.fx.corners || Config.fx.hotCorner
        mask: Region { item: Config.fx.hotCorner ? hot : null }

        MouseArea {
            id: hot
            width: 3
            height: 3
            hoverEnabled: true
            onEntered: dwell.restart()
            onExited: dwell.stop()
        }
        Timer {
            id: dwell
            interval: 140
            onTriggered: Panels.toggle("overview")
        }
    }

    CornerStrip {
        screen: root.modelData
        isTop: false
        visible: Config.fx.corners
    }

    // warm screen tint
    PanelWindow {
        screen: root.modelData
        visible: tint.opacity > 0.001
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "prism-warm"
        mask: Region {}
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        Rectangle {
            id: tint
            anchors.fill: parent
            color: "#ff8a2a"
            opacity: Toggles.warm ? Toggles.warmStrength : 0
            Behavior on opacity { NumberAnimation { duration: 1200 } }
        }
    }
}
