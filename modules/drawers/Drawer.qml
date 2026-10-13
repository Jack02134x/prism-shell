import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.common
import qs.services
import qs.widgets

// Edge drawer you pull out from the side of the screen. A thin strip on the
// edge catches the pointer: drag inwards and the panel follows, let go past a
// third of the way and it snaps open (or rest the pointer there, if enabled).
// Drag it back, click elsewhere or press Esc to close.
PanelWindow {
    id: win

    required property var modelData
    property bool leftSide: true
    property real panelWidth: 420
    property bool open: false
    property real progress: 0
    property bool dragging: false
    property color accent: Theme.primary
    default property alias content: body.data

    signal requestOpen(bool value)

    readonly property real gap: Config.bar.margin
    readonly property bool shown: progress > 0.005

    screen: modelData
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: panelWidth + gap + 24
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "prism-drawer"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: win.leftSide
        right: !win.leftSide
    }
    margins.top: Config.bar.height + Config.bar.margin * 2

    mask: Region {
        item: win.shown ? panel : strip
    }

    onOpenChanged: {
        progress = open ? 1 : 0;
        if (open)
            escKeys.forceActiveFocus();
    }

    // Esc closes the drawer
    Item {
        id: escKeys
        focus: true
        Keys.onEscapePressed: win.requestOpen(false)
    }
    Behavior on progress {
        enabled: !win.dragging
        NumberAnimation {
            duration: Motion.slow
            easing.type: Easing.BezierSpline
            easing.bezierCurve: win.open ? Motion.spatial : Motion.accel
        }
    }

    function settle() {
        dragging = false;
        const want = progress > 0.33;
        if (want !== open)
            requestOpen(want);
        progress = want ? 1 : 0;
    }

    HyprlandFocusGrab {
        windows: [win]
        active: win.open
        onCleared: win.requestOpen(false)
    }

    // ---- edge catcher ----
    Item {
        id: strip
        width: 6
        height: parent.height - 40
        anchors.verticalCenter: parent.verticalCenter
        x: win.leftSide ? 0 : parent.width - width

        // glowing hint while hovered
        Rectangle {
            width: 4
            height: stripArea.containsMouse || win.dragging ? parent.height * 0.6 : 0
            anchors.verticalCenter: parent.verticalCenter
            x: win.leftSide ? 1 : 1
            radius: 2
            opacity: 0.8
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.accent(0) }
                GradientStop { position: 0.5; color: win.accent }
                GradientStop { position: 1; color: Theme.accent(6) }
            }
            Behavior on height { NumAnim { duration: Motion.normal; easing.bezierCurve: Motion.spatial } }
        }

        MouseArea {
            id: stripArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            property real startX: 0
            onEntered: if (Config.drawers.hoverOpen) dwell.restart()
            onExited: dwell.stop()
            onPressed: mouse => {
                dwell.stop();
                startX = mapToItem(null, mouse.x, 0).x;
                win.dragging = true;
            }
            onPositionChanged: mouse => {
                if (!pressed)
                    return;
                const x = mapToItem(null, mouse.x, 0).x;
                const d = win.leftSide ? x - startX : startX - x;
                win.progress = Utils.clamp(d / win.panelWidth, 0, 1);
            }
            onReleased: {
                if (win.progress < 0.02)
                    win.progress = 0.4; // a plain click opens it
                win.settle();
            }
        }
        Timer {
            id: dwell
            interval: 260
            onTriggered: win.requestOpen(true)
        }
    }

    // ---- panel ----
    Rectangle {
        id: panel
        width: win.panelWidth
        height: parent.height - win.gap
        y: 0
        x: win.leftSide ? -width + (width + win.gap) * win.progress : win.width - (width + win.gap) * win.progress
        visible: win.shown
        radius: Theme.r.xl
        gradient: TintGradient { alpha: 0.95; amount: 0.16; orientation: Gradient.Vertical }
        border.width: 1
        border.color: Theme.alpha(win.accent, 0.35)
        opacity: Math.min(1, win.progress * 2)

        GlowBorder {
            z: -1
            radius: panel.radius
            pad: 14
            glow: 0.35
            c1: win.accent
        }

        Item {
            id: body
            anchors.fill: parent
            anchors.margins: 16
        }

        // grip on the inner edge: drag it back to close
        Rectangle {
            width: 5
            height: 56
            radius: 3
            anchors.verticalCenter: parent.verticalCenter
            x: win.leftSide ? parent.width - 10 : 5
            color: Theme.alpha(win.accent, gripArea.containsMouse || win.dragging ? 0.9 : 0.4)
            MouseArea {
                id: gripArea
                anchors.fill: parent
                anchors.margins: -10
                hoverEnabled: true
                cursorShape: Qt.SizeHorCursor
                property real startX: 0
                onPressed: mouse => {
                    startX = mapToItem(null, mouse.x, 0).x;
                    win.dragging = true;
                }
                onPositionChanged: mouse => {
                    if (!pressed)
                        return;
                    const x = mapToItem(null, mouse.x, 0).x;
                    const d = win.leftSide ? startX - x : x - startX;
                    win.progress = Utils.clamp(1 - d / win.panelWidth, 0, 1);
                }
                onReleased: win.settle()
            }
        }
    }
}
