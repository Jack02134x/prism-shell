pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.services
import qs.widgets

// Screen recording panel (wf-recorder). Keys: 1/2/3 region/window/screen,
// A toggles audio, S stops, Esc closes.
Overlay {
    id: win

    name: "record"
    open: Panels.record
    scrimOpacity: 0.3
    onDismiss: Panels.record = false
    onOpened: keys.forceActiveFocus()

    readonly property var modes: [
        { id: "region", name: "Region", icon: "selection_drag", c: 0, key: "1" },
        { id: "window", name: "Window", icon: "dock_window", c: 3, key: "2" },
        { id: "full", name: "Screen", icon: "monitor", c: 6, key: "3" }
    ]

    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            if (Toggles.recording && event.key === Qt.Key_S)
                Toggles.stopRecording();
            else if (!Toggles.recording && event.key >= Qt.Key_1 && event.key <= Qt.Key_3)
                Toggles.startRecording(win.modes[event.key - Qt.Key_1].id);
            else if (event.key === Qt.Key_A)
                Toggles.recordAudio = !Toggles.recordAudio;
            else
                return;
            event.accepted = true;
        }
    }

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        y: Config.bar.height + Config.bar.margin + 14 - (1 - win.progress) * 30
        width: 560
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
            c1: "#ff5a6a"
            c2: Theme.accent(8)
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
                    icon: "record_rec"
                    text: "Screen recording"
                    accent: "#ff5a6a"
                }
                Txt {
                    text: "saves to " + Config.paths.recordings.replace(Config.home, "~")
                    font.pixelSize: 11
                    color: Theme.fgDim
                }
            }

            // recording in progress
            RowLayout {
                visible: Toggles.recording
                Layout.fillWidth: true
                spacing: 12
                Rectangle {
                    implicitWidth: 14
                    implicitHeight: 14
                    radius: 7
                    color: "#ff4d5e"
                    SequentialAnimation on opacity {
                        running: Toggles.recording && win.open
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 600 }
                        NumberAnimation { to: 1; duration: 600 }
                    }
                }
                Txt {
                    Layout.fillWidth: true
                    text: "Recording  " + Utils.mmss((clock.date.getTime() - Toggles.recordStart) / 1000)
                    font.family: Theme.mono
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    color: "#ff8a95"
                }
                Btn {
                    icon: "stop"
                    text: "Stop"
                    accent: "#ff5a6a"
                    onClicked: {
                        Panels.record = false;
                        Toggles.stopRecording();
                    }
                }
            }

            RowLayout {
                visible: !Toggles.recording
                Layout.fillWidth: true
                spacing: 12
                Repeater {
                    model: win.modes
                    Rectangle {
                        id: m
                        required property var modelData
                        readonly property color accent: Theme.accent(modelData.c)
                        Layout.fillWidth: true
                        implicitHeight: 112
                        radius: mHover.hovered ? 30 : 22
                        color: mHover.hovered ? accent : Theme.alpha(accent, 0.14)
                        border.width: 1
                        border.color: Theme.alpha(accent, 0.5)
                        Behavior on radius { NumAnim { easing.bezierCurve: Motion.spatial } }
                        Behavior on color { ColAnim {} }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Icon {
                                Layout.alignment: Qt.AlignHCenter
                                icon: m.modelData.icon
                                size: 34
                                color: mHover.hovered ? Theme.on(m.accent) : m.accent
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
                            onTapped: Toggles.startRecording(m.modelData.id)
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Btn {
                    icon: Toggles.recordAudio ? "volume_high" : "volume_off"
                    text: Toggles.recordAudio ? "Audio on" : "Audio off"
                    filled: Toggles.recordAudio
                    accent: Theme.accent(4)
                    onClicked: Toggles.recordAudio = !Toggles.recordAudio
                }
                Item { Layout.fillWidth: true }
                Btn {
                    icon: "folder_play"
                    text: "Recordings"
                    filled: false
                    onClicked: {
                        Panels.record = false;
                        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && xdg-open \"$1\"", "o", Config.paths.recordings]);
                    }
                }
                Btn {
                    icon: "camera"
                    text: "Screenshot"
                    filled: false
                    onClicked: Shot.capture("region", "both", 0)
                }
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
}
