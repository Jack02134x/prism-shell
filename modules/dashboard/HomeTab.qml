pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.common
import qs.services
import qs.widgets

Item {
    id: root

    property bool active: false

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        // ================= hero =================
        Card {
            Layout.fillWidth: true
            Layout.preferredHeight: 150
            shown: root.active
            clip: true

            ClippingRectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                Aurora {
                    anchors.fill: parent
                    intensity: 1
                    speed: 1
                    bg: Theme.surfaceLowest
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 20

                Avatar {
                    Layout.preferredWidth: 96
                    Layout.preferredHeight: 96
                    ring: 3.5
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Txt {
                        text: Utils.greeting() + ", " + Config.user.name
                        font.pixelSize: 28
                        font.weight: Font.Black
                        font.family: Theme.display
                        color: Theme.fg
                    }
                    Txt {
                        text: Qt.formatDate(clock.date, "dddd, d MMMM") + "  ·  up " + Utils.human(SysStats.uptime)
                        font.pixelSize: 13
                        color: Theme.alpha(Theme.fg, 0.8)
                    }
                    RowLayout {
                        spacing: 8
                        Repeater {
                            model: [
                                { icon: Power.icon, text: Power.percent + "%", c: 3 },
                                { icon: Net.icon, text: Net.name, c: 5 },
                                { icon: Power.profileIcon, text: Power.profileName, c: 1 },
                                { icon: "bell", text: Notifs.count + "", c: 7 }
                            ]
                            Rectangle {
                                required property var modelData
                                implicitHeight: 26
                                implicitWidth: chip.implicitWidth + 18
                                radius: 13
                                color: Theme.alpha(Theme.surface, 0.55)
                                border.width: 1
                                border.color: Theme.alpha(Theme.accent(modelData.c), 0.5)
                                RowLayout {
                                    id: chip
                                    anchors.centerIn: parent
                                    spacing: 5
                                    Icon {
                                        icon: parent.parent.modelData.icon
                                        size: 13
                                        color: Theme.accent(parent.parent.modelData.c)
                                    }
                                    Txt {
                                        text: parent.parent.modelData.text
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: Theme.fg
                                        Layout.maximumWidth: 140
                                    }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    spacing: 0
                    Txt {
                        Layout.alignment: Qt.AlignRight
                        text: Qt.formatTime(clock.date, "HH:mm")
                        font.pixelSize: 64
                        font.weight: Font.Thin
                        font.family: Theme.display
                        color: Theme.fg
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        visible: Weather.ready
                        spacing: 6
                        Icon {
                            icon: Weather.icon
                            size: 18
                            color: Weather.tint
                        }
                        Txt {
                            text: Weather.tempText + "  " + Weather.desc
                            font.pixelSize: 13
                            color: Theme.alpha(Theme.fg, 0.85)
                        }
                    }
                }
            }
        }

        // ================= body =================
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            // ---- column A: toggles + sliders ----
            ColumnLayout {
                Layout.preferredWidth: 372
                Layout.fillHeight: true
                spacing: 14

                Card {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    shown: root.active
                    delay: 60

                    GridLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        columns: 3
                        rowSpacing: 8
                        columnSpacing: 8

                        QuickTile {
                            Layout.fillWidth: true
                            icon: Net.icon
                            label: "Wi-Fi"
                            sub: Net.wifiEnabled ? (Net.active?.name ?? "On") : "Off"
                            checked: Net.wifiEnabled
                            accent: Theme.accent(0)
                            onClicked: Net.toggleWifi()
                            onRightClicked: Panels.openDashboard(4)
                        }
                        QuickTile {
                            Layout.fillWidth: true
                            icon: BT.icon
                            label: "Bluetooth"
                            sub: BT.summary
                            checked: BT.enabled
                            accent: Theme.accent(1)
                            onClicked: BT.toggle()
                            onRightClicked: Panels.openDashboard(4)
                        }
                        QuickTile {
                            Layout.fillWidth: true
                            icon: Notifs.dnd ? "bell_sleep" : "bell"
                            label: "Do not disturb"
                            sub: Notifs.dnd ? "Silenced" : "Off"
                            checked: Notifs.dnd
                            accent: Theme.accent(2)
                            onClicked: Notifs.dnd = !Notifs.dnd
                        }
                        QuickTile {
                            Layout.fillWidth: true
                            icon: Toggles.caffeine ? "coffee" : "coffee_outline"
                            label: "Caffeine"
                            sub: Toggles.caffeine ? "Awake" : "Off"
                            checked: Toggles.caffeine
                            accent: Theme.accent(3)
                            onClicked: Toggles.toggleCaffeine()
                        }
                        QuickTile {
                            Layout.fillWidth: true
                            icon: "waves"
                            label: "Study noise"
                            sub: Utils.capitalize(Toggles.noise)
                            checked: Toggles.noise !== "off"
                            accent: Theme.accent(4)
                            onClicked: Toggles.cycleNoise()
                            onRightClicked: Toggles.setNoise("off")
                        }
                        QuickTile {
                            Layout.fillWidth: true
                            icon: Audio.micIcon
                            label: "Microphone"
                            sub: Audio.micMuted ? "Muted" : "Live"
                            checked: !Audio.micMuted
                            accent: Theme.accent(5)
                            onClicked: Audio.toggleMic()
                        }
                        QuickTile {
                            Layout.fillWidth: true
                            icon: Power.profileIcon
                            label: "Power"
                            sub: Power.profileName
                            checked: Power.profile !== 1
                            accent: Theme.accent(6)
                            onClicked: Power.cycleProfile()
                        }
                        QuickTile {
                            Layout.fillWidth: true
                            icon: "gamepad_variant"
                            label: "Game mode"
                            sub: Toggles.gameMode ? "Eye-candy off" : "Off"
                            checked: Toggles.gameMode
                            accent: Theme.accent(7)
                            onClicked: Toggles.toggleGameMode()
                        }
                        QuickTile {
                            Layout.fillWidth: true
                            icon: "weather_night"
                            label: "Warm screen"
                            sub: Toggles.warm ? "On" : "Off"
                            checked: Toggles.warm
                            accent: Theme.accent(8)
                            onClicked: Toggles.toggleWarm()
                        }
                        QuickTile {
                            Layout.fillWidth: true
                            icon: "equalizer"
                            label: "GLava"
                            sub: Toggles.glava ? "Running" : "Off"
                            checked: Toggles.glava
                            accent: Theme.accent(9)
                            onClicked: Toggles.toggleGlava()
                        }
                        QuickTile {
                            Layout.fillWidth: true
                            icon: "record_rec"
                            label: "Record"
                            sub: Toggles.recording ? "Recording…" : "Region"
                            checked: Toggles.recording
                            accent: "#ff5a6a"
                            onClicked: {
                                Panels.dashboard = false;
                                Toggles.toggleRecording();
                            }
                        }
                        QuickTile {
                            Layout.fillWidth: true
                            icon: "monitor_screenshot"
                            label: "Screenshot"
                            sub: "Menu"
                            accent: Theme.accent(1)
                            onClicked: Shot.capture("region", "both", 0)
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    Layout.preferredHeight: sliders.implicitHeight + 28
                    shown: root.active
                    delay: 120
                    ColumnLayout {
                        id: sliders
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10
                        StyledSlider {
                            Layout.fillWidth: true
                            icon: Audio.icon
                            value: Audio.volume
                            max: 1.5
                            softMax: 1
                            accent: Theme.accent(0)
                            accent2: Theme.accent(2)
                            onMoved: v => Audio.setVolume(v)
                            onIconClicked: Audio.toggleMute()
                        }
                        StyledSlider {
                            Layout.fillWidth: true
                            icon: Audio.micIcon
                            value: Audio.micVolume
                            max: 1.5
                            softMax: 1
                            accent: Theme.accent(5)
                            accent2: Theme.accent(7)
                            onMoved: v => Audio.setMic(v)
                            onIconClicked: Audio.toggleMic()
                        }
                        StyledSlider {
                            Layout.fillWidth: true
                            visible: Brightness.available
                            icon: Brightness.icon
                            value: Brightness.value
                            accent: Theme.accent(1)
                            accent2: Theme.accent(3)
                            onMoved: v => Brightness.set(v)
                        }
                    }
                }
            }

            // ---- column B: media + screen time ----
            ColumnLayout {
                Layout.preferredWidth: 400
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14

                MediaCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 246
                    shown: root.active
                    delay: 90
                }

                Card {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    shown: root.active
                    delay: 150

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8
                        RowLayout {
                            SectionTitle {
                                Layout.fillWidth: true
                                icon: "timer_outline"
                                text: "Screen time today"
                                accent: Theme.accent(4)
                            }
                            Txt {
                                text: ScreenTime.available ? Utils.human(ScreenTime.today) : "—"
                                font.pixelSize: 20
                                font.weight: Font.Black
                                font.family: Theme.display
                                color: Theme.accent(4)
                            }
                        }
                        Repeater {
                            model: ScreenTime.apps.slice(0, 4)
                            ColumnLayout {
                                id: stRow
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                spacing: 3
                                RowLayout {
                                    Layout.fillWidth: true
                                    AppIcon {
                                        size: 16
                                        source: Hypr.iconFor(stRow.modelData.name.toLowerCase())
                                        fallbackColor: Theme.accent(stRow.index * 2)
                                    }
                                    Txt {
                                        Layout.fillWidth: true
                                        text: stRow.modelData.name + "  ·  " + (stRow.modelData.details[0]?.name ?? "")
                                        font.pixelSize: 12
                                    }
                                    Txt {
                                        text: Utils.human(stRow.modelData.total)
                                        font.pixelSize: 11
                                        font.family: Theme.mono
                                        color: Theme.fgDim
                                    }
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 6
                                    radius: 3
                                    color: Theme.alpha(Theme.fg, 0.07)
                                    Rectangle {
                                        height: parent.height
                                        radius: 3
                                        width: root.active ? parent.width * stRow.modelData.total / Math.max(1, ScreenTime.apps[0]?.total ?? 1) : 0
                                        color: ScreenTime.colorFor(stRow.modelData.name)
                                        Behavior on width { NumAnim { duration: Motion.slower; easing.bezierCurve: Motion.spatial } }
                                    }
                                }
                            }
                        }
                        Item { Layout.fillHeight: true }
                        Txt {
                            visible: !ScreenTime.available
                            text: "Screen time tracker data not found"
                            color: Theme.fgDim
                            font.pixelSize: 12
                        }
                    }
                    TapHandler {
                        onTapped: Panels.openDashboard(3)
                    }
                }
            }

            // ---- column C: weather + phone + mini stats ----
            ColumnLayout {
                Layout.preferredWidth: 330
                Layout.fillHeight: true
                spacing: 14

                WeatherCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    shown: root.active
                    delay: 120
                }

                PhoneCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 112
                    shown: root.active
                    delay: 180
                }

                Card {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 92
                    shown: root.active
                    delay: 210
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6
                        Repeater {
                            model: [
                                { label: "CPU", v: SysStats.cpu, t: Math.round(SysStats.cpu * 100) + "%", c: 0 },
                                { label: "RAM", v: SysStats.mem, t: Math.round(SysStats.mem * 100) + "%", c: 3 },
                                { label: "TEMP", v: SysStats.cpuTemp / 100, t: Math.round(SysStats.cpuTemp) + "°", c: 6 },
                                { label: "DISK", v: SysStats.diskTotal > 0 ? SysStats.diskUsed / SysStats.diskTotal : 0, t: Math.round(SysStats.diskTotal > 0 ? SysStats.diskUsed / SysStats.diskTotal * 100 : 0) + "%", c: 8 }
                            ]
                            ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 2
                                Ring {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: 48
                                    Layout.preferredHeight: 48
                                    value: parent.modelData.v
                                    thickness: 5
                                    color: Theme.accent(parent.modelData.c)
                                    Txt {
                                        anchors.centerIn: parent
                                        text: parent.parent.modelData.t
                                        font.pixelSize: 11
                                        font.weight: Font.Black
                                        font.family: Theme.mono
                                    }
                                }
                                Txt {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: parent.modelData.label
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    color: Theme.fgDim
                                }
                            }
                        }
                    }
                    TapHandler {
                        onTapped: Panels.openDashboard(2)
                    }
                }
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
