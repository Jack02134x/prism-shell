import QtQuick
import qs.common

// Little 3D keyboard key.
Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property color accent: Theme.primary

    implicitWidth: Math.max(26, (icon !== "" ? 14 : label.implicitWidth) + 14)
    implicitHeight: 26
    radius: 7
    color: Theme.surfaceHighest
    border.width: 1
    border.color: Theme.alpha(root.accent, 0.5)

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 3
        radius: 7
        color: Theme.alpha(root.accent, 0.45)
    }

    Icon {
        visible: root.icon !== ""
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        icon: root.icon
        size: 13
        color: Theme.fg
        bounce: false
    }

    Txt {
        id: label
        visible: root.icon === ""
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        text: root.text
        font.family: Theme.mono
        font.pixelSize: 11
        font.weight: Font.Bold
        color: Theme.fg
        elide: Text.ElideNone
    }
}
