pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.common
import qs.widgets

// Custom-styled DBus menu for tray items, with submenu navigation.
PopupWindow {
    id: root

    property var rootMenu: null
    property var stack: []
    readonly property var current: stack.length > 0 ? stack[stack.length - 1] : rootMenu

    function openFor(item, menu) {
        rootMenu = menu;
        stack = [];
        anchor.item = item;
        visible = true;
    }
    function close() {
        visible = false;
    }

    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.adjustment: PopupAdjustment.All
    anchor.margins.top: 12
    grabFocus: true
    color: "transparent"
    implicitWidth: 270
    implicitHeight: Math.min(560, col.implicitHeight + 16)

    QsMenuOpener {
        id: opener
        menu: root.current
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Theme.r.lg
        gradient: TintGradient { base: Theme.surfaceContainer; alpha: 0.97; amount: 0.12; orientation: Gradient.Vertical }
        border.width: 1
        border.color: Theme.alpha(Theme.outlineVariant, 0.8)
        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.9
        transformOrigin: Item.Top
        Behavior on opacity { NumAnim { duration: Motion.fast } }
        Behavior on scale { NumAnim { duration: Motion.normal; easing.bezierCurve: Motion.spatialFast } }

        Flickable {
            anchors.fill: parent
            anchors.margins: 8
            contentHeight: col.implicitHeight
            clip: true

            ColumnLayout {
                id: col
                width: parent.width
                spacing: 2

                // back row for submenus
                Rectangle {
                    visible: root.stack.length > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: 10
                    color: "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        spacing: 8
                        Icon {
                            icon: "chevron_left"
                            size: 16
                            color: Theme.primary
                        }
                        Txt {
                            text: "Back"
                            color: Theme.primary
                            font.weight: Font.DemiBold
                        }
                    }
                    Interactive {
                        radius: 10
                        onClicked: root.stack = root.stack.slice(0, -1)
                    }
                }

                Repeater {
                    model: opener.children

                    delegate: Item {
                        id: entry
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredHeight: modelData.isSeparator ? 9 : 34

                        Rectangle {
                            visible: entry.modelData.isSeparator
                            anchors.centerIn: parent
                            width: parent.width - 16
                            height: 1
                            color: Theme.alpha(Theme.outlineVariant, 0.8)
                        }

                        Rectangle {
                            visible: !entry.modelData.isSeparator
                            anchors.fill: parent
                            radius: 10
                            color: "transparent"
                            opacity: entry.modelData.enabled ? 1 : 0.4

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                Item {
                                    Layout.preferredWidth: 18
                                    Layout.preferredHeight: 18
                                    IconImage {
                                        anchors.fill: parent
                                        source: entry.modelData.icon
                                        visible: entry.modelData.icon !== "" && entry.modelData.buttonType === QsMenuButtonType.None
                                    }
                                    Rectangle {
                                        visible: entry.modelData.buttonType !== QsMenuButtonType.None
                                        anchors.centerIn: parent
                                        width: 16
                                        height: 16
                                        radius: entry.modelData.buttonType === QsMenuButtonType.RadioButton ? 8 : 4
                                        color: entry.modelData.checkState === Qt.Checked ? Theme.accent(entry.index) : "transparent"
                                        border.width: 2
                                        border.color: entry.modelData.checkState === Qt.Checked ? Theme.accent(entry.index) : Theme.outline
                                        Icon {
                                            anchors.centerIn: parent
                                            visible: entry.modelData.checkState === Qt.Checked
                                            icon: "check"
                                            size: 11
                                            color: Theme.surface
                                            bounce: false
                                        }
                                    }
                                }
                                Txt {
                                    Layout.fillWidth: true
                                    text: entry.modelData.text.replace(/_(?!_)/g, "")
                                    font.pixelSize: 13
                                }
                                Icon {
                                    visible: entry.modelData.hasChildren
                                    icon: "chevron_right"
                                    size: 16
                                    color: Theme.fgDim
                                }
                            }

                            Interactive {
                                radius: 10
                                enabled: entry.modelData.enabled
                                tint: Theme.accent(entry.index)
                                onClicked: {
                                    if (entry.modelData.hasChildren) {
                                        root.stack = root.stack.concat([entry.modelData]);
                                    } else {
                                        entry.modelData.triggered();
                                        root.close();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
