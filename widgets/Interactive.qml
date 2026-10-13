import QtQuick
import Quickshell.Widgets
import qs.common

// Hover state layer + Material ripple, clipped to the parent's rounded shape.
MouseArea {
    id: root

    property color tint: Theme.fg
    property real radius: 0
    property real hoverOpacity: 0.08
    property real pressOpacity: 0.14

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

    onPressed: mouse => {
        ripple.cx = mouse.x;
        ripple.cy = mouse.y;
        rippleAnim.restart();
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: root.tint
            opacity: root.containsMouse ? (root.pressed ? root.pressOpacity : root.hoverOpacity) : 0
            Behavior on opacity { NumAnim { duration: Motion.fast } }
        }

        Rectangle {
            id: ripple
            property real cx: 0
            property real cy: 0
            x: cx - width / 2
            y: cy - height / 2
            width: 0
            height: width
            radius: width / 2
            color: root.tint
            opacity: 0
        }
    }

    ParallelAnimation {
        id: rippleAnim
        NumberAnimation {
            target: ripple
            property: "width"
            from: 0
            to: Math.hypot(root.width, root.height) * 2.2
            duration: 650
            easing.type: Easing.OutCubic
        }
        SequentialAnimation {
            NumberAnimation { target: ripple; property: "opacity"; from: 0; to: 0.2; duration: 70 }
            NumberAnimation { target: ripple; property: "opacity"; to: 0; duration: 560; easing.type: Easing.InQuad }
        }
    }
}
