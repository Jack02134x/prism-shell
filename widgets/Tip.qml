import QtQuick
import qs.common

// Small tooltip that pops under (or above) its parent.
Rectangle {
    id: root

    property string text: ""
    property bool show: false
    property bool above: false

    anchors.horizontalCenter: parent.horizontalCenter
    y: above ? -height - 8 : parent.height + 8
    z: 1000
    implicitWidth: label.implicitWidth + 18
    implicitHeight: label.implicitHeight + 10
    radius: 8
    color: Theme.inverseSurface
    opacity: show && text !== "" ? 1 : 0
    scale: opacity > 0 ? 1 : 0.85
    visible: opacity > 0
    transformOrigin: above ? Item.Bottom : Item.Top

    Behavior on opacity { NumAnim { duration: Motion.fast } }
    Behavior on scale { NumAnim { duration: Motion.normal; easing.bezierCurve: Motion.spatialFast } }

    Txt {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: Theme.surface
        font.pixelSize: 12
        font.weight: Font.Medium
        elide: Text.ElideNone
    }
}
