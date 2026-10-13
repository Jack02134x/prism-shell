pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services
import qs.widgets

// Capture panel: mode × action × delay, plus recording and the colour picker.
// Keys: 1/2/3 capture region/window/screen, R recording menu, C colour, Esc close.
Overlay {
    id: win

    name: "screenshot"
    open: Panels.screenshot
    scrimOpacity: 0.3
    onDismiss: Panels.screenshot = false
    onOpened: keys.forceActiveFocus()

    property string action: "both"
    property int delay: 0

    readonly property var modes: [
        { id: "region", name: "Region", icon: "selection_drag", c: 0, key: "1" },
        { id: "window", name: "Window", icon: "dock_window", c: 3, key: "2" },
        { id: "full", name: "Screen", icon: "monitor_screenshot", c: 6, key: "3" }
    ]

    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_1)
                Shot.capture("region", win.action, win.delay);
            else if (event.key === Qt.Key_2)
                Shot.capture("window", win.action, win.delay);
            else if (event.key === Qt.Key_3 || event.key === Qt.Key_Return)
                Shot.capture("full", win.action, win.delay);
            else if (event.key === Qt.Key_R)
                Panels.show("record");
            else if (event.key === Qt.Key_C)
                Shot.pickColor();
            else
                return;
            event.accepted = true;
        }
    }

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        y: Config.bar.height + Config.bar.margin + 14 - (1 - win.progress) * 30
        width: 620
        height: col.implicitHeight + 40
        radius: Theme.r.xl
        gradient: TintGradient { alpha: 0.96; amount: 0.14 }
        opacity: win.progress
        scale: 0.9 + 0.1 * win.progress
        transformOrigin: Item.Top

        GlowBorder {
            z: -1
            radius: card.radius
            pad: 16
            glow: 0.5
            speed: 4
        }
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            RowLayout {
                SectionTitle {
                    Layout.fillWidth: true
                    icon: "camera"
                    text: "Capture"
                    accent: Theme.accent(0)
                }
                Txt {
                    text: "saves to " + Config.paths.screenshots.replace(Config.home, "~")
                    font.pixelSize: 11
                    color: Theme.fgDim
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Repeater {
                    model: win.modes
                    Rectangle {
                        id: m
                        required property var modelData
                        required property int index
                        readonly property color accent: Theme.accent(modelData.c)
                        Layout.fillWidth: true
                        implicitHeight: 118
                        radius: mHover.hovered ? 30 : 22
                        color: mHover.hovered ? accent : Theme.alpha(accent, 0.14)
                        border.width: 1
                        border.color: Theme.alpha(accent, 0.5)
                        scale: mTap.pressed ? 0.94 : 1
                        Behavior on radius { NumAnim { easing.bezierCurve: Motion.spatial } }
                        Behavior on color { ColAnim {} }
                        Behavior on scale { NumAnim { duration: Motion.fast } }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Icon {
                                Layout.alignment: Qt.AlignHCenter
                                icon: m.modelData.icon
                                size: mHover.hovered ? 40 : 34
                                color: mHover.hovered ? Theme.on(m.accent) : m.accent
                                Behavior on size { NumAnim { easing.bezierCurve: Motion.spatialFast } }
                            }
                            Txt {
                                Layout.alignment: Qt.AlignHCenter
                                text: m.modelData.name
                                font.weight: Font.Bold
                                color: mHover.hovered ? Theme.on(m.accent) : Theme.fg
                            }
                            Keycap {
                                Layout.alignment: Qt.AlignHCenter
                                text: m.modelData.key
                                accent: m.accent
                            }
                        }
                        HoverHandler {
                            id: mHover
                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            id: mTap
                            onTapped: Shot.capture(m.modelData.id, win.action, win.delay)
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Txt {
                    text: "Then"
                    color: Theme.fgDim
                    Layout.preferredWidth: 46
                }
                Repeater {
                    model: [
                        { id: "copy", name: "Copy", icon: "content_copy" },
                        { id: "save", name: "Save", icon: "content_save" },
                        { id: "both", name: "Both", icon: "content_save_all" }
                    ]
                    Btn {
                        required property var modelData
                        required property int index
                        icon: modelData.icon
                        text: modelData.name
                        filled: win.action === modelData.id
                        accent: Theme.accent(index * 2 + 1)
                        implicitHeight: 32
                        fontSize: 12
                        onClicked: win.action = modelData.id
                    }
                }
                Item { Layout.fillWidth: true }
                Icon {
                    icon: "timer_outline"
                    size: 16
                    color: Theme.fgDim
                }
                Repeater {
                    model: [0, 3, 5, 10]
                    Btn {
                        required property int modelData
                        text: modelData === 0 ? "Now" : modelData + "s"
                        filled: win.delay === modelData
                        accent: Theme.accent(8)
                        implicitHeight: 32
                        fontSize: 12
                        pad: 10
                        onClicked: win.delay = modelData
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.alpha(Theme.outlineVariant, 0.8)
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Btn {
                    icon: "record_rec"
                    text: "Screen recording…"
                    filled: false
                    onClicked: Panels.show("record")
                }
                Item { Layout.fillWidth: true }
                Btn {
                    icon: "eyedropper"
                    text: "Colour"
                    accent: Theme.accent(5)
                    onClicked: Shot.pickColor()
                }
            }
        }
    }
}
