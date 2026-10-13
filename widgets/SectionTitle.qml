import QtQuick
import QtQuick.Layouts
import qs.common

RowLayout {
    id: root

    property string icon: ""
    property string text: ""
    property color accent: Theme.primary

    spacing: 8

    Rectangle {
        visible: root.icon !== ""
        implicitWidth: 26
        implicitHeight: 26
        radius: 8
        color: Theme.alpha(root.accent, 0.18)
        Icon {
            anchors.centerIn: parent
            icon: root.icon
            size: 15
            color: root.accent
        }
    }
    Txt {
        text: root.text
        font.pixelSize: 14
        font.weight: Font.Bold
        color: Theme.fg
        Layout.fillWidth: true
    }
}
