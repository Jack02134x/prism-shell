import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services
import qs.widgets

ColumnLayout {
    id: root

    property var win
    spacing: 10

    Txt {
        text: "Add"
        font.pixelSize: 18
        font.weight: Font.Bold
    }
    Repeater {
        model: [
            { id: "alarm", icon: "alarm_plus", title: "Alarm", sub: "A single alarm." },
            { id: "group", icon: "folder_clock_outline", title: "Group", sub: "A named set of alarms. Click its name to switch them all on or off together." }
        ]
        Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: row.implicitHeight + 28
            radius: Theme.r.lg
            color: Theme.alpha(Theme.surfaceHighest, 0.6)
            RowLayout {
                id: row
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14
                Icon {
                    icon: parent.parent.modelData.icon
                    size: 26
                    color: Theme.primary
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Txt {
                        text: row.parent.modelData.title
                        font.pixelSize: 15
                        font.weight: Font.Bold
                    }
                    Txt {
                        Layout.fillWidth: true
                        text: row.parent.modelData.sub
                        font.pixelSize: 12
                        color: Theme.fgDim
                        wrapMode: Text.Wrap
                        elide: Text.ElideNone
                    }
                }
            }
            Interactive {
                radius: parent.radius
                onClicked: parent.modelData.id === "alarm" ? root.win.editAlarm(null) : root.win.openSheet("group", { id: 0, name: "", tone: "" })
            }
        }
    }
}
