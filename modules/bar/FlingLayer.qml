import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common

// A full-screen, click-through overlay that draws a notification torn out of
// the island while it's dragged and thrown (the island's own window is only as
// big as the bar). `island` drives it: position, tilt and fade.
PanelWindow {
    id: win

    required property var island

    screen: island.QsWindow.window?.screen ?? null
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "prism-fling"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    // input goes straight through
    mask: Region {}

    Image {
        x: win.island.flyOrigin.x + win.island.fx
        y: win.island.flyOrigin.y + win.island.fy
        width: win.island.flySize.width
        height: win.island.flySize.height
        source: win.island.flyShot?.url ?? ""
        rotation: win.island.rot
        opacity: win.island.flyAlpha
        scale: win.island.thrown ? 1 : 1.03 // lifted a little while held
        smooth: true
        antialiasing: true
        Behavior on scale { NumberAnimation { duration: 120 } }

        // a soft shadow so it reads as picked up
        Rectangle {
            visible: parent.status === Image.Ready
            z: -1
            anchors.fill: parent
            anchors.margins: -6
            anchors.topMargin: 2
            radius: Math.min(height / 2, 34)
            color: Qt.rgba(0, 0, 0, 0.22 * win.island.flyAlpha)
        }
    }

    // YEET! (on some throws): pops where it was let go, wobbles, floats up, fades
    Text {
        id: yeet
        readonly property real t: win.island.flyT
        readonly property bool pixel: Qt.fontFamilies().indexOf(Theme.pixel) >= 0
        visible: win.island.yeet && win.island.thrown
        x: win.island.yeetPos.x - width / 2
        y: win.island.yeetPos.y - height / 2 - t * 70
        text: "YEET!"
        font.family: pixel ? Theme.pixel : Theme.display
        font.pixelSize: pixel ? 64 : 72
        font.weight: Font.Black
        font.italic: !pixel
        color: Theme.grad1
        style: Text.Outline
        styleColor: "#1a1a1a"
        // overshoot in, a little wobble, then fade out
        scale: t < 0.16 ? 0.3 + 1.05 * Math.sin(t / 0.16 * Math.PI / 2) * 1.12 : 1.18 - Math.min(0.18, (t - 0.16) * 0.5)
        rotation: win.island.yeetTilt + Math.sin(t * 22) * 4 * Math.max(0, 1 - t * 1.6)
        opacity: t < 0.7 ? 1 : Math.max(0, 1 - (t - 0.7) / 0.32)

        // a second, offset copy for a punchy drop shadow
        Text {
            z: -1
            x: 4
            y: 5
            text: parent.text
            font: parent.font
            color: Qt.rgba(0, 0, 0, 0.35)
        }
    }
}
