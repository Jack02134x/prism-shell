import QtQuick
import qs.common

// Thick expressive slider with a gradient fill, an icon riding inside the fill
// and a handle that stretches while dragging. value is 0..1 (or up to `max`).
Item {
    id: root

    property real value: 0
    property real max: 1
    property string icon: ""
    property color accent: Theme.primary
    property color accent2: Theme.tertiary
    property bool showValue: true
    property real step: 0.05
    // the mouse wheel stops here; only dragging goes past it (e.g. volume above 100%)
    property real softMax: max
    readonly property bool dragging: ma.pressed
    readonly property real frac: Utils.clamp(value / max, 0, 1)

    signal moved(real value)
    signal iconClicked

    implicitHeight: 38
    implicitWidth: 240

    property real shown: frac
    Behavior on shown {
        enabled: !ma.pressed
        NumAnim { duration: Motion.normal }
    }

    Rectangle {
        id: track
        anchors.fill: parent
        radius: 13
        color: Theme.alpha(Theme.fg, 0.08)
        clip: true

        Rectangle {
            id: fill
            width: Math.max(height, (root.width - 10) * root.shown + 4)
            height: parent.height
            radius: 13
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: root.accent }
                GradientStop { position: 1; color: root.accent2 }
            }
        }
    }

    Icon {
        id: ico
        visible: root.icon !== ""
        anchors.left: parent.left
        anchors.leftMargin: 11
        anchors.verticalCenter: parent.verticalCenter
        icon: root.icon
        size: 17
        color: fill.width > 36 ? Theme.on(root.accent) : Theme.fg
        Behavior on color { ColAnim {} }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: root.iconClicked()
        }
    }

    // a notch at the soft limit (100% volume)
    Rectangle {
        visible: root.softMax < root.max
        width: 2
        height: root.height - 16
        radius: 1
        anchors.verticalCenter: parent.verticalCenter
        x: 5 + (root.width - 10) * root.softMax / root.max - 1
        color: Theme.alpha(Theme.fg, 0.35)
    }

    // handle
    Rectangle {
        id: handle
        width: ma.pressed ? 6 : 4
        height: ma.pressed ? root.height + 8 : root.height - 10
        radius: 3
        anchors.verticalCenter: parent.verticalCenter
        x: Utils.clamp(fill.width + 3, 0, root.width - width)
        color: Theme.fg
        Behavior on height { NumAnim { duration: Motion.fast; easing.bezierCurve: Motion.spatialFast } }
        Behavior on width { NumAnim { duration: Motion.fast } }
    }

    Txt {
        visible: root.showValue
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(root.value * 100) + "%"
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.family: Theme.mono
        color: handle.x > root.width - 52 ? Theme.on(root.accent2) : Theme.fgDim
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.leftMargin: root.icon !== "" ? 34 : 0
        cursorShape: Qt.PointingHandCursor
        preventStealing: true

        function update(mx) {
            const x = mx + anchors.leftMargin;
            const v = Utils.clamp((x - 5) / (root.width - 10), 0, 1) * root.max;
            root.shown = v / root.max;
            root.moved(v);
        }

        onPressed: mouse => update(mouse.x)
        onPositionChanged: mouse => { if (pressed) update(mouse.x); }
        onWheel: wheel => {
            const up = wheel.angleDelta.y > 0;
            // scrolling never pushes past the soft limit; above it (dragged there) it only goes down
            if (up && root.value >= root.softMax)
                return;
            root.moved(Utils.clamp(root.value + (up ? root.step : -root.step), 0, up ? root.softMax : root.max));
        }
    }
}
