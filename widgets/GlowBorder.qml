import QtQuick
import qs.common

// Animated spectrum border + halo drawn by a shader around the parent's shape.
// Fill the parent; it bleeds `pad` px outside for the glow.
ShaderEffect {
    id: root

    property real pad: 10
    property real radius: 16
    property real thickness: 1.5
    property real glow: 0.35
    property int speed: 2
    property real phase: 0
    // wallpaper colours by default
    property color c1: Theme.grad1
    property color c2: Theme.primary
    property color c3: Theme.grad2
    property color c4: Theme.grad3

    anchors.fill: parent
    anchors.margins: -pad

    readonly property real time: (Motion.t * speed + phase) % 1
    readonly property real w: width
    readonly property real h: height

    fragmentShader: Qt.resolvedUrl("../shaders/border.frag.qsb")
}
