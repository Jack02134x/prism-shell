import QtQuick
import qs.common

// Surface gradient that leans toward the wallpaper's own colours at both ends,
// so panels pick up the wallpaper instead of sitting flat on top of it.
Gradient {
    id: g

    property color base: Theme.surface
    property real amount: 0.16
    property real alpha: 1
    property color from: Theme.grad1
    property color to: Theme.grad2

    orientation: Gradient.Horizontal

    GradientStop { position: 0; color: Theme.alpha(Theme.mix(g.base, g.from, g.amount), g.alpha) }
    GradientStop { position: 0.5; color: Theme.alpha(Theme.mix(g.base, g.from, g.amount * 0.25), g.alpha) }
    GradientStop { position: 1; color: Theme.alpha(Theme.mix(g.base, g.to, g.amount), g.alpha) }
}
