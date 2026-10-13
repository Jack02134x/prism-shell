import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

// Full-screen layer surface on the focused monitor used by every popup panel.
// `progress` animates 0 -> 1 when opened; the window stays mapped until the
// closing animation finishes. Esc or a click on the scrim calls dismiss().
// Panels are created on demand (see Lazy in shell.qml), usually already open,
// so the open animation and opened() also run on creation.
PanelWindow {
    id: win

    property bool open: false
    property string name: "overlay"
    property bool keyboard: true
    property real scrimOpacity: 0.45
    property bool closeOnScrim: true
    property int openDuration: Motion.slow
    property int closeDuration: Motion.normal
    default property alias content: contentScope.data
    readonly property Item contentRoot: contentScope

    property var targetScreen: null
    property real progress: 0

    signal dismiss
    signal opened

    Behavior on progress {
        NumberAnimation {
            duration: win.open ? win.openDuration : win.closeDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: win.open ? Motion.decel : Motion.accel
        }
    }

    function handleOpen() {
        targetScreen = Panels.focusedScreen;
        Qt.callLater(() => win.opened());
    }
    onOpenChanged: if (open) handleOpen()
    Component.onCompleted: {
        if (open)
            handleOpen();
        // bind after creation so a panel created open still animates in from 0
        progress = Qt.binding(() => open ? 1 : 0);
    }

    screen: targetScreen ?? Panels.focusedScreen
    visible: (open || progress > 0.001) && !Panels.capturing
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "prism-" + name
    WlrLayershell.keyboardFocus: open && keyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: win.scrimOpacity * win.progress

        MouseArea {
            anchors.fill: parent
            enabled: win.open
            acceptedButtons: Qt.AllButtons
            onClicked: if (win.closeOnScrim) win.dismiss()
        }
    }

    FocusScope {
        id: contentScope
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: win.dismiss()
    }
}
