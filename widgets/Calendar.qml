pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.common

// Month calendar with animated month switching (scroll or arrows).
ColumnLayout {
    id: root

    property date today: new Date()
    property int offset: 0
    readonly property date month: new Date(today.getFullYear(), today.getMonth() + offset, 1)
    property int slideDir: 1

    spacing: 8

    function shift(d) {
        slideDir = d;
        offset += d;
        slide.restart();
    }

    RowLayout {
        Layout.fillWidth: true
        Txt {
            Layout.fillWidth: true
            text: Qt.formatDate(root.month, "MMMM yyyy")
            font.pixelSize: 15
            font.weight: Font.Bold
            font.family: Theme.display
        }
        IconBtn {
            visible: root.offset !== 0
            icon: "calendar_today"
            size: 28
            iconSize: 14
            tooltip: "Today"
            onClicked: {
                root.slideDir = root.offset > 0 ? -1 : 1;
                root.offset = 0;
                slide.restart();
            }
        }
        IconBtn {
            icon: "chevron_left"
            size: 28
            onClicked: root.shift(-1)
        }
        IconBtn {
            icon: "chevron_right"
            size: 28
            onClicked: root.shift(1)
        }
    }

    Grid {
        id: grid
        Layout.fillWidth: true
        columns: 7
        rowSpacing: 4
        columnSpacing: 0
        readonly property real cell: width / 7

        Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            Txt {
                required property string modelData
                required property int index
                width: grid.cell
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                font.pixelSize: 11
                font.weight: Font.Bold
                color: index >= 5 ? Theme.accent(7) : Theme.fgDim
            }
        }

        Repeater {
            model: 42
            Item {
                id: day
                required property int index
                readonly property int lead: (root.month.getDay() + 6) % 7
                readonly property date date: new Date(root.month.getFullYear(), root.month.getMonth(), index - lead + 1)
                readonly property bool inMonth: date.getMonth() === root.month.getMonth()
                readonly property bool isToday: date.toDateString() === root.today.toDateString()
                width: grid.cell
                height: 30

                Rectangle {
                    anchors.centerIn: parent
                    width: 30
                    height: 30
                    radius: day.isToday ? 10 : 15
                    color: day.isToday ? Theme.accent(day.date.getDate()) : dayHover.hovered ? Theme.alpha(Theme.fg, 0.08) : "transparent"
                    rotation: day.isToday ? 45 * 0 : 0
                }
                Txt {
                    anchors.centerIn: parent
                    text: day.date.getDate()
                    font.pixelSize: 12
                    font.weight: day.isToday ? Font.Black : Font.Medium
                    color: day.isToday ? Theme.on(Theme.accent(day.date.getDate())) : day.inMonth ? Theme.fg : Theme.alpha(Theme.fgDim, 0.35)
                }
                HoverHandler {
                    id: dayHover
                }
            }
        }

        transform: Translate { id: gridT }
        SequentialAnimation {
            id: slide
            ParallelAnimation {
                NumberAnimation { target: gridT; property: "x"; from: 40 * root.slideDir; to: 0; duration: Motion.slow; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.spatial }
                NumberAnimation { target: grid; property: "opacity"; from: 0; to: 1; duration: Motion.normal }
            }
        }

        WheelHandler {
            onWheel: event => root.shift(event.angleDelta.y > 0 ? -1 : 1)
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root.today = new Date()
    }
}
