import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services
import qs.widgets

// What's ringing (an alarm, a timer, the end of intervals), at the top of the
// focused screen, above fullscreen windows. It doesn't take the keyboard, so
// typing elsewhere goes on; `qs ipc call clock stop / snooze` work as keys.
PanelWindow {
    id: win

    readonly property var r: Chrono.ringing
    property var last: null
    onRChanged: if (r) last = r

    screen: Panels.focusedScreen
    visible: r !== null
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "prism-clock-ring"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors.top: true
    margins.top: 56
    implicitWidth: 440
    implicitHeight: 112

    Rectangle {
        id: card
        anchors.fill: parent
        anchors.margins: 4
        radius: Theme.r.xl
        gradient: TintGradient { alpha: 0.97; amount: 0.2; orientation: Gradient.Vertical }
        border.width: 2
        border.color: Theme.alpha(Theme.primary, pulse.v)

        // breathe
        QtObject {
            id: pulse
            property real v: 0.5
            SequentialAnimation on v {
                running: win.visible
                loops: Animation.Infinite
                NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.35; duration: 600; easing.type: Easing.InOutSine }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 14
            spacing: 14

            Rectangle {
                implicitWidth: 56
                implicitHeight: 56
                radius: Theme.r.lg
                color: Theme.primaryContainer
                Icon {
                    anchors.centerIn: parent
                    icon: win.last?.kind === "alarm" ? "alarm" : "timer_sand_complete"
                    size: 28
                    color: Theme.fgPrimaryContainer
                    rotation: (pulse.v - 0.65) * 30
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Txt {
                    Layout.fillWidth: true
                    text: win.last?.title ?? ""
                    font.pixelSize: 18
                    font.weight: Font.Bold
                }
                Txt {
                    Layout.fillWidth: true
                    text: win.last?.sub ?? ""
                    font.pixelSize: 12
                    color: Theme.fgDim
                }
            }
            ColumnLayout {
                spacing: 6
                Btn {
                    Layout.fillWidth: true
                    visible: win.last?.kind !== "interval"
                    icon: win.last?.kind === "alarm" ? "alarm_snooze" : "plus"
                    text: win.last?.kind === "alarm" ? "Snooze " + Chrono.d.settings.snooze + "m" : "1 min"
                    filled: false
                    implicitHeight: 34
                    onClicked: Chrono.snooze()
                }
                Btn {
                    Layout.fillWidth: true
                    icon: "stop"
                    text: "Stop"
                    implicitHeight: 34
                    onClicked: Chrono.stopRinging()
                }
            }
        }
    }
}
