import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.common
import qs.services

// Fullscreen windows cover the bar (it lives on the "top" layer, and that's what
// you want for videos and games). So while this monitor shows a fullscreen window,
// a copy of the island waits on the overlay layer and pops up only when there's
// something to see: the volume / brightness OSD, a notification (alarms too) or a
// track change. Nothing at all is mapped the rest of the time.
Scope {
    id: root

    required property var modelData
    readonly property var monitor: Hyprland.monitorFor(modelData)
    readonly property bool fullscreen: monitor?.activeWorkspace?.hasFullscreen ?? false

    LazyLoader {
        active: root.fullscreen

        PanelWindow {
            id: win

            screen: root.modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "prism-island-fullscreen"
            anchors.top: true
            implicitWidth: 600
            implicitHeight: 230
            // stays up a moment after the alert so the island can shrink away
            visible: (island.alerting || island.hovered || linger.running) && !Panels.capturing
            mask: Region {
                item: island.hitbox
            }

            Connections {
                target: island
                function onAlertingChanged() {
                    if (!island.alerting)
                        linger.restart();
                }
            }
            Timer {
                id: linger
                interval: 700
            }

            Island {
                id: island
                anchors.horizontalCenter: parent.horizontalCenter
                y: Config.bar.margin
                barHeight: Config.bar.height
            }
        }
    }
}
