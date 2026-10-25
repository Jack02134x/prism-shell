import QtQuick
import qs.common
import qs.widgets

// Where a screenshot thread is tied: a small glowing bead.
Item {
    id: root

    property color color: Theme.grad1
    property real size: 12
    property bool shown: true

    width: size
    height: size
    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.3
    Behavior on opacity { NumAnim { duration: Motion.fast } }
    Behavior on scale { NumAnim { duration: Motion.normal; easing.bezierCurve: Motion.spatialFast } }

    Rectangle {
        anchors.centerIn: parent
        width: root.size * 2.2
        height: width
        radius: width / 2
        color: Theme.alpha(root.color, 0.18)
    }
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.color
        border.width: 2
        border.color: Theme.alpha("#ffffff", 0.75)
    }
}
