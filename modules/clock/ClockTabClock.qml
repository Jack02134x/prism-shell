import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services
import qs.widgets

// The time (running fast if fast mode is on: hold it to see the real time),
// the next alarm, and other cities.
Flickable {
    id: root

    property var win
    property bool peeking: false

    readonly property real offset: peeking ? 0 : Chrono.fastOffset()
    readonly property var shown: new Date(Chrono.now + offset)
    readonly property var parts: Chrono.fmt(shown.getHours(), shown.getMinutes())
    readonly property int localOffset: -new Date(Chrono.now).getTimezoneOffset()

    contentHeight: col.implicitHeight + 24
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: col
        x: 20
        width: root.width - 40
        spacing: 10

        // ---- the time ----
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 150
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 14
                spacing: 6
                Txt {
                    text: root.parts.t
                    font.family: Theme.display
                    font.pixelSize: 84
                    font.weight: Font.Light
                    font.features: { "tnum": 1 }
                    color: root.peeking ? Theme.tertiary : Theme.fg
                    Behavior on color { ColAnim {} }
                }
                Column {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 16
                    Txt {
                        visible: Chrono.d.settings.secs
                        text: Chrono.pad(root.shown.getSeconds())
                        font.family: Theme.display
                        font.pixelSize: 26
                        font.weight: Font.Light
                        color: Theme.fgDim
                    }
                    Txt {
                        visible: root.parts.ap !== ""
                        text: root.parts.ap
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: Theme.fgDim
                    }
                }
            }
            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 112
                text: Qt.formatDate(root.shown, "dddd, d MMMM")
                font.pixelSize: 15
                color: Theme.fgDim
            }
            MouseArea {
                anchors.fill: parent
                enabled: Chrono.d.settings.fast
                onPressed: root.peeking = true
                onReleased: root.peeking = false
                onCanceled: root.peeking = false
            }
        }
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            visible: Chrono.d.settings.fast
            implicitWidth: badge.implicitWidth + 24
            implicitHeight: 26
            radius: 13
            color: Theme.alpha(root.peeking ? Theme.tertiary : Theme.primary, 0.16)
            Txt {
                id: badge
                anchors.centerIn: parent
                text: root.peeking ? "real time" : "running fast · hold the time to peek"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: root.peeking ? Theme.tertiary : Theme.primary
            }
        }

        // ---- next alarm ----
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 6
            implicitHeight: 52
            radius: Theme.r.lg
            color: Theme.alpha(Theme.surfaceHighest, 0.5)
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12
                Icon {
                    icon: Chrono.nextAlarm ? "alarm" : "alarm_off"
                    size: 20
                    color: Chrono.nextAlarm ? Theme.primary : Theme.fgDim
                }
                Txt {
                    Layout.fillWidth: true
                    text: Chrono.nextAlarm ? Chrono.nextAlarm.label + " · " + Chrono.fmtWhen(Chrono.nextAlarm.at) : "No alarms on"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Txt {
                    visible: Chrono.nextAlarm !== null
                    text: Chrono.nextAlarm ? "in " + Chrono.untilText(Chrono.nextAlarm.inMs) : ""
                    font.pixelSize: 12
                    color: Theme.fgDim
                }
            }
            Interactive {
                radius: parent.radius
                onClicked: Chrono.setTab("alarm")
            }
        }

        // ---- other cities ----
        Txt {
            Layout.topMargin: 10
            visible: Chrono.d.cities.length > 0
            text: "WORLD"
            font.pixelSize: 11
            font.weight: Font.Black
            font.letterSpacing: 1.5
            color: Theme.fgDim
        }
        Repeater {
            model: Chrono.d.cities
            Rectangle {
                id: city
                required property string modelData
                readonly property int off: Chrono.zoneOffsets[modelData] ?? 0
                readonly property bool known: Chrono.zoneOffsets[modelData] !== undefined
                readonly property var t: new Date(Chrono.now + (off - root.localOffset) * 60000)
                readonly property int diff: off - root.localOffset
                readonly property int dayDiff: Math.round((new Date(t.getFullYear(), t.getMonth(), t.getDate()) - new Date(new Date(Chrono.now).getFullYear(), new Date(Chrono.now).getMonth(), new Date(Chrono.now).getDate())) / 86400000)
                Layout.fillWidth: true
                implicitHeight: 62
                radius: Theme.r.lg
                color: Theme.alpha(Theme.surfaceHighest, cityHover.hovered ? 0.6 : 0.4)
                HoverHandler {
                    id: cityHover
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 12
                    spacing: 8
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Txt {
                            Layout.fillWidth: true
                            text: Chrono.cityName(city.modelData)
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }
                        Txt {
                            Layout.fillWidth: true
                            text: !city.known ? "…" : (city.dayDiff > 0 ? "Tomorrow" : city.dayDiff < 0 ? "Yesterday" : "Today") + ", " + (city.diff === 0 ? "same time" : (city.diff > 0 ? "+" : "−") + Math.floor(Math.abs(city.diff) / 60) + "h" + (Math.abs(city.diff) % 60 ? " " + Math.abs(city.diff) % 60 + "m" : ""))
                            font.pixelSize: 11
                            color: Theme.fgDim
                        }
                    }
                    Txt {
                        text: city.known ? Chrono.fmtClock(city.t.getHours(), city.t.getMinutes()) : ""
                        font.family: Theme.display
                        font.pixelSize: 26
                        font.weight: Font.Light
                    }
                    IconBtn {
                        icon: "close"
                        size: 26
                        opacity: cityHover.hovered ? 1 : 0
                        tooltip: "Remove"
                        onClicked: Chrono.removeCity(city.modelData)
                    }
                }
            }
        }
        Btn {
            Layout.fillWidth: true
            Layout.topMargin: 4
            icon: "earth"
            text: "Add a city"
            filled: false
            onClicked: root.win.openSheet("city")
        }
    }
}
