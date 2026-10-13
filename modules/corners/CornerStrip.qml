pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.common

// A thin click-through strip along the top or bottom screen edge that draws the
// two rounded screen corners at its ends.
PanelWindow {
    id: strip

    property bool isTop: true
    readonly property real r: Config.fx.cornerRadius

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "prism-corners"
    implicitHeight: Math.max(r, 3)
    anchors.top: strip.isTop
    anchors.bottom: !strip.isTop
    anchors.left: true
    anchors.right: true
    mask: Region {}

    Repeater {
        model: Config.fx.corners ? [true, false] : []

        Shape {
            required property bool modelData
            readonly property bool isLeft: modelData
            width: strip.r
            height: strip.r
            x: isLeft ? 0 : strip.width - width
            y: strip.isTop ? 0 : strip.height - height
            preferredRendererType: Shape.CurveRenderer
            rotation: strip.isTop ? (isLeft ? 0 : 90) : (isLeft ? 270 : 180)

            ShapePath {
                fillColor: "black"
                strokeColor: "transparent"
                startX: 0
                startY: 0
                PathLine { x: strip.r; y: 0 }
                PathArc {
                    x: 0
                    y: strip.r
                    radiusX: strip.r
                    radiusY: strip.r
                    direction: PathArc.Counterclockwise
                }
                PathLine { x: 0; y: 0 }
            }
        }
    }
}
