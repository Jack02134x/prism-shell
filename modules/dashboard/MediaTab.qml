pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Widgets
import qs.common
import qs.services
import qs.widgets

// Big "now playing": spinning vinyl, blurred backdrop, full-width spectrum.
Item {
    id: root

    property bool active: false

    ClippingRectangle {
        anchors.fill: parent
        radius: Theme.r.lg
        color: Theme.surfaceLowest

        Image {
            id: bg
            anchors.fill: parent
            source: Media.art
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 160
            sourceSize.height: 160
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: bg
            blurEnabled: true
            blur: 1
            blurMax: 64
            saturation: 0.5
            opacity: Media.art !== "" ? 0.5 : 0
            Behavior on opacity { NumAnim {} }
        }
        Aurora {
            anchors.fill: parent
            visible: Media.art === ""
            intensity: 0.8
            bg: Theme.surfaceLowest
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.alpha(Theme.surfaceLowest, 0.35) }
                GradientStop { position: 0.6; color: Theme.alpha(Theme.surfaceLowest, 0.6) }
                GradientStop { position: 1; color: Theme.alpha(Theme.surfaceLowest, 0.95) }
            }
        }

        // mirrored spectrum along the bottom
        Visualizer {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 20
            height: 150
            count: 48
            spacing: 4
            gain: 1.1
            radius: 3
            hifi: true
            visible: root.active
            opacity: Media.playing ? 0.9 : 0.25
            Behavior on opacity { NumAnim {} }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 36
        anchors.bottomMargin: 190
        spacing: 40

        // vinyl
        Item {
            Layout.preferredWidth: 340
            Layout.preferredHeight: 340
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                anchors.centerIn: parent
                width: 340 + Cava.bass * 40
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 3
                border.color: Theme.alpha(Theme.accent(0), 0.25 + Cava.bass * 0.5)
                visible: Media.playing
            }

            Item {
                id: vinyl
                anchors.fill: parent
                anchors.margins: 10
                rotation: spin.angle

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "#111"
                    border.width: 2
                    border.color: Theme.alpha(Theme.accent(3), 0.6)
                }
                // grooves
                Repeater {
                    model: 7
                    Rectangle {
                        required property int index
                        anchors.centerIn: parent
                        width: vinyl.width * (0.95 - index * 0.06)
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.06)
                    }
                }
                ClippingRectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.52
                    height: width
                    radius: width / 2
                    color: Theme.surfaceHigh
                    Image {
                        anchors.fill: parent
                        source: Media.art
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 400
                        sourceSize.height: 400
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: Media.art === ""
                        icon: "music"
                        size: 60
                        color: Theme.accent(0)
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    radius: 7
                    color: "#111"
                    border.width: 2
                    border.color: Theme.accent(0)
                }
                // sheen
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    rotation: -spin.angle - 35
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.12) }
                        GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0) }
                        GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            Item { Layout.fillHeight: true }
            RowLayout {
                spacing: 8
                Icon {
                    icon: Media.sourceIcon
                    size: 16
                    color: Theme.accent(5)
                }
                Txt {
                    text: Media.hasPlayer ? Media.identity.toUpperCase() : "NO PLAYER"
                    font.pixelSize: 12
                    font.weight: Font.Black
                    font.letterSpacing: 2
                    color: Theme.accent(5)
                }
            }
            Marquee {
                Layout.fillWidth: true
                text: Media.title || "Nothing playing"
                pixelSize: 40
                weight: Font.Black
                family: Theme.display
                color: Theme.fg
            }
            Txt {
                Layout.fillWidth: true
                text: Media.artist
                font.pixelSize: 20
                font.weight: Font.DemiBold
                color: Theme.accent(1)
            }
            Txt {
                Layout.fillWidth: true
                visible: text !== ""
                text: Media.album
                font.pixelSize: 14
                color: Theme.alpha(Theme.fg, 0.6)
            }
            Item { implicitHeight: 14 }
            WavyProgress {
                Layout.fillWidth: true
                implicitHeight: 26
                amplitude: 5
                wavelength: 34
                lineWidth: 4
                value: Media.progress
                playing: Media.playing
                color: Theme.accent(0)
                onSeek: frac => Media.seek(frac)
            }
            RowLayout {
                Layout.fillWidth: true
                Txt {
                    text: Utils.mmss(Media.position)
                    font.family: Theme.mono
                    font.pixelSize: 12
                    color: Theme.alpha(Theme.fg, 0.7)
                }
                Item { Layout.fillWidth: true }
                Txt {
                    text: Utils.mmss(Media.length)
                    font.family: Theme.mono
                    font.pixelSize: 12
                    color: Theme.alpha(Theme.fg, 0.7)
                }
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 18
                IconBtn {
                    icon: "skip_previous"
                    size: 52
                    iconColor: Theme.fg
                    onClicked: Media.previous()
                }
                IconBtn {
                    icon: Media.playing ? "pause" : "play"
                    size: 76
                    active: true
                    accent: Theme.accent(0)
                    onClicked: Media.toggle()
                }
                IconBtn {
                    icon: "skip_next"
                    size: 52
                    iconColor: Theme.fg
                    onClicked: Media.next()
                }
            }
            Item { Layout.fillHeight: true }

            // players
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: Media.players
                    Btn {
                        required property var modelData
                        required property int index
                        icon: modelData.isPlaying ? "play" : "pause"
                        text: modelData.identity
                        filled: modelData === Media.active
                        accent: Theme.accent(index * 3)
                        implicitHeight: 30
                        fontSize: 12
                        onClicked: Media.pinned = modelData
                    }
                }
            }
        }
    }

    Item {
        id: spin
        visible: false
        property real angle: 0
        NumberAnimation on angle {
            from: 0
            to: 360
            duration: 6000
            loops: Animation.Infinite
            running: root.active && Media.playing
        }
    }
}
