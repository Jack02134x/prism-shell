import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.common
import qs.services
import qs.widgets

// Floating three-pill bar. The window is taller than the bar so the island
// can expand downwards; input outside the pills passes through (mask).
PanelWindow {
    id: bar

    required property var modelData
    readonly property var monitor: Hyprland.monitorFor(modelData)
    readonly property real h: Config.bar.height
    readonly property real m: Config.bar.margin

    screen: modelData
    color: "transparent"
    implicitHeight: 230
    exclusiveZone: h + m
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "prism-bar"

    anchors {
        top: true
        left: true
        right: true
    }

    mask: Region {
        item: left
        Region { item: right }
        Region { item: island.hitbox }
    }

    IdleInhibitor {
        window: bar
        enabled: Toggles.caffeine
    }

    Item {
        id: content
        x: bar.m
        y: bar.m
        width: bar.width - bar.m * 2
        height: bar.h

        // entrance: drop in from above on startup
        transform: Translate {
            id: enter
            y: -80
        }
        Component.onCompleted: enterAnim.start()
        NumberAnimation {
            id: enterAnim
            target: enter
            property: "y"
            to: 0
            duration: 900
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.spatial
        }

        // ---- left pill ----
        Pill {
            id: left
            anchors.left: parent.left
            height: parent.height
            width: Math.min(leftRow.implicitWidth + 16, content.width / 2 - island.width / 2 - 14)
            phase: 0
            clip: false

            RowLayout {
                id: leftRow
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Logo {}
                Rectangle {
                    implicitWidth: 1
                    implicitHeight: 20
                    color: Theme.alpha(Theme.outline, 0.4)
                }
                Workspaces {
                    monitor: bar.monitor
                }
                Rectangle {
                    visible: Config.bar.showTitle
                    implicitWidth: 1
                    implicitHeight: 20
                    color: Theme.alpha(Theme.outline, 0.4)
                }
                ActiveWindow {
                    visible: Config.bar.showTitle
                    Layout.fillWidth: true
                    Layout.maximumWidth: maxWidth
                    maxWidth: 300
                }
            }
        }

        // ---- island ----
        Island {
            id: island
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            barHeight: bar.h
        }

        // ---- right pill ----
        Pill {
            id: right
            anchors.right: parent.right
            height: parent.height
            width: rightRow.implicitWidth + 20
            phase: 0.5

            RowLayout {
                id: rightRow
                anchors.centerIn: parent
                spacing: 10

                Stats {
                    visible: Config.bar.showStats
                }
                Rectangle {
                    visible: Config.bar.showStats
                    implicitWidth: 1
                    implicitHeight: 20
                    color: Theme.alpha(Theme.outline, 0.4)
                }
                Tray {
                    menu: trayMenu
                }
                Status {}
            }
        }
    }

    TrayMenu {
        id: trayMenu
        anchor.window: bar
    }
}
