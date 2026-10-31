import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services
import qs.widgets

// One alarm: its time, label and repeat; click to edit, switch to turn on/off.
Rectangle {
    id: root

    property var win
    property var alarm
    property bool inGroup: false

    readonly property var f: Chrono.fmt(alarm.h, alarm.m)
    implicitHeight: 70
    radius: Theme.r.lg
    color: inGroup ? "transparent" : Theme.alpha(Theme.surfaceHighest, 0.45)

    Interactive {
        radius: root.radius
        onClicked: root.win.editAlarm(root.alarm)
    }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 14
        spacing: 10
        opacity: root.alarm.on ? 1 : 0.5
        Behavior on opacity { NumAnim {} }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Row {
                spacing: 4
                Txt {
                    text: root.f.t
                    font.family: Theme.display
                    font.pixelSize: 30
                    font.weight: Font.Normal
                }
                Txt {
                    y: 14
                    visible: root.f.ap !== ""
                    text: root.f.ap
                    font.pixelSize: 13
                    color: Theme.fgDim
                }
            }
            Txt {
                Layout.fillWidth: true
                text: [root.alarm.label, Chrono.repeatText(root.alarm), root.alarm.on && root.alarm.skip > Chrono.now ? "skipping next" : "", root.alarm.on && root.alarm.snoozeTo > Chrono.now ? "snoozed till " + Chrono.fmtWhen(root.alarm.snoozeTo) : ""].filter(s => s).join(" · ")
                font.pixelSize: 12
                color: Theme.fgDim
            }
        }
        StyledSwitch {
            checked: root.alarm.on
            onToggled: v => {
                const due = Chrono.setAlarmOn(root.alarm.id, v);
                if (v && due)
                    root.win.toast("Rings in " + Chrono.untilText(due - Date.now()));
            }
        }
    }
}
