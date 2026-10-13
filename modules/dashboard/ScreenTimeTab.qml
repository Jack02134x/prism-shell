pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.common
import qs.services
import qs.widgets

// Screen time from a hypr-screentime tracker (Config.paths.screentime, read-only).
Item {
    id: root

    property bool active: false
    readonly property var topApps: ScreenTime.apps.slice(0, 7)
    readonly property real topSum: topApps.reduce((a, b) => a + b.total, 0)
    property real grow: active ? 1 : 0
    Behavior on grow { NumAnim { duration: 1100; easing.bezierCurve: Motion.decel } }

    RowLayout {
        anchors.fill: parent
        spacing: 14

        // ---- left: donut + list ----
        Card {
            Layout.preferredWidth: 470
            Layout.fillHeight: true
            shown: root.active

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                RowLayout {
                    SectionTitle {
                        Layout.fillWidth: true
                        icon: "timer_outline"
                        text: "Today"
                        accent: Theme.accent(4)
                    }
                    Rectangle {
                        visible: ScreenTime.liveApp !== ""
                        implicitHeight: 24
                        implicitWidth: live.implicitWidth + 20
                        radius: 12
                        color: Theme.alpha(Theme.accent(2), 0.16)
                        RowLayout {
                            id: live
                            anchors.centerIn: parent
                            spacing: 6
                            Rectangle {
                                implicitWidth: 7
                                implicitHeight: 7
                                radius: 4
                                color: ScreenTime.liveState === "active" ? "#7dee9b" : Theme.fgDim
                                SequentialAnimation on opacity {
                                    running: root.active && ScreenTime.liveState === "active"
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.3; duration: 700 }
                                    NumberAnimation { to: 1; duration: 700 }
                                }
                            }
                            Txt {
                                text: ScreenTime.liveApp + (ScreenTime.liveDetail ? " · " + ScreenTime.liveDetail : "")
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: Theme.accent(2)
                                Layout.maximumWidth: 220
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 230

                    Repeater {
                        model: root.topApps
                        Shape {
                            id: seg
                            required property var modelData
                            required property int index
                            readonly property real start: root.topApps.slice(0, index).reduce((a, b) => a + b.total, 0) / Math.max(1, root.topSum)
                            readonly property real frac: modelData.total / Math.max(1, root.topSum)
                            anchors.centerIn: parent
                            width: 220
                            height: 220
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                strokeColor: Theme.accent(seg.index * 3 % 10)
                                strokeWidth: 26
                                fillColor: "transparent"
                                capStyle: ShapePath.FlatCap
                                PathAngleArc {
                                    centerX: 110
                                    centerY: 110
                                    radiusX: 92
                                    radiusY: 92
                                    startAngle: -90 + 360 * seg.start * root.grow + 1
                                    sweepAngle: Math.max(0, 360 * seg.frac * root.grow - 2)
                                }
                            }
                        }
                    }
                    Column {
                        anchors.centerIn: parent
                        Txt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Utils.human(ScreenTime.today * root.grow)
                            font.pixelSize: 30
                            font.weight: Font.Black
                            font.family: Theme.display
                        }
                        Txt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "avg " + Utils.human(ScreenTime.weekAvg) + " / day"
                            font.pixelSize: 11
                            color: Theme.fgDim
                        }
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 8
                    model: ScreenTime.apps
                    delegate: ColumnLayout {
                        id: app
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        spacing: 3
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Rectangle {
                                implicitWidth: 10
                                implicitHeight: 10
                                radius: 3
                                color: app.index < 7 ? Theme.accent(app.index * 3 % 10) : Theme.outline
                            }
                            AppIcon {
                                size: 16
                                source: Hypr.iconFor(app.modelData.name.toLowerCase())
                            }
                            Txt {
                                Layout.fillWidth: true
                                text: app.modelData.name
                                font.weight: Font.DemiBold
                            }
                            Txt {
                                text: Utils.human(app.modelData.total)
                                font.family: Theme.mono
                                font.pixelSize: 12
                                color: Theme.fgDim
                            }
                        }
                        Txt {
                            Layout.fillWidth: true
                            Layout.leftMargin: 42
                            text: app.modelData.details.map(d => d.name + " " + Utils.human(d.total)).join("  ·  ")
                            font.pixelSize: 10
                            color: Theme.fgDim
                        }
                    }
                }
            }
        }

        // ---- right: hourly + week ----
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                shown: root.active
                delay: 80
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 10
                    SectionTitle {
                        icon: "clock_outline"
                        text: "By hour"
                        accent: Theme.accent(6)
                    }
                    RowLayout {
                        id: hourRow
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 4
                        readonly property real peak: Math.max(1, ...ScreenTime.hours)
                        Repeater {
                            model: 24
                            ColumnLayout {
                                id: hr
                                required property int index
                                readonly property real v: ScreenTime.hours[index] / hourRow.peak
                                readonly property bool now: new Date().getHours() === index
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 4
                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        height: Math.max(3, parent.height * hr.v * root.grow)
                                        radius: 4
                                        gradient: Gradient {
                                            GradientStop { position: 0; color: Theme.accent(Math.floor(hr.index / 2.4)) }
                                            GradientStop { position: 1; color: Theme.alpha(Theme.accent(Math.floor(hr.index / 2.4)), 0.35) }
                                        }
                                        border.width: hr.now ? 2 : 0
                                        border.color: Theme.fg
                                    }
                                }
                                Txt {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: hr.index % 3 === 0 ? hr.index : ""
                                    font.pixelSize: 9
                                    color: Theme.fgDim
                                }
                            }
                        }
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                Layout.preferredHeight: 230
                shown: root.active
                delay: 140
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 10
                    RowLayout {
                        SectionTitle {
                            Layout.fillWidth: true
                            icon: "calendar_week"
                            text: "Last 7 days"
                            accent: Theme.accent(8)
                        }
                        Btn {
                            icon: "open_in_new"
                            text: "Full tracker"
                            filled: false
                            implicitHeight: 30
                            fontSize: 12
                            onClicked: {
                                Panels.dashboard = false;
                                ScreenTime.openGui();
                            }
                        }
                    }
                    RowLayout {
                        id: weekRow
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 12
                        readonly property real peak: Math.max(1, ...ScreenTime.week.map(d => d.total))
                        Repeater {
                            model: ScreenTime.week
                            ColumnLayout {
                                id: wd
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 4
                                Txt {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: wd.modelData.total > 0 ? Utils.human(wd.modelData.total) : ""
                                    font.pixelSize: 9
                                    font.family: Theme.mono
                                    color: Theme.fgDim
                                }
                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: Math.min(parent.width, 46)
                                        height: Math.max(4, parent.height * wd.modelData.total / weekRow.peak * root.grow)
                                        radius: 10
                                        color: wd.index === 6 ? Theme.accent(8) : Theme.alpha(Theme.accent(wd.index + 1), 0.55)
                                    }
                                }
                                Txt {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: wd.modelData.label
                                    font.pixelSize: 10
                                    font.weight: wd.index === 6 ? Font.Black : Font.Medium
                                    color: wd.index === 6 ? Theme.accent(8) : Theme.fgDim
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Txt {
        anchors.centerIn: parent
        visible: !ScreenTime.available
        text: "No screen time data found at " + ScreenTime.usagePath
        color: Theme.fgDim
    }
}
