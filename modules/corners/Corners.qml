pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

// Rounded screen corners (click-through), the top-left hot corner, and the
// warm-screen tint, per monitor.
Scope {
    id: root

    required property var modelData

    component Corner: PanelWindow {
        id: c
        property bool isTop: true
        property bool isLeft: true
        readonly property real r: Config.fx.cornerRadius

        screen: root.modelData
        visible: Config.fx.corners
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "prism-corner"
        implicitWidth: r
        implicitHeight: r
        mask: Region {}
        anchors.top: c.isTop
        anchors.bottom: !c.isTop
        anchors.left: c.isLeft
        anchors.right: !c.isLeft

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            rotation: c.isTop ? (c.isLeft ? 0 : 90) : (c.isLeft ? 270 : 180)
            ShapePath {
                fillColor: "black"
                strokeColor: "transparent"
                startX: 0
                startY: 0
                PathLine { x: c.r; y: 0 }
                PathArc {
                    x: 0
                    y: c.r
                    radiusX: c.r
                    radiusY: c.r
                    direction: PathArc.Counterclockwise
                }
                PathLine { x: 0; y: 0 }
            }
        }
    }

    Corner {
        isTop: true
        isLeft: true
    }
    Corner {
        isTop: true
        isLeft: false
    }
    Corner {
        isTop: false
        isLeft: true
    }
    Corner {
        isTop: false
        isLeft: false
    }

    // hot corner: rest the pointer in the top-left corner to open the overview
    PanelWindow {
        screen: root.modelData
        visible: Config.fx.hotCorner
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "prism-hotcorner"
        implicitWidth: 3
        implicitHeight: 3
        anchors.top: true
        anchors.left: true

        MouseArea {
            anchors.fill: parent
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
