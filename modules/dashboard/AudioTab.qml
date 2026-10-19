pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.common
import qs.services
import qs.widgets

// Output / input selection, per-app mixer and a live mic level meter.
Item {
    id: root

    property bool active: false

    PwNodePeakMonitor {
        id: micPeak
        node: Audio.source
        enabled: root.active
    }
    PwNodePeakMonitor {
        id: outPeak
        node: Audio.sink
        enabled: root.active
    }

    component DeviceList: ColumnLayout {
        id: dl
        property var nodes: []
        property var current: null
        property int accentIndex: 0
        property bool isSink: true
        spacing: 6
        Repeater {
            model: dl.nodes
            Rectangle {
                id: node
                required property var modelData
                readonly property bool sel: modelData === dl.current
                Layout.fillWidth: true
                implicitHeight: 44
                radius: Theme.r.md
                color: sel ? Theme.alpha(Theme.accent(dl.accentIndex), 0.22) : Theme.alpha(Theme.fg, 0.04)
                border.width: sel ? 1 : 0
                border.color: Theme.accent(dl.accentIndex)
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    Icon {
                        icon: node.sel ? "radiobox_marked" : "radiobox_blank"
                        size: 18
                        color: Theme.accent(dl.accentIndex)
                    }
                    Txt {
                        Layout.fillWidth: true
                        text: Audio.nodeName(node.modelData)
                        font.weight: node.sel ? Font.Bold : Font.Normal
                    }
                }
                Interactive {
                    radius: node.radius
                    onClicked: dl.isSink ? Audio.setDefaultSink(node.modelData) : Audio.setDefaultSource(node.modelData)
                }
            }
        }
    }

    component Meter: Rectangle {
        property real level: 0
        property color accent: Theme.primary
        implicitHeight: 8
        radius: 4
        color: Theme.alpha(Theme.fg, 0.08)
        Rectangle {
            height: parent.height
            radius: 4
            width: parent.width * Math.min(1, parent.level)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#7dee9b" }
                GradientStop { position: 0.7; color: "#ffd166" }
                GradientStop { position: 1; color: "#ff5a6a" }
            }
            Behavior on width { NumberAnimation { duration: 60 } }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 14

        ColumnLayout {
            Layout.preferredWidth: 460
            Layout.maximumWidth: 460
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: 14

            Card {
                Layout.fillWidth: true
                Layout.preferredHeight: outCol.implicitHeight + 32
                shown: root.active
                ColumnLayout {
                    id: outCol
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10
                    RowLayout {
                        Layout.fillWidth: true
                        SectionTitle {
                            Layout.fillWidth: true
                            icon: "speaker"
                            text: "Output"
                            accent: Theme.accent(0)
                        }
                        Txt {
                            text: "EasyEffects"
                            font.pixelSize: 12
                            color: Theme.fgDim
                        }
                        StyledSwitch {
                            checked: Toggles.easyEffects
                            accent: Theme.accent(3)
                            onToggled: Toggles.toggleEasyEffects()
                        }
                    }
                    StyledSlider {
                        Layout.fillWidth: true
                        icon: Audio.icon
                        value: Audio.volume
                        softMax: 1
                        max: 1.5
                        accent: Theme.accent(0)
                        accent2: Theme.accent(2)
                        onMoved: v => Audio.setVolume(v)
                        onIconClicked: Audio.toggleMute()
                    }
                    Meter {
                        Layout.fillWidth: true
                        level: outPeak.peak
                    }
                    DeviceList {
                        Layout.fillWidth: true
                        nodes: Audio.sinks
                        current: Audio.sink
                        accentIndex: 0
                        isSink: true
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                shown: root.active
                delay: 80
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10
                    SectionTitle {
                        icon: "microphone"
                        text: "Input"
                        accent: Theme.accent(5)
                    }
                    StyledSlider {
                        Layout.fillWidth: true
                        icon: Audio.micIcon
                        value: Audio.micVolume
                        softMax: 1
                        max: 1.5
                        accent: Theme.accent(5)
                        accent2: Theme.accent(7)
                        onMoved: v => Audio.setMic(v)
                        onIconClicked: Audio.toggleMic()
                    }
                    RowLayout {
                        Icon {
                            icon: "waveform"
                            size: 14
                            color: Theme.accent(5)
                        }
                        Meter {
                            Layout.fillWidth: true
                            level: Audio.micMuted ? 0 : micPeak.peak * 1.5
                        }
                    }
                    DeviceList {
                        Layout.fillWidth: true
                        nodes: Audio.sources
                        current: Audio.source
                        accentIndex: 5
                        isSink: false
                    }
                    Item { Layout.fillHeight: true }
                }
            }
        }

        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            shown: root.active
            delay: 120
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                SectionTitle {
                    icon: "tune_variant"
                    text: "Applications"
                    accent: Theme.accent(3)
                }
                Repeater {
                    model: Audio.streams
                    ColumnLayout {
                        id: stream
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: 6
                        RowLayout {
                            spacing: 10
                            AppIcon {
                                size: 22
                                source: Quickshell.iconPath(Audio.streamIcon(stream.modelData), true)
                                fallback: "music_note"
                                fallbackColor: Theme.accent(stream.index * 2)
                            }
                            Txt {
                                Layout.fillWidth: true
                                text: Audio.streamName(stream.modelData) + "  ·  " + (stream.modelData.properties?.["media.name"] ?? "")
                                font.weight: Font.DemiBold
                            }
                        }
                        StyledSlider {
                            Layout.fillWidth: true
                            icon: stream.modelData.audio?.muted ? "volume_off" : "volume_high"
                            value: stream.modelData.audio?.volume ?? 0
                            accent: Theme.accent(stream.index * 2)
                            accent2: Theme.accent(stream.index * 2 + 2)
                            onMoved: v => {
                                if (stream.modelData.audio)
                                    stream.modelData.audio.volume = v;
                            }
                            onIconClicked: {
                                if (stream.modelData.audio)
                                    stream.modelData.audio.muted = !stream.modelData.audio.muted;
                            }
                        }
                    }
                }
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Column {
                        anchors.centerIn: parent
                        visible: Audio.streams.length === 0
                        spacing: 8
                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            icon: "volume_off"
                            size: 40
                            color: Theme.alpha(Theme.accent(3), 0.6)
                        }
                        Txt {
                            text: "No apps are playing audio"
                            color: Theme.fgDim
                        }
                    }
                }
            }
        }
    }
}
