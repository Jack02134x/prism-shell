import QtQuick
import Quickshell
import qs.common
import qs.services

// The two pull-out drawers for one monitor: controls on the left edge,
// notifications + calendar on the right edge.
Scope {
    id: root

    required property var modelData
    readonly property bool focused: modelData === Panels.focusedScreen

    Drawer {
        id: left
        modelData: root.modelData
        visible: Config.drawers.left && !Panels.capturing
        leftSide: true
        panelWidth: 420
        accent: Theme.accent(0)
        open: Panels.controls && root.focused
        onRequestOpen: value => value ? Panels.show("controls") : (Panels.controls = false)

        DrawerBody {
            shown: left.shown
            sourceComponent: ControlsContent {
                active: Panels.controls && root.focused
            }
        }
    }

    Drawer {
        id: right
        modelData: root.modelData
        visible: Config.drawers.right && !Panels.capturing
        leftSide: false
        panelWidth: 430
        accent: Theme.accent(7)
        open: Panels.sidebar && root.focused
        onRequestOpen: value => value ? Panels.show("sidebar") : (Panels.sidebar = false)

        DrawerBody {
            shown: right.shown
            sourceComponent: NotificationsContent {
                active: Panels.sidebar && root.focused
            }
        }
    }
}
