import QtQuick
import qs.common

// Material 3 switch: the thumb grows and shows a check when on.
Rectangle {
    id: root

    property bool checked: false
    property color accent: Theme.primary
    signal toggled(bool value)

    implicitWidth: 52
    implicitHeight: 30
    radius: height / 2
    color: checked ? accent : Theme.surfaceHighest
    border.width: checked ? 0 : 2
    border.color: Theme.outline

    Behavior on color { ColAnim {} }

    Rectangle {
        id: thumb
        property real d: root.checked ? 22 : (ia.pressed ? 26 : 16)
        width: d
        height: d
        radius: d / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - d - 4 : (ia.pressed ? 2 : 7)
        color: root.checked ? Theme.on(root.accent) : Theme.outline

        Behavior on x { NumAnim { duration: Motion.normal; easing.bezierCurve: Motion.spatial } }
        Behavior on d { NumAnim { duration: Motion.normal; easing.bezierCurve: Motion.spatial } }
        Behavior on color { ColAnim {} }

        Icon {
            anchors.centerIn: parent
            icon: "check"
            size: 14
            color: root.accent
            opacity: root.checked ? 1 : 0
            scale: root.checked ? 1 : 0.3
            Behavior on opacity { NumAnim {} }
            Behavior on scale { NumAnim { easing.bezierCurve: Motion.spatialFast } }
        }
    }

    MouseArea {
        id: ia
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
