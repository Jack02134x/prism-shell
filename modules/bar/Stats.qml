pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services
import qs.widgets

// CPU / RAM / temperature mini-rings. Click for the system monitor.
RowLayout {
    id: root

    spacing: 10

    Repeater {
        model: [
            { icon: "chip", value: () => SysStats.cpu, label: () => Math.round(SysStats.cpu * 100) + "%", tip: "CPU", accent: 0 },
            { icon: "memory", value: () => SysStats.mem, label: () => Math.round(SysStats.mem * 100) + "%", tip: "Memory", accent: 3 },
            { icon: "thermometer", value: () => SysStats.cpuTemp / 100, label: () => Math.round(SysStats.cpuTemp) + "°", tip: "CPU temp", accent: 6 }
        ]

        delegate: Item {
            id: stat
            required property var modelData
            readonly property real v: modelData.value()
            readonly property color c: v > 0.85 ? Theme.error : Theme.accent(modelData.accent)
            implicitWidth: rowItem.implicitWidth
            implicitHeight: 28

            RowLayout {
                id: rowItem
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                Ring {
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    value: Math.round(stat.v * 50) / 50
                    animated: false
                    thickness: 2.6
                    color: stat.c
                    Icon {
                        anchors.centerIn: parent
                        icon: stat.modelData.icon
                        size: 11
                        color: stat.c
                        bounce: false
                    }
                }
                Txt {
                    text: stat.modelData.label()
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.family: Theme.mono
                    color: Theme.fg
                    Layout.minimumWidth: 28
                }
            }

            HoverHandler {
                id: hh
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: Panels.openDashboard(2)
            }
            Tip {
                text: stat.modelData.tip
                show: hh.hovered
            }
        }
    }
}
