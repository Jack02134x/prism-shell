pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services
import qs.widgets

// Current conditions with a floating animated glyph, hourly strip, 3-day outlook.
Card {
    id: root

    gradient: Gradient {
        GradientStop { position: 0; color: Theme.mix(Theme.surfaceContainer, Weather.tint, 0.18) }
        GradientStop { position: 1; color: Theme.alpha(Theme.surfaceContainer, 0.9) }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Icon {
                id: glyph
                icon: Weather.icon
                size: 54
                color: Weather.tint
                transform: Translate { id: bob }
                SequentialAnimation {
                    running: root.visible && Motion.ambient
                    loops: Animation.Infinite
                    NumberAnimation { target: bob; property: "y"; to: -4; duration: 1800; easing.type: Easing.InOutSine }
                    NumberAnimation { target: bob; property: "y"; to: 4; duration: 1800; easing.type: Easing.InOutSine }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Txt {
                    text: Weather.ready ? Weather.tempText : "—"
                    font.pixelSize: 38
                    font.weight: Font.Black
                    font.family: Theme.display
                }
                Txt {
                    Layout.fillWidth: true
                    text: Weather.ready ? Weather.desc + " · feels " + Math.round(Weather.feels) + "°" : "Fetching weather…"
                    font.pixelSize: 12
                    color: Theme.fgDim
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [
                    { icon: "map_marker", t: Weather.location || "—" },
                    { icon: "water_percent", t: Weather.humidity + "%" },
                    { icon: "weather_windy", t: Math.round(Weather.wind) + " km/h" }
                ]
                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 24
                    radius: 12
                    color: Theme.alpha(Theme.fg, 0.07)
                    RowLayout {
                        anchors.centerIn: parent
                        width: parent.width - 12
                        spacing: 4
                        Icon {
                            icon: parent.parent.modelData.icon
                            size: 12
                            color: Weather.tint
                        }
                        Txt {
                            Layout.fillWidth: true
                            text: parent.parent.modelData.t
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }

        // hourly
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: Weather.hourly.slice(0, 6)
                ColumnLayout {
                    id: hour
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 2
                    Txt {
                        Layout.alignment: Qt.AlignHCenter
                        text: Utils.pad2(hour.modelData.time) + "h"
                        font.pixelSize: 10
                        color: Theme.fgDim
                    }
                    Icon {
                        Layout.alignment: Qt.AlignHCenter
                        icon: Weather.iconFor(hour.modelData.code, hour.modelData.time >= 6 && hour.modelData.time < 19)
                        size: 18
                        color: Theme.accent(hour.index + 2)
                    }
                    Txt {
                        Layout.alignment: Qt.AlignHCenter
                        text: Math.round(hour.modelData.temp) + "°"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // days
        Repeater {
            model: Weather.days.slice(0, 3)
            RowLayout {
                id: day
                required property var modelData
                required property int index
                Layout.fillWidth: true
                spacing: 8
                Txt {
                    Layout.preferredWidth: 44
                    text: day.index === 0 ? "Today" : Qt.formatDate(new Date(day.modelData.date), "ddd")
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
                Icon {
                    icon: Weather.iconFor(day.modelData.code, true)
                    size: 16
                    color: Theme.accent(day.index * 3)
                }
                Txt {
                    text: Math.round(day.modelData.min) + "°"
                    font.pixelSize: 11
                    color: Theme.fgDim
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 5
                    radius: 3
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "#6cb8ff" }
                        GradientStop { position: 1; color: "#ffb35c" }
                    }
                }
                Txt {
                    text: Math.round(day.modelData.max) + "°"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }
            }
        }
    }

    TapHandler {
        onTapped: Weather.refresh()
    }
}
