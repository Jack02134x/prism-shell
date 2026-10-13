pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.common
import qs.widgets

// System tray. Left click activates, right click opens a themed menu.
RowLayout {
    id: root

    property var menu: null   // TrayMenu instance from the bar
    spacing: 4
    visible: SystemTray.items.values.length > 0

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: item
            required property var modelData
            required property int index
            implicitWidth: 26
            implicitHeight: 26

            Rectangle {
                anchors.fill: parent
                radius: 9
                color: Theme.alpha(Theme.accent(item.index * 2), hh.hovered ? 0.22 : 0)
                Behavior on color { ColAnim {} }
            }

            IconImage {
                id: img
                anchors.centerIn: parent
                implicitSize: 17
                source: {
                    const icon = item.modelData.icon;
                    // some apps pass "name?path=/dir" style icons
                    if (icon.includes("?path=")) {
                        const [name, path] = icon.split("?path=");
                        return "file://" + path + "/" + name.slice(name.lastIndexOf("/") + 1);
                    }
                    return icon;
                }
                scale: hh.hovered ? 1.2 : 1
                Behavior on scale { NumAnim { duration: Motion.fast; easing.bezierCurve: Motion.spatialFast } }
            }

            // attention dot
            Rectangle {
                visible: item.modelData.status === Status.NeedsAttention
                anchors.right: parent.right
                anchors.top: parent.top
                width: 7
                height: 7
                radius: 4
                color: Theme.error
            }

            HoverHandler {
                id: hh
                cursorShape: Qt.PointingHandCursor
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: mouse => {
                    const m = item.modelData;
                    if (mouse.button === Qt.MiddleButton) {
                        m.secondaryActivate();
                    } else if (mouse.button === Qt.RightButton || m.onlyMenu) {
                        if (m.hasMenu && root.menu)
                            root.menu.openFor(item, m.menu);
                    } else {
                        m.activate();
                    }
                }
                onWheel: wheel => item.modelData.scroll(wheel.angleDelta.y, false)
            }
            Tip {
                text: item.modelData.tooltipTitle || item.modelData.title || item.modelData.id
                show: hh.hovered
            }
        }
    }
}
