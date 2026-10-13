import QtQuick
import qs.common

// Surface card with an optional entrance animation (fade + rise), staggered by `delay`.
Rectangle {
    id: root

    property int delay: 0
    property bool animateIn: true
    property bool shown: true

    radius: Theme.r.lg
    gradient: TintGradient { base: Theme.surfaceContainer; alpha: 0.9; amount: 0.1; orientation: Gradient.Vertical }
    border.width: 1
    border.color: Theme.alpha(Theme.outlineVariant, 0.6)

    opacity: 0
    transform: Translate { id: tr; y: 18 }

    function enter() {
        if (!animateIn) {
            opacity = 1;
            tr.y = 0;
            return;
        }
        opacity = 0;
        tr.y = 18;
        anim.restart();
    }

    onShownChanged: if (shown) enter()
    Component.onCompleted: if (shown) enter()

    SequentialAnimation {
        id: anim
        PauseAnimation { duration: root.delay }
        ParallelAnimation {
            NumberAnimation { target: root; property: "opacity"; to: 1; duration: Motion.slow; easing.type: Easing.OutCubic }
            NumberAnimation { target: tr; property: "y"; to: 0; duration: Motion.slower; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.spatial }
        }
    }
}
