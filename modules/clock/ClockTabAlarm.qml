import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services
import qs.widgets

// Groups first, then the alarms that aren't in one; + adds either.
Item {
    id: root

    property var win
    readonly property var loose: Chrono.d.alarms.filter(a => !a.group || !Chrono.groupById(a.group)).sort((a, b) => a.h * 60 + a.m - b.h * 60 - b.m)

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + 90
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            x: 16
            width: parent.width - 32
            spacing: 8

            Txt {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.bottomMargin: 2
                visible: Chrono.nextAlarm !== null
                text: Chrono.nextAlarm ? "Next: " + Chrono.fmtWhen(Chrono.nextAlarm.at) + " · in " + Chrono.untilText(Chrono.nextAlarm.inMs) : ""
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Theme.primary
            }
            Repeater {
                model: Chrono.d.groups
                GroupCard {
                    required property var modelData
                    Layout.fillWidth: true
                    win: root.win
                    group: modelData
                }
            }
            Repeater {
                model: root.loose
                AlarmRow {
                    required property var modelData
                    Layout.fillWidth: true
                    win: root.win
                    alarm: modelData
                }
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: Chrono.d.alarms.length === 0 && Chrono.d.groups.length === 0
        spacing: 8
        Icon {
            Layout.alignment: Qt.AlignHCenter
            icon: "alarm_plus"
            size: 44
            color: Theme.fgDim
        }
        Txt {
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            text: "No alarms yet.\nAdd an alarm, or a group of alarms\nyou can switch on together."
            font.pixelSize: 13
            color: Theme.fgDim
        }
    }

    // the + button
    Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 18
        width: 58
        height: 58
        radius: Theme.r.lg
        color: Theme.primaryContainer
        Icon {
            anchors.centerIn: parent
            icon: "plus"
            size: 26
            color: Theme.fgPrimaryContainer
        }
        Interactive {
            radius: parent.radius
            tint: Theme.fgPrimaryContainer
            onClicked: root.win.openSheet("add")
        }
    }
}
