import QtQuick
import qs.common

// Flowing aurora backdrop (shader). Colours default to the live palette.
ShaderEffect {
    id: root

    property real intensity: 1
    property int speed: 1
    property color c1: Theme.primary
    property color c2: Theme.tertiary
    property color c3: Theme.accent(5)
    property color bg: Theme.surfaceLowest

    readonly property real time: (Motion.t * speed) % 1
    readonly property real w: width
    readonly property real h: height

    fragmentShader: Qt.resolvedUrl("../shaders/aurora.frag.qsb")
}
