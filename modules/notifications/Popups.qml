pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services
import qs.widgets

// Toast stack in the top-right corner of the focused monitor.
PanelWindow {
    id: win

    screen: Panels.focusedScreen
    visible: Notifs.popups.length > 0 && !Panels.sidebar && !Panels.capturing
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "prism-notifications"
    implicitWidth: 440
    implicitHeight: (screen?.height ?? 1080) - 20

    anchors {
        top: true
        right: true
    }
    margins {
        top: Config.bar.height + Config.bar.margin * 2
        right: Config.bar.margin
    }

    mask: Region {
        item: list
    }

    ListView {
        id: list
        anchors.top: parent.top
        anchors.right: parent.right
        width: 420
        height: Math.min(contentHeight, parent.height)
        spacing: 10
        interactive: false
        model: ScriptModel {
            values: Notifs.popups.slice(0, 5)
        }

        delegate: NotifCard {
            required property var modelData
            entry: modelData
            popup: true
            width: 420
        }

        add: Transition {
            NumberAnimation { property: "scale"; from: 0.85; to: 1; duration: Motion.slow; easing.type: Easing.OutBack }
        }
        displaced: Transition {
            NumberAnimation { properties: "y"; duration: Motion.slow; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.spatial }
        }
    }
}
