import QtQuick
import QtQuick.Shapes
import qs.common

// Circular progress ring (0..1) with rounded caps and an animated sweep.
Item {
    id: root

    property real value: 0
    property real thickness: 4
    property color color: Theme.primary
    property color trackColor: Theme.alpha(Theme.fg, 0.1)
    property real startAngle: -90

    // animating every sample forces full-rate redraws; bar rings turn it off
    property bool animated: true
    property real shown: Utils.clamp(value, 0, 1)
    Behavior on shown {
        enabled: root.animated
        NumAnim { duration: Motion.slow }
    }

    implicitWidth: 32
    implicitHeight: 32

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.trackColor
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.width / 2 - root.thickness / 2
                radiusY: root.height / 2 - root.thickness / 2
                startAngle: 0
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.width / 2 - root.thickness / 2
                radiusY: root.height / 2 - root.thickness / 2
                startAngle: root.startAngle
                sweepAngle: 360 * root.shown
            }
        }
    }
}
