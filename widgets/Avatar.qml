import QtQuick
import Quickshell.Widgets
import qs.common

// Round avatar with a spinning spectrum ring around it.
Item {
    id: root

    property string source: Utils.toUrl(Config.user.avatar)
    property real ring: 3

    implicitWidth: 64
    implicitHeight: 64

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        rotation: Motion.t * 360 * 4
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.accent(0) }
            GradientStop { position: 0.5; color: Theme.accent(4) }
            GradientStop { position: 1; color: Theme.accent(7) }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.ring
        radius: width / 2
        color: Theme.surface
    }

    ClippingRectangle {
        anchors.fill: parent
        anchors.margins: root.ring + 2
        radius: width / 2
        color: Theme.surfaceHigh

        Image {
            id: img
            anchors.fill: parent
            source: root.source
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 256
            sourceSize.height: 256
            asynchronous: true
        }

        Icon {
            anchors.centerIn: parent
            visible: img.status !== Image.Ready
            icon: "account_circle"
            size: parent.width * 0.8
            color: Theme.primary
        }
    }
}
