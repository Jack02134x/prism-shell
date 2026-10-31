import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services
import qs.widgets

// A named set of alarms. Click the name to switch them all on (or, if all are
// on, off); the arrow shows them.
Rectangle {
    id: root

    property var win
    property var group

    readonly property var m: Chrono.members(group.id)
    readonly property int onCount: m.filter(a => a.on).length
    readonly property string state: !m.length || !onCount ? "off" : onCount === m.length ? "on" : "partial"
    readonly property bool open: Chrono.d.win.openGroups.indexOf(group.id) >= 0
    readonly property var next: {
        const due = m.filter(a => a.on && a.due).map(a => a.due);
        return due.length ? Math.min(...due) : 0;
    }

    implicitHeight: col.implicitHeight
    radius: Theme.r.lg
    color: Theme.alpha(state === "off" ? Theme.surfaceHighest : Theme.primary, state === "off" ? 0.45 : 0.12)
    border.width: 1
    border.color: Theme.alpha(Theme.primary, state === "on" ? 0.55 : state === "partial" ? 0.25 : 0)
    Behavior on color { ColAnim {} }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 66
            spacing: 4
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Interactive {
                    radius: root.radius
                    onClicked: {
                        const msg = Chrono.toggleGroup(root.group.id);
                        if (msg === "") {
                            Chrono.setGroupOpen(root.group.id, true);
                            root.win.toast(root.group.name + " has no alarms yet");
                        } else {
                            root.win.toast(msg);
                        }
                    }
                }
                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    RowLayout {
                        spacing: 8
                        Icon {
                            icon: "folder_clock_outline"
                            size: 17
                            color: root.state === "off" ? Theme.fgDim : Theme.primary
                        }
                        Txt {
                            text: root.group.name
                            font.pixelSize: 16
                            font.weight: Font.Bold
                        }
                    }
                    Txt {
                        Layout.fillWidth: true
                        text: !root.m.length ? "No alarms yet" : (root.onCount ? root.onCount + " of " + root.m.length + " on" : "Off") + " · " + root.m.length + (root.m.length > 1 ? " alarms" : " alarm") + (root.next ? " · next " + Chrono.fmtWhen(root.next) : "")
                        font.pixelSize: 12
                        color: Theme.fgDim
                    }
                }
            }
            IconBtn {
                icon: "dots_horizontal"
                size: 34
                tooltip: "Group settings"
                onClicked: root.win.openSheet("group", JSON.parse(JSON.stringify(root.group)))
            }
            IconBtn {
                Layout.rightMargin: 8
                icon: "chevron_down"
                size: 34
                rotation: root.open ? 180 : 0
                Behavior on rotation { NumAnim {} }
                onClicked: Chrono.setGroupOpen(root.group.id, !root.open)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            Layout.bottomMargin: 8
            visible: root.open
            spacing: 0
            Repeater {
                model: root.open ? root.m : []
                AlarmRow {
                    required property var modelData
                    Layout.fillWidth: true
                    win: root.win
                    alarm: modelData
                    inGroup: true
                }
            }
            Btn {
                Layout.fillWidth: true
                Layout.topMargin: 4
                icon: "plus"
                text: "Add an alarm to " + root.group.name
                filled: false
                onClicked: root.win.editAlarm(null, root.group.id)
            }
        }
    }
}
