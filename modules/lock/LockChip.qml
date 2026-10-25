import QtQuick
import QtQuick.Layouts
import qs.common
import qs.widgets

// A small glass pill on the lock screen: icon + text.
Rectangle {
    id: root

    property string icon: ""
    property color tint: Theme.grad1
    property string text: ""

    implicitWidth: row.implicitWidth + 26
    implicitHeight: 34
    radius: height / 2
    color: Qt.rgba(0, 0, 0, 0.32)
    border.width: 1
    border.color: Theme.alpha(tint, 0.35)

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 7
        Icon {
            icon: root.icon
            size: 16
            color: root.tint
        }
        Txt {
            text: root.text
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: "white"
        }
    }
}
