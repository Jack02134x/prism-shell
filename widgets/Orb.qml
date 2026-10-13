import QtQuick
import qs.common

// Wobbling plasma orb (shader). Feed `level` 0..1 to make it pulse with audio.
ShaderEffect {
    id: root

    property real level: 0
    property int speed: 3
    property color c1: Theme.primary
    property color c2: Theme.accent(4)
    property color c3: Theme.tertiary

    readonly property real time: (Motion.t * speed) % 1

    implicitWidth: 28
    implicitHeight: 28
    fragmentShader: Qt.resolvedUrl("../shaders/orb.frag.qsb")
}
