import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.common
import qs.services
import qs.widgets

// The lock screen's now-playing card: album art, title, wavy progress and controls.
Item {
    id: root

    implicitWidth: 440
    implicitHeight: card.height

    Rectangle {
        id: card
        anchors.bottom: parent.bottom
        width: parent.width
        height: 132
        radius: Theme.r.xl
        gradient: TintGradient { alpha: 0.5; amount: 0.18; orientation: Gradient.Vertical }
        border.width: 1
        border.color: Theme.alpha(Theme.grad1, Media.playing ? 0.25 + Cava.bass * 0.4 : 0.2)

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            // album art (rounded), or the player's icon
            Item {
                Layout.preferredWidth: 100
                Layout.preferredHeight: 100
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.r.lg
                    color: Theme.alpha(Theme.grad1, 0.15)
                    Icon {
                        anchors.centerIn: parent
                        visible: art.status !== Image.Ready
                        icon: Media.sourceIcon
                        size: 36
                        color: Theme.grad1
                    }
                }
                Image {
                    id: art
                    anchors.fill: parent
                    source: Media.art
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 200
                    asynchronous: true
                    visible: false
                }
                Rectangle {
                    id: artMask
                    anchors.fill: parent
                    radius: Theme.r.lg
                    visible: false
                    layer.enabled: true
                }
                MultiEffect {
                    anchors.fill: parent
                    source: art
                    visible: art.status === Image.Ready
                    maskEnabled: true
                    maskSource: artMask
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Marquee {
                    Layout.fillWidth: true
                    text: Media.title || "Nothing playing"
                    pixelSize: 18
                    weight: Font.Black
                    color: "white"
                }
                Txt {
                    Layout.fillWidth: true
                    text: Media.artist
                    visible: text !== ""
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Theme.accent(1)
                    elide: Text.ElideRight
                }
                WavyProgress {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    implicitHeight: 18
                    amplitude: 3
                    wavelength: 24
                    lineWidth: 3
                    value: Media.progress
                    playing: Media.playing
                    color: Theme.accent(0)
                    onSeek: frac => Media.seek(frac)
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Txt {
                        text: Utils.mmss(Media.position) + " / " + Utils.mmss(Media.length)
                        font.family: Theme.mono
                        font.pixelSize: 11
                        color: Qt.rgba(1, 1, 1, 0.6)
                    }
                    Item { Layout.fillWidth: true }
                    IconBtn {
                        icon: "skip_previous"
                        size: 30
                        iconColor: "white"
                        onClicked: Media.previous()
                    }
                    IconBtn {
                        icon: Media.playing ? "pause" : "play"
                        size: 36
                        active: true
                        accent: Theme.accent(0)
                        onClicked: Media.toggle()
                    }
                    IconBtn {
                        icon: "skip_next"
                        size: 30
                        iconColor: "white"
                        onClicked: Media.next()
                    }
                }
            }
        }
    }
}
