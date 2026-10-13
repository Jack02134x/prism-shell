import QtQuick
import QtQuick.Layouts
import qs.common

// Pill button with optional icon + label.
Rectangle {
    id: root

    property string icon: ""
    property string text: ""
    property color accent: Theme.primary
    property bool filled: true
    property bool active: filled
    property real pad: 14
    property real iconSize: 16
    property real fontSize: 13
    readonly property color fg: active ? Theme.on(accent) : Theme.fg
    readonly property bool hovered: ia.containsMouse

    signal clicked(var mouse)

    implicitHeight: 36
    implicitWidth: row.implicitWidth + pad * 2
    radius: height / 2
    color: active ? accent : Theme.alpha(Theme.fg, 0.06)
    border.width: active ? 0 : 1
    border.color: Theme.alpha(Theme.outline, 0.35)
    scale: ia.pressed ? 0.94 : 1

    Behavior on color { ColAnim {} }
    Behavior on scale { NumAnim { duration: Motion.normal; easing.bezierCurve: Motion.spatialFast } }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Icon {
            visible: root.icon !== ""
            icon: root.icon
            size: root.iconSize
            color: root.fg
        }
        Txt {
            visible: root.text !== ""
            text: root.text
            color: root.fg
            font.pixelSize: root.fontSize
            font.weight: Font.DemiBold
        }
    }

    Interactive {
        id: ia
        radius: root.radius
        tint: root.fg
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => root.clicked(mouse)
    }
}
