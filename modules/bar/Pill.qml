import QtQuick
import qs.common
import qs.widgets

// Glass pill with a slowly rotating spectrum border.
Rectangle {
    id: root

    property real glow: 0.28
    property real phase: 0
    property int speed: 1

    radius: height / 2
    gradient: TintGradient { base: Theme.surface; alpha: Config.bar.opacity; amount: 0.22 }
    border.width: 0

    GlowBorder {
        z: -1
        radius: root.radius
        pad: 8
        thickness: 1.4
        glow: root.glow
        phase: root.phase
        speed: root.speed
    }
}
