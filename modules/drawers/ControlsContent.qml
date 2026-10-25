pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.services
import qs.widgets
import qs.modules.dashboard

// Left drawer: sliders, quick toggles, now playing, system at a glance.
Flickable {
    id: root

    property bool active: false

    contentHeight: col.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: col
        width: root.width
        spacing: 14

        // header
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Avatar {
                Layout.preferredWidth: 52
                Layout.preferredHeight: 52
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Txt {
                    text: Utils.greeting() + ", " + Config.user.name
                    font.pixelSize: 16
                    font.weight: Font.Black
                    font.family: Theme.display
                }
                Txt {
                    text: "up " + Utils.human(SysStats.uptime) + "  ·  " + Power.percent + "%  ·  " + Power.profileName
                    font.pixelSize: 11
                    color: Theme.fgDim
                }
            }
            IconBtn {
                icon: "code_braces"
                size: 34
                tooltip: "Quick edit"
                onClicked: Panels.show("edit")
            }
            IconBtn {
                icon: "view_dashboard"
                size: 34
                tooltip: "Dashboard"
                onClicked: Panels.openDashboard(0)
            }
            IconBtn {
                icon: "power"
                size: 34
                iconColor: hovered ? Theme.fgError : Theme.error
                idleColor: hovered ? Theme.error : "transparent"
                tooltip: "Power"
                onClicked: Panels.show("power")
            }
        }

        // sliders
        Card {
            Layout.fillWidth: true
            implicitHeight: sliders.implicitHeight + 28
            shown: root.active
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

        // toggles
        GridLayout {
            Layout.fillWidth: true
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
                label: "Silence"
                sub: Notifs.dnd ? "DND on" : "Off"
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
                label: "Noise"
                sub: Utils.capitalize(Toggles.noise)
                checked: Toggles.noise !== "off"
                accent: Theme.accent(4)
                onClicked: Toggles.cycleNoise()
                onRightClicked: Toggles.setNoise("off")
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
                sub: Toggles.gameMode ? "On" : "Off"
                checked: Toggles.gameMode
                accent: Theme.accent(7)
                onClicked: Toggles.toggleGameMode()
            }
            QuickTile {
                Layout.fillWidth: true
                icon: "weather_night"
                label: "Warm"
                sub: Toggles.warm ? "On" : "Off"
                checked: Toggles.warm
                accent: Theme.accent(8)
                onClicked: Toggles.toggleWarm()
            }
            QuickTile {
                Layout.fillWidth: true
                icon: Focus.working ? "timer_outline" : Focus.active ? "coffee" : "timer_outline"
                label: Focus.active ? Focus.label : "Focus"
                sub: Focus.active ? Focus.leftText + (Focus.paused ? " paused" : "") : Config.focus.workMinutes + " min"
                checked: Focus.active
                accent: Focus.active ? Focus.tint : Theme.accent(0)
                onClicked: Focus.active ? Focus.pause() : Focus.start()
                onRightClicked: Focus.stop()
            }
            QuickTile {
                Layout.fillWidth: true
                icon: Chrono.timerRunning ? "timer_sand" : Chrono.swRunning ? "timer_outline" : "alarm"
                label: "Clock"
                sub: Chrono.timerRunning ? Utils.hms(Chrono.timerLeft / 1000) + " left" : Chrono.swRunning ? Utils.hms(Chrono.swElapsed / 1000) : Chrono.nextAlarm ? "Alarm in " + Utils.human(Chrono.nextAlarm.inMs / 1000) : "Timer · alarms"
                checked: Chrono.open || Chrono.timerRunning || Chrono.swRunning
                accent: Theme.grad1
                onClicked: {
                    Chrono.toggle();
                    Panels.controls = false;
                }
            }
            QuickTile {
                Layout.fillWidth: true
                icon: "tune_variant"
                label: "EasyEffects"
                sub: Toggles.easyEffects ? "Running" : "Off"
                checked: Toggles.easyEffects
                accent: Theme.accent(3)
                onClicked: Toggles.toggleEasyEffects()
            }
            QuickTile {
                Layout.fillWidth: true
                icon: "dock_window"
                label: "Windows"
                sub: Hypr.toplevels.length + " open"
                accent: Theme.accent(5)
                onClicked: Panels.show("switcher")
            }
            QuickTile {
                Layout.fillWidth: true
                icon: Wallpapers.light ? "weather_sunny" : "weather_night"
                label: Wallpapers.light ? "Light" : "Dark"
                sub: "Theme"
                checked: Wallpapers.light
                accent: "#f2b84b"
                onClicked: Wallpapers.toggleMode()
            }
            QuickTile {
                Layout.fillWidth: true
                icon: "monitor_screenshot"
                label: "Capture"
                sub: Toggles.recording ? "Recording…" : "Menu"
                checked: Toggles.recording
                accent: Theme.accent(9)
                onClicked: Shot.capture("region", "both", 0)
            }
            // your own tiles (config.json: drawers.customTiles), each runs its command
            Repeater {
                model: Config.drawers.customTiles ?? []
                QuickTile {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    icon: modelData.icon || "star_four_points"
                    label: modelData.label || "Custom"
                    sub: modelData.sub || ""
                    accent: Theme.accent(index * 2 + 1)
                    onClicked: {
                        if (modelData.command) {
                            Quickshell.execDetached(["sh", "-c", modelData.command]);
                            Panels.controls = false;
                        }
                    }
                }
            }
        }

        MediaCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 220
            shown: root.active
            delay: 80
            visible: Media.hasPlayer
        }

        // system at a glance
        Card {
            Layout.fillWidth: true
            implicitHeight: 96
            shown: root.active
            delay: 120
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6
                Repeater {
                    model: [
                        { label: "CPU", v: SysStats.cpu, t: Math.round(SysStats.cpu * 100) + "%", c: 0 },
                        { label: "RAM", v: SysStats.mem, t: Math.round(SysStats.mem * 100) + "%", c: 3 },
                        { label: "TEMP", v: SysStats.cpuTemp / 100, t: Math.round(SysStats.cpuTemp) + "°", c: 6 },
                        { label: "BATT", v: Power.level, t: Power.percent + "%", c: 8 }
                    ]
                    ColumnLayout {
                        id: ring
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 2
                        Ring {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 50
                            Layout.preferredHeight: 50
                            value: ring.modelData.v
                            thickness: 5
                            color: Theme.accent(ring.modelData.c)
                            Txt {
                                anchors.centerIn: parent
                                text: ring.modelData.t
                                font.pixelSize: 11
                                font.weight: Font.Black
                                font.family: Theme.mono
                            }
                        }
                        Txt {
                            Layout.alignment: Qt.AlignHCenter
                            text: ring.modelData.label
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

        // weather strip
        Card {
            Layout.fillWidth: true
            implicitHeight: 64
            shown: root.active
            delay: 160
            visible: Weather.ready
            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10
                Icon {
                    icon: Weather.icon
                    size: 30
                    color: Weather.tint
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Txt {
                        text: Weather.tempText + "  " + Weather.desc
                        font.weight: Font.Bold
                    }
                    Txt {
                        text: Weather.location + " · feels " + Math.round(Weather.feels) + "°"
                        font.pixelSize: 11
                        color: Theme.fgDim
                    }
                }
            }
        }
    }
}
