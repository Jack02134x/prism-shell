import QtQuick
import qs.common

// Round icon button. When `active` it morphs into a squircle filled with its
// accent colour (Material 3 expressive shape morph).
Rectangle {
    id: root

    property string icon: ""
    property real size: 34
    property real iconSize: Math.round(size * 0.52)
    property bool active: false
    property color accent: Theme.primary
    property color idleColor: "transparent"
    property color iconColor: active ? Theme.on(accent) : Theme.fg
    property string tooltip: ""
    property bool tipAbove: false
    readonly property bool hovered: ia.containsMouse

    signal clicked(var mouse)
    signal wheel(var event)

    implicitWidth: size
    implicitHeight: size
    radius: active ? size * 0.32 : size / 2
    color: active ? accent : idleColor
    scale: ia.pressed ? 0.86 : 1

    Behavior on radius { NumAnim { duration: Motion.normal; easing.bezierCurve: Motion.spatial } }
    Behavior on color { ColAnim {} }
    Behavior on scale { NumAnim { duration: Motion.normal; easing.bezierCurve: Motion.spatialFast } }

    Icon {
        anchors.centerIn: parent
        icon: root.icon
        size: root.iconSize
        color: root.iconColor
        Behavior on color { ColAnim {} }
    }

    Interactive {
        id: ia
        radius: root.radius
        tint: root.iconColor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => root.clicked(mouse)
        onWheel: event => root.wheel(event)
    }

    Tip {
        text: root.tooltip
        show: ia.containsMouse
        above: root.tipAbove
    }
}
