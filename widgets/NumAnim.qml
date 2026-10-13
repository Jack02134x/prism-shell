import QtQuick
import qs.common

NumberAnimation {
    duration: Motion.normal
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Motion.decel
}
