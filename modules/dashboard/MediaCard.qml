import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Widgets
import qs.common
import qs.services
import qs.widgets

// Now-playing card: blurred album-art backdrop, art, wavy progress, controls
// and a live spectrum along the bottom edge.
Card {
    id: root

    clip: true

    ClippingRectangle {
        anchors.fill: parent
        radius: root.radius
        color: Theme.surfaceLow

        Image {
            id: bgArt
            anchors.fill: parent
            source: Media.art
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 128
            sourceSize.height: 128
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: bgArt
            blurEnabled: true
            blur: 1
            blurMax: 48
            saturation: 0.3
            opacity: Media.art !== "" ? 0.55 : 0
            Behavior on opacity { NumAnim {} }
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.alpha(Theme.surfaceLowest, 0.2) }
                GradientStop { position: 1; color: Theme.alpha(Theme.surfaceLowest, 0.85) }
            }
        }

        Visualizer {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 60
            count: 40
            spacing: 3
            opacity: Media.playing ? 0.45 : 0
            visible: opacity > 0
            radius: 2
            Behavior on opacity { NumAnim {} }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 18

        // art with a glow ring that pulses with the bass
        Item {
            Layout.preferredWidth: 150
            Layout.preferredHeight: 150
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                anchors.centerIn: parent
                width: 150 + Cava.bass * 26
                height: width
                radius: 30
                color: Theme.alpha(Theme.accent(0), 0.25 + Cava.bass * 0.3)
                visible: Media.playing
            }
            ClippingRectangle {
                anchors.fill: parent
                radius: 24
                color: Theme.surfaceHigh
                Image {
                    anchors.fill: parent
                    source: Media.art
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 300
                    sourceSize.height: 300
                }
                Icon {
                    anchors.centerIn: parent
                    visible: Media.art === ""
                    icon: Media.hasPlayer ? "music" : "music_off"
                    size: 60
                    color: Theme.accent(0)
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4

            RowLayout {
                spacing: 6
                Icon {
                    icon: Media.sourceIcon
                    size: 14
                    color: Theme.accent(5)
                }
                Txt {
                    Layout.fillWidth: true
                    text: Media.hasPlayer ? Media.identity : "No players"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: Theme.accent(5)
                }
                IconBtn {
                    visible: Media.players.length > 1
                    icon: "swap_horizontal"
                    size: 26
                    iconSize: 14
                    tooltip: "Switch player"
                    onClicked: Media.cycle()
                }
            }
            Marquee {
                Layout.fillWidth: true
                text: Media.title || "Nothing playing"
                pixelSize: 19
                weight: Font.Black
                family: Theme.display
            }
            Txt {
                Layout.fillWidth: true
                text: Media.artist || (Media.hasPlayer ? "" : "Play something to see it here")
                font.pixelSize: 13
                color: Theme.accent(1)
            }
            Item { Layout.fillHeight: true }
            WavyProgress {
                Layout.fillWidth: true
                value: Media.progress
                playing: Media.playing
                color: Theme.accent(0)
                onSeek: frac => Media.seek(frac)
            }
            RowLayout {
                Layout.fillWidth: true
                Txt {
                    text: Utils.mmss(Media.position)
                    font.pixelSize: 10
                    font.family: Theme.mono
                    color: Theme.fgDim
                }
                Item { Layout.fillWidth: true }
                IconBtn {
                    icon: "shuffle"
                    size: 30
                    iconSize: 15
                    visible: Media.active?.shuffleSupported ?? false
                    iconColor: Media.active?.shuffle ? Theme.accent(2) : Theme.fgDim
                    onClicked: Media.active.shuffle = !Media.active.shuffle
                }
                IconBtn {
                    icon: "skip_previous"
                    size: 36
                    onClicked: Media.previous()
                }
                IconBtn {
                    icon: Media.playing ? "pause" : "play"
                    size: 48
                    active: true
                    accent: Theme.accent(0)
                    onClicked: Media.toggle()
                }
                IconBtn {
                    icon: "skip_next"
                    size: 36
                    onClicked: Media.next()
                }
                IconBtn {
                    icon: (Media.active?.loopState ?? 0) === 1 ? "repeat_once" : "repeat"
                    size: 30
                    iconSize: 15
                    visible: Media.active?.loopSupported ?? false
                    iconColor: (Media.active?.loopState ?? 0) !== 0 ? Theme.accent(2) : Theme.fgDim
                    onClicked: Media.active.loopState = ((Media.active.loopState + 1) % 3)
                }
                Item { Layout.fillWidth: true }
                Txt {
                    text: Utils.mmss(Media.length)
                    font.pixelSize: 10
                    font.family: Theme.mono
                    color: Theme.fgDim
                }
            }
        }
    }
}
