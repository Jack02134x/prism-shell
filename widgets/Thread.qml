import QtQuick
import QtQuick.Shapes
import qs.common

// One string of the screenshot tool, tied at `from` and pulled to `to`.
// Its middle is a damped spring: it sags a little, trails behind when the end
// moves and rings when plucked. The spring only ticks while it's moving.
Shape {
    id: root

    property point from
    property point to
    property color color: Theme.grad1
    property real thickness: 2
    property real slack: 0.05 // sag, as a share of the length

    // the middle point (absolute) and its velocity
    property real px: (from.x + to.x) / 2
    property real py: (from.y + to.y) / 2
    property real vx: 0
    property real vy: 0
    property bool awake: true

    readonly property real len: Math.hypot(to.x - from.x, to.y - from.y)
    readonly property real restX: (from.x + to.x) / 2
    readonly property real restY: (from.y + to.y) / 2 + len * slack

    // a sideways kick, as a share of the length
    function pluck(amount) {
        if (len < 1)
            return;
        const nx = -(to.y - from.y) / len, ny = (to.x - from.x) / len;
        const kick = len * amount * 9;
        vx += nx * kick;
        vy += ny * kick;
        awake = true;
    }

    onToChanged: awake = true
    onFromChanged: awake = true

    FrameAnimation {
        running: root.awake && root.visible
        onTriggered: {
            const dt = Math.min(frameTime, 1 / 30);
            const k = 170, c = 11; // stiffness, damping (under-damped: it wobbles)
            const ax = k * (root.restX - root.px) - c * root.vx;
            const ay = k * (root.restY - root.py) - c * root.vy;
            root.vx += ax * dt;
            root.vy += ay * dt;
            root.px += root.vx * dt;
            root.py += root.vy * dt;
            if (Math.abs(root.vx) + Math.abs(root.vy) < 0.5 && Math.abs(root.restX - root.px) + Math.abs(root.restY - root.py) < 0.3) {
                root.px = root.restX;
                root.py = root.restY;
                root.vx = root.vy = 0;
                root.awake = false;
            }
        }
    }

    preferredRendererType: Shape.CurveRenderer

    // soft glow under the line
    ShapePath {
        strokeColor: Theme.alpha(root.color, 0.22)
        strokeWidth: root.thickness * 4
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        startX: root.from.x
        startY: root.from.y
        PathQuad {
            // passes through the spring point halfway along
            x: root.to.x
            y: root.to.y
            controlX: 2 * root.px - (root.from.x + root.to.x) / 2
            controlY: 2 * root.py - (root.from.y + root.to.y) / 2
        }
    }
    ShapePath {
        strokeColor: root.color
        strokeWidth: root.thickness
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        startX: root.from.x
        startY: root.from.y
        PathQuad {
            x: root.to.x
            y: root.to.y
            controlX: 2 * root.px - (root.from.x + root.to.x) / 2
            controlY: 2 * root.py - (root.from.y + root.to.y) / 2
        }
    }
}
